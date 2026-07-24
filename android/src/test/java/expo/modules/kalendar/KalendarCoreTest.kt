package expo.modules.kalendar

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

// Runs the Kotlin implementation against the shared fixtures generated
// from the TypeScript reference (spec/generate.mjs).

private fun fixture(file: String): String {
  var dir = File(System.getProperty("user.dir")!!)
  repeat(6) {
    val candidate = File(dir, "spec/fixtures/$file")
    if (candidate.exists()) return candidate.readText()
    dir = dir.parentFile ?: return@repeat
  }
  error("fixture not found: $file (from ${System.getProperty("user.dir")})")
}

class KalendarCoreTest {

  @Test
  fun monthGridFixtures() {
    val cases = JSONArray(fixture("month-grid.json"))
    assertTrue(cases.length() > 0)
    for (i in 0 until cases.length()) {
      val c = cases.getJSONObject(i)
      val name = c.optString("name")
      val input = c.getJSONObject("input")
      val weekStart0 = input.getInt("weekStart0")
      if (c.has("expectedWeekdays")) {
        val expected = c.getJSONArray("expectedWeekdays").toIntList()
        assertEquals(name, expected, KalendarCore.orderedWeekdays(weekStart0))
        continue
      }
      val expected = c.getJSONArray("expected").toNullableIntList()
      val actual = KalendarCore.grid(input.getInt("firstDow0"), input.getInt("daysInMonth"), weekStart0)
      assertEquals(name, expected, actual)
    }
  }

  @Test
  fun overlapFixtures() {
    val cases = JSONArray(fixture("overlap.json"))
    assertTrue(cases.length() > 0)
    for (i in 0 until cases.length()) {
      val c = cases.getJSONObject(i)
      val name = c.optString("name")
      val events = c.getJSONArray("events").let { arr ->
        (0 until arr.length()).map { j ->
          val e = arr.getJSONObject(j)
          KalendarCore.CoreEvent(e.getString("uid"), e.getInt("start"), e.getInt("end"))
        }
      }
      val expected = c.getJSONObject("expected")
      val expPlaced = expected.getJSONArray("placed").let { arr ->
        (0 until arr.length()).map { j ->
          val p = arr.getJSONObject(j)
          KalendarCore.CorePlaced(p.getString("uid"), p.getInt("col"), p.getInt("cols"), p.getBoolean("reserved"))
        }
      }
      val expOverflow = expected.getJSONArray("overflow").let { arr ->
        (0 until arr.length()).map { j ->
          val o = arr.getJSONObject(j)
          KalendarCore.CoreOverflow(o.getJSONArray("uids").toStringList(), o.getInt("start"), o.getInt("end"))
        }
      }
      val (placed, overflow) = KalendarCore.layoutEvents(events, c.getInt("maxCols"))
      assertEquals(name, expPlaced, placed)
      assertEquals(name, expOverflow, overflow)
    }
  }

  @Test
  fun snapFixtures() {
    val root = JSONObject(fixture("snap.json"))
    val snaps = root.getJSONArray("snap")
    assertTrue(snaps.length() > 0)
    for (i in 0 until snaps.length()) {
      val c = snaps.getJSONObject(i)
      assertEquals(
        "snap raw=${c.getDouble("raw")}",
        c.getInt("expected"),
        KalendarCore.snapDelta(c.getDouble("raw"), c.getInt("lo"), c.getInt("hi"))
      )
    }
    val slots = root.getJSONArray("slot")
    for (i in 0 until slots.length()) {
      val c = slots.getJSONObject(i)
      val expected = c.getJSONObject("expected")
      val (s, e) = KalendarCore.slotForPress(c.getInt("pressed"), c.getInt("startHour"), c.getInt("endHour"))
      assertEquals("slot pressed=${c.getInt("pressed")}", expected.getInt("start"), s)
      assertEquals("slot pressed=${c.getInt("pressed")}", expected.getInt("end"), e)
    }
  }

  @Test
  fun monthBarsFixtures() {
    val cases = JSONArray(fixture("month-bars.json"))
    assertTrue(cases.length() > 0)
    for (i in 0 until cases.length()) {
      val c = cases.getJSONObject(i)
      val name = c.optString("name")
      val dayKeys = c.getJSONArray("dayKeys").let { arr ->
        (0 until arr.length()).map { j -> if (arr.isNull(j)) null else arr.getString(j) }
      }
      val events = c.getJSONArray("events").let { arr ->
        (0 until arr.length()).map { j ->
          val e = arr.getJSONObject(j)
          KalendarCore.SpanEvent(e.getString("uid"), e.getString("startKey"), e.getString("endKey"))
        }
      }
      val expected = c.getJSONObject("expected")
      val expSegs = expected.getJSONArray("segments").let { arr ->
        (0 until arr.length()).map { j ->
          val s = arr.getJSONObject(j)
          KalendarCore.BarSegment(
            s.getString("uid"), s.getInt("week"), s.getInt("startCol"), s.getInt("endCol"),
            s.getInt("lane"), s.getBoolean("continuesLeft"), s.getBoolean("continuesRight")
          )
        }
      }
      val expOverflow = expected.getJSONObject("overflow").let { o ->
        o.keys().asSequence().associateWith { k -> o.getInt(k) }
      }
      val (segments, overflow) = KalendarCore.layoutMonthBars(dayKeys, events, c.getInt("maxLanes"))
      assertEquals(name, expSegs, segments)
      assertEquals(name, expOverflow, overflow)
    }
  }
}

private fun JSONArray.toIntList(): List<Int> = (0 until length()).map { getInt(it) }
private fun JSONArray.toStringList(): List<String> = (0 until length()).map { getString(it) }
private fun JSONArray.toNullableIntList(): List<Int?> =
  (0 until length()).map { if (isNull(it)) null else getInt(it) }
