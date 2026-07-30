import SwiftUI

enum SelectionShape: String { case circle, rounded, square }
enum SelectionMode: String { case single, range, multiple }
enum GlassVariant: String { case regular, clear }
enum TimeFormat: String { case locale, h12 = "12h", h24 = "24h" }

struct KalEvent: Identifiable {
  let srcId: String?
  let key: String
  let endKey: String
  let allDay: Bool
  let startMin: Int
  let endMin: Int
  let title: String
  let color: Color?
  let colorHex: String?

  /// Stable identity for SwiftUI sheets and drag bookkeeping.
  var id: String { srcId ?? "\(key)#\(title)#\(startMin)" }
  /// Occupies the all-day row / month bars rather than the hourly timeline.
  var spanning: Bool { allDay || endKey > key }
  func covers(_ dayKey: String) -> Bool { key <= dayKey && dayKey <= endKey }
}

func mwParseMinutes(_ hm: String?, fallback: Int) -> Int {
  guard let hm, hm.contains(":") else { return fallback }
  let parts = hm.split(separator: ":")
  let h = Int(parts[0]) ?? 0
  let m = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
  return max(0, min(24 * 60, h * 60 + m))
}

extension Color {
  init?(hexString: String) {
    var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard let v = UInt64(s, radix: 16) else { return nil }
    let r, g, b, a: Double
    switch s.count {
    case 6:
      r = Double((v >> 16) & 0xFF) / 255; g = Double((v >> 8) & 0xFF) / 255
      b = Double(v & 0xFF) / 255; a = 1
    case 8:
      r = Double((v >> 24) & 0xFF) / 255; g = Double((v >> 16) & 0xFF) / 255
      b = Double((v >> 8) & 0xFF) / 255; a = Double(v & 0xFF) / 255
    default:
      return nil
    }
    self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
  }
}

enum KalLevel: Equatable {
  case year
  case month
  case day(String)

  var name: String {
    switch self {
    case .year: return "year"
    case .month: return "month"
    case .day: return "day"
    }
  }
}

// Props from JS mutate this; JS owns selection, native side emits taps.
final class KalendarModel: ObservableObject {
  @Published var accent: Color = Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1 indigo
  @Published var textColor: Color = .primary
  @Published var mutedColor: Color = .secondary
  @Published var background: Color = .clear
  @Published var selectedTextColor: Color = .white
  @Published var cornerRadius: CGFloat = 14
  @Published var selectionShape: SelectionShape = .circle
  @Published var fontDesign: Font.Design = .default
  @Published var firstWeekday: Int = Calendar.current.firstWeekday
  @Published var locale: Locale = .current
  @Published var timeFormat: TimeFormat = .locale

  /// Liquid Glass appearance (iOS 26+); falls back to solid fills below.
  @Published var glass: Bool = true
  @Published var glassVariant: GlassVariant = .regular

  /// Glass is only real from iOS 26; below that the views use solid fills.
  var glassActive: Bool {
    if #available(iOS 26.0, *) { return glass }
    return false
  }
  /// Opt-in native edit sheet when tapping an event on the day timeline.
  @Published var eventEditorEnabled = false
  /// Suppresses all day-view editing gestures: drag-to-reschedule, long-press to
  /// create a slot, and opening the editor. Taps still fire read callbacks.
  @Published var readOnly = false
  var canEdit: Bool { eventEditorEnabled && !readOnly }
  @Published var hapticsEnabled = true

  @Published var yearViewEnabled = false
  @Published var dayViewEnabled = false
  /// Opt-in: month collapses to a single week strip via a grabber (or the
  /// `expanded` prop). `expandedProp` drives it from JS when controlled.
  @Published var expandableEnabled = false
  @Published var expandedProp: Bool?
  /// Opt-in: tapping a day in the month opens a bottom sheet with that day's
  /// events (view + edit), Apple Calendar style, instead of zooming to the day.
  @Published var daySheetEnabled = false
  /// Month navigation: false = paged (swipe L/R a month at a time); true =
  /// continuous vertical scroll of weeks (Apple Calendar style).
  @Published var scrollContinuous = false
  @Published var dayStartHour = 0
  @Published var dayEndHour = 24
  @Published var showNowIndicator = true
  @Published var initialScrollTime: String?
  /// Day-timeline zoom (pinch) and the lift-to-drag scroll lock live here, not in
  /// DayView, so the reused day panes — which observe the model — pick them up.
  @Published var hourHeight: CGFloat = 56
  @Published var dragLock = false
  /// Set by the `level` prop to drive navigation from JS ("year"/"month"/"day").
  @Published var levelProp: String?
  /// Consumer-localized strings by key; dates/weekdays/times come from the
  /// locale formatter and selected/disabled from native traits, so this only
  /// holds the remaining UI + accessibility text. Reads fall back to English.
  @Published var labels: [String: String] = [:]

  func label(_ key: String, _ fallback: String) -> String { labels[key] ?? fallback }
  /// Events shown on the day view timeline; also dot the month grid.
  @Published var events: [KalEvent] = []
  /// Optimistic per-event drag offsets (minutes) until the consumer's updated
  /// `events` prop echoes back. On the model so the reused day pages reflect it.
  @Published var dragOffsets: [String: Int] = [:]

  @Published var selectionMode: SelectionMode = .single
  @Published var selectedKeys: Set<String> = []
  @Published var markedKeys: Set<String> = []
  @Published var disabledKeys: Set<String> = []
  @Published var disabledDaysOfWeek: [Int] = []
  @Published var rangeStart: Date?
  @Published var rangeEnd: Date?
  @Published var minDate: Date?
  @Published var maxDate: Date?
  @Published var monthAnchor: Date = Date()

  var onRangeChange: ((Date, Date?) -> Void)?
  var onSelect: ((Date) -> Void)?
  var onOpenDay: ((Date) -> Void)?
  var onDayHold: ((Date) -> Void)?
  var onEventTap: ((KalEvent) -> Void)?
  var onEventHold: ((KalEvent) -> Void)?
  var onEventMove: ((KalEvent, Int, Int) -> Void)?
  /// Editor save: event, new title, new startMin/endMin, new color hex.
  var onEventEdit: ((KalEvent, String, Int, Int, String?, Bool) -> Void)?
  var onEventDelete: ((KalEvent) -> Void)?
  var onSlotHold: ((String, Int, Int) -> Void)?
  var onLevelChange: ((String) -> Void)?
  var onMonthChange: ((Date) -> Void)?
  var onExpandedChange: ((Bool) -> Void)?

  /// Day keys carrying a timed (non-spanning) event — these get a dot; spanning
  /// events are drawn as bars instead, so they must not also dot the start day.
  var timedDayKeys: Set<String> { Set(events.filter { !$0.spanning }.map { $0.key }) }
  /// All-day / multi-day events, laid out as bars across the month grid.
  var spanningEvents: [KalEvent] { events.filter { $0.spanning } }
  /// Every event covering a day, serialized for the `onDayPress` payload so
  /// consumers can render their own day view instead of the built-in one.
  /// All-day / multi-day events first, then timed events by start.
  func dayEventsPayload(_ key: String) -> [[String: Any]] {
    events.filter { $0.covers(key) }
      .sorted { a, b in a.spanning != b.spanning ? a.spanning : a.startMin < b.startMin }
      .map { ev in
        var p: [String: Any] = ["id": ev.srcId as Any, "date": ev.key, "title": ev.title, "allDay": ev.allDay]
        if ev.endKey != ev.key { p["endDate"] = ev.endKey }
        if !ev.allDay { p["start"] = KalendarModel.hm(ev.startMin); p["end"] = KalendarModel.hm(ev.endMin) }
        if let hex = ev.colorHex { p["color"] = hex }
        return p
      }
  }
  /// Timed single-day events for the hourly timeline, earliest first.
  func timelineEvents(on key: String) -> [KalEvent] {
    events.filter { $0.key == key && !$0.spanning }.sorted { $0.startMin < $1.startMin }
  }
  /// All-day / multi-day events covering a day, earliest start first.
  func allDayEvents(on key: String) -> [KalEvent] {
    events.filter { $0.spanning && $0.covers(key) }.sorted { $0.key < $1.key }
  }

  private static let parser: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  static func parse(_ iso: String?) -> Date? {
    guard let iso, !iso.isEmpty else { return nil }
    return parser.date(from: iso)
  }
  static func key(_ date: Date) -> String { parser.string(from: date) }

  /// Minutes-from-midnight as canonical "HH:mm" for event payloads sent to JS.
  static func hm(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

  /// Key of the first day of a date's month — the identity used for year→month zoom.
  static func monthKey(_ date: Date) -> String {
    let c = Calendar(identifier: .gregorian)
    let comps = c.dateComponents([.year, .month], from: date)
    return key(c.date(from: comps) ?? date)
  }

  func setMonth(iso: String?) { if let d = Self.parse(iso) { monthAnchor = d } }

  func isDisabled(_ date: Date, _ calendar: Calendar) -> Bool {
    let day = calendar.startOfDay(for: date)
    if disabledKeys.contains(Self.key(date)) { return true }
    if let mn = minDate, day < calendar.startOfDay(for: mn) { return true }
    if let mx = maxDate, day > calendar.startOfDay(for: mx) { return true }
    if !disabledDaysOfWeek.isEmpty {
      let weekdayJS = calendar.component(.weekday, from: date) - 1
      if disabledDaysOfWeek.contains(weekdayJS) { return true }
    }
    return false
  }

  /// Keep a month within min/max so paging can't leave the allowed range.
  func clampMonth(_ date: Date) -> Date {
    if let mn = minDate, Self.monthKey(date) < Self.monthKey(mn) { return mn }
    if let mx = maxDate, Self.monthKey(date) > Self.monthKey(mx) { return mx }
    return date
  }

  func select(_ date: Date, _ calendar: Calendar) {
    guard !isDisabled(date, calendar) else { return }
    onSelect?(date)
  }
}

// MARK: - Shared month math

func mwCalendar(_ firstWeekday: Int) -> Calendar {
  var c = Calendar(identifier: .gregorian)
  c.firstWeekday = firstWeekday
  return c
}

/// The cells of a month grid: leading nil padding, then each day.
/// Thin adapter over the shared-spec core in KalendarCore.
func mwMonthDays(_ anchor: Date, _ calendar: Calendar) -> [Date?] {
  guard let mi = calendar.dateInterval(of: .month, for: anchor) else { return [] }
  let first = mi.start
  let n = calendar.range(of: .day, in: .month, for: anchor)?.count ?? 30
  let firstDow0 = calendar.component(.weekday, from: first) - 1
  return mwGrid(firstDow0: firstDow0, daysInMonth: n, weekStart0: calendar.firstWeekday - 1).map { day in
    day.flatMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
  }
}

#if canImport(UIKit)
func mwHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
  UIImpactFeedbackGenerator(style: style).impactOccurred()
}
#endif

/// DateFormatters are costly to allocate; cache by pattern + locale + calendar.
private var mwFormatterCache: [String: DateFormatter] = [:]
func mwFormatter(_ pattern: String, _ calendar: Calendar, _ locale: Locale) -> DateFormatter {
  let key = "\(pattern)|\(locale.identifier)|\(calendar.identifier)"
  if let f = mwFormatterCache[key] { return f }
  let f = DateFormatter()
  f.calendar = calendar
  f.locale = locale
  f.dateFormat = pattern
  mwFormatterCache[key] = f
  return f
}

func mwWeekdaySymbols(_ calendar: Calendar, _ locale: Locale) -> [String] {
  let f = mwFormatter("", calendar, locale)
  let symbols = f.veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
  let start = calendar.firstWeekday - 1
  return Array(symbols[start...] + symbols[..<start])
}

extension View {
  @ViewBuilder func mwSoftTopEdge() -> some View {
    if #available(iOS 26.0, macOS 26.0, *) { scrollEdgeEffectStyle(.soft, for: .top) } else { self }
  }
}
