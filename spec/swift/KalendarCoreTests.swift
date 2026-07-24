import XCTest
@testable import KalendarCore

// Runs the Swift implementation against the shared fixtures generated
// from the TypeScript reference (spec/generate.mjs).

private func fixturesURL(_ file: String) -> URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("fixtures")
    .appendingPathComponent(file)
}

private func loadJSON(_ file: String) throws -> Any {
  let data = try Data(contentsOf: fixturesURL(file))
  return try JSONSerialization.jsonObject(with: data)
}

final class MonthGridVectors: XCTestCase {
  func testVectors() throws {
    let cases = try XCTUnwrap(loadJSON("month-grid.json") as? [[String: Any]])
    XCTAssertFalse(cases.isEmpty)
    for c in cases {
      let name = c["name"] as? String ?? "?"
      let input = try XCTUnwrap(c["input"] as? [String: Any])
      let weekStart0 = try XCTUnwrap(input["weekStart0"] as? Int)
      if let expectedWeekdays = c["expectedWeekdays"] as? [Int] {
        XCTAssertEqual(mwOrderedWeekdays(weekStart0: weekStart0), expectedWeekdays, name)
        continue
      }
      let firstDow0 = try XCTUnwrap(input["firstDow0"] as? Int)
      let daysInMonth = try XCTUnwrap(input["daysInMonth"] as? Int)
      let expected = try XCTUnwrap(c["expected"] as? [Any]).map { $0 as? Int }
      let actual = mwGrid(firstDow0: firstDow0, daysInMonth: daysInMonth, weekStart0: weekStart0)
      XCTAssertEqual(actual, expected, name)
    }
  }
}

final class OverlapVectors: XCTestCase {
  func testVectors() throws {
    let cases = try XCTUnwrap(loadJSON("overlap.json") as? [[String: Any]])
    XCTAssertFalse(cases.isEmpty)
    for c in cases {
      let name = c["name"] as? String ?? "?"
      let maxCols = try XCTUnwrap(c["maxCols"] as? Int)
      let events = try XCTUnwrap(c["events"] as? [[String: Any]]).map {
        MWCoreEvent(
          uid: $0["uid"] as! String,
          start: $0["start"] as! Int,
          end: $0["end"] as! Int
        )
      }
      let expected = try XCTUnwrap(c["expected"] as? [String: Any])
      let expPlaced = try XCTUnwrap(expected["placed"] as? [[String: Any]]).map {
        MWPlaced(
          uid: $0["uid"] as! String,
          col: $0["col"] as! Int,
          cols: $0["cols"] as! Int,
          reserved: $0["reserved"] as! Bool
        )
      }
      let expOverflow = try XCTUnwrap(expected["overflow"] as? [[String: Any]]).map {
        MWOverflow(
          uids: $0["uids"] as! [String],
          start: $0["start"] as! Int,
          end: $0["end"] as! Int
        )
      }
      let actual = mwLayoutEvents(events, maxCols: maxCols)
      XCTAssertEqual(actual.placed, expPlaced, name)
      XCTAssertEqual(actual.overflow, expOverflow, name)
    }
  }
}

final class SnapVectors: XCTestCase {
  func testVectors() throws {
    let root = try XCTUnwrap(loadJSON("snap.json") as? [String: Any])
    let snaps = try XCTUnwrap(root["snap"] as? [[String: Any]])
    XCTAssertFalse(snaps.isEmpty)
    for c in snaps {
      let raw = try XCTUnwrap(c["raw"] as? Double)
      let lo = try XCTUnwrap(c["lo"] as? Int)
      let hi = try XCTUnwrap(c["hi"] as? Int)
      let expected = try XCTUnwrap(c["expected"] as? Int)
      XCTAssertEqual(mwSnapDelta(raw, lo: lo, hi: hi), expected, "snap raw=\(raw)")
    }
    let slots = try XCTUnwrap(root["slot"] as? [[String: Any]])
    for c in slots {
      let pressed = try XCTUnwrap(c["pressed"] as? Int)
      let startHour = try XCTUnwrap(c["startHour"] as? Int)
      let endHour = try XCTUnwrap(c["endHour"] as? Int)
      let expected = try XCTUnwrap(c["expected"] as? [String: Any])
      let actual = mwSlotForPress(pressed, startHour: startHour, endHour: endHour)
      XCTAssertEqual(actual.start, expected["start"] as! Int, "slot pressed=\(pressed)")
      XCTAssertEqual(actual.end, expected["end"] as! Int, "slot pressed=\(pressed)")
    }
  }
}

final class MonthBarsVectors: XCTestCase {
  func testVectors() throws {
    let cases = try XCTUnwrap(loadJSON("month-bars.json") as? [[String: Any]])
    XCTAssertFalse(cases.isEmpty)
    for c in cases {
      let name = c["name"] as? String ?? "?"
      let maxLanes = try XCTUnwrap(c["maxLanes"] as? Int)
      let dayKeys = try XCTUnwrap(c["dayKeys"] as? [Any]).map { $0 as? String }
      let events = try XCTUnwrap(c["events"] as? [[String: Any]]).map {
        MWSpanEvent(uid: $0["uid"] as! String, startKey: $0["startKey"] as! String, endKey: $0["endKey"] as! String)
      }
      let expected = try XCTUnwrap(c["expected"] as? [String: Any])
      let expSegs = try XCTUnwrap(expected["segments"] as? [[String: Any]]).map {
        MWBarSegment(
          uid: $0["uid"] as! String, week: $0["week"] as! Int, startCol: $0["startCol"] as! Int,
          endCol: $0["endCol"] as! Int, lane: $0["lane"] as! Int,
          continuesLeft: $0["continuesLeft"] as! Bool, continuesRight: $0["continuesRight"] as! Bool
        )
      }
      let expOverflow = (expected["overflow"] as? [String: Any])?.mapValues { $0 as! Int } ?? [:]
      let actual = mwLayoutMonthBars(dayKeys, events, maxLanes: maxLanes)
      XCTAssertEqual(actual.segments, expSegs, name)
      XCTAssertEqual(actual.overflow, expOverflow, name)
    }
  }
}
