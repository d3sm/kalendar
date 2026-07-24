package expo.modules.kalendar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.format.DateTimeFormatter
import kotlin.math.max
import kotlin.math.roundToInt

private val EDITOR_PALETTE = listOf("#ff5c8a", "#ff8a00", "#facc15", "#22c55e", "#00c2ff", "#7c5cff")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun EditorSheet(
  state: KalendarState,
  ev: KalEvent,
  onDismiss: () -> Unit,
) {
  var title by remember { mutableStateOf(ev.title) }
  var start by remember { mutableStateOf(ev.startMin) }
  var end by remember { mutableStateOf(ev.endMin) }
  var colorHex by remember { mutableStateOf(ev.colorHex) }
  val palette = EDITOR_PALETTE
  val text = state.resolvedText()

  ModalBottomSheet(onDismissRequest = onDismiss) {
    Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 32.dp)) {
      Text(state.label("editEvent", "Edit event"), fontSize = 17.sp, fontWeight = FontWeight.Bold, color = text)
      Spacer(Modifier.height(12.dp))
      OutlinedTextField(
        value = title,
        onValueChange = { title = it },
        label = { Text(state.label("title", "Title")) },
        modifier = Modifier.fillMaxWidth(),
      )
      Spacer(Modifier.height(12.dp))
      TimeRow(state.label("starts", "Starts"), start) { new ->
        start = new.coerceIn(0, 23 * 60 + 45)
        if (end < start + 15) end = start + 15
      }
      TimeRow(state.label("ends", "Ends"), end) { new ->
        end = new.coerceIn(start + 15, 24 * 60)
      }
      Spacer(Modifier.height(12.dp))
      Row {
        palette.forEach { hex ->
          val c = KalendarState.parseColor(hex) ?: Color.Gray
          Box(
            Modifier
              .padding(end = 10.dp)
              .size(30.dp)
              .clip(CircleShape)
              .background(c)
              .then(
                if (colorHex?.lowercase() == hex) {
                  Modifier.border(2.dp, text, CircleShape)
                } else {
                  Modifier
                },
              ).clickable { colorHex = hex },
          )
        }
      }
      Spacer(Modifier.height(18.dp))
      Row {
        TextButton(onClick = {
          state.onEventDelete?.invoke(ev)
          onDismiss()
        }) {
          Text(state.label("delete", "Delete"), color = Color(0xFFFF3B30))
        }
        Spacer(Modifier.weight(1f))
        TextButton(onClick = onDismiss) { Text(state.label("cancel", "Cancel")) }
        Spacer(Modifier.width(8.dp))
        Button(onClick = {
          state.onEventChange?.invoke(ev, title, start, end, colorHex, ev.allDay)
          onDismiss()
        }) { Text(state.label("save", "Save")) }
      }
    }
  }
}

@Composable
internal fun TimeRow(
  label: String,
  minutes: Int,
  onChange: (Int) -> Unit,
) {
  Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 4.dp)) {
    Text(label, modifier = Modifier.weight(1f))
    TextButton(onClick = { onChange(minutes - 15) }) { Text("−15") }
    Text(KalendarState.hm(minutes), fontWeight = FontWeight.SemiBold)
    TextButton(onClick = { onChange(minutes + 15) }) { Text("+15") }
  }
}

@Composable
internal fun OverflowSheet(
  state: KalendarState,
  evs: List<KalEvent>,
  onSelect: (KalEvent) -> Unit,
  onDismiss: () -> Unit,
) {
  val text = state.resolvedText()
  val muted = state.resolvedMuted()
  Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp)) {
    Text(state.label("atSameTime", "At the same time"), fontSize = 16.sp, fontWeight = FontWeight.Bold, color = text)
    Spacer(Modifier.height(10.dp))
    evs.forEach { ev ->
      Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier =
          Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .clickable { onSelect(ev) }
            .padding(vertical = 10.dp, horizontal = 6.dp),
      ) {
        Box(Modifier.size(10.dp).clip(CircleShape).background(ev.color ?: state.accent))
        Spacer(Modifier.width(10.dp))
        Column {
          Text(ev.title, fontWeight = FontWeight.SemiBold, color = text)
          Text(
            "${KalendarState.hm(ev.startMin)} – ${KalendarState.hm(ev.endMin)}",
            fontSize = 12.sp,
            color = muted,
          )
        }
      }
    }
  }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DaySheet(
  state: KalendarState,
  dayKey: String,
  onOpenDay: (String) -> Unit,
  onDismiss: () -> Unit,
) {
  val locale = state.locale()
  val text = state.resolvedText()
  val muted = state.resolvedMuted()
  val date = KalendarState.parse(dayKey)
  val evs = remember(dayKey, state.events) { state.allDayEventsOn(dayKey) + state.timelineEventsOn(dayKey) }

  ModalBottomSheet(onDismissRequest = onDismiss) {
    Column(
      Modifier
        .fillMaxWidth()
        .padding(horizontal = 20.dp)
        .padding(bottom = 32.dp)
        .verticalScroll(rememberScrollState()),
    ) {
      Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
          date?.let {
            Text(
              it.format(DateTimeFormatter.ofPattern("EEEE", locale)).replaceFirstChar { c -> c.titlecase(locale) },
              color = state.accent,
              fontSize = 11.sp,
              fontWeight = FontWeight.SemiBold,
            )
            Text(
              it.format(DateTimeFormatter.ofPattern("d MMMM yyyy", locale)),
              color = text,
              fontSize = 20.sp,
              fontWeight = FontWeight.Bold,
            )
          }
        }
        if (state.dayViewEnabled) {
          TextButton(onClick = { onOpenDay(dayKey) }) {
            Text(state.label("openDay", "Open"), color = state.accent)
          }
        }
      }
      Spacer(Modifier.height(12.dp))
      if (evs.isEmpty()) {
        Text(state.label("noEvents", "No events"), color = muted, fontSize = 14.sp)
      } else {
        evs.forEach { ev ->
          DaySheetEventRow(state, ev, onDismiss)
        }
      }
    }
  }
}

@Composable
private fun DaySheetEventRow(
  state: KalendarState,
  ev: KalEvent,
  onDismiss: () -> Unit,
) {
  val text = state.resolvedText()
  val muted = state.resolvedMuted()
  Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier =
      Modifier
        .fillMaxWidth()
        .clip(RoundedCornerShape(10.dp))
        .clickable {
          state.onEventPress?.invoke(ev)
          onDismiss()
        }.padding(vertical = 10.dp, horizontal = 4.dp),
  ) {
    Box(
      Modifier
        .width(4.dp)
        .height(36.dp)
        .clip(RoundedCornerShape(2.dp))
        .background(ev.color ?: state.accent),
    )
    Spacer(Modifier.width(12.dp))
    Column(Modifier.weight(1f)) {
      Text(ev.title, color = text, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
      if (ev.allDay || ev.endKey > ev.key) {
        Text(state.label("allDay", "All day"), color = muted, fontSize = 12.sp)
      } else {
        Text(
          "${KalendarState.hm(ev.startMin)} – ${KalendarState.hm(ev.endMin)}",
          color = muted,
          fontSize = 12.sp,
        )
      }
    }
  }
}

@Composable
internal fun EventChipView(
  state: KalendarState,
  ev: KalEvent,
  base: Int,
  hourHeight: Float,
  startHour: Int,
  endHour: Int,
  widthDp: Dp,
  xDp: Dp,
  timeLabel: (Int, Int) -> String,
  setDragLock: (Boolean) -> Unit,
  onCommit: (Int) -> Unit,
  onTap: () -> Unit,
  onLongPress: (() -> Unit)? = null,
) {
  val haptics = LocalHapticFeedback.current
  val density = LocalDensity.current
  var dragging by remember { mutableStateOf(false) }
  var deltaMin by remember { mutableStateOf(0f) }
  var snapped by remember { mutableStateOf(0) }
  val dur = ev.endMin - ev.startMin
  val lo = (startHour * 60 - ev.startMin).toFloat()
  val hi = max(lo, (endHour * 60 - dur - ev.startMin).toFloat())
  val hourPx = with(density) { hourHeight.dp.toPx() }
  val visual = if (dragging) deltaMin.roundToInt() else base
  val labelDelta = if (dragging) snapped else base
  val color = ev.color ?: state.accent
  val hDp = max(dur / 60f * hourHeight - 2f, 26f)
  val text = state.resolvedText()
  val muted = state.resolvedMuted()

  Column(
    verticalArrangement = Arrangement.Center,
    modifier =
      Modifier
        .offset(x = xDp, y = ((ev.startMin + visual - startHour * 60) / 60f * hourHeight + 8f).dp)
        .size(width = widthDp, height = hDp.dp)
        .graphicsLayer {
          if (dragging) {
            scaleX = 1.04f
            scaleY = 1.04f
            shadowElevation = 24f
          }
        }.clip(RoundedCornerShape(10.dp))
        .background(color.copy(alpha = if (state.solid) 0.9f else 0.3f))
        .border(1.dp, color.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
        .then(
          if (!state.readOnly) {
            Modifier.pointerInput(ev.uid) {
              detectDragGesturesAfterLongPress(
                onDragStart = {
                  if (state.hapticsEnabled) haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                  onLongPress?.invoke()
                  deltaMin = base.toFloat()
                  snapped = base
                  dragging = true
                  setDragLock(true)
                },
                onDrag = { change, amount ->
                  change.consume()
                  deltaMin = (deltaMin + amount.y / hourPx * 60f).coerceIn(lo, hi)
                  val s = KalendarCore.snapDelta(deltaMin.toDouble(), lo.toInt(), hi.toInt())
                  if (s != snapped) {
                    if (state.hapticsEnabled) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    snapped = s
                  }
                },
                onDragEnd = {
                  dragging = false
                  setDragLock(false)
                  if (snapped != base) onCommit(snapped)
                },
                onDragCancel = {
                  dragging = false
                  setDragLock(false)
                },
              )
            }
          } else if (onLongPress != null) {
            Modifier.pointerInput(ev.uid) {
              detectTapGestures(onLongPress = {
                if (state.hapticsEnabled) haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onLongPress()
              })
            }
          } else {
            Modifier
          },
        ).clickable(onClick = onTap)
        .padding(horizontal = 8.dp, vertical = 3.dp),
  ) {
    Text(ev.title, color = text, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
    Text(
      timeLabel(ev.startMin + labelDelta, ev.endMin + labelDelta),
      color = muted,
      fontSize = 10.sp,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
    )
  }
}

@Composable
internal fun DayAgendaInline(
  state: KalendarState,
  dayKey: String,
  setLevel: (KalendarLevel) -> Unit,
  modifier: Modifier = Modifier,
) {
  val text = state.resolvedText()
  val muted = state.resolvedMuted()
  val evs = remember(dayKey, state.events) { state.allDayEventsOn(dayKey) + state.timelineEventsOn(dayKey) }
  Column(modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(top = 8.dp)) {
    if (evs.isEmpty()) {
      Text(state.label("noEvents", "No events"), color = muted, fontSize = 13.sp, modifier = Modifier.padding(8.dp))
    } else {
      evs.forEach { ev ->
        Row(
          verticalAlignment = Alignment.CenterVertically,
          modifier =
            Modifier
              .fillMaxWidth()
              .clickable {
                state.onEventPress?.invoke(ev)
                if (state.dayViewEnabled) setLevel(KalendarLevel.Day(ev.key))
              }.padding(vertical = 8.dp, horizontal = 4.dp),
        ) {
          Box(
            Modifier
              .width(4.dp)
              .height(32.dp)
              .clip(RoundedCornerShape(2.dp))
              .background(ev.color ?: state.accent),
          )
          Spacer(Modifier.width(12.dp))
          Column {
            Text(ev.title, color = text, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (!ev.allDay && ev.endKey == ev.key) {
              Text(
                "${KalendarState.hm(ev.startMin)} – ${KalendarState.hm(ev.endMin)}",
                color = muted,
                fontSize = 12.sp,
              )
            }
          }
        }
      }
    }
  }
}
