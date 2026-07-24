import SwiftUI

/// Shared scroll offset across the three recycled day panes so swiping keeps
/// the same hour in view. Reference type so mutations don't trigger re-renders.
final class DayScrollBox {
  var topHour: Int?
}

struct DayTimeline: View {
  @ObservedObject var model: KalendarModel
  let date: Date
  let openedDate: Date
  let calendar: Calendar
  let glassActive: Bool
  let dayScroll: DayScrollBox

  @Environment(\.horizontalSizeClass) private var hSize
  @State private var pinchBase: CGFloat = 56
  @State private var editing: KalEvent?
  @State private var overflowSel: Overflow?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      allDayRow
      timeline
    }
    .sheet(item: $overflowSel) { overflowList($0) }
    .sheet(item: $editing) { ev in
      EventEditor(model: model, event: ev, day: KalendarModel.parse(ev.key) ?? date, calendar: calendar)
    }
  }

  @ViewBuilder
  private var allDayRow: some View {
    let events = model.allDayEvents(on: KalendarModel.key(date))
    if !events.isEmpty {
      HStack(alignment: .top, spacing: 12) {
        Text(model.label("allDay", "all-day"))
          .font(.system(.caption2, design: model.fontDesign))
          .foregroundStyle(model.mutedColor)
          .frame(width: 52, alignment: .trailing)
          .padding(.top, 6)
        VStack(spacing: 5) {
          ForEach(Array(events.enumerated()), id: \.offset) { _, ev in
            AllDayChip(model: model, ev: ev, verticalPadding: 6, glass: glassActive) {
              model.onEventTap?(ev)
              if model.eventEditorEnabled { editing = ev }
            }
          }
        }
      }
      .padding(.horizontal, 18)
      .padding(.top, 10).padding(.bottom, 8)
      Divider().overlay(model.mutedColor.opacity(0.3))
    }
  }

  private var timeline: some View {
    let key = KalendarModel.key(date)
    let today = calendar.isDateInToday(date)
    return ScrollViewReader { proxy in
      ScrollView(showsIndicators: false) {
        ZStack(alignment: .topLeading) {
          VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
              HStack(alignment: .top, spacing: 12) {
                Text(hourLabel(hour))
                  .font(.system(.caption2, design: model.fontDesign))
                  .foregroundStyle(model.mutedColor)
                  .frame(width: 52, alignment: .trailing)
                Rectangle()
                  .fill(model.mutedColor.opacity(0.18))
                  .frame(height: 1)
                  .frame(maxWidth: .infinity)
                  .padding(.top, 7)
              }
              .frame(height: model.hourHeight, alignment: .top)
              .id(hour)
            }
          }
          .contentShape(Rectangle())
          .gesture(slotGesture(for: key))
          .accessibilityHidden(true)
          if model.showNowIndicator, today, nowWithinRange { nowLine }
          GeometryReader { g in eventsLayer(for: key, width: g.size.width) }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
      }
      .mwSoftTopEdge()
      .scrollDisabled(model.dragLock)
      .simultaneousGesture(
        MagnificationGesture()
          .onChanged { model.hourHeight = min(120, max(36, pinchBase * $0)) }
          .onEnded { _ in pinchBase = model.hourHeight }
      )
      .onAppear {
        if dayScroll.topHour == nil {
          if let timeStr = model.initialScrollTime {
            let h = mwParseMinutes(timeStr, fallback: startHour * 60) / 60
            dayScroll.topHour = min(max(startHour, h), endHour - 1)
          } else {
            let opened = calendar.isDateInToday(openedDate)
            let h = opened ? calendar.component(.hour, from: Date()) : max(startHour, 8)
            dayScroll.topHour = min(max(startHour, h - 1), endHour - 1)
          }
        }
        proxy.scrollTo(dayScroll.topHour ?? startHour, anchor: .top)
      }
      .onChange(of: key) { _ in
        proxy.scrollTo(dayScroll.topHour ?? startHour, anchor: .top)
      }
    }
  }

  private func eventsLayer(for dayKey: String, width: CGFloat) -> some View {
    let (placed, overflow) = layoutEvents(model.timelineEvents(on: dayKey))
    let area = max(width - gutter - 6, 40)
    return ZStack(alignment: .topLeading) {
      ForEach(Array(placed.enumerated()), id: \.offset) { _, p in
        let ev = p.ev
        let key = ev.id
        let dur = ev.endMin - ev.startMin
        let lo = startHour * 60 - ev.startMin
        let hi = max(lo, endHour * 60 - dur - ev.startMin)
        let cw = (p.reserved ? area - 50 : area) / CGFloat(p.cols)
        EventChip(
          base: model.dragOffsets[key] ?? 0,
          hourHeight: model.hourHeight,
          startMin: ev.startMin,
          range: lo...hi,
          yFor: yFor,
          haptics: model.hapticsEnabled,
          onLift: { model.dragLock = $0 },
          onCommit: { snapped in
            model.dragOffsets[key] = snapped
            model.onEventMove?(ev, ev.startMin + snapped, ev.endMin + snapped)
          },
          onTap: {
            model.onEventTap?(ev)
            if model.canEdit { DispatchQueue.main.async { editing = ev } }
          },
          onLongPress: { model.onEventHold?(ev) },
          readOnly: model.readOnly
        ) { labelDelta in
          eventBlock(ev, shiftedBy: labelDelta)
            .frame(height: blockHeight(ev), alignment: .topLeading)
            .frame(width: max(cw - 3, 30), alignment: .leading)
            .contentShape(Rectangle())
            .padding(.leading, gutter + cw * CGFloat(p.col))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ev.title), \(clockLabel(ev.startMin)) – \(clockLabel(ev.endMin))")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text(model.label("moveLater", "Move 15 minutes later"))) {
          nudgeEvent(ev, key: key, range: lo...hi, by: 15)
        }
        .accessibilityAction(named: Text(model.label("moveEarlier", "Move 15 minutes earlier"))) {
          nudgeEvent(ev, key: key, range: lo...hi, by: -15)
        }
      }
      ForEach(overflow) { of in
        Button {
          haptic(.light)
          overflowSel = of
        } label: {
          Text("+\(of.events.count)")
            .font(.system(.footnote, design: model.fontDesign).weight(.bold))
            .foregroundStyle(model.textColor)
            .frame(width: 44)
            .frame(height: max(CGFloat(of.endMin - of.startMin) / 60 * model.hourHeight - 2, 30))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .modifier(EventCard(tint: model.accent, glass: glassActive))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(of.events.count) \(model.label("moreEvents", "more events"))")
        .offset(x: gutter + area - 46, y: yFor(of.startMin))
        .zIndex(3)
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.events.map(\.startMin))
  }

  private func slotGesture(for dayKey: String) -> some Gesture {
    LongPressGesture(minimumDuration: 0.3)
      .sequenced(before: DragGesture(minimumDistance: 0))
      .onEnded { value in
        guard !model.readOnly, case .second(true, let drag?) = value else { return }
        let pressed = startHour * 60 + Int((drag.startLocation.y - 7) / model.hourHeight * 60)
        let onEvent = model.timelineEvents(on: dayKey).contains {
          pressed >= $0.startMin && pressed < $0.endMin
        }
        guard !onEvent else { return }
        let slot = mwSlotForPress(pressed, startHour: startHour, endHour: endHour)
        haptic(.medium)
        model.onSlotHold?(dayKey, slot.start, slot.end)
      }
  }

  private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    if model.hapticsEnabled { mwHaptic(style) }
  }

  private func eventBlock(_ ev: KalEvent, shiftedBy delta: Int = 0) -> some View {
    let color = ev.color ?? model.accent
    return HStack(spacing: 0) {
      RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3)
      VStack(alignment: .leading, spacing: 1) {
        Text(ev.title)
          .font(.system(.footnote, design: model.fontDesign).weight(.semibold))
          .foregroundStyle(model.textColor)
          .lineLimit(1)
        Text("\(clockLabel(ev.startMin + delta)) – \(clockLabel(ev.endMin + delta))")
          .font(.system(size: 10, design: model.fontDesign))
          .foregroundStyle(model.mutedColor)
          .lineLimit(1)
      }
      .padding(.leading, 7)
      .padding(.vertical, 4)
      Spacer(minLength: 0)
    }
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .modifier(EventCard(tint: color, glass: glassActive))
  }

  private func blockHeight(_ ev: KalEvent) -> CGFloat {
    max(26, CGFloat(ev.endMin - ev.startMin) / 60 * model.hourHeight - 2)
  }

  private func nudgeEvent(_ ev: KalEvent, key: String, range: ClosedRange<Int>, by minutes: Int) {
    guard !model.readOnly else { return }
    let cur = model.dragOffsets[key] ?? 0
    let next = min(max(cur + minutes, range.lowerBound), range.upperBound)
    guard next != cur else { return }
    model.dragOffsets[key] = next
    model.onEventMove?(ev, ev.startMin + next, ev.endMin + next)
  }

  private func yFor(_ minute: Int) -> CGFloat {
    CGFloat(minute - startHour * 60) / 60 * model.hourHeight + 7
  }

  private var nowWithinRange: Bool {
    let now = Date()
    let m = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
    return m >= startHour * 60 && m <= endHour * 60
  }

  private var nowLine: some View {
    TimelineView(.periodic(from: Date(), by: 60)) { context in
      let comps = calendar.dateComponents([.hour, .minute], from: context.date)
      let nowMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
      HStack(spacing: 6) {
        Text(nowLabel)
          .font(.system(size: 10, design: model.fontDesign).weight(.bold))
          .foregroundStyle(model.selectedTextColor)
          .padding(.horizontal, 7).padding(.vertical, 3)
          .modifier(GlassChip(tint: model.accent, glass: glassActive))
        Rectangle().fill(model.accent).frame(height: 2)
      }
      .offset(y: yFor(nowMin) - 8)
    }
  }

  private func overflowList(_ of: Overflow) -> some View {
    NavigationStack {
      List {
        ForEach(Array(of.events.enumerated()), id: \.offset) { _, ev in
          Button {
            overflowSel = nil
            model.onEventTap?(ev)
            if model.canEdit {
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { editing = ev }
            }
          } label: {
            HStack(spacing: 10) {
              Circle().fill(ev.color ?? model.accent).frame(width: 10, height: 10)
              VStack(alignment: .leading, spacing: 1) {
                Text(ev.title).fontWeight(.semibold)
                Text("\(clockLabel(ev.startMin)) – \(clockLabel(ev.endMin))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }
      .navigationTitle(model.label("sameTime", "At the same time"))
      .navigationBarTitleDisplayMode(.inline)
    }
    .tint(model.accent)
    .presentationDetents([.medium])
  }

  // MARK: - Time formatting

  private func clockLabel(_ minute: Int) -> String {
    var comps = DateComponents()
    comps.hour = minute / 60
    comps.minute = minute % 60
    return calendar.date(from: comps).map { mwFormatter(timePattern(minutes: true), calendar, patternLocale).string(from: $0) } ?? ""
  }

  private func timePattern(minutes: Bool) -> String {
    switch model.timeFormat {
    case .h12: return minutes ? "h:mm" : "h a"
    case .h24: return "HH:mm"
    case .locale:
      let template = minutes ? "jm" : "j"
      return DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: model.locale) ?? (minutes ? "h:mm" : "h a")
    }
  }

  private var patternLocale: Locale {
    guard model.timeFormat != .locale else { return model.locale }
    var comps = Locale.Components(locale: model.locale)
    comps.hourCycle = model.timeFormat == .h24 ? .zeroToTwentyThree : .oneToTwelve
    return Locale(components: comps)
  }

  private func hourLabel(_ hour: Int) -> String {
    var c = DateComponents(); c.hour = hour
    return calendar.date(from: c).map { mwFormatter(timePattern(minutes: false), calendar, patternLocale).string(from: $0) } ?? "\(hour)"
  }

  private var nowLabel: String {
    mwFormatter(timePattern(minutes: true), calendar, patternLocale).string(from: Date())
  }

  // MARK: - Layout helpers

  private var startHour: Int { max(0, min(23, model.dayStartHour)) }
  private var endHour: Int { max(startHour + 1, min(24, model.dayEndHour)) }
  private var maxCols: Int { hSize == .regular ? 3 : 2 }
  private let gutter: CGFloat = 64

  struct Placed {
    let ev: KalEvent
    let col: Int
    let cols: Int
    let reserved: Bool
  }

  struct Overflow: Identifiable {
    let id: String
    let events: [KalEvent]
    let startMin: Int
    let endMin: Int
  }

  private func layoutEvents(_ evs: [KalEvent]) -> ([Placed], [Overflow]) {
    let byUid = Dictionary(evs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    let result = mwLayoutEvents(
      evs.map { MWCoreEvent(uid: $0.id, start: $0.startMin, end: $0.endMin) },
      maxCols: maxCols
    )
    let placed = result.placed.compactMap { p in
      byUid[p.uid].map { Placed(ev: $0, col: p.col, cols: p.cols, reserved: p.reserved) }
    }
    let overflow = result.overflow.map { of in
      Overflow(
        id: "of-\(of.start)-\(of.uids.count)",
        events: of.uids.compactMap { byUid[$0] },
        startMin: of.start,
        endMin: of.end
      )
    }
    return (placed, overflow)
  }
}
