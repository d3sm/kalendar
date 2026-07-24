package expo.modules.kalendar

import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

// Shared-spec algorithms. No Compose/Android deps — plain Kotlin, tested
// against the fixtures in spec/fixtures (see android/src/test). The
// TypeScript reference lives in src/core; keep implementations in lockstep.

object KalendarCore {
  /** 0 = Sunday … 6 = Saturday for both arguments. null = leading blank. */
  fun grid(
    firstDow0: Int,
    daysInMonth: Int,
    weekStart0: Int,
  ): List<Int?> {
    val lead = (firstDow0 - weekStart0 + 7) % 7
    return List(lead) { null } + (1..daysInMonth).toList()
  }

  /** Weekday indices (0 = Sunday) in display order for a given week start. */
  fun orderedWeekdays(weekStart0: Int): List<Int> = List(7) { (weekStart0 + it) % 7 }

  data class CoreEvent(
    val uid: String,
    val start: Int,
    val end: Int,
  )

  data class CorePlaced(
    val uid: String,
    val col: Int,
    val cols: Int,
    val reserved: Boolean,
  )

  data class CoreOverflow(
    val uids: List<String>,
    val start: Int,
    val end: Int,
  )

  fun layoutEvents(
    events: List<CoreEvent>,
    maxCols: Int,
  ): Pair<List<CorePlaced>, List<CoreOverflow>> {
    val sorted = events.sortedWith(compareBy({ it.start }, { -it.end }, { it.uid }))
    val placed = mutableListOf<CorePlaced>()
    val overflow = mutableListOf<CoreOverflow>()
    var colEnds = mutableListOf<Int>()
    var members = mutableListOf<Pair<String, Int>>()
    var hidden = mutableListOf<CoreEvent>()
    var clusterEnd = Int.MIN_VALUE

    fun close() {
      if (members.isEmpty() && hidden.isEmpty()) return
      val cols = max(colEnds.size, 1)
      placed += members.map { CorePlaced(it.first, it.second, cols, hidden.isNotEmpty()) }
      if (hidden.isNotEmpty()) {
        overflow +=
          CoreOverflow(
            hidden.map { it.uid },
            hidden.minOf { it.start },
            hidden.maxOf { it.end },
          )
      }
      colEnds = mutableListOf()
      members = mutableListOf()
      hidden = mutableListOf()
      clusterEnd = Int.MIN_VALUE
    }

    for (ev in sorted) {
      if (ev.start >= clusterEnd) close()
      val c = colEnds.indexOfFirst { it <= ev.start }
      when {
        c >= 0 -> {
          colEnds[c] = ev.end
          members += ev.uid to c
        }
        colEnds.size < maxCols -> {
          colEnds += ev.end
          members += ev.uid to (colEnds.size - 1)
        }
        else -> hidden += ev
      }
      clusterEnd = max(clusterEnd, ev.end)
    }
    close()
    return placed to overflow
  }

  /** Rounding is floor(x/step + 0.5) — ties toward +∞ — matching the spec. */
  fun snapDelta(
    raw: Double,
    lo: Int,
    hi: Int,
    step: Int = 15,
  ): Int {
    val clamped = min(max(raw, lo.toDouble()), hi.toDouble())
    val snapped = floor(clamped / step + 0.5).toInt() * step
    return min(max(snapped, lo), hi)
  }

  fun slotForPress(
    pressedMin: Int,
    startHour: Int,
    endHour: Int,
  ): Pair<Int, Int> {
    var m = floor(pressedMin / 30.0).toInt() * 30
    m = min(max(m, startHour * 60), endHour * 60 - 60)
    return m to (m + 60)
  }

  data class SpanEvent(
    val uid: String,
    val startKey: String,
    val endKey: String,
  )

  data class BarSegment(
    val uid: String,
    val week: Int,
    val startCol: Int,
    val endCol: Int,
    val lane: Int,
    val continuesLeft: Boolean,
    val continuesRight: Boolean,
  )

  data class MonthBars(
    val segments: List<BarSegment>,
    val overflow: Map<String, Int>,
  )

  fun layoutMonthBars(
    dayKeys: List<String?>,
    events: List<SpanEvent>,
    maxLanes: Int,
  ): MonthBars {
    val weeks = (dayKeys.size + 6) / 7
    val segments = mutableListOf<BarSegment>()
    val overflow = mutableMapOf<String, Int>()
    val sorted =
      events.sortedWith(
        compareBy<SpanEvent> { it.startKey }.thenByDescending { it.endKey }.thenBy { it.uid },
      )

    for (w in 0 until weeks) {
      val cells = dayKeys.subList(w * 7, minOf(w * 7 + 7, dayKeys.size))
      val laneRanges = mutableListOf<MutableList<Pair<Int, Int>>>()
      for (ev in sorted) {
        var startCol = -1
        var endCol = -1
        for (c in cells.indices) {
          val key = cells[c]
          if (key != null && ev.startKey <= key && key <= ev.endKey) {
            if (startCol < 0) startCol = c
            endCol = c
          }
        }
        if (startCol < 0) continue
        var lane = -1
        for (l in 0 until maxLanes) {
          val ranges = laneRanges.getOrNull(l) ?: emptyList()
          if (ranges.none { !(endCol < it.first || startCol > it.second) }) {
            lane = l
            break
          }
        }
        if (lane >= 0) {
          while (laneRanges.size <= lane) laneRanges.add(mutableListOf())
          laneRanges[lane].add(startCol to endCol)
          segments.add(
            BarSegment(
              ev.uid,
              w,
              startCol,
              endCol,
              lane,
              continuesLeft = ev.startKey < (cells[startCol] ?: ""),
              continuesRight = ev.endKey > (cells[endCol] ?: ""),
            ),
          )
        } else {
          for (c in startCol..endCol) {
            val key = cells[c]
            if (key != null) overflow[key] = (overflow[key] ?: 0) + 1
          }
        }
      }
    }
    return MonthBars(segments, overflow)
  }
}
