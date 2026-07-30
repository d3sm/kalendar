package expo.modules.kalendar

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import kotlin.math.max

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
internal fun DayView(
  state: KalendarState,
  initialKey: String,
  setLevel: (KalendarLevel) -> Unit,
) {
  val baseDay = remember { KalendarState.parse(initialKey) ?: LocalDate.now() }
  val pager = rememberPagerState(initialPage = 5000) { 10000 }

  fun dayFor(page: Int): LocalDate = baseDay.plusDays((page - 5000).toLong())

  var dragLock by remember { mutableStateOf(false) }
  var hourHeight by remember { mutableStateOf(56f) }
  var editing by remember { mutableStateOf<KalEvent?>(null) }
  var overflowEvs by remember { mutableStateOf<List<KalEvent>?>(null) }
  LaunchedEffect(pager) {
    snapshotFlow { pager.settledPage }.collectLatest { page ->
      val d = dayFor(page)
      val k = KalendarState.key(d)
      if (!state.isDisabled(d)) state.onDayPress?.invoke(k)
      state.onDayOpen?.invoke(k)
    }
  }

  HorizontalPager(pager, Modifier.fillMaxSize(), userScrollEnabled = !dragLock) { page ->
    DayPane(
      state = state,
      day = dayFor(page),
      openedDay = baseDay,
      hourHeight = hourHeight,
      dragLock = dragLock,
      dragOffsets = state.dragOffsets,
      setHourHeight = { hourHeight = it },
      setDragLock = { dragLock = it },
      onEdit = { if (state.canEdit) editing = it },
      onOverflow = { overflowEvs = it },
      onBack = { setLevel(KalendarLevel.Month) },
    )
  }

  overflowEvs?.let { evs ->
    ModalBottomSheet(onDismissRequest = { overflowEvs = null }) {
      OverflowSheet(
        state,
        evs,
        onSelect = { ev ->
          overflowEvs = null
          state.onEventPress?.invoke(ev)
          if (state.canEdit) editing = ev
        },
        onDismiss = { overflowEvs = null },
      )
    }
  }

  editing?.let { ev ->
    EditorSheet(state, ev, onDismiss = { editing = null })
  }
}

@Composable
private fun DayPane(
  state: KalendarState,
  day: LocalDate,
  openedDay: LocalDate,
  hourHeight: Float,
  dragLock: Boolean,
  dragOffsets: MutableMap<String, Int>,
  setHourHeight: (Float) -> Unit,
  setDragLock: (Boolean) -> Unit,
  onEdit: (KalEvent) -> Unit,
  onOverflow: (List<KalEvent>) -> Unit,
  onBack: () -> Unit,
) {
  val locale = state.locale()
  val haptics = LocalHapticFeedback.current
  val density = LocalDensity.current
  val key = KalendarState.key(day)
  val isToday = day == LocalDate.now()
  val startHour = state.dayStartHour.coerceIn(0, 23)
  val endHour = state.dayEndHour.coerceIn(startHour + 1, 24)
  val hours = endHour - startHour
  val hourPx = with(density) { hourHeight.dp.toPx() }
  val is24h =
    when (state.timeFormat) {
      TimeFormat.H24 -> true
      TimeFormat.H12 -> false
      TimeFormat.LOCALE ->
        android.text.format.DateFormat
          .is24HourFormat(LocalContext.current)
    }
  val text = state.resolvedText()
  val muted = state.resolvedMuted()

  fun timeLabel(
    minutes: Int,
    withMin: Boolean,
  ): String {
    val h = minutes / 60
    val m = minutes % 60
    if (is24h) return "%02d:%02d".format(h, m)
    val h12 = ((h + 11) % 12) + 1
    val suf = if (h < 12) "AM" else "PM"
    return if (withMin) "$h12:%02d $suf".format(m) else "$h12 $suf"
  }

  Column(Modifier.fillMaxSize()) {
    Row(
      verticalAlignment = Alignment.CenterVertically,
      modifier = Modifier.padding(horizontal = 18.dp, vertical = 12.dp),
    ) {
      Chevron(state, "‹", onClick = onBack)
      Spacer(Modifier.width(14.dp))
      Column {
        Text(
          day.format(DateTimeFormatter.ofPattern("EEEE", locale)).uppercase(locale),
          color = state.accent,
          fontSize = 11.sp,
          fontWeight = FontWeight.SemiBold,
        )
        Text(
          day.format(DateTimeFormatter.ofPattern("d MMMM yyyy", locale)),
          color = text,
          fontSize = 22.sp,
          fontWeight = FontWeight.Bold,
        )
      }
      Spacer(Modifier.weight(1f))
      if (isToday) {
        Text(
          state.label("today", "TODAY"),
          color = state.selectedTextColor,
          fontSize = 10.sp,
          fontWeight = FontWeight.Bold,
          modifier =
            Modifier
              .clip(RoundedCornerShape(50))
              .background(state.accent)
              .padding(horizontal = 10.dp, vertical = 5.dp),
        )
      }
    }
    Box(Modifier.fillMaxWidth().height(1.dp).background(muted.copy(alpha = 0.25f)))

    val allDay = state.allDayEventsOn(key)
    if (allDay.isNotEmpty()) {
      Row(
        Modifier
          .fillMaxWidth()
          .horizontalScroll(rememberScrollState())
          .padding(horizontal = 18.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
      ) {
        allDay.forEach { ev ->
          val c = ev.color ?: state.accent
          Text(
            ev.title,
            color = state.selectedTextColor,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            modifier =
              Modifier
                .padding(end = 6.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(c)
                .padding(horizontal = 8.dp, vertical = 3.dp)
                .clickable { state.onEventPress?.invoke(ev) },
          )
        }
      }
      Box(Modifier.fillMaxWidth().height(1.dp).background(muted.copy(alpha = 0.14f)))
    }

    val scroll = rememberScrollState()
    LaunchedEffect(openedDay) {
      val explicit = state.initialScrollTime?.let { KalendarState.parseMinutes(it, -1) }?.takeIf { it >= 0 }
      if (explicit != null) {
        scroll.scrollTo(((explicit / 60f - startHour) * hourPx).coerceAtLeast(0f).toInt())
      } else {
        val h = if (openedDay == LocalDate.now()) LocalTime.now().hour else maxOf(startHour, 8)
        scroll.scrollTo(((h - 1 - startHour).coerceAtLeast(0) * hourPx).toInt())
      }
    }

    val gutterDp = 60.dp
    Box(
      Modifier
        .fillMaxSize()
        .verticalScroll(scroll, enabled = !dragLock)
        .pointerInput(Unit) {
          detectTransformGestures { _, _, zoom, _ ->
            if (zoom != 1f) setHourHeight((hourHeight * zoom).coerceIn(36f, 120f))
          }
        },
    ) {
      Column(
        Modifier
          .fillMaxWidth()
          .height((hours * hourHeight + 30).dp)
          .pointerInput(key, hourPx) {
            if (state.readOnly) return@pointerInput
            detectTapGestures(onLongPress = { off ->
              val pressed =
                startHour * 60 +
                  ((off.y - with(density) { 8.dp.toPx() }) / hourPx * 60).toInt()
              val onEv = state.timelineEventsOn(key).any { pressed >= it.startMin && pressed < it.endMin }
              if (!onEv) {
                val slot = KalendarCore.slotForPress(pressed, startHour, endHour)
                if (state.hapticsEnabled) haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                state.onSlotPress?.invoke(key, slot.first, slot.second)
              }
            })
          },
      ) {
        for (h in startHour until endHour) {
          Row(Modifier.height(hourHeight.dp), verticalAlignment = Alignment.Top) {
            Text(
              timeLabel(h * 60, false),
              color = muted,
              fontSize = 10.sp,
              textAlign = TextAlign.End,
              modifier = Modifier.width(gutterDp).padding(end = 8.dp, top = 2.dp),
            )
            Box(
              Modifier
                .weight(1f)
                .padding(top = 8.dp)
                .height(1.dp)
                .background(muted.copy(alpha = 0.18f)),
            )
          }
        }
      }

      val evs = state.timelineEventsOn(key)
      val coreEvs = evs.map { KalendarCore.CoreEvent(it.uid, it.startMin, it.endMin) }
      val (corePlaced, coreOverflow) = KalendarCore.layoutEvents(coreEvs, maxCols = 2)
      val byUid = evs.associateBy { it.uid }

      BoxWithConstraints(Modifier.fillMaxWidth()) {
        val areaDp = maxWidth - gutterDp - 8.dp
        corePlaced.forEach { p ->
          val ev = byUid[p.uid] ?: return@forEach
          val cwDp = (if (p.reserved) areaDp - 50.dp else areaDp) / p.cols
          EventChipView(
            state = state,
            ev = ev,
            base = dragOffsets[ev.uid] ?: 0,
            hourHeight = hourHeight,
            startHour = startHour,
            endHour = endHour,
            widthDp = cwDp - 3.dp,
            xDp = gutterDp + cwDp * p.col,
            timeLabel = { s, e -> "${timeLabel(s, true)} – ${timeLabel(e, true)}" },
            setDragLock = setDragLock,
            onCommit = { snapped ->
              dragOffsets[ev.uid] = snapped
              state.onEventChange?.invoke(
                ev,
                ev.title,
                ev.startMin + snapped,
                ev.endMin + snapped,
                null,
                ev.allDay,
              )
            },
            onTap = {
              state.onEventPress?.invoke(ev)
              if (state.canEdit) onEdit(ev)
            },
            onLongPress = state.onEventLongPress?.let { cb -> { cb(ev) } },
          )
        }
        coreOverflow.forEach { of ->
          val ofEvs = of.uids.mapNotNull { byUid[it] }
          val hDp = max((of.end - of.start) / 60f * hourHeight - 2f, 30f)
          Box(
            contentAlignment = Alignment.Center,
            modifier =
              Modifier
                .offset(
                  x = gutterDp + areaDp - 46.dp,
                  y = ((of.start - startHour * 60) / 60f * hourHeight + 8f).dp,
                ).size(width = 44.dp, height = hDp.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(text.copy(alpha = 0.14f))
                .border(1.dp, text.copy(alpha = 0.2f), RoundedCornerShape(10.dp))
                .clickable {
                  if (state.hapticsEnabled) haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                  onOverflow(ofEvs)
                },
          ) {
            Text("+${of.uids.size}", color = text, fontSize = 13.sp, fontWeight = FontWeight.Bold)
          }
        }
      }

      if (state.showNowIndicator && isToday) {
        val now by produceState(LocalTime.now()) {
          while (true) {
            delay(60_000)
            value = LocalTime.now()
          }
        }
        val nowMin = now.hour * 60 + now.minute
        if (nowMin in (startHour * 60)..(endHour * 60)) {
          Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier =
              Modifier
                .offset(y = ((nowMin - startHour * 60) / 60f * hourHeight + 1f).dp)
                .padding(start = gutterDp - 46.dp),
          ) {
            Text(
              timeLabel(nowMin, true),
              color = state.selectedTextColor,
              fontSize = 9.sp,
              fontWeight = FontWeight.Bold,
              modifier =
                Modifier
                  .clip(RoundedCornerShape(50))
                  .background(state.accent)
                  .padding(horizontal = 6.dp, vertical = 2.dp),
            )
            Spacer(Modifier.width(4.dp))
            Box(Modifier.weight(1f).height(2.dp).background(state.accent))
          }
        }
      }
    }
  }
}
