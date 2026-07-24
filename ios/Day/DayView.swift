import SwiftUI

struct DayView: View {
  @ObservedObject var model: KalendarModel
  let dayKey: String
  @Binding var currentDayKey: String?
  @Binding var level: KalLevel

  private var calendar: Calendar { mwCalendar(model.firstWeekday) }
  private var date: Date { KalendarModel.parse(dayKey) ?? Date() }

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  private var glassActive: Bool { model.glassActive && !reduceTransparency }

  @State private var dayScroll = DayScrollBox()

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      persistentHeader
      Divider().overlay(model.mutedColor.opacity(0.3))
      pager
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(model.background)
  }

  /// The header stays mounted across day swipes AND level transitions so its
  /// Liquid Glass back-button never re-initializes — only the date text rebinds on settle.
  @ViewBuilder
  private var persistentHeader: some View {
    if #available(iOS 26.0, *), model.glass {
      GlassEffectContainer(spacing: 6) { DayHeader(model: model, date: date, calendar: calendar, glass: glassActive, level: $level) }
    } else {
      DayHeader(model: model, date: date, calendar: calendar, glass: glassActive, level: $level)
    }
  }

  /// Native pager between days; UIKit nests its horizontal pan with the
  /// timeline's vertical scroll exactly like Apple Calendar.
  private var pager: some View {
    PagedView(
      model: model,
      current: date,
      unit: .day,
      calendar: calendar,
      key: { KalendarModel.key($0) },
      locked: model.dragLock,
      content: { d in
        DayTimeline(
          model: model, date: d, openedDate: date,
          calendar: calendar, glassActive: glassActive, dayScroll: dayScroll
        )
      },
      onCommit: { nd in
        let k = KalendarModel.key(nd)
        currentDayKey = k
        level = .day(k)
        model.select(nd, calendar)
        model.onOpenDay?(nd)
      }
    )
  }
}
