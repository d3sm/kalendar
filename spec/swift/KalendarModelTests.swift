import XCTest
@testable import KalendarCore

private let cal: Calendar = {
  var c = Calendar(identifier: .gregorian)
  c.timeZone = TimeZone(identifier: "UTC")!
  return c
}()

private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
  cal.date(from: DateComponents(timeZone: TimeZone(identifier: "UTC"), year: year, month: month, day: day))!
}

final class IsDisabledTests: XCTestCase {

  func testBeforeMinDate_isDisabled() {
    let model = KalendarModel()
    model.minDate = date(2026, 7, 15)
    XCTAssertTrue(model.isDisabled(date(2026, 7, 14), cal))
  }

  func testOnMinDate_isEnabled() {
    let model = KalendarModel()
    model.minDate = date(2026, 7, 15)
    XCTAssertFalse(model.isDisabled(date(2026, 7, 15), cal))
  }

  func testAfterMaxDate_isDisabled() {
    let model = KalendarModel()
    model.maxDate = date(2026, 7, 15)
    XCTAssertTrue(model.isDisabled(date(2026, 7, 16), cal))
  }

  func testOnMaxDate_isEnabled() {
    let model = KalendarModel()
    model.maxDate = date(2026, 7, 15)
    XCTAssertFalse(model.isDisabled(date(2026, 7, 15), cal))
  }

  func testInDisabledKeys_isDisabled() {
    let model = KalendarModel()
    model.disabledKeys = ["2026-07-15"]
    XCTAssertTrue(model.isDisabled(date(2026, 7, 15), cal))
  }

  func testNoConstraints_isEnabled() {
    let model = KalendarModel()
    XCTAssertFalse(model.isDisabled(date(2026, 7, 15), cal))
  }
}

final class ClampMonthTests: XCTestCase {

  func testBeforeMin_clampsToMin() {
    let model = KalendarModel()
    model.minDate = date(2026, 7, 1)
    let result = model.clampMonth(date(2026, 5, 1))
    XCTAssertEqual(KalendarModel.monthKey(result), KalendarModel.monthKey(model.minDate!))
  }

  func testAfterMax_clampsToMax() {
    let model = KalendarModel()
    model.maxDate = date(2026, 7, 1)
    let result = model.clampMonth(date(2026, 9, 1))
    XCTAssertEqual(KalendarModel.monthKey(result), KalendarModel.monthKey(model.maxDate!))
  }

  func testWithinRange_unchanged() {
    let model = KalendarModel()
    model.minDate = date(2026, 5, 1)
    model.maxDate = date(2026, 9, 1)
    let d = date(2026, 7, 1)
    XCTAssertEqual(KalendarModel.monthKey(model.clampMonth(d)), KalendarModel.monthKey(d))
  }

  func testExactlyOnMin_unchanged() {
    let model = KalendarModel()
    model.minDate = date(2026, 7, 1)
    let d = date(2026, 7, 15)
    XCTAssertEqual(KalendarModel.monthKey(model.clampMonth(d)), KalendarModel.monthKey(d))
  }
}

final class SelectCallbackTests: XCTestCase {

  func testSelectDisabled_doesNotFireCallback() {
    let model = KalendarModel()
    model.maxDate = date(2026, 7, 15)
    var fired = false
    model.onSelect = { _ in fired = true }
    model.select(date(2026, 7, 20), cal)
    XCTAssertFalse(fired)
  }

  func testSelectEnabled_firesCallback() {
    let model = KalendarModel()
    var received: Date?
    model.onSelect = { received = $0 }
    let d = date(2026, 7, 15)
    model.select(d, cal)
    XCTAssertNotNil(received)
  }
}
