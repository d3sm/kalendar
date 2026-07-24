import ExpoModulesCore
import SwiftUI

/// A single timed event, decoded from JS. Times are "HH:mm"; color is a hex string.
struct EventRecord: Record {
  @Field var id: String?
  @Field var date: String = ""
  @Field var endDate: String?
  @Field var allDay: Bool = false
  @Field var start: String?
  @Field var end: String?
  @Field var title: String = ""
  @Field var color: String?
}

public class KalendarModule: Module {
  public func definition() -> ModuleDefinition {
    Name("Kalendar")

    View(KalendarView.self) {
      Events(
        "onDayPress", "onDayOpen", "onDayLongPress", "onEventPress", "onEventLongPress",
        "onEventChange", "onEventDelete", "onSlotPress", "onLevelChange", "onMonthChange",
        "onExpandedChange"
      )

      // Imperative navigation, callable on the view's ref. Runs on the main queue.
      AsyncFunction("goToToday") { (v: KalendarView) in
        let today = KalendarModel.key(Date())
        v.model.setMonth(iso: today)
        v.model.selectedKeys = [today]
      }
      AsyncFunction("scrollToDate") { (v: KalendarView, date: String) in
        v.model.setMonth(iso: date)
        v.model.selectedKeys = [date]
      }

      // Styling
      Prop("accentColor") { (v: KalendarView, c: UIColor?) in
        if let c { v.model.accent = Color(uiColor: c) }
      }
      Prop("textColor") { (v: KalendarView, c: UIColor?) in
        if let c { v.model.textColor = Color(uiColor: c) }
      }
      Prop("mutedColor") { (v: KalendarView, c: UIColor?) in
        if let c { v.model.mutedColor = Color(uiColor: c) }
      }
      Prop("backgroundColor") { (v: KalendarView, c: UIColor?) in
        v.model.background = c.map { Color(uiColor: $0) } ?? .clear
      }
      Prop("selectedTextColor") { (v: KalendarView, c: UIColor?) in
        if let c { v.model.selectedTextColor = Color(uiColor: c) }
      }
      Prop("cornerRadius") { (v: KalendarView, value: Double?) in
        v.model.cornerRadius = CGFloat(value ?? 14)
      }
      Prop("selectionShape") { (v: KalendarView, value: String?) in
        v.model.selectionShape = SelectionShape(rawValue: value ?? "circle") ?? .circle
      }
      Prop("fontDesign") { (v: KalendarView, value: String?) in
        v.model.fontDesign = mapFontDesign(value)
      }
      Prop("firstWeekday") { (v: KalendarView, value: Int?) in
        v.model.firstWeekday = value ?? Calendar.current.firstWeekday
      }
      Prop("locale") { (v: KalendarView, value: String?) in
        v.model.locale = value.map { Locale(identifier: $0) } ?? .current
      }
      Prop("timeFormat") { (v: KalendarView, value: String?) in
        v.model.timeFormat = TimeFormat(rawValue: value ?? "locale") ?? .locale
      }
      Prop("material") { (v: KalendarView, value: String?) in
        v.model.glass = (value ?? "glass") != "solid"
      }
      Prop("glassVariant") { (v: KalendarView, value: String?) in
        v.model.glassVariant = GlassVariant(rawValue: value ?? "regular") ?? .regular
      }

      // Display
      Prop("month") { (v: KalendarView, value: String?) in
        v.model.setMonth(iso: value)
      }

      // Apple-style hierarchy (opt-in) + day view
      Prop("yearView") { (v: KalendarView, value: Bool?) in
        v.model.yearViewEnabled = value ?? false
      }
      Prop("dayView") { (v: KalendarView, value: Bool?) in
        v.model.dayViewEnabled = value ?? false
      }
      Prop("expandable") { (v: KalendarView, value: Bool?) in
        v.model.expandableEnabled = value ?? false
      }
      Prop("expanded") { (v: KalendarView, value: Bool?) in
        v.model.expandedProp = value
      }
      Prop("daySheet") { (v: KalendarView, value: Bool?) in
        v.model.daySheetEnabled = value ?? false
      }
      Prop("scroll") { (v: KalendarView, value: String?) in
        v.model.scrollContinuous = value == "continuous"
      }
      Prop("level") { (v: KalendarView, value: String?) in
        v.model.levelProp = value
      }
      Prop("labels") { (v: KalendarView, value: [String: String]?) in
        v.model.labels = value ?? [:]
      }
      Prop("eventEditor") { (v: KalendarView, value: Bool?) in
        v.model.eventEditorEnabled = value ?? false
      }
      Prop("readOnly") { (v: KalendarView, value: Bool?) in
        v.model.readOnly = value ?? false
      }
      Prop("testID") { (v: KalendarView, value: String?) in
        v.accessibilityIdentifier = value
      }
      Prop("accessibilityLabel") { (v: KalendarView, value: String?) in
        v.accessibilityLabel = value
      }
      Prop("accessibilityHint") { (v: KalendarView, value: String?) in
        v.accessibilityHint = value
      }
      Prop("haptics") { (v: KalendarView, value: Bool?) in
        v.model.hapticsEnabled = value ?? true
      }
      Prop("dayStartHour") { (v: KalendarView, value: Int?) in
        v.model.dayStartHour = value ?? 0
      }
      Prop("dayEndHour") { (v: KalendarView, value: Int?) in
        v.model.dayEndHour = value ?? 24
      }
      Prop("showNowIndicator") { (v: KalendarView, value: Bool?) in
        v.model.showNowIndicator = value ?? true
      }
      Prop("initialScrollTime") { (v: KalendarView, value: String?) in
        v.model.initialScrollTime = value
      }
      Prop("events") { (v: KalendarView, value: [EventRecord]?) in
        // Fresh events from the consumer bake in any optimistic offset — drop them.
        v.model.dragOffsets = [:]
        v.model.events = (value ?? []).compactMap { r in
          guard !r.date.isEmpty else { return nil }
          let start = mwParseMinutes(r.start, fallback: 0)
          let end = mwParseMinutes(r.end, fallback: start + 60)
          return KalEvent(
            srcId: r.id,
            key: r.date,
            endKey: (r.endDate.map { $0 >= r.date ? $0 : r.date }) ?? r.date,
            allDay: r.allDay,
            startMin: start,
            endMin: max(start + 15, end),
            title: r.title,
            color: r.color.flatMap { Color(hexString: $0) },
            colorHex: r.color
          )
        }
      }

      // Selection
      Prop("selectionMode") { (v: KalendarView, value: String?) in
        v.model.selectionMode = SelectionMode(rawValue: value ?? "single") ?? .single
      }
      Prop("selectedDate") { (v: KalendarView, value: String?) in
        v.model.selectedKeys = value.map { Set([$0]) } ?? []
      }
      Prop("selectedDates") { (v: KalendarView, value: [String]?) in
        v.model.selectedKeys = Set(value ?? [])
      }
      Prop("markedDates") { (v: KalendarView, value: [String]?) in
        v.model.markedKeys = Set(value ?? [])
      }
      Prop("disabledDates") { (v: KalendarView, value: [String]?) in
        v.model.disabledKeys = Set(value ?? [])
      }
      Prop("disabledDaysOfWeek") { (v: KalendarView, value: [Int]?) in
        v.model.disabledDaysOfWeek = value ?? []
      }
      Prop("rangeStart") { (v: KalendarView, value: String?) in
        v.model.rangeStart = KalendarModel.parse(value)
      }
      Prop("rangeEnd") { (v: KalendarView, value: String?) in
        v.model.rangeEnd = KalendarModel.parse(value)
      }
      Prop("minDate") { (v: KalendarView, value: String?) in
        v.model.minDate = KalendarModel.parse(value)
      }
      Prop("maxDate") { (v: KalendarView, value: String?) in
        v.model.maxDate = KalendarModel.parse(value)
      }
    }
  }
}

private func mapFontDesign(_ value: String?) -> Font.Design {
  switch value {
  case "rounded": return .rounded
  case "serif": return .serif
  case "monospaced": return .monospaced
  default: return .default
  }
}
