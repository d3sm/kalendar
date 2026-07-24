import SwiftUI

// MARK: - Agenda

struct DayAgendaView: View {
  @ObservedObject var model: KalendarModel
  let dayKey: String
  let glass: Bool
  let onTap: (KalEvent) -> Void

  var body: some View {
    let allDay = model.allDayEvents(on: dayKey)
    let timed = model.timelineEvents(on: dayKey)
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        if allDay.isEmpty && timed.isEmpty {
          Text(model.label("noEvents", "No events"))
            .font(.system(.subheadline, design: model.fontDesign))
            .foregroundStyle(model.mutedColor)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 24)
        }
        ForEach(Array(allDay.enumerated()), id: \.offset) { _, ev in
          AllDayChip(model: model, ev: ev, verticalPadding: 7, glass: glass) { onTap(ev) }
        }
        ForEach(Array(timed.enumerated()), id: \.offset) { _, ev in row(ev) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 18)
      .padding(.vertical, 10)
    }
  }

  private func row(_ ev: KalEvent) -> some View {
    let color = ev.color ?? model.accent
    return HStack(alignment: .top, spacing: 12) {
      Text(mwAgendaTime(ev.startMin, model))
        .font(.system(.caption, design: model.fontDesign))
        .foregroundStyle(model.mutedColor)
        .frame(width: 58, alignment: .trailing)
      Circle().fill(color).frame(width: 8, height: 8).padding(.top, 4)
      VStack(alignment: .leading, spacing: 2) {
        Text(ev.title)
          .font(.system(.subheadline, design: model.fontDesign).weight(.semibold))
          .foregroundStyle(model.textColor)
          .lineLimit(1)
        Text("\(mwAgendaTime(ev.startMin, model)) – \(mwAgendaTime(ev.endMin, model))")
          .font(.system(.caption2, design: model.fontDesign))
          .foregroundStyle(model.mutedColor)
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .onTapGesture { onTap(ev) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(ev.title), \(mwAgendaTime(ev.startMin, model)) – \(mwAgendaTime(ev.endMin, model))")
    .accessibilityAddTraits(.isButton)
  }
}

private func mwAgendaTime(_ minutes: Int, _ model: KalendarModel) -> String {
  let pattern: String
  let locale: Locale
  switch model.timeFormat {
  case .h24:
    pattern = "HH:mm"
    var comps = Locale.Components(locale: model.locale); comps.hourCycle = .zeroToTwentyThree
    locale = Locale(components: comps)
  case .h12:
    pattern = "h:mm a"
    var comps = Locale.Components(locale: model.locale); comps.hourCycle = .oneToTwelve
    locale = Locale(components: comps)
  case .locale:
    pattern = DateFormatter.dateFormat(fromTemplate: "jm", options: 0, locale: model.locale) ?? "h:mm a"
    locale = model.locale
  }
  let calendar = mwCalendar(model.firstWeekday)
  var comps = DateComponents(); comps.hour = minutes / 60; comps.minute = minutes % 60
  return calendar.date(from: comps).map { mwFormatter(pattern, calendar, locale).string(from: $0) } ?? ""
}

struct DayRef: Identifiable { let key: String; var id: String { key } }

struct DaySheet: View {
  @ObservedObject var model: KalendarModel
  let dayKey: String
  let calendar: Calendar
  let openDay: (String) -> Void
  @State private var editing: KalEvent?

  private var date: Date { KalendarModel.parse(dayKey) ?? Date() }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(mwFormatter("EEEE", calendar, model.locale).string(from: date).uppercased(with: model.locale))
            .font(.system(.caption, design: model.fontDesign).weight(.semibold))
            .foregroundStyle(model.accent)
          Text(mwFormatter("d MMMM", calendar, model.locale).string(from: date))
            .font(.system(.title2, design: model.fontDesign).weight(.bold))
            .foregroundStyle(model.textColor)
        }
        Spacer()
        Button {
          if model.hapticsEnabled { mwHaptic(.light) }
          model.onDayHold?(date)
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(model.accent)
            .frame(width: 34, height: 34)
            .background(model.accent.opacity(0.14), in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.label("addEvent", "Add event"))
      }
      .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 4)

      // Solid chips (glass: false): warming Liquid Glass up while the sheet
      // animates in janks the first frames, so keep the transient sheet cheap.
      DayAgendaView(model: model, dayKey: dayKey, glass: false) { ev in
        model.onEventTap?(ev)
        if model.canEdit { editing = ev }
      }
      .frame(maxHeight: .infinity)

      if model.dayViewEnabled {
        Button { openDay(dayKey) } label: {
          Text(model.label("openDay", "Open day"))
            .font(.system(.subheadline, design: model.fontDesign).weight(.semibold))
            .foregroundStyle(model.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20).padding(.bottom, 8)
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .sheet(item: $editing) { ev in
      EventEditor(model: model, event: ev, day: KalendarModel.parse(ev.key) ?? date, calendar: calendar)
    }
  }
}
