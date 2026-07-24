import SwiftUI

// MARK: - Backgrounds

struct SelectionBackground: ViewModifier {
  let accent: Color
  let glass: Bool
  let clearGlass: Bool
  let solid: Bool
  let today: Bool
  let shape: AnyShape
  let glassID: String
  let namespace: Namespace.ID

  func body(content: Content) -> some View {
    if solid {
      if #available(iOS 26.0, *), glass {
        let g: Glass = clearGlass ? .clear : .regular
        content
          .glassEffect(g.interactive(), in: shape)
          .glassEffectID(glassID, in: namespace)
          .glassEffectTransition(.matchedGeometry)
      } else {
        content.background(shape.fill(accent))
      }
    } else if today {
      content.background(shape.stroke(accent, lineWidth: 1.5).padding(1.5))
    } else {
      content
    }
  }
}

struct ChevronBackground: ViewModifier {
  let accent: Color
  let glass: Bool
  let clearGlass: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *), glass {
      let g: Glass = clearGlass ? .clear : .regular
      content.glassEffect(g.interactive(), in: Circle())
    } else {
      content.background(accent.opacity(0.12), in: Circle())
    }
  }
}

struct GlassCapsule: ViewModifier {
  let glass: Bool
  let clearGlass: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *), glass {
      let g: Glass = clearGlass ? .clear : .regular
      content.glassEffect(g.interactive(), in: Capsule())
    } else {
      content
    }
  }
}

struct GlassChip: ViewModifier {
  let tint: Color
  let glass: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *), glass {
      content.glassEffect(.regular.tint(tint), in: Capsule())
    } else {
      content.background(Capsule().fill(tint))
    }
  }
}

struct EventCard: ViewModifier {
  let tint: Color
  let glass: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *), glass {
      content.glassEffect(.regular.tint(tint.opacity(0.45)), in: RoundedRectangle(cornerRadius: 10))
    } else {
      content.background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
    }
  }
}

/// Interactive glass card for the year grid's mini-months. Clear glass +
/// a dark scrim keeps small text legible over any background; `.regular`
/// glass washes white text out.
struct GlassCard: ViewModifier {
  let glass: Bool
  let fallback: Color

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *), glass {
      content
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.28)))
        .glassEffect(Glass.clear.interactive(), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    } else {
      content.background(fallback, in: RoundedRectangle(cornerRadius: 16))
    }
  }
}
