package expo.modules.kalendar

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.flow.collectLatest
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.time.format.TextStyle as JTextStyle

private const val PAGER_CENTER = 5000
private const val CONT_CENTER = 2400
private const val CONT_TOTAL = 4800

@OptIn(ExperimentalFoundationApi::class)
@Composable
internal fun MonthView(
  state: KalendarState,
  setLevel: (KalendarLevel) -> Unit,
) {
  val locale = state.locale()
  val text = state.resolvedText()
  val muted = state.resolvedMuted()
  val base = remember { YearMonth.from(state.monthAnchor) }
  var expanded by remember { mutableStateOf(true) }
  var weekAnchor by remember { mutableStateOf(state.monthAnchor) }
  var daySheetKey by remember { mutableStateOf<String?>(null) }

  fun ymFor(page: Int): YearMonth = base.plusMonths((page - PAGER_CENTER).toLong())

  val pager = rememberPagerState(initialPage = PAGER_CENTER) { 10000 }
  LaunchedEffect(state.monthAnchor) {
    val target = PAGER_CENTER + ChronoUnit.MONTHS.between(base, YearMonth.from(state.monthAnchor)).toInt()
    if (pager.currentPage != target && !pager.isScrollInProgress) pager.animateScrollToPage(target)
  }
  LaunchedEffect(pager) {
    snapshotFlow { pager.settledPage }.collectLatest { page ->
      val ym = ymFor(page)
      if (YearMonth.from(state.monthAnchor) != ym) {
        state.monthAnchor = state.clampMonth(ym.atDay(1))
        state.onMonthChange?.invoke(state.monthAnchor)
      }
    }
  }
  LaunchedEffect(state.expandedProp) {
    state.expandedProp?.let { if (it != expanded) expanded = it }
  }

  val onDayTap: (LocalDate, String) -> Unit = { date, key ->
    state.select(date)
    if (state.selectionMode == SelectionMode.RANGE) {
      val (start, end) =
        if (state.rangeStart != null && state.rangeEnd == null) {
          Pair(KalendarState.key(state.rangeStart!!), key)
        } else {
          Pair(key, null)
        }
      state.onRangeChange?.invoke(start, end)
    }
    state.onDayPress?.invoke(key)
    if (state.selectionMode == SelectionMode.SINGLE) {
      when {
        state.daySheetEnabled -> daySheetKey = key
        state.dayViewEnabled -> setLevel(KalendarLevel.Day(key))
      }
    }
  }

  Column(Modifier.fillMaxSize().padding(18.dp).background(state.background)) {
    Row(verticalAlignment = Alignment.CenterVertically) {
      val title =
        state.monthAnchor
          .format(DateTimeFormatter.ofPattern("LLLL yyyy", locale))
          .replaceFirstChar { it.titlecase(locale) }
      if (state.yearViewEnabled) {
        Row(
          verticalAlignment = Alignment.CenterVertically,
          modifier =
            Modifier
              .clip(RoundedCornerShape(50))
              .background(chipFill(state))
              .clickable { setLevel(KalendarLevel.Year) }
              .padding(horizontal = 14.dp, vertical = 7.dp),
        ) {
          Text("‹ ", color = text, fontSize = 17.sp)
          Text(title, color = text, fontSize = 19.sp, fontWeight = FontWeight.SemiBold)
        }
      } else {
        Text(title, color = text, fontSize = 19.sp, fontWeight = FontWeight.SemiBold)
      }
      Spacer(Modifier.weight(1f))
      if (!state.scrollContinuous) {
        Chevron(state, "‹", state.label("prevMonth", "Previous month")) {
          state.monthAnchor = state.clampMonth(state.monthAnchor.minusMonths(1).withDayOfMonth(1))
          state.onMonthChange?.invoke(state.monthAnchor)
        }
        Spacer(Modifier.width(8.dp))
        Chevron(state, "›", state.label("nextMonth", "Next month")) {
          state.monthAnchor = state.clampMonth(state.monthAnchor.plusMonths(1).withDayOfMonth(1))
          state.onMonthChange?.invoke(state.monthAnchor)
        }
      }
    }
    Spacer(Modifier.height(14.dp))
    Row(Modifier.fillMaxWidth()) {
      for (i in 0 until 7) {
        Text(
          dayOfWeekFor(state.firstWeekday, i)
            .getDisplayName(JTextStyle.NARROW, locale)
            .uppercase(locale),
          color = muted,
          fontSize = 11.sp,
          fontWeight = FontWeight.SemiBold,
          textAlign = TextAlign.Center,
          modifier = Modifier.weight(1f),
        )
      }
    }
    Spacer(Modifier.height(4.dp))
    val hasSpans = state.spanningEvents.isNotEmpty()
    val gridH = if (hasSpans) 290.dp else 252.dp
    val stripH = if (hasSpans) 60.dp else 52.dp
    when {
      state.scrollContinuous -> ContinuousMonths(state, onDayTap, Modifier.weight(1f))
      expanded ->
        HorizontalPager(pager, Modifier.height(gridH)) { page ->
          MonthGrid(state, ymFor(page), onDayTap)
        }
      else -> WeekStripRow(state, weekAnchor, onDayTap, Modifier.height(stripH))
    }
    if (state.expandableEnabled && !state.scrollContinuous) {
      Box(
        contentAlignment = Alignment.Center,
        modifier =
          Modifier.fillMaxWidth().height(44.dp).clickable {
            val next = !expanded
            if (next) state.monthAnchor = weekAnchor.withDayOfMonth(1) else weekAnchor = state.monthAnchor
            expanded = next
            state.onExpandedChange?.invoke(next)
          },
      ) {
        Box(Modifier.size(width = 36.dp, height = 5.dp).clip(CircleShape).background(muted.copy(alpha = 0.35f)))
      }
    }
    if (state.expandableEnabled && !state.scrollContinuous && !expanded) {
      DayAgendaInline(state, KalendarState.key(weekAnchor), setLevel, Modifier.weight(1f))
    } else if (!state.scrollContinuous) {
      Spacer(Modifier.weight(1f))
    }
  }

  daySheetKey?.let { k ->
    DaySheet(
      state,
      k,
      onOpenDay = { key ->
        daySheetKey = null
        if (state.dayViewEnabled) setLevel(KalendarLevel.Day(key))
      },
      onDismiss = { daySheetKey = null },
    )
  }
}

@Composable
private fun ContinuousMonths(
  state: KalendarState,
  onDayTap: (LocalDate, String) -> Unit,
  modifier: Modifier = Modifier,
) {
  val locale = state.locale()
  val text = state.resolvedText()
  val baseWeek =
    remember(state.firstWeekday) {
      val m = state.monthAnchor.withDayOfMonth(1)
      m.minusDays(((m.dayOfWeek.value % 7 - state.firstWeekday + 7) % 7).toLong())
    }
  val listState = rememberLazyListState(initialFirstVisibleItemIndex = CONT_CENTER)
  val visibleMonth by remember {
    derivedStateOf {
      listState.firstVisibleItemIndex
        .let { baseWeek.plusWeeks((it - CONT_CENTER).toLong()).plusDays(3).withDayOfMonth(1) }
    }
  }
  LaunchedEffect(visibleMonth) {
    if (visibleMonth != state.monthAnchor.withDayOfMonth(1)) {
      state.monthAnchor = state.clampMonth(visibleMonth)
      state.onMonthChange?.invoke(state.monthAnchor)
    }
  }
  LaunchedEffect(state.monthAnchor) {
    val target =
      state.monthAnchor
        .withDayOfMonth(1)
        .let { m -> m.minusDays(((m.dayOfWeek.value % 7 - state.firstWeekday + 7) % 7).toLong()) }
    val idx = CONT_CENTER + ChronoUnit.WEEKS.between(baseWeek, target).toInt()
    if (idx != listState.firstVisibleItemIndex) listState.scrollToItem(idx)
  }
  BoxWithConstraints(modifier) {
    val colW = maxWidth / 7
    LazyColumn(state = listState) {
      items(CONT_TOTAL) { i ->
        val weekStart = baseWeek.plusWeeks((i - CONT_CENTER).toLong())
        val days: List<LocalDate?> = (0 until 7).map { weekStart.plusDays(it.toLong()) }
        val dayKeys = days.map { it?.let { d -> KalendarState.key(d) } }
        val spans = state.spanningEvents
        val bars =
          if (spans.isNotEmpty()) {
            KalendarCore.layoutMonthBars(dayKeys, spans.map { KalendarCore.SpanEvent(it.uid, it.key, it.endKey) }, 2)
          } else {
            null
          }
        val colorFor = spans.associate { it.uid to (it.color ?: state.accent) }
        if (days.any { it?.dayOfMonth == 1 }) {
          val m = days.first { it?.dayOfMonth == 1 }!!.withDayOfMonth(1)
          Text(
            m
              .format(DateTimeFormatter.ofPattern("LLLL yyyy", locale))
              .replaceFirstChar { it.titlecase(locale) },
            color = text,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 14.dp, start = 4.dp, bottom = 4.dp),
          )
        }
        MonthWeekRow(
          state,
          days,
          week = 0,
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

@Composable
private fun WeekStripRow(
  state: KalendarState,
  anchor: LocalDate,
  onTap: (LocalDate, String) -> Unit,
  modifier: Modifier = Modifier,
) {
  val first = anchor.minusDays(((anchor.dayOfWeek.value % 7 - state.firstWeekday + 7) % 7).toLong())
  val days: List<LocalDate?> = (0 until 7).map { first.plusDays(it.toLong()) }
  val dayKeys = days.map { it?.let { d -> KalendarState.key(d) } }
  val spans = state.spanningEvents
  val bars =
    if (spans.isNotEmpty()) {
      KalendarCore.layoutMonthBars(dayKeys, spans.map { KalendarCore.SpanEvent(it.uid, it.key, it.endKey) }, 2)
    } else {
      null
    }
  BoxWithConstraints(modifier.fillMaxWidth()) {
    MonthWeekRow(
      state,
      days,
      week = 0,
      bars = bars,
      colorFor = spans.associate { it.uid to (it.color ?: state.accent) },
      hasSpans = spans.isNotEmpty(),
      colW = maxWidth / 7,
      onTap = onTap,
    )
  }
}
