import SwiftUI

/// Live month title for the continuous scroll header; only the month string
/// re-renders, leaving the glass header elements undisturbed.
final class ContHeaderStore: ObservableObject {
  @Published var month = Date()
  var topIdx: Int?
  var scrolling = false
  var scrollGen = 0
}

struct ContinuousMonthTitle: View {
  @ObservedObject var store: ContHeaderStore
  let model: KalendarModel
  let calendar: Calendar
  var body: some View {
    Text(mwFormatter("LLLL yyyy", calendar, model.locale).string(from: store.month))
      .font(.system(.title2, design: model.fontDesign).weight(.semibold))
      .foregroundStyle(model.textColor)
      .contentTransition(.numericText())
  }
}

/// `scrollPosition(id:)` / `scrollTargetLayout()` are iOS 17+.
struct ScrollPositionIf: ViewModifier {
  @Binding var id: Int?
  func body(content: Content) -> some View {
    if #available(iOS 17.0, *) { content.scrollPosition(id: $id) } else { content }
  }
}

struct ScrollTargetLayoutIf: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 17.0, *) { content.scrollTargetLayout() } else { content }
  }
}

struct ContinuousMonths: View {
  @ObservedObject var model: KalendarModel
  @ObservedObject var headerStore: ContHeaderStore
  let calendar: Calendar
  let maxLanes: Int
  let namespace: Namespace.ID
  let glassActive: Bool
  let onTap: (Date, String) -> Void
  let onLongPress: (Date) -> Void

  @State private var contBase: Date?
  @State private var contReady = false

  private let contCount = 2400
  private let contCenter = 1200

  var body: some View {
    let base = contBase ?? weekStartOf(firstOfMonth(model.monthAnchor))
    // One width read for the whole list: every week is full-width so the column
    // width is constant and rows don't each need their own GeometryReader.
    return GeometryReader { geo in
      let colW = geo.size.width / 7
      ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
          LazyVStack(spacing: 2) {
            ForEach(0..<contCount, id: \.self) { i in
              contWeekBlock(calendar.date(byAdding: .weekOfYear, value: i - contCenter, to: base) ?? base, colW: colW)
                .id(i)
            }
          }
          .modifier(ScrollTargetLayoutIf())
        }
        // Write-only (get is nil): reports the top row but never drives position,
        // so it can't fight `proxy.scrollTo` by re-pinning a stale index.
        .modifier(ScrollPositionIf(id: Binding(
          get: { nil },
          set: { headerStore.topIdx = $0; syncMonthOnScroll(base: base) }
        )))
        .onAppear {
          if contBase == nil { contBase = base }
          headerStore.topIdx = contCenter
          headerStore.month = firstOfMonth(model.monthAnchor)
          // LazyVStack row-height estimation makes a single far-index jump undershoot;
          // re-scroll across a couple of runloops so it lands true once rows measure.
          proxy.scrollTo(contCenter, anchor: .top)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            proxy.scrollTo(contCenter, anchor: .top)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
              proxy.scrollTo(contCenter, anchor: .top)
              contReady = true
            }
          }
        }
        .onChange(of: model.monthAnchor) { new in
          guard contReady else { return }
          headerStore.month = firstOfMonth(new)
          // An external `month` change scrolls there; skip while the user scrolls
          // or a month echo is feeding back mid-fling, so nothing fights.
          guard !headerStore.scrolling, let top = headerStore.topIdx else { return }
          let target = contIndex(for: new, base: base)
          guard abs(target - top) > 1 else { return }
          withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(target, anchor: .top) }
        }
      }
    }
  }

  @ViewBuilder
  private func contWeekBlock(_ weekStart: Date, colW: CGFloat) -> some View {
    let days = weekDays(for: weekStart)
    let dayKeys = days.map { $0.map { KalendarModel.key($0) } }
    let spans = model.spanningEvents
    let bars = mwLayoutMonthBars(
      dayKeys,
      spans.map { MWSpanEvent(uid: $0.id, startKey: $0.key, endKey: $0.endKey) },
      maxLanes: maxLanes
    )
    let colorFor = Dictionary(spans.map { ($0.id, $0.color ?? model.accent) }, uniquingKeysWith: { a, _ in a })
    let hasSpans = !spans.isEmpty
    VStack(alignment: .leading, spacing: 4) {
      if let monthStart = monthStartInWeek(days) {
        Text(mwFormatter("LLLL yyyy", calendar, model.locale).string(from: monthStart))
          .font(.system(.title3, design: model.fontDesign).weight(.bold))
          .foregroundStyle(model.textColor)
          .padding(.top, 12)
          .padding(.leading, 2)
      }
      MonthWeekRow(
        model: model, days: days, dayKeys: dayKeys, week: 0,
        bars: bars, colorFor: colorFor, hasBars: hasSpans,
        calendar: calendar, glassActive: glassActive, namespace: namespace,
        onTap: onTap, onLongPress: onLongPress, colW: colW
      )
    }
  }

  private func weekDays(for date: Date) -> [Date?] {
    guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
    return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start) }
  }

  private func weekStartOf(_ d: Date) -> Date {
    calendar.dateInterval(of: .weekOfYear, for: d)?.start ?? d
  }

  private func firstOfMonth(_ date: Date) -> Date {
    calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
  }

  private func monthStartInWeek(_ days: [Date?]) -> Date? {
    days.compactMap { $0 }.first { calendar.component(.day, from: $0) == 1 }
  }

  private func contIndex(for month: Date, base: Date) -> Int {
    let target = weekStartOf(firstOfMonth(month))
    let weeks = calendar.dateComponents([.weekOfYear], from: base, to: target).weekOfYear ?? 0
    return contCenter + weeks
  }

  private func syncMonthOnScroll(base: Date) {
    guard contReady, let idx = headerStore.topIdx else { return }
    headerStore.scrolling = true
    headerStore.scrollGen += 1
    let gen = headerStore.scrollGen
    let live = monthForIndex(idx, base: base)
    if KalendarModel.monthKey(live) != KalendarModel.monthKey(headerStore.month) {
      headerStore.month = live
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      guard gen == headerStore.scrollGen else { return }
      headerStore.scrolling = false
      guard let idx2 = headerStore.topIdx else { return }
      let m = monthForIndex(idx2, base: base)
      guard KalendarModel.monthKey(m) != KalendarModel.monthKey(model.monthAnchor) else { return }
      model.monthAnchor = m
      model.onMonthChange?(m)
    }
  }

  /// The month that owns the top-most visible week (mid-week day so a week
  /// straddling two months resolves to the one it mostly belongs to).
  private func monthForIndex(_ idx: Int, base: Date) -> Date {
    let weekStart = calendar.date(byAdding: .weekOfYear, value: idx - contCenter, to: base) ?? base
    let mid = calendar.date(byAdding: .day, value: 3, to: weekStart) ?? weekStart
    return firstOfMonth(mid)
  }
}
