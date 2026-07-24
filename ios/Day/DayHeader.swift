import SwiftUI

struct DayHeader: View {
  @ObservedObject var model: KalendarModel
  let date: Date
  let calendar: Calendar
  let glass: Bool
  @Binding var level: KalLevel

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      Button { level = .month } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(model.accent)
          .frame(width: 34, height: 34)
          .modifier(ChevronBackground(accent: model.accent, glass: glass, clearGlass: model.glassVariant == .clear))
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(model.label("back", "Back"))

      VStack(alignment: .leading, spacing: 2) {
        Text(weekdayName(date).uppercased())
          .font(.system(.caption, design: model.fontDesign).weight(.semibold))
          .foregroundStyle(model.accent)
        Text(bigTitle(date))
          .font(.system(.title, design: model.fontDesign).weight(.bold))
          .foregroundStyle(model.textColor)
      }
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      Spacer()
      if calendar.isDateInToday(date) {
        Text(model.label("today", "Today").uppercased(with: model.locale))
          .font(.system(.caption2, design: model.fontDesign).weight(.bold))
          .foregroundStyle(model.selectedTextColor)
          .padding(.horizontal, 10).padding(.vertical, 5)
          .modifier(GlassChip(tint: model.accent, glass: glass))
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 14)
    .padding(.bottom, 12)
  }

  private func weekdayName(_ d: Date) -> String {
    mwFormatter("EEEE", calendar, model.locale).string(from: d)
  }

  private func bigTitle(_ d: Date) -> String {
    mwFormatter("d MMMM yyyy", calendar, model.locale).string(from: d)
  }
}
