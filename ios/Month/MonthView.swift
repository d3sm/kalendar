import SwiftUI

struct MonthView: View {
  @ObservedObject var model: KalendarModel
  @Binding var level: KalLevel
  @Binding var zoomAnchor: UnitPoint
  @Binding var yearAnchor: UnitPoint
  @Binding var dayKey: String?
  let container: CGSize
  @Namespace private var glassNS
  @State private var expanded = true
  @State private var weekAnchor = Date()
  @State private var daySheetDay: DayRef?
  @StateObject private var headerStore = ContHeaderStore()

  private var calendar: Calendar { mwCalendar(model.firstWeekday) }
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  private var glassActive: Bool { model.glassActive && !reduceTransparency }
  private let maxLanes = 2
  private var hasSpans: Bool { !model.spanningEvents.isEmpty }

  var body: some View {
    content
      .padding(18)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(model.background)
      .sheet(item: $daySheetDay) { ref in
        DaySheet(model: model, dayKey: ref.key, calendar: calendar, openDay: openDaySheetDay)
      }
  }

  private func openDaySheetDay(_ k: String) {
    daySheetDay = nil
    guard model.dayViewEnabled, let d = KalendarModel.parse(k) else { return }
    model.onOpenDay?(d)
    zoomAnchor = anchor(for: d)
    dayKey = k
    level = .day(k)
  }

  @ViewBuilder
  private var content: some View {
    // The glass container coordinates every .glassEffect beneath it each frame —
    // fine for the paged grid, but a drag on the continuous list would pay that
    // cost across a fast-recycling scroll, so it opts out.
    if #available(iOS 26.0, *), model.glass, !model.scrollContinuous {
      GlassEffectContainer(spacing: 6) { stack }
    } else {
      stack
    }
  }

  private var stack: some View {
    VStack(spacing: 14) {
      header
      weekdayRow
      pagerArea
      if model.expandableEnabled && !model.scrollContinuous { grabber }
      if model.expandableEnabled && !model.scrollContinuous && !expanded {
        DayAgendaView(model: model, dayKey: agendaDayKey, glass: glassActive, onTap: openEvent)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Spacer(minLength: 0)
      }
    }
    .onAppear {
      weekAnchor = collapseSeedDate()
      if let want = model.expandedProp { expanded = want }
    }
    .onChange(of: model.expandedProp) { _ in syncExpanded() }
    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: expanded)
  }

  @ViewBuilder
  private var pagerArea: some View {
    if model.scrollContinuous {
      ContinuousMonths(
        model: model, headerStore: headerStore, calendar: calendar,
        maxLanes: maxLanes, namespace: glassNS, glassActive: glassActive,
        onTap: { tap($0, $1) }, onLongPress: { model.onDayHold?($0) }
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if expanded {
      monthPager.frame(height: hasSpans ? 334 : 292).transition(.opacity)
    } else {
      weekPager.frame(height: hasSpans ? 60 : 52).transition(.opacity)
    }
  }

  private var monthPager: some View {
    PagedView(
      model: model, current: model.monthAnchor, unit: .month, calendar: calendar,
      key: { KalendarModel.monthKey($0) },
      content: { anchor in grid(for: anchor) },
      onCommit: { model.monthAnchor = model.clampMonth($0); model.onMonthChange?(model.monthAnchor) }
    )
  }

  private var weekPager: some View {
    PagedView(
      model: model, current: weekAnchor, unit: .weekOfYear, calendar: calendar,
      key: { weekKey($0) },
      content: { date in weekStrip(for: date) },
      onCommit: { d in weekAnchor = d; syncMonth(toWeekOf: d) }
    )
  }

  private var grabber: some View {
    Capsule()
      .fill(model.mutedColor.opacity(0.35))
      .frame(width: 36, height: 5)
      .frame(maxWidth: .infinity, minHeight: 44)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onEnded { v in
            let dy = v.translation.height
            if dy > 12 { setExpanded(true) } else if dy < -12 { setExpanded(false) } else { setExpanded(!expanded) }
          }
      )
      .accessibilityLabel(expanded ? model.label("collapse", "Collapse to week") : model.label("expand", "Expand to month"))
      .accessibilityAddTraits(.isButton)
  }

  private func weekStrip(for date: Date) -> some View {
    let days = weekDays(for: date)
    let dayKeys = days.map { $0.map { KalendarModel.key($0) } }
    let spans = model.spanningEvents
    let bars = mwLayoutMonthBars(dayKeys, spans.map { MWSpanEvent(uid: $0.id, startKey: $0.key, endKey: $0.endKey) }, maxLanes: maxLanes)
    let colorFor = Dictionary(spans.map { ($0.id, $0.color ?? model.accent) }, uniquingKeysWith: { a, _ in a })
    return MonthWeekRow(
      model: model, days: days, dayKeys: dayKeys, week: 0,
      bars: bars, colorFor: colorFor, hasBars: hasSpans,
      calendar: calendar, glassActive: glassActive, namespace: glassNS,
      onTap: { tap($0, $1) }, onLongPress: { model.onDayHold?($0) }
    )
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private func grid(for anchor: Date) -> some View {
    let days = mwMonthDays(anchor, calendar)
    let dayKeys = days.map { $0.map { KalendarModel.key($0) } }
    let spans = model.spanningEvents
    let bars = mwLayoutMonthBars(dayKeys, spans.map { MWSpanEvent(uid: $0.id, startKey: $0.key, endKey: $0.endKey) }, maxLanes: maxLanes)
    let colorFor = Dictionary(spans.map { ($0.id, $0.color ?? model.accent) }, uniquingKeysWith: { a, _ in a })
    let weeks = (days.count + 6) / 7
    return VStack(spacing: 2) {
      ForEach(0..<weeks, id: \.self) { w in
        MonthWeekRow(
          model: model, days: days, dayKeys: dayKeys, week: w,
          bars: bars, colorFor: colorFor, hasBars: hasSpans,
          calendar: calendar, glassActive: glassActive, namespace: glassNS,
          onTap: { tap($0, $1) }, onLongPress: { model.onDayHold?($0) }
        )
      }
    }
    .animation(.spring(response: 0.32, dampingFraction: 0.72), value: model.selectedKeys)
    .animation(.spring(response: 0.32, dampingFraction: 0.72), value: model.rangeStart)
    .animation(.spring(response: 0.32, dampingFraction: 0.72), value: model.rangeEnd)
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private var header: some View {
    HStack {
      if model.yearViewEnabled {
        Button {
          yearAnchor = mwYearCellAnchor(calendar.component(.month, from: model.monthAnchor), container)
          level = .year
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold))
              .accessibilityHidden(true)
            monthTitleView
          }
          .foregroundStyle(model.textColor)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .modifier(GlassCapsule(glass: glassActive, clearGlass: model.glassVariant == .clear))
        }
        .buttonStyle(.plain)
        .accessibilityHint(model.label("showYear", "Show year"))
      } else {
        monthTitleView.accessibilityAddTraits(.isHeader)
      }
      Spacer()
      if !model.scrollContinuous {
        HStack(spacing: 8) {
          ChevronButton(name: "chevron.left", label: model.label("prevMonth", "Previous month"), accent: model.accent, glass: glassActive, clearGlass: model.glassVariant == .clear) { shift(-1) }
          ChevronButton(name: "chevron.right", label: model.label("nextMonth", "Next month"), accent: model.accent, glass: glassActive, clearGlass: model.glassVariant == .clear) { shift(1) }
        }
      }
    }
  }

  @ViewBuilder
  private var monthTitleView: some View {
    if model.scrollContinuous {
      ContinuousMonthTitle(store: headerStore, model: model, calendar: calendar)
    } else {
      Text(mwFormatter("LLLL yyyy", calendar, model.locale).string(from: model.monthAnchor))
        .font(.system(.title2, design: model.fontDesign).weight(.semibold))
        .foregroundStyle(model.textColor)
        .contentTransition(.numericText())
    }
  }

  private var weekdayRow: some View {
    HStack(spacing: 0) {
      ForEach(Array(mwWeekdaySymbols(calendar, model.locale).enumerated()), id: \.offset) { _, sym in
        Text(sym.uppercased())
          .font(.system(.caption, design: model.fontDesign).weight(.semibold))
          .foregroundStyle(model.mutedColor)
          .frame(maxWidth: .infinity)
      }
    }
    .accessibilityHidden(true)
  }

  // MARK: - Helpers

  private func weekDays(for date: Date) -> [Date?] {
    guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
    return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start) }
  }

  private func weekKey(_ d: Date) -> String {
    KalendarModel.key(calendar.dateInterval(of: .weekOfYear, for: d)?.start ?? d)
  }

  private func firstOfMonth(_ date: Date) -> Date {
    calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
  }

  private func syncMonth(toWeekOf date: Date) {
    let m = firstOfMonth(date)
    guard KalendarModel.monthKey(m) != KalendarModel.monthKey(model.monthAnchor) else { return }
    model.monthAnchor = m
    model.onMonthChange?(m)
  }

  private func collapseSeedDate() -> Date {
    if let sel = model.selectedKeys.first.flatMap({ KalendarModel.parse($0) }),
       calendar.isDate(sel, equalTo: model.monthAnchor, toGranularity: .month) { return sel }
    if calendar.isDate(Date(), equalTo: model.monthAnchor, toGranularity: .month) { return Date() }
    return model.monthAnchor
  }

  private func setExpanded(_ v: Bool) {
    guard v != expanded else { return }
    applyExpanded(v)
    model.onExpandedChange?(v)
  }

  private func syncExpanded() {
    guard let want = model.expandedProp, want != expanded else { return }
    applyExpanded(want)
  }

  private func applyExpanded(_ v: Bool) {
    if v { model.monthAnchor = firstOfMonth(weekAnchor) } else { weekAnchor = collapseSeedDate() }
    expanded = v
  }

  private func tap(_ date: Date, _ k: String) {
    model.select(date, calendar)
    if model.selectionMode == .range {
      let (start, end): (Date, Date?) = (model.rangeStart != nil && model.rangeEnd == nil)
        ? (model.rangeStart!, date) : (date, nil)
      model.onRangeChange?(start, end)
      return
    }
    guard model.selectionMode == .single else { return }
    if model.expandableEnabled && !expanded { return }
    if model.daySheetEnabled {
      daySheetDay = DayRef(key: k)
      return
    }
    guard model.dayViewEnabled else { return }
    model.onOpenDay?(date)
    zoomAnchor = anchor(for: date)
    dayKey = k
    level = .day(k)
  }

  private var agendaDayKey: String {
    let week = calendar.dateInterval(of: .weekOfYear, for: weekAnchor)
    if let sel = model.selectedKeys.first, let d = KalendarModel.parse(sel),
       week?.contains(d) == true { return sel }
    return weekKey(weekAnchor)
  }

  private func openEvent(_ ev: KalEvent) {
    model.onEventTap?(ev)
    guard model.dayViewEnabled else { return }
    if let d = KalendarModel.parse(ev.key) {
      model.select(d, calendar)
      model.onOpenDay?(d)
      zoomAnchor = .center
      dayKey = ev.key
      level = .day(ev.key)
    }
  }

  private func anchor(for date: Date) -> UnitPoint {
    let days = mwMonthDays(model.monthAnchor, calendar)
    guard container.width > 0, container.height > 0,
          let idx = days.firstIndex(where: { $0.map { calendar.isDate($0, inSameDayAs: date) } ?? false })
    else { return .center }
    let col = CGFloat(idx % 7), row = CGFloat(idx / 7)
    let x = (18 + (container.width - 36) * (col + 0.5) / 7) / container.width
    let y = (104 + (row + 0.5) * 48) / container.height
    return UnitPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
  }

  private func shift(_ m: Int) {
    if expanded {
      if let d = calendar.date(byAdding: .month, value: m, to: model.monthAnchor) {
        let clamped = model.clampMonth(d)
        guard KalendarModel.monthKey(clamped) != KalendarModel.monthKey(model.monthAnchor) else { return }
        model.monthAnchor = clamped
        model.onMonthChange?(clamped)
      }
    } else if let d = calendar.date(byAdding: .weekOfYear, value: m, to: weekAnchor) {
      weekAnchor = d
      syncMonth(toWeekOf: d)
    }
  }
}
