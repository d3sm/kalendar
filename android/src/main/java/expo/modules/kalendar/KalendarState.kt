package expo.modules.kalendar

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateMap
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter

@Immutable
data class KalEvent(
  val id: String?,
  val key: String,
  val endKey: String,
  val allDay: Boolean,
  val startMin: Int,
  val endMin: Int,
  val title: String,
  val color: Color?,
  val colorHex: String?,
) {
  val uid: String get() = id ?: "$key#$title#$startMin"

  val spanning: Boolean get() = allDay || endKey > key

  fun covers(dayKey: String): Boolean = key <= dayKey && dayKey <= endKey
}

enum class SelectionShape { CIRCLE, ROUNDED, SQUARE }

enum class SelectionMode { SINGLE, RANGE, MULTIPLE }

enum class TimeFormat { LOCALE, H12, H24 }

/** Prop-driven state; Compose observes the mutableStateOf fields directly. */
class KalendarState {
  var accent by mutableStateOf(Color(0xFF6366F1))

  // Unspecified = "use the theme" (resolved in KalendarRoot), matching iOS's
  // adaptive .primary/.secondary so text stays readable on light or dark.
  var textColor by mutableStateOf(Color.Unspecified)
  var mutedColor by mutableStateOf(Color.Unspecified)
  var background by mutableStateOf(Color.Transparent)
  var selectedTextColor by mutableStateOf(Color.White)
  var cornerRadius by mutableStateOf(14f)
  var selectionShape by mutableStateOf(SelectionShape.CIRCLE)
  var firstWeekday by mutableStateOf(0)
  var localeTag by mutableStateOf<String?>(null)
  var timeFormat by mutableStateOf(TimeFormat.LOCALE)
  var solid by mutableStateOf(false)
  var yearViewEnabled by mutableStateOf(false)
  var dayViewEnabled by mutableStateOf(false)
  var expandableEnabled by mutableStateOf(false)
  var expandedProp by mutableStateOf<Boolean?>(null)
  var daySheetEnabled by mutableStateOf(false)

  var scrollContinuous by mutableStateOf(false)
  var eventEditorEnabled by mutableStateOf(false)

  // Suppress all day-view editing gestures (drag, slot-create, editor).
  var readOnly by mutableStateOf(false)

  // testID passthrough → Compose testTag on the root, for E2E targeting.
  var testTag by mutableStateOf<String?>(null)

  // Resolved from the `fontDesign` prop; applied to all text via LocalTextStyle.
  var fontFamily by mutableStateOf<FontFamily?>(null)
  val canEdit: Boolean get() = eventEditorEnabled && !readOnly
  var hapticsEnabled by mutableStateOf(true)
  var dayStartHour by mutableStateOf(0)
  var dayEndHour by mutableStateOf(24)
  var showNowIndicator by mutableStateOf(true)
  var initialScrollTime by mutableStateOf<String?>(null)

  var selectionMode by mutableStateOf(SelectionMode.SINGLE)
  var selectedKeys by mutableStateOf(setOf<String>())
  var markedKeys by mutableStateOf(setOf<String>())
  var disabledKeys by mutableStateOf(setOf<String>())
  var disabledDaysOfWeek by mutableStateOf(setOf<Int>())
  var rangeStart by mutableStateOf<LocalDate?>(null)
  var rangeEnd by mutableStateOf<LocalDate?>(null)
  var minDate by mutableStateOf<LocalDate?>(null)
  var maxDate by mutableStateOf<LocalDate?>(null)

  fun clampMonth(date: LocalDate): LocalDate {
    val ym = YearMonth.from(date)
    minDate?.let { if (ym < YearMonth.from(it)) return it }
    maxDate?.let { if (ym > YearMonth.from(it)) return it }
    return date
  }

  var monthAnchor by mutableStateOf(LocalDate.now().withDayOfMonth(1))
  var events by mutableStateOf(listOf<KalEvent>())
  val dragOffsets: SnapshotStateMap<String, Int> = mutableStateMapOf()
  var accessibilityLabel by mutableStateOf<String?>(null)
  var accessibilityHint by mutableStateOf<String?>(null)
  var levelProp by mutableStateOf<String?>(null)

  var labels by mutableStateOf<Map<String, String>>(emptyMap())

  fun label(
    key: String,
    fallback: String,
  ): String = labels[key] ?: fallback

  var onRangeChange: ((String, String?) -> Unit)? = null
  var onDayPress: ((String) -> Unit)? = null
  var onDayOpen: ((String) -> Unit)? = null
  var onDayLongPress: ((String) -> Unit)? = null
  var onEventPress: ((KalEvent) -> Unit)? = null
  var onEventLongPress: ((KalEvent) -> Unit)? = null
  var onEventChange: ((KalEvent, String, Int, Int, String?, Boolean) -> Unit)? = null
  var onEventDelete: ((KalEvent) -> Unit)? = null
  var onSlotPress: ((String, Int, Int) -> Unit)? = null
  var onLevelChange: ((String) -> Unit)? = null
  var onMonthChange: ((java.time.LocalDate) -> Unit)? = null
  var onExpandedChange: ((Boolean) -> Unit)? = null

  fun timelineEventsOn(key: String): List<KalEvent> = events.filter { it.key == key && !it.spanning }.sortedBy { it.startMin }

  fun allDayEventsOn(key: String): List<KalEvent> = events.filter { it.spanning && it.covers(key) }.sortedBy { it.key }

  fun dayEventsPayload(key: String): List<Map<String, Any?>> =
    events
      .filter { it.covers(key) }
      .sortedWith(compareByDescending<KalEvent> { it.spanning }.thenBy { it.startMin })
      .map { ev ->
        buildMap {
          put("id", ev.id)
          put("date", ev.key)
          put("title", ev.title)
          put("allDay", ev.allDay)
          if (ev.endKey != ev.key) put("endDate", ev.endKey)
          if (!ev.allDay) {
            put("start", KalendarState.hm(ev.startMin))
            put("end", KalendarState.hm(ev.endMin))
          }
          ev.colorHex?.let { put("color", it) }
        }
      }

  // spanning events are bars; their start day must not also be dotted
  val timedDayKeys: Set<String> get() = events.filter { !it.spanning }.map { it.key }.toSet()

  val spanningEvents: List<KalEvent> get() = events.filter { it.spanning }

  fun select(date: LocalDate) {
    val k = key(date)
    when (selectionMode) {
      SelectionMode.SINGLE ->
        selectedKeys = if (selectedKeys == setOf(k)) emptySet() else setOf(k)
      SelectionMode.MULTIPLE ->
        selectedKeys = if (selectedKeys.contains(k)) selectedKeys - k else selectedKeys + k
      SelectionMode.RANGE -> Unit
    }
  }

  fun isDisabled(date: LocalDate): Boolean {
    if (disabledKeys.contains(key(date))) return true
    if (disabledDaysOfWeek.contains(date.dayOfWeek.value % 7)) return true
    minDate?.let { if (date.isBefore(it)) return true }
    maxDate?.let { if (date.isAfter(it)) return true }
    return false
  }

  companion object {
    private val fmt: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

    fun key(date: LocalDate): String = date.format(fmt)

    fun parse(iso: String?): LocalDate? = iso?.takeIf { it.isNotEmpty() }?.let { runCatching { LocalDate.parse(it, fmt) }.getOrNull() }

    fun parseMinutes(
      hm: String?,
      fallback: Int,
    ): Int {
      if (hm == null || !hm.contains(":")) return fallback
      val parts = hm.split(":")
      val h = parts[0].toIntOrNull() ?: 0
      val m = parts.getOrNull(1)?.toIntOrNull() ?: 0
      return (h * 60 + m).coerceIn(0, 24 * 60)
    }

    fun hm(minutes: Int): String = "%02d:%02d".format(minutes / 60, minutes % 60)

    fun parseColor(hex: String?): Color? {
      var s = hex?.trim() ?: return null
      if (s.startsWith("#")) s = s.substring(1)
      val v = s.toULongOrNull(16) ?: return null
      return when (s.length) {
        6 ->
          Color(
            ((v shr 16) and 0xFFu).toInt(),
            ((v shr 8) and 0xFFu).toInt(),
            (v and 0xFFu).toInt(),
          )
        8 ->
          Color(
            ((v shr 24) and 0xFFu).toInt(),
            ((v shr 16) and 0xFFu).toInt(),
            ((v shr 8) and 0xFFu).toInt(),
            (v and 0xFFu).toInt(),
          )
        else -> null
      }
    }
  }
}
