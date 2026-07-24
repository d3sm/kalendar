import SwiftUI

// MARK: - Shared views

struct ChevronButton: View {
  let name: String
  let label: String
  let accent: Color
  let glass: Bool
  let clearGlass: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: name)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(accent)
        .frame(width: 34, height: 34)
        .modifier(ChevronBackground(accent: accent, glass: glass, clearGlass: clearGlass))
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

struct AllDayChip: View {
  @ObservedObject var model: KalendarModel
  let ev: KalEvent
  let verticalPadding: CGFloat
  let glass: Bool
  let onTap: () -> Void

  var body: some View {
    let color = ev.color ?? model.accent
    return HStack(spacing: 8) {
      Text(ev.title)
        .font(.system(.footnote, design: model.fontDesign).weight(.semibold))
        .foregroundStyle(model.textColor)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10).padding(.vertical, verticalPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .modifier(EventCard(tint: color, glass: glass))
    .contentShape(Rectangle())
    .onTapGesture { onTap() }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(ev.title), \(model.label("allDay", "all-day"))")
    .accessibilityAddTraits(.isButton)
  }
}
