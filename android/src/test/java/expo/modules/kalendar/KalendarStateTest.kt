package expo.modules.kalendar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class KalendarStateTest {

  private fun state() = KalendarState()

  @Test
  fun selectSingle_tapSelects() {
    val s = state()
    val d = LocalDate.of(2026, 7, 15)
    s.select(d)
    assertTrue(s.selectedKeys.contains(KalendarState.key(d)))
  }

  @Test
  fun selectSingle_tapSameDeselects() {
    val s = state()
    val d = LocalDate.of(2026, 7, 15)
    s.select(d)
    s.select(d)
    assertTrue(s.selectedKeys.isEmpty())
  }

  @Test
  fun selectSingle_tapDifferentReplaces() {
    val s = state()
    val d1 = LocalDate.of(2026, 7, 15)
    val d2 = LocalDate.of(2026, 7, 16)
    s.select(d1)
    s.select(d2)
    assertFalse(s.selectedKeys.contains(KalendarState.key(d1)))
    assertTrue(s.selectedKeys.contains(KalendarState.key(d2)))
  }

  @Test
  fun selectMultiple_tapAdds() {
    val s = state().also { it.selectionMode = SelectionMode.MULTIPLE }
    val d1 = LocalDate.of(2026, 7, 15)
    val d2 = LocalDate.of(2026, 7, 16)
    s.select(d1)
    s.select(d2)
    assertTrue(s.selectedKeys.containsAll(listOf(KalendarState.key(d1), KalendarState.key(d2))))
  }

  @Test
  fun selectMultiple_tapSameRemoves() {
    val s = state().also { it.selectionMode = SelectionMode.MULTIPLE }
    val d = LocalDate.of(2026, 7, 15)
    s.select(d)
    s.select(d)
    assertFalse(s.selectedKeys.contains(KalendarState.key(d)))
  }

  @Test
  fun selectRange_firstTapSetsStart() {
    val s = state().also { it.selectionMode = SelectionMode.RANGE }
    val d = LocalDate.of(2026, 7, 15)
    s.select(d)
    assertEquals(d, s.rangeStart)
    assertNull(s.rangeEnd)
  }

  @Test
  fun selectRange_secondTapSetsEnd() {
    val s = state().also { it.selectionMode = SelectionMode.RANGE }
    val d1 = LocalDate.of(2026, 7, 15)
    val d2 = LocalDate.of(2026, 7, 20)
    s.select(d1)
    s.select(d2)
    assertEquals(d1, s.rangeStart)
    assertEquals(d2, s.rangeEnd)
  }

  @Test
  fun selectRange_thirdTapResetsToNewStart() {
    val s = state().also { it.selectionMode = SelectionMode.RANGE }
    val d1 = LocalDate.of(2026, 7, 15)
    val d2 = LocalDate.of(2026, 7, 20)
    val d3 = LocalDate.of(2026, 7, 25)
    s.select(d1); s.select(d2); s.select(d3)
    assertEquals(d3, s.rangeStart)
    assertNull(s.rangeEnd)
  }

  @Test
  fun isDisabled_beforeMinDate_true() {
    val s = state()
    s.minDate = LocalDate.of(2026, 7, 15)
    assertTrue(s.isDisabled(LocalDate.of(2026, 7, 14)))
  }

  @Test
  fun isDisabled_onMinDate_false() {
    val s = state()
    s.minDate = LocalDate.of(2026, 7, 15)
    assertFalse(s.isDisabled(LocalDate.of(2026, 7, 15)))
  }

  @Test
  fun isDisabled_afterMaxDate_true() {
    val s = state()
    s.maxDate = LocalDate.of(2026, 7, 15)
    assertTrue(s.isDisabled(LocalDate.of(2026, 7, 16)))
  }

  @Test
  fun isDisabled_onMaxDate_false() {
    val s = state()
    s.maxDate = LocalDate.of(2026, 7, 15)
    assertFalse(s.isDisabled(LocalDate.of(2026, 7, 15)))
  }

  @Test
  fun isDisabled_inDisabledKeys_true() {
    val s = state()
    s.disabledKeys = setOf("2026-07-15")
    assertTrue(s.isDisabled(LocalDate.of(2026, 7, 15)))
  }

  @Test
  fun clampMonth_beforeMin_clampsToMin() {
    val s = state()
    s.minDate = LocalDate.of(2026, 7, 1)
    val result = s.clampMonth(LocalDate.of(2026, 5, 1))
    assertEquals(s.minDate, result)
  }

  @Test
  fun clampMonth_afterMax_clampsToMax() {
    val s = state()
    s.maxDate = LocalDate.of(2026, 7, 1)
    val result = s.clampMonth(LocalDate.of(2026, 9, 1))
    assertEquals(s.maxDate, result)
  }

  @Test
  fun clampMonth_withinRange_unchanged() {
    val s = state()
    s.minDate = LocalDate.of(2026, 5, 1)
    s.maxDate = LocalDate.of(2026, 9, 1)
    val d = LocalDate.of(2026, 7, 1)
    assertEquals(d, s.clampMonth(d))
  }

  @Test
  fun clampMonth_exactlyOnMin_unchanged() {
    val s = state()
    s.minDate = LocalDate.of(2026, 7, 1)
    val d = LocalDate.of(2026, 7, 15)
    assertEquals(d, s.clampMonth(d))
  }
}
