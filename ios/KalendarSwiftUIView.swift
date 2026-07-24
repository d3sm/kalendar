import SwiftUI

// MARK: - Root: a ZStack wiring year ⇄ month ⇄ day with hero zooms

/// A custom calendar so every color, shape, font, and material is ours to
/// style. All levels live in one ZStack with no NavigationStack, so the view
/// stays fully transparent over whatever the consumer renders behind it.
struct KalendarSwiftUIView: View {
  @ObservedObject var model: KalendarModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var level: KalLevel = .month
  @State private var zoomAnchor: UnitPoint = .center
  @State private var yearAnchor: UnitPoint = .center
  @State private var dayKey: String?

  var body: some View {
    GeometryReader { geo in
      let dk = dayKey ?? KalendarModel.key(model.monthAnchor)
      let isDay = level == .day(dk)
      ZStack {
        YearView(model: model, level: $level, yearAnchor: $yearAnchor, container: geo.size)
          .modifier(LevelFX(shown: level == .year, scale: reduceMotion ? 1 : (level == .year ? 1 : 2.4), anchor: yearAnchor, trigger: level))
          .zIndex(0)
        MonthView(model: model, level: $level, zoomAnchor: $zoomAnchor, yearAnchor: $yearAnchor, dayKey: $dayKey, container: geo.size)
          .modifier(LevelFX(
            shown: level == .month,
            scale: reduceMotion ? 1 : monthScale,
            anchor: level == .year ? yearAnchor : zoomAnchor,
            trigger: level))
          .zIndex(1)
        DayView(model: model, dayKey: dk, currentDayKey: $dayKey, level: $level)
          .clipShape(RoundedRectangle(cornerRadius: isDay ? 0 : 28))
          .modifier(LevelFX(shown: isDay, scale: reduceMotion ? 1 : (isDay ? 1 : 0.45), anchor: zoomAnchor, trigger: level))
          .zIndex(2)
      }
    }
    .tint(model.accent)
    .background(model.background)
    // Clamp Dynamic Type: the largest accessibility sizes break the fixed-height grid.
    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    .onAppear(perform: applyLevelProp)
    .onChange(of: model.levelProp) { _ in applyLevelProp() }
    .onChange(of: level) { newLevel in model.onLevelChange?(newLevel.name) }
  }

  /// Apply a JS-driven `level` request. Taps still change `level` locally and
  /// notify JS via onLevelChange, so this only fires on an actual prop change.
  private func applyLevelProp() {
    switch model.levelProp {
    case "year": if level != .year { level = .year }
    case "month": if level != .month { level = .month }
    case "day":
      let key = model.selectedKeys.first ?? KalendarModel.key(model.monthAnchor)
      if level != .day(key) { dayKey = key; level = .day(key) }
    default: break
    }
  }

  private var monthScale: CGFloat {
    switch level {
    case .year: return 0.27
    case .month: return 1
    case .day: return 1.2
    }
  }
}

/// Every level stays mounted so the Liquid Glass materials don't re-initialize
/// (that reads as a white flash). The hero zoom between levels is driven here.
private struct LevelFX: ViewModifier {
  let shown: Bool
  let scale: CGFloat
  let anchor: UnitPoint
  let trigger: KalLevel

  func body(content: Content) -> some View {
    // Scale and opacity animate on separate curves, each keyed to its own
    // value. Scale springs; opacity ramps fast, so the incoming level (kept on
    // top by zIndex) is opaque before the outgoing fades and they never ghost.
    content
      .scaleEffect(scale, anchor: anchor)
      .animation(.spring(response: 0.42, dampingFraction: 0.9), value: scale)
      .opacity(shown ? 1 : 0)
      .animation(.easeInOut(duration: 0.15), value: shown)
      .allowsHitTesting(shown)
  }
}

/// Approximate center of a month's card in the year grid, for anchored zooms.
func mwYearCellAnchor(_ month: Int, _ size: CGSize) -> UnitPoint {
  guard size.width > 0, size.height > 0 else { return .center }
  let col = CGFloat((month - 1) % 3), row = CGFloat((month - 1) / 3)
  let cw = (size.width - 36 - 24) / 3
  let x = (18 + col * (cw + 12) + cw / 2) / size.width
  let ch: CGFloat = 158
  let y = (64 + row * ch + ch / 2) / size.height
  return UnitPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
}

// MARK: - Month
