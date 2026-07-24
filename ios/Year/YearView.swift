import SwiftUI

// MARK: - Year

struct YearView: View {
  @ObservedObject var model: KalendarModel
  @Binding var level: KalLevel
  @Binding var yearAnchor: UnitPoint
  let container: CGSize
  @State private var year = Calendar.current.component(.year, from: Date())
  @State private var slideEdge: Edge = .trailing

  private var calendar: Calendar { mwCalendar(model.firstWeekday) }
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  private var glassActive: Bool { model.glassActive && !reduceTransparency }

  var body: some View {
    // Solid, not glass: compositing a dozen glass mini-months while they scale in
    // the level zoom stutters, and solid reads the same at this size.
    yearStack
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(model.background)
    .onAppear { year = calendar.component(.year, from: model.monthAnchor) }
    .onChange(of: level) { newLevel in
      if newLevel == .year { year = calendar.component(.year, from: model.monthAnchor) }
    }
  }

  private var yearStack: some View {
    VStack(spacing: 12) {
      HStack {
        Text(String(year))
          .font(.system(.largeTitle, design: model.fontDesign).weight(.bold))
          .foregroundStyle(model.accent)
          .contentTransition(.numericText())
          .accessibilityAddTraits(.isHeader)
        Spacer()
        HStack(spacing: 8) {
          ChevronButton(name: "chevron.left", label: model.label("prevYear", "Previous year"), accent: model.accent, glass: glassActive, clearGlass: model.glassVariant == .clear) { shiftYear(-1) }
          ChevronButton(name: "chevron.right", label: model.label("nextYear", "Next year"), accent: model.accent, glass: glassActive, clearGlass: model.glassVariant == .clear) { shiftYear(1) }
        }
      }
      .padding(.horizontal, 18)
      .padding(.top, 8)

      ScrollView(showsIndicators: false) {
        ZStack {
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
            ForEach(1...12, id: \.self) { m in
              if let anchor = monthAnchor(m) {
                Button {
                  model.monthAnchor = anchor
                  model.onMonthChange?(anchor)
                  yearAnchor = mwYearCellAnchor(m, container)
                  level = .month
                } label: {
                  MiniMonth(anchor: anchor, model: model, calendar: calendar)
                    .padding(10)
                    .modifier(GlassCard(glass: false, fallback: model.textColor.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(mwFormatter("LLLL yyyy", calendar, model.locale).string(from: anchor))
              }
            }
          }
          .id(year)
          .transition(.push(from: slideEdge))
        }
        .clipped()
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
      }
      .mwSoftTopEdge()
    }
  }

  private func monthAnchor(_ month: Int) -> Date? {
    calendar.date(from: DateComponents(year: year, month: month, day: 1))
  }

  private func shiftYear(_ delta: Int) {
    let edge: Edge = delta > 0 ? .trailing : .leading
    let apply = { withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) { year += delta } }
    if slideEdge == edge {
      apply()
    } else {
      slideEdge = edge
      DispatchQueue.main.async(execute: apply)
    }
  }

}

private struct MiniMonth: View {
  let anchor: Date
  @ObservedObject var model: KalendarModel
  let calendar: Calendar

  private var title: String {
    mwFormatter("LLLL", calendar, model.locale).string(from: anchor)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(.subheadline, design: model.fontDesign).weight(.bold))
        .foregroundStyle(model.accent)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 3) {
        ForEach(Array(mwMonthDays(anchor, calendar).enumerated()), id: \.offset) { _, day in
          if let day {
            let isToday = calendar.isDateInToday(day)
            Text("\(calendar.component(.day, from: day))")
              .font(.system(size: 9, design: model.fontDesign).weight(isToday ? .bold : .medium))
              .monospacedDigit()
              .foregroundStyle(isToday ? model.selectedTextColor : model.textColor)
              // Fill the column so all seven stay in fixed, aligned columns; a
              // fixed cell width overflows the narrow year-grid cards.
              .frame(maxWidth: .infinity, minHeight: 13)
              .background { if isToday { Circle().fill(model.accent).frame(width: 13, height: 13) } }
          } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: 13)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
