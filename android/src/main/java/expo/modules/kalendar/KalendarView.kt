package expo.modules.kalendar

import android.content.Context
import android.widget.FrameLayout
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.viewevent.EventDispatcher
import expo.modules.kotlin.views.ExpoView

class KalendarView(
  context: Context,
  appContext: AppContext,
) : ExpoView(context, appContext) {
  val state = KalendarState()

  private val onRangeChange by EventDispatcher()
  private val onDayPress by EventDispatcher()
  private val onDayOpen by EventDispatcher()
  private val onDayLongPress by EventDispatcher()
  private val onEventPress by EventDispatcher()
  private val onEventLongPress by EventDispatcher()
  private val onEventChange by EventDispatcher()
  private val onEventDelete by EventDispatcher()
  private val onSlotPress by EventDispatcher()
  private val onLevelChange by EventDispatcher()
  private val onMonthChange by EventDispatcher()
  private val onExpandedChange by EventDispatcher()

  init {
    state.onRangeChange = { start, end ->
      onRangeChange(
        buildMap {
          put("start", start)
          end?.let { put("end", it) }
        },
      )
    }
    state.onDayPress = { key -> onDayPress(mapOf("date" to key, "events" to state.dayEventsPayload(key))) }
    state.onDayOpen = { key -> onDayOpen(mapOf("date" to key)) }
    state.onDayLongPress = { key -> onDayLongPress(mapOf("date" to key, "events" to state.dayEventsPayload(key))) }
    state.onEventPress = { ev -> onEventPress(eventPayload(ev, ev.startMin, ev.endMin, ev.title, ev.colorHex, ev.allDay)) }
    state.onEventLongPress = { ev -> onEventLongPress(eventPayload(ev, ev.startMin, ev.endMin, ev.title, ev.colorHex, ev.allDay)) }
    state.onEventChange = { ev, title, start, end, colorHex, allDay ->
      onEventChange(eventPayload(ev, start, end, title, colorHex ?: ev.colorHex, allDay))
    }
    state.onEventDelete = { ev ->
      onEventDelete(
        buildMap {
          ev.id?.let { put("id", it) }
          put("date", ev.key)
        },
      )
    }
    state.onSlotPress = { key, start, end ->
      onSlotPress(
        mapOf("date" to key, "start" to KalendarState.hm(start), "end" to KalendarState.hm(end)),
      )
    }
    state.onLevelChange = { level -> onLevelChange(mapOf("level" to level)) }
    state.onMonthChange = { date -> onMonthChange(mapOf("month" to KalendarState.key(date))) }
    state.onExpandedChange = { expanded -> onExpandedChange(mapOf("expanded" to expanded)) }

    val compose =
      ComposeView(context).apply {
        setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
        setContent { KalendarRoot(state) }
      }
    addView(compose, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
  }

  // RN's Yoga does not lay out natively-added children — size the Compose
  // host to fill this view whenever RN assigns us a frame.
  override fun onLayout(
    changed: Boolean,
    left: Int,
    top: Int,
    right: Int,
    bottom: Int,
  ) {
    super.onLayout(changed, left, top, right, bottom)
    val child = getChildAt(0) ?: return
    val w = right - left
    val h = bottom - top
    child.measure(
      MeasureSpec.makeMeasureSpec(w, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(h, MeasureSpec.EXACTLY),
    )
    child.layout(0, 0, w, h)
  }

  private fun eventPayload(
    ev: KalEvent,
    start: Int,
    end: Int,
    title: String,
    colorHex: String?,
    allDay: Boolean,
  ): Map<String, Any> =
    buildMap {
      ev.id?.let { put("id", it) }
      put("date", ev.key)
      put("allDay", allDay)
      put("title", title)
      put("start", KalendarState.hm(start))
      put("end", KalendarState.hm(end))
      colorHex?.let { put("color", it) }
    }
}
