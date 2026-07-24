import SwiftUI

/// A recycling horizontal pager: three hosting controllers, created once and
/// rebound to a new date on settle instead of rebuilt. Reusing the views keeps
/// their Liquid Glass from re-initializing (and flashing) on every swipe.
struct PagedView<Content: View>: UIViewControllerRepresentable {
  /// Observed so a page rebuilds when the model changes (events edited, selection
  /// moved) — the reused pages otherwise track only their date and go stale.
  @ObservedObject var model: KalendarModel
  let current: Date
  let unit: Calendar.Component
  let calendar: Calendar
  let key: (Date) -> String
  var locked = false
  @ViewBuilder let content: (Date) -> Content
  let onCommit: (Date) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIViewController(context: Context) -> MWPagerVC {
    context.coordinator.makeVC()
  }

  func updateUIViewController(_ vc: MWPagerVC, context: Context) {
    context.coordinator.parent = self
    context.coordinator.apply(current: current, locked: locked)
  }

  final class Coordinator: NSObject, UIScrollViewDelegate {
    var parent: PagedView
    private var boxes: [MWPageBox] = []
    private weak var vc: MWPagerVC?
    private var dragging = false
    private let slots = [-1, 0, 1]

    init(_ parent: PagedView) { self.parent = parent }

    func makeVC() -> MWPagerVC {
      boxes = slots.map { MWPageBox(shifted(parent.current, $0)) }
      let build = parent.content
      let model = parent.model
      let hosts = boxes.map { box -> UIHostingController<AnyView> in
        let h = UIHostingController(rootView: AnyView(MWPageContent(box: box, model: model) { build($0) }))
        h.view.backgroundColor = .clear
        return h
      }
      let vc = MWPagerVC(hosts: hosts, delegate: self)
      self.vc = vc
      return vc
    }

    private func shifted(_ d: Date, _ by: Int) -> Date {
      parent.calendar.date(byAdding: parent.unit, value: by, to: d) ?? d
    }

    /// External `current` change (chevron, open a day, goToToday, JS): rebind
    /// the three pages around it and recenter instantly. Animated programmatic
    /// scrolling is fragile — a layout pass mid-scroll cancels it — so only real
    /// user swipes animate; a chevron just jumps to the new page.
    func apply(current: Date, locked: Bool) {
      guard let vc else { return }
      vc.scroll.isScrollEnabled = !locked
      guard !dragging, parent.key(boxes[1].date) != parent.key(current) else { return }
      recenter(around: current)
    }

    private func recenter(around date: Date) {
      for (i, off) in slots.enumerated() { boxes[i].date = shifted(date, off) }
      vc?.scrollToPage(1, animated: false)
    }

    func scrollViewWillBeginDragging(_ sv: UIScrollView) { dragging = true }
    func scrollViewDidEndDragging(_ sv: UIScrollView, willDecelerate: Bool) { if !willDecelerate { settle() } }
    func scrollViewDidEndDecelerating(_ sv: UIScrollView) { settle() }
    func scrollViewDidEndScrollingAnimation(_ sv: UIScrollView) { settle() }

    private func settle() {
      dragging = false
      guard let vc, vc.laidOut, vc.pageWidth > 0 else { return }
      let page = Int((vc.scroll.contentOffset.x / vc.pageWidth).rounded())
      guard page != 1, page >= 0, page < boxes.count else { return }
      let landed = boxes[page].date
      recenter(around: landed)
      parent.onCommit(landed)
    }
  }
}

/// One reused page: the observable date drives the content, so rebinding it
/// re-renders in place (keeping glass warm) instead of re-creating the view.
private final class MWPageBox: ObservableObject {
  @Published var date: Date
  init(_ date: Date) { self.date = date }
}

private struct MWPageContent<Content: View>: View {
  @ObservedObject var box: MWPageBox
  /// Also observed: the date alone can't tell the page the model's contents moved.
  @ObservedObject var model: KalendarModel
  @ViewBuilder let build: (Date) -> Content
  var body: some View { build(box.date) }
}

/// Paging scroll view that only claims horizontal-dominant drags. Vertical
/// drags and stationary presses fall through to the content, so the day
/// timeline's scroll, slot-create long-press, and event-chip reschedule keep
/// working inside the pager instead of being swallowed by it.
final class MWPagingScrollView: UIScrollView {
  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer == panGestureRecognizer {
      let v = panGestureRecognizer.velocity(in: self)
      return abs(v.x) > abs(v.y)
    }
    return super.gestureRecognizerShouldBegin(gestureRecognizer)
  }
}

/// Hosts three reused pages in a paging UIScrollView.
final class MWPagerVC: UIViewController {
  let scroll = MWPagingScrollView()
  private let hosts: [UIViewController]
  private(set) var laidOut = false
  var pageWidth: CGFloat { view.bounds.width }

  init(hosts: [UIViewController], delegate: UIScrollViewDelegate) {
    self.hosts = hosts
    super.init(nibName: nil, bundle: nil)
    scroll.isPagingEnabled = true
    scroll.showsHorizontalScrollIndicator = false
    scroll.bounces = false
    scroll.delegate = delegate
    scroll.backgroundColor = .clear
    scroll.contentInsetAdjustmentBehavior = .never
    // Deliver touches to content immediately so long-press gestures (slot
    // create, chip lift) start without the scroll view's tap-delay.
    scroll.delaysContentTouches = false
  }
  @MainActor required dynamic init?(coder: NSCoder) { fatalError("unused") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(scroll)
    for h in hosts { addChild(h); scroll.addSubview(h.view); h.didMove(toParent: self) }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let w = view.bounds.width, h = view.bounds.height
    guard w > 0, h > 0 else { return }
    scroll.frame = view.bounds
    scroll.contentSize = CGSize(width: w * CGFloat(hosts.count), height: h)
    for (i, host) in hosts.enumerated() {
      host.view.frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h)
    }
    if !laidOut { scroll.contentOffset = CGPoint(x: w, y: 0); laidOut = true }
  }

  func scrollToPage(_ page: Int, animated: Bool) {
    scroll.setContentOffset(CGPoint(x: CGFloat(page) * pageWidth, y: 0), animated: animated)
  }
}
