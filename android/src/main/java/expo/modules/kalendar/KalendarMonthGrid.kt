package expo.modules.kalendar

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter

@Composable
internal fun Chevron(
  state: KalendarState,
  glyph: String,
  label: String? = null,
  onClick: () -> Unit,
) {
  Box(
    contentAlignment = Alignment.Center,
    modifier =
      Modifier
        .size(36.dp)
        .clip(CircleShape)
        .background(chipFill(state))
        .then(if (label != null) Modifier.semantics { contentDescription = label } else Modifier)
        .clickable(onClick = onClick),
  ) {
    Text(glyph, color = state.accent, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
  }
}

@Composable
internal fun MonthGrid(
  state: KalendarState,
  month: YearMonth,
  onDayTap: (LocalDate, String) -> Unit,
) {
  val allDays = monthDays(month, state.firstWeekday)
  val allKeys = allDays.map { it?.let { d -> KalendarState.key(d) } }
  val spans = state.spanningEvents
  val bars =
    if (spans.isNotEmpty()) {
      KalendarCore.layoutMonthBars(allKeys, spans.map { KalendarCore.SpanEvent(it.uid, it.key, it.endKey) }, 2)
    } else {
      null
    }
  val colorFor = spans.associate { it.uid to (it.color ?: state.accent) }
  val weeks = (allDays.size + 6) / 7
  BoxWithConstraints(Modifier.fillMaxWidth()) {
    val colW = maxWidth / 7
    Column {
      for (w in 0 until weeks) {
        val rowDays = (0 until 7).map { allDays.getOrNull(w * 7 + it) }
        MonthWeekRow(
          state,
          rowDays,
          week = w,
          bars = bars,
          colorFor = colorFor,
          hasSpans = spans.isNotEmpty(),
          colW = colW,
          onTap = onDayTap,
        )
      }
    }
  }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
internal fun MonthWeekRow(
  state: KalendarState,
  days: List<LocalDate?>,
  week: Int,
  bars: KalendarCore.MonthBars?,
  colorFor: Map<String, Color>,
  hasSpans: Boolean,
  colW: Dp,
  onTap: (LocalDate, String) -> Unit,
) {
  val haptics = LocalHapticFeedback.current
  val today = LocalDate.now()
  val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
  val cellH = if (hasSpans) 56.dp else 46.dp
  val numArea = 40.dp
  val rowHasBars = hasSpans && bars != null && bars.segments.any { it.week == week }

  Box(Modifier.fillMaxWidth()) {
    Row(Modifier.fillMaxWidth()) {
      for (col in 0 until 7) {
        val date = days.getOrNull(col)
        Box(Modifier.weight(1f).height(cellH), contentAlignment = Alignment.TopCenter) {
          if (date != null) {
            val key = KalendarState.key(date)
            val disabled = state.isDisabled(date)
            val selected = state.selectionMode != SelectionMode.RANGE && state.selectedKeys.contains(key)
            val (inRange, isEnd) = rangeInfo(state, date)
            val solid = selected || isEnd
            val marked = state.markedKeys.contains(key) || state.timedDayKeys.contains(key)
            val overflow = bars?.overflow?.get(key) ?: 0
            val shape =
              when (state.selectionShape) {
                SelectionShape.CIRCLE -> CircleShape
                SelectionShape.ROUNDED -> RoundedCornerShape(state.cornerRadius.dp)
                SelectionShape.SQUARE -> RoundedCornerShape(0.dp)
              }
            val fg =
              when {
                disabled -> state.resolvedMuted().copy(alpha = 0.4f)
                solid && state.solid -> state.selectedTextColor
                else -> state.resolvedText()
              }
            if (inRange && !isEnd) {
              Box(Modifier.matchParentSize().background(state.accent.copy(alpha = 0.16f)))
            }
            val circleBg =
              when {
                solid && state.solid -> state.accent
                solid -> state.resolvedText().copy(alpha = 0.18f)
                else -> Color.Transparent
              }
            val circleMod =
              Modifier
                .size(if (hasSpans) 36.dp else 40.dp)
                .clip(shape)
                .background(circleBg)
                .then(if (date == today && !solid && !disabled) Modifier.border(1.5.dp, state.accent, shape) else Modifier)
                .combinedClickable(
                  enabled = !disabled,
                  onClick = { onTap(date, key) },
                  onLongClick = {
                    if (state.hapticsEnabled) haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    state.onDayLongPress?.invoke(key)
                  },
                )
            if (hasSpans) {
              Box(Modifier.fillMaxWidth().height(if (rowHasBars) numArea else cellH), contentAlignment = Alignment.Center) {
                Box(contentAlignment = Alignment.Center, modifier = circleMod) {
                  Text("${date.dayOfMonth}", color = fg, fontSize = 14.sp, fontWeight = if (solid) FontWeight.Bold else FontWeight.Normal)
                }
              }
            } else {
              Box(contentAlignment = Alignment.Center, modifier = Modifier.padding(top = 3.dp).then(circleMod)) {
                Text("${date.dayOfMonth}", color = fg, fontSize = 15.sp, fontWeight = if (solid) FontWeight.Bold else FontWeight.Normal)
              }
            }
            if (hasSpans && overflow > 0) {
              Text(
                "+$overflow",
                color = state.resolvedMuted(),
                fontSize = 8.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 2.dp),
              )
            } else if (!hasSpans && marked) {
              Box(
                Modifier
                  .align(Alignment.BottomCenter)
                  .padding(bottom = 5.dp)
                  .size(4.5.dp)
                  .clip(CircleShape)
                  .background(if (solid && state.solid) state.selectedTextColor else state.accent),
              )
            }
          }
        }
      }
    }
    if (hasSpans && bars != null) {
      val barH = 4.dp
      val barGap = 2.dp
      bars.segments.filter { it.week == week }.forEach { seg ->
        val sc = if (rtl) (6 - seg.endCol) else seg.startCol
        val lead = if (if (rtl) seg.continuesRight else seg.continuesLeft) 0.dp else 2.dp
        val trail = if (if (rtl) seg.continuesLeft else seg.continuesRight) 0.dp else 2.dp
        val x = colW * sc + lead
        val w = (colW * (seg.endCol - seg.startCol + 1) - lead - trail).coerceAtLeast(0.dp)
        Box(
          Modifier
            .offset(x = x, y = numArea + (barH + barGap) * seg.lane)
            .size(width = w, height = barH)
            .clip(RoundedCornerShape(2.dp))
            .background(colorFor[seg.uid] ?: state.accent),
        )
      }
    }
  }
}

@Composable
internal fun YearView(
  state: KalendarState,
  setLevel: (KalendarLevel) -> Unit,
) {
  val locale = state.locale()
  val text = state.resolvedText()
  var year by remember { mutableStateOf(state.monthAnchor.year) }
  Column(Modifier.fillMaxSize().padding(18.dp).verticalScroll(rememberScrollState())) {
    Row(verticalAlignment = Alignment.CenterVertically) {
      Text("$year", color = state.accent, fontSize = 30.sp, fontWeight = FontWeight.Bold)
      Spacer(Modifier.weight(1f))
      Chevron(state, "‹", state.label("prevYear", "Previous year")) { year-- }
      Spacer(Modifier.width(8.dp))
      Chevron(state, "›", state.label("nextYear", "Next year")) { year++ }
    }
    Spacer(Modifier.height(14.dp))
    for (row in 0 until 4) {
      Row(Modifier.fillMaxWidth()) {
        for (col in 0 until 3) {
          val m = row * 3 + col + 1
          val ym = YearMonth.of(year, m)
          Column(
            Modifier
              .weight(1f)
              .padding(5.dp)
              .clip(RoundedCornerShape(14.dp))
              .background(text.copy(alpha = 0.07f))
              .border(1.dp, text.copy(alpha = 0.08f), RoundedCornerShape(14.dp))
              .clickable {
                state.monthAnchor = state.clampMonth(ym.atDay(1))
                state.onMonthChange?.invoke(state.monthAnchor)
                setLevel(KalendarLevel.Month)
              }.padding(8.dp),
          ) {
            Text(
              ym
                .atDay(1)
                .format(DateTimeFormatter.ofPattern("LLLL", locale))
                .replaceFirstChar { it.titlecase(locale) },
              color = state.accent,
              fontSize = 12.sp,
              fontWeight = FontWeight.Bold,
              maxLines = 1,
              overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(4.dp))
            MiniMonth(state, ym)
          }
        }
      }
    }
  }
}

@Composable
private fun MiniMonth(
  state: KalendarState,
  month: YearMonth,
) {
  val today = LocalDate.now()
  val days = monthDays(month, state.firstWeekday)
  Column {
    for (row in 0 until ((days.size + 6) / 7)) {
      Row {
        for (col in 0 until 7) {
          val date = days.getOrNull(row * 7 + col)
          Box(Modifier.weight(1f).height(13.dp), contentAlignment = Alignment.Center) {
            if (date != null) {
              val isToday = date == today
              Box(
                contentAlignment = Alignment.Center,
                modifier =
                  if (isToday) {
                    Modifier.size(12.dp).clip(CircleShape).background(state.accent)
                  } else {
                    Modifier
                  },
              ) {
                Text(
                  "${date.dayOfMonth}",
                  color = if (isToday) state.selectedTextColor else state.resolvedText(),
                  fontSize = 7.sp,
                  fontWeight = if (isToday) FontWeight.Bold else FontWeight.Medium,
                )
              }
            }
          }
        }
      }
    }
  }
}
