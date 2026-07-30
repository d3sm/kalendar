package expo.modules.kalendar

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.util.Locale

internal sealed class KalendarLevel {
  data object Year : KalendarLevel()

  data object Month : KalendarLevel()

  data class Day(
    val key: String,
  ) : KalendarLevel()
}

internal val KalendarLevel.levelName: String
  get() =
    when (this) {
      is KalendarLevel.Year -> "year"
      is KalendarLevel.Month -> "month"
      is KalendarLevel.Day -> "day"
    }

internal fun KalendarState.locale(): Locale = localeTag?.let { Locale.forLanguageTag(it) } ?: Locale.getDefault()

@Composable
internal fun KalendarState.resolvedText(): Color = if (textColor == Color.Unspecified) MaterialTheme.colorScheme.onSurface else textColor

@Composable
internal fun KalendarState.resolvedMuted(): Color = if (mutedColor == Color.Unspecified) MaterialTheme.colorScheme.onSurfaceVariant else mutedColor

internal fun dayOfWeekFor(
  weekStart0: Int,
  i: Int,
): DayOfWeek = DayOfWeek.of(((weekStart0 + i + 6) % 7) + 1)

internal fun monthDays(
  month: YearMonth,
  weekStart0: Int,
): List<LocalDate?> {
  val first = month.atDay(1)
  val firstDow = first.dayOfWeek.value % 7
  val lead = (firstDow - weekStart0 + 7) % 7
  return List(lead) { null } + (1..month.lengthOfMonth()).map { month.atDay(it) }
}

@Composable
internal fun chipFill(state: KalendarState): Color = if (state.solid) state.accent.copy(alpha = 0.14f) else state.resolvedText().copy(alpha = 0.1f)

internal fun rangeInfo(
  state: KalendarState,
  date: LocalDate,
): Pair<Boolean, Boolean> {
  if (state.selectionMode != SelectionMode.RANGE) return false to false
  val s = state.rangeStart ?: return false to false
  val e = state.rangeEnd ?: s
  val lo = minOf(s, e)
  val hi = maxOf(s, e)
  return (!date.isBefore(lo) && !date.isAfter(hi)) to (date == lo || date == hi)
}

@Composable
fun KalendarRoot(state: KalendarState) {
  val dark = isSystemInDarkTheme()
  val scheme = if (dark) darkColorScheme() else lightColorScheme()
  MaterialTheme(colorScheme = scheme) {
    var level by remember { mutableStateOf<KalendarLevel>(KalendarLevel.Month) }

    LaunchedEffect(state.levelProp) {
      when (state.levelProp) {
        "year" -> if (level != KalendarLevel.Year) level = KalendarLevel.Year
        "month" -> if (level != KalendarLevel.Month) level = KalendarLevel.Month
        "day" -> {
          val k =
            state.selectedKeys.firstOrNull()
              ?: KalendarState.key(state.monthAnchor)
          if (level != KalendarLevel.Day(k)) level = KalendarLevel.Day(k)
        }
      }
    }

    val tag = state.testTag
    val a11yLabel = state.accessibilityLabel
    Box(
      Modifier
        .fillMaxSize()
        .background(state.background)
        .then(if (tag != null) Modifier.testTag(tag) else Modifier)
        .then(if (a11yLabel != null) Modifier.semantics { contentDescription = a11yLabel } else Modifier),
    ) {
      AnimatedContent(
        targetState = level,
        transitionSpec = {
          val entering =
            targetState is KalendarLevel.Day ||
              (targetState is KalendarLevel.Month && initialState is KalendarLevel.Year)
          if (entering) {
            (fadeIn(tween(200)) + scaleIn(initialScale = 0.85f, animationSpec = tween(280)))
              .togetherWith(fadeOut(tween(160)) + scaleOut(targetScale = 1.1f, animationSpec = tween(280)))
          } else {
            (fadeIn(tween(200)) + scaleIn(initialScale = 1.1f, animationSpec = tween(280)))
              .togetherWith(fadeOut(tween(160)) + scaleOut(targetScale = 0.85f, animationSpec = tween(280)))
          }
        },
        label = "level",
      ) { lv ->
        val navigate: (KalendarLevel) -> Unit = { next ->
          state.onLevelChange?.invoke(next.levelName)
          level = next
        }
        when (lv) {
          is KalendarLevel.Year -> YearView(state, navigate)
          is KalendarLevel.Month -> MonthView(state, navigate)
          is KalendarLevel.Day -> DayView(state, lv.key, navigate)
        }
      }
    }
  }
}
