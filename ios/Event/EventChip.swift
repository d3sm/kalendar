import SwiftUI

// MARK: - Day

/// A single timeline chip. Long-press lifts it, then it follows the finger
/// 1:1 (no implicit animation mid-drag); the label shows the 15-minute snap
/// that commits on release. Owning the gesture state here keeps per-frame
/// invalidation scoped to this one view.
struct EventChip<Content: View>: View {
  let base: Int
  let hourHeight: CGFloat
  let startMin: Int
  let range: ClosedRange<Int>
  let yFor: (Int) -> CGFloat
  let haptics: Bool
  let onLift: (Bool) -> Void
  let onCommit: (Int) -> Void
  let onTap: () -> Void
  var onLongPress: (() -> Void)?
  var readOnly = false
  @ViewBuilder let content: (Int) -> Content

  @State private var delta: Double = 0
  @State private var snapped = 0
  // @GestureState, not @State: SwiftUI auto-resets it the instant the gesture
  // ends OR is cancelled. Presenting the editor sheet cancels the in-flight
  // gesture; with plain @State the lift would stick and the chip go dead.
  @GestureState private var pressing = false

  var body: some View {
    let visual = pressing ? Int(delta.rounded()) : base
    content(pressing ? snapped : base)
      .scaleEffect(pressing ? 1.05 : 1)
      .shadow(color: .black.opacity(pressing ? 0.3 : 0), radius: 14, y: 6)
      .offset(y: yFor(startMin + visual))
      .zIndex(pressing ? 2 : (base != 0 ? 1 : 0))
      .onTapGesture { onTap() }
      .gesture(dragGesture)
      // dragLock follows the gesture, so it releases when `pressing` auto-resets.
      .onChange(of: pressing) { active in onLift(active) }
      .animation(pressing ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: visual)
  }

  private var dragGesture: some Gesture {
    LongPressGesture(minimumDuration: 0.25, maximumDistance: 40)
      .sequenced(before: DragGesture(minimumDistance: 0))
      .updating($pressing) { value, state, _ in
        guard !readOnly else { return }
        switch value {
        case .first(true), .second(true, _): state = true
        default: break
        }
      }
      .onChanged { value in
        guard !readOnly else { return }
        switch value {
        case .first(true):
          if haptics { mwHaptic(.medium) }
          onLongPress?()
          delta = Double(base)
          snapped = base
        case .second(true, let drag):
          guard let drag else { return }
          let raw = min(
            max(Double(drag.translation.height) / Double(hourHeight) * 60 + Double(base), Double(range.lowerBound)),
            Double(range.upperBound)
          )
          let snap = mwSnapDelta(raw, lo: range.lowerBound, hi: range.upperBound)
          if snap != snapped, haptics { mwHaptic(.light) }
          delta = raw
          snapped = snap
        default:
          break
        }
      }
      .onEnded { _ in
        guard !readOnly, snapped != base else { return }
        if haptics { mwHaptic(.rigid) }
        onCommit(snapped)
      }
  }
}
