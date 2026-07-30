package expo.modules.kalendar

import androidx.compose.ui.text.font.FontFamily
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record
import java.time.LocalDate

class EventRecord : Record {
  @Field var id: String? = null

  @Field var date: String = ""

  @Field var endDate: String? = null

  @Field var allDay: Boolean = false

  @Field var start: String? = null

  @Field var end: String? = null

  @Field var title: String = ""

  @Field var color: String? = null
}

class KalendarModule : Module() {
  override fun definition() =
    ModuleDefinition {
      Name("Kalendar")

      View(KalendarView::class) {
        Events(
          "onRangeChange",
          "onDayPress",
          "onDayOpen",
          "onDayLongPress",
          "onEventPress",
          "onEventLongPress",
          "onEventChange",
          "onEventDelete",
          "onSlotPress",
          "onLevelChange",
          "onMonthChange",
          "onExpandedChange",
        )

        Prop("accentColor") { view: KalendarView, value: String? ->
          KalendarState.parseColor(value)?.let { view.state.accent = it }
        }
        Prop("textColor") { view: KalendarView, value: String? ->
          KalendarState.parseColor(value)?.let { view.state.textColor = it }
        }
        Prop("mutedColor") { view: KalendarView, value: String? ->
          KalendarState.parseColor(value)?.let { view.state.mutedColor = it }
        }
        Prop("backgroundColor") { view: KalendarView, value: String? ->
          view.state.background = KalendarState.parseColor(value) ?: androidx.compose.ui.graphics.Color.Transparent
        }
        Prop("selectedTextColor") { view: KalendarView, value: String? ->
          KalendarState.parseColor(value)?.let { view.state.selectedTextColor = it }
        }
        Prop("cornerRadius") { view: KalendarView, value: Double? ->
          view.state.cornerRadius = (value ?: 14.0).toFloat()
        }
        Prop("selectionShape") { view: KalendarView, value: String? ->
          view.state.selectionShape =
            when (value) {
              "rounded" -> SelectionShape.ROUNDED
              "square" -> SelectionShape.SQUARE
              else -> SelectionShape.CIRCLE
            }
        }
        Prop("fontDesign") { view: KalendarView, value: String? ->
          // Android has no "rounded" system font, so it maps to the default sans.
          view.state.fontFamily =
            when (value) {
              "serif" -> FontFamily.Serif
              "monospaced" -> FontFamily.Monospace
              else -> null
            }
        }
        Prop("material") { view: KalendarView, value: String? ->
          view.state.solid = value == "solid"
        }
        // iOS-only glass material; accepted for prop parity, no effect on Android.
        Prop("glassVariant") { _: KalendarView, _: String? -> }

        Prop("firstWeekday") { view: KalendarView, value: Int? ->
          // 1 = Sunday … 7 = Saturday (Apple convention); stored 0-based from Sunday.
          view.state.firstWeekday = ((value ?: 1) - 1).coerceIn(0, 6)
        }
        Prop("locale") { view: KalendarView, value: String? ->
          view.state.localeTag = value
        }
        Prop("timeFormat") { view: KalendarView, value: String? ->
          view.state.timeFormat =
            when (value) {
              "12h" -> TimeFormat.H12
              "24h" -> TimeFormat.H24
              else -> TimeFormat.LOCALE
            }
        }

        Prop("month") { view: KalendarView, value: String? ->
          KalendarState.parse(value)?.let { view.state.monthAnchor = it.withDayOfMonth(1) }
        }
        Prop("yearView") { view: KalendarView, value: Boolean? ->
          view.state.yearViewEnabled = value ?: false
        }
        Prop("dayView") { view: KalendarView, value: Boolean? ->
          view.state.dayViewEnabled = value ?: false
        }
        Prop("expandable") { view: KalendarView, value: Boolean? ->
          view.state.expandableEnabled = value ?: false
        }
        Prop("expanded") { view: KalendarView, value: Boolean? ->
          view.state.expandedProp = value
        }
        Prop("daySheet") { view: KalendarView, value: Boolean? ->
          view.state.daySheetEnabled = value ?: false
        }
        Prop("scroll") { view: KalendarView, value: String? ->
          view.state.scrollContinuous = value == "continuous"
        }
        Prop("level") { view: KalendarView, value: String? ->
          view.state.levelProp = value
        }
        Prop("labels") { view: KalendarView, value: Map<String, String>? ->
          view.state.labels = value ?: emptyMap()
        }
        Prop("eventEditor") { view: KalendarView, value: Boolean? ->
          view.state.eventEditorEnabled = value ?: false
        }
        Prop("readOnly") { view: KalendarView, value: Boolean? ->
          view.state.readOnly = value ?: false
        }
        AsyncFunction("goToToday") { view: KalendarView ->
          val today = LocalDate.now()
          view.state.monthAnchor = today.withDayOfMonth(1)
          view.state.selectedKeys = setOf(KalendarState.key(today))
        }
        AsyncFunction("scrollToDate") { view: KalendarView, date: String ->
          KalendarState.parse(date)?.let {
            view.state.monthAnchor = it.withDayOfMonth(1)
            view.state.selectedKeys = setOf(KalendarState.key(it))
          }
        }
        Prop("testID") { view: KalendarView, value: String? ->
          view.state.testTag = value
        }
        Prop("accessibilityLabel") { view: KalendarView, value: String? ->
          view.state.accessibilityLabel = value
        }
        Prop("accessibilityHint") { view: KalendarView, value: String? ->
          view.state.accessibilityHint = value
        }
        Prop("haptics") { view: KalendarView, value: Boolean? ->
          view.state.hapticsEnabled = value ?: true
        }
        Prop("dayStartHour") { view: KalendarView, value: Int? ->
          view.state.dayStartHour = value ?: 0
        }
        Prop("dayEndHour") { view: KalendarView, value: Int? ->
          view.state.dayEndHour = value ?: 24
        }
        Prop("showNowIndicator") { view: KalendarView, value: Boolean? ->
          view.state.showNowIndicator = value ?: true
        }
        Prop("initialScrollTime") { view: KalendarView, value: String? ->
          view.state.initialScrollTime = value
        }
        Prop("events") { view: KalendarView, value: List<EventRecord>? ->
          view.state.dragOffsets.clear()
          view.state.events =
            (value ?: emptyList()).mapNotNull { r ->
              if (r.date.isEmpty()) return@mapNotNull null
              val start = KalendarState.parseMinutes(r.start, 0)
              val end = KalendarState.parseMinutes(r.end, start + 60)
              KalEvent(
                id = r.id,
                key = r.date,
                endKey = r.endDate?.let { if (it >= r.date) it else r.date } ?: r.date,
                allDay = r.allDay,
                startMin = start,
                endMin = maxOf(start + 15, end),
                title = r.title,
                color = KalendarState.parseColor(r.color),
                colorHex = r.color,
              )
            }
        }

        Prop("selectionMode") { view: KalendarView, value: String? ->
          view.state.selectionMode =
            when (value) {
              "range" -> SelectionMode.RANGE
              "multiple" -> SelectionMode.MULTIPLE
              else -> SelectionMode.SINGLE
            }
        }
        Prop("selectedDate") { view: KalendarView, value: String? ->
          view.state.selectedKeys = value?.let { setOf(it) } ?: emptySet()
        }
        Prop("selectedDates") { view: KalendarView, value: List<String>? ->
          view.state.selectedKeys = (value ?: emptyList()).toSet()
        }
        Prop("markedDates") { view: KalendarView, value: List<String>? ->
          view.state.markedKeys = (value ?: emptyList()).toSet()
        }
        Prop("disabledDates") { view: KalendarView, value: List<String>? ->
          view.state.disabledKeys = (value ?: emptyList()).toSet()
        }
        Prop("disabledDaysOfWeek") { view: KalendarView, value: List<Int>? ->
          view.state.disabledDaysOfWeek = (value ?: emptyList()).toSet()
        }
        Prop("rangeStart") { view: KalendarView, value: String? ->
          view.state.rangeStart = KalendarState.parse(value)
        }
        Prop("rangeEnd") { view: KalendarView, value: String? ->
          view.state.rangeEnd = KalendarState.parse(value)
        }
        Prop("minDate") { view: KalendarView, value: String? ->
          view.state.minDate = KalendarState.parse(value)
        }
        Prop("maxDate") { view: KalendarView, value: String? ->
          view.state.maxDate = KalendarState.parse(value)
        }
      }
    }
}
