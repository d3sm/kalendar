import SwiftUI

// MARK: - Event editor

/// Native edit sheet: title, times, color, delete. Emits through the model;
/// JS stays the source of truth and echoes the updated events back.
struct EventEditor: View {
  @ObservedObject var model: KalendarModel
  let event: KalEvent
  let day: Date
  let calendar: Calendar
  @Environment(\.dismiss) private var dismiss

  @State private var title: String
  @State private var start: Date
  @State private var end: Date
  @State private var colorHex: String?
  @State private var allDay: Bool

  private static let palette = ["#ff5c8a", "#ff8a00", "#facc15", "#22c55e", "#00c2ff", "#7c5cff"]

  init(model: KalendarModel, event: KalEvent, day: Date, calendar: Calendar) {
    self.model = model
    self.event = event
    self.day = day
    self.calendar = calendar
    _title = State(initialValue: event.title)
    _start = State(initialValue: Self.time(day, event.startMin, calendar))
    _end = State(initialValue: Self.time(day, event.endMin, calendar))
    _colorHex = State(initialValue: event.colorHex)
    _allDay = State(initialValue: event.allDay)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(model.label("eventTitle", "Title"), text: $title)
          Toggle(model.label("allDay", "All-day"), isOn: $allDay.animation())
          if !allDay {
            DatePicker(model.label("starts", "Starts"), selection: $start, displayedComponents: .hourAndMinute)
            DatePicker(model.label("ends", "Ends"), selection: $end, in: start..., displayedComponents: .hourAndMinute)
          }
        }
        Section(model.label("color", "Color")) {
          HStack(spacing: 12) {
            ForEach(Self.palette, id: \.self) { hex in
              Circle()
                .fill(Color(hexString: hex) ?? .gray)
                .frame(width: 28, height: 28)
                .overlay {
                  if colorHex?.lowercased() == hex {
                    Circle().strokeBorder(.white, lineWidth: 2).padding(2)
                  }
                }
                .onTapGesture { colorHex = hex }
            }
          }
          .padding(.vertical, 2)
        }
        Section {
          Button(model.label("delete", "Delete"), role: .destructive) {
            model.onEventDelete?(event)
            dismiss()
          }
        }
      }
      .navigationTitle(model.label("editEvent", "Edit event"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(model.label("cancel", "Cancel")) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(model.label("save", "Save")) {
            let s = Self.minutes(start, calendar)
            let e = max(Self.minutes(end, calendar), s + 15)
            model.onEventEdit?(event, title, s, e, colorHex, allDay)
            dismiss()
          }
          .fontWeight(.semibold)
        }
      }
    }
    .tint(model.accent)
    .presentationDetents([.medium, .large])
  }

  private static func time(_ day: Date, _ minutes: Int, _ calendar: Calendar) -> Date {
    calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
  }

  private static func minutes(_ date: Date, _ calendar: Calendar) -> Int {
    let c = calendar.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
  }
}
