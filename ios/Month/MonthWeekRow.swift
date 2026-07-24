import SwiftUI

struct MonthWeekRow: View {
  @ObservedObject var model: KalendarModel
  let days: [Date?]
  let dayKeys: [String?]
  let week: Int
  let bars: MWMonthBars
  let colorFor: [String: Color]
  let hasBars: Bool
  let calendar: Calendar
  let glassActive: Bool
  let namespace: Namespace.ID
  let onTap: (Date, String) -> Void
  let onLongPress: (Date) -> Void
  var colW: CGFloat?

  @Environment(\.layoutDirection) private var layoutDirection

  private let barH: CGFloat = 4
  private let barGap: CGFloat = 2
  private let numberArea: CGFloat = 36
  private let maxLanes: Int = 2

  var body: some View {
    let lo = week * 7
    ZStack(alignment: .top) {
      HStack(spacing: 0) {
        ForEach(0..<7, id: \.self) { col in
          let i = lo + col
          if i < days.count, let day = days[i] {
            dayCell(day, hasBars: hasBars, overflow: bars.overflow[dayKeys[i] ?? ""] ?? 0)
          } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: cellHeight(hasBars))
          }
        }
      }
      if hasBars {
        barsOverlay(week: week)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
  }

  @ViewBuilder
  private func barsOverlay(week w: Int) -> some View {
    // Positioned by absolute x from a fixed LTR origin; RTL is handled by
    // mirroring the column in barView instead of flipping the overlay.
    let rtl = layoutDirection == .rightToLeft
    Group {
      if let colW {
        ZStack(alignment: .topLeading) {
          ForEach(Array(bars.segments.enumerated()), id: \.offset) { _, seg in
            if seg.week == w { barView(seg, colW: colW, color: colorFor[seg.uid] ?? model.accent, rtl: rtl) }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      } else {
        GeometryReader { geo in
          let cw = geo.size.width / 7
          ForEach(Array(bars.segments.enumerated()), id: \.offset) { _, seg in
            if seg.week == w { barView(seg, colW: cw, color: colorFor[seg.uid] ?? model.accent, rtl: rtl) }
          }
        }
      }
    }
    .environment(\.layoutDirection, .leftToRight)
  }

  /// A single spanning bar: flush to the week edge where it continues past,
  /// rounded where the event actually starts or ends. RTL mirrors the columns.
  private func barView(_ seg: MWBarSegment, colW: CGFloat, color: Color, rtl: Bool) -> some View {
    let leadInset: CGFloat = (rtl ? seg.continuesRight : seg.continuesLeft) ? 0 : 2
    let trailInset: CGFloat = (rtl ? seg.continuesLeft : seg.continuesRight) ? 0 : 2
    let startCol = rtl ? (6 - seg.endCol) : seg.startCol
    let x = CGFloat(startCol) * colW + leadInset
    let width = CGFloat(seg.endCol - seg.startCol + 1) * colW - leadInset - trailInset
    let y = numberArea + CGFloat(seg.lane) * (barH + barGap)
    return RoundedRectangle(cornerRadius: barH / 2)
      .fill(color)
      .frame(width: max(width, 0), height: barH)
      .offset(x: x, y: y)
  }

  private func cellHeight(_ hasBars: Bool) -> CGFloat {
    hasBars ? numberArea + CGFloat(maxLanes) * (barH + barGap) + 6 : 46
  }

  private func dayCell(_ date: Date, hasBars: Bool, overflow: Int) -> some View {
    let k = KalendarModel.key(date)
    let disabled = model.isDisabled(date, calendar)
    let isToday = calendar.isDateInToday(date)
    let selected = model.selectionMode != .range && model.selectedKeys.contains(k)
    let r = rangeInfo(date)
    let solid = selected || r.isEndpoint
    let marked = model.markedKeys.contains(k) || model.timedDayKeys.contains(k)
    let hasBar = model.spanningEvents.contains { $0.covers(k) }

    let disc = Text("\(calendar.component(.day, from: date))")
      .font(.system(.body, design: model.fontDesign).weight(solid ? .bold : .regular))
      .foregroundStyle(dayColor(disabled: disabled, solid: solid))
      .frame(width: hasBars ? 34 : nil, height: hasBars ? 34 : nil)
      .frame(maxWidth: hasBars ? nil : .infinity, minHeight: hasBars ? nil : 46)
      .modifier(SelectionBackground(
        accent: model.accent,
        glass: glassActive,
        clearGlass: model.glassVariant == .clear,
        solid: solid,
        today: isToday && !disabled,
        shape: shape,
        glassID: model.selectionMode == .single ? "sel" : k,
        namespace: namespace
      ))

    let cell = Group {
      if hasBars {
        VStack(spacing: 0) {
          disc.padding(.top, 1)
          Spacer(minLength: 0)
          if overflow > 0 {
            Text("+\(overflow)")
              .font(.system(size: 8, design: model.fontDesign).weight(.semibold))
              .foregroundStyle(model.mutedColor)
              .padding(.bottom, 2)
          } else if marked && !hasBar {
            Circle().fill(model.accent).frame(width: 4, height: 4).padding(.bottom, 4)
          }
        }
        .frame(maxWidth: .infinity, minHeight: cellHeight(true), alignment: .top)
      } else {
        disc.overlay(alignment: .bottom) {
          Circle()
            .fill(solid ? dayColor(disabled: disabled, solid: true) : model.accent)
            .frame(width: 5, height: 5)
            .padding(.bottom, 5)
            .opacity(marked ? 1 : 0)
        }
      }
    }

    return cell
      .background { if r.inRange && !r.isEndpoint { Rectangle().fill(model.accent.opacity(0.18)) } }
      .contentShape(Rectangle())
      .gesture(
        LongPressGesture(minimumDuration: 0.35)
          .onEnded { _ in
            if model.hapticsEnabled { mwHaptic(.medium) }
            onLongPress(date)
          }
          .exclusively(before: TapGesture().onEnded { onTap(date, k) })
      )
      .disabled(disabled)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(a11yLabel(date, isToday: isToday, hasEvents: marked || !model.allDayEvents(on: k).isEmpty))
      .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }

  private func a11yLabel(_ date: Date, isToday: Bool, hasEvents: Bool) -> String {
    var parts = [mwFormatter("EEEE d MMMM yyyy", calendar, model.locale).string(from: date)]
    if isToday { parts.append(model.label("today", "Today")) }
    if hasEvents { parts.append(model.label("hasEvents", "Has events")) }
    return parts.joined(separator: ", ")
  }

  private var shape: AnyShape {
    switch model.selectionShape {
    case .circle: return AnyShape(Circle())
    case .rounded: return AnyShape(RoundedRectangle(cornerRadius: model.cornerRadius))
    case .square: return AnyShape(Rectangle())
    }
  }

  private func dayColor(disabled: Bool, solid: Bool) -> Color {
    if disabled { return model.mutedColor.opacity(0.4) }
    if solid { return glassActive ? model.textColor : model.selectedTextColor }
    return model.textColor
  }

  private func rangeInfo(_ date: Date) -> (inRange: Bool, isEndpoint: Bool) {
    guard model.selectionMode == .range, let s = model.rangeStart else { return (false, false) }
    let e = model.rangeEnd ?? s
    let lo = min(s, e), hi = max(s, e)
    let d = calendar.startOfDay(for: date)
    let inR = d >= calendar.startOfDay(for: lo) && d <= calendar.startOfDay(for: hi)
    let isEnd = calendar.isDate(date, inSameDayAs: lo) || calendar.isDate(date, inSameDayAs: hi)
    return (inR, isEnd)
  }
}
