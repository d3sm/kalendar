import ExpoModulesCore
import SwiftUI

/// The native RN view. Hosts the SwiftUI calendar via a UIHostingController and
/// bridges day selection back to JS through an EventDispatcher.
class KalendarView: ExpoView {
  let model = KalendarModel()
  let onRangeChange = EventDispatcher()
  let onDayPress = EventDispatcher()
  let onDayOpen = EventDispatcher()
  let onDayLongPress = EventDispatcher()
  let onEventPress = EventDispatcher()
  let onEventLongPress = EventDispatcher()
  let onEventChange = EventDispatcher()
  let onEventDelete = EventDispatcher()
  let onSlotPress = EventDispatcher()
  let onLevelChange = EventDispatcher()
  let onMonthChange = EventDispatcher()
  let onExpandedChange = EventDispatcher()
  private var hostingController: UIHostingController<KalendarSwiftUIView>?

  required init(appContext: AppContext? = nil) {
    super.init(appContext: appContext)
    clipsToBounds = true
    backgroundColor = .clear

    model.onRangeChange = { [weak self] start, end in
      guard let self else { return }
      var payload: [String: Any] = ["start": KalendarModel.key(start)]
      if let end { payload["end"] = KalendarModel.key(end) }
      self.onRangeChange(payload)
    }
    model.onSelect = { [weak self] date in
      guard let self else { return }
      let key = KalendarModel.key(date)
      self.onDayPress(["date": key, "events": self.model.dayEventsPayload(key)])
    }
    model.onOpenDay = { [weak self] date in
      self?.onDayOpen(["date": KalendarModel.key(date)])
    }
    model.onEventTap = { [weak self] ev in
      self?.onEventPress(Self.eventPayload(ev, ev.startMin, ev.endMin))
    }
    model.onEventHold = { [weak self] ev in
      self?.onEventLongPress(Self.eventPayload(ev, ev.startMin, ev.endMin))
    }
    model.onEventMove = { [weak self] ev, start, end in
      self?.onEventChange(Self.eventPayload(ev, start, end))
    }
    model.onEventEdit = { [weak self] ev, title, start, end, colorHex, allDay in
      self?.onEventChange(Self.eventPayload(ev, start, end, title: title, color: colorHex, allDay: allDay))
    }
    model.onEventDelete = { [weak self] ev in
      var p: [String: Any] = ["date": ev.key]
      if let id = ev.srcId { p["id"] = id }
      self?.onEventDelete(p)
    }
    model.onDayHold = { [weak self] date in
      guard let self else { return }
      let key = KalendarModel.key(date)
      self.onDayLongPress(["date": key, "events": self.model.dayEventsPayload(key)])
    }
    model.onSlotHold = { [weak self] key, start, end in
      self?.onSlotPress(["date": key, "start": KalendarModel.hm(start), "end": KalendarModel.hm(end)])
    }
    model.onLevelChange = { [weak self] level in
      self?.onLevelChange(["level": level])
    }
    model.onMonthChange = { [weak self] date in
      self?.onMonthChange(["month": KalendarModel.monthKey(date)])
    }
    model.onExpandedChange = { [weak self] expanded in
      self?.onExpandedChange(["expanded": expanded])
    }

    let host = UIHostingController(rootView: KalendarSwiftUIView(model: model))
    host.view.backgroundColor = .clear
    host.view.translatesAutoresizingMaskIntoConstraints = false
    addSubview(host.view)
    NSLayoutConstraint.activate([
      host.view.topAnchor.constraint(equalTo: topAnchor),
      host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
      host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: trailingAnchor)
    ])
    self.hostingController = host
  }

  /// Adopt the hosting controller into the VC hierarchy while in a window (SwiftUI
  /// `.sheet` can't present from a detached controller), and — crucially — detach
  /// it when we leave, or the ancestor VC's `children` keeps the whole SwiftUI tree
  /// and `model` alive after every unmount.
  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard let host = hostingController else { return }
    if window == nil { detachHost(host); return }
    guard host.parent == nil else { return }
    var responder: UIResponder? = next
    while let r = responder {
      if let vc = r as? UIViewController {
        vc.addChild(host)
        host.didMove(toParent: vc)
        break
      }
      responder = r.next
    }
  }

  private func detachHost(_ host: UIHostingController<KalendarSwiftUIView>) {
    guard host.parent != nil else { return }
    host.willMove(toParent: nil)
    host.removeFromParent()
  }

  deinit {
    if let host = hostingController { detachHost(host) }
  }

  private static func eventPayload(
    _ ev: KalEvent, _ start: Int, _ end: Int,
    title: String? = nil, color: String? = nil, allDay: Bool? = nil
  ) -> [String: Any] {
    var p: [String: Any] = [
      "date": ev.key,
      "allDay": allDay ?? ev.allDay,
      "title": title ?? ev.title,
      "start": KalendarModel.hm(start),
      "end": KalendarModel.hm(end)
    ]
    if let id = ev.srcId { p["id"] = id }
    if let hex = color ?? ev.colorHex { p["color"] = hex }
    return p
  }
}
