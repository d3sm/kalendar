import Foundation

// Shared-spec algorithms. Foundation-only — no SwiftUI, no ExpoModulesCore —
// so this file also compiles as an SPM target and runs against the fixtures
// in spec/fixtures (see spec/swift). The TypeScript reference lives
// in src/core; keep the three implementations in lockstep.

// MARK: - Month grid

/// 0 = Sunday … 6 = Saturday for both arguments. nil = leading blank.
func mwGrid(firstDow0: Int, daysInMonth: Int, weekStart0: Int) -> [Int?] {
  let lead = (firstDow0 - weekStart0 + 7) % 7
  let days = daysInMonth > 0 ? (1...daysInMonth).map { Int?($0) } : []
  return Array(repeating: nil, count: lead) + days
}

/// Weekday indices (0 = Sunday) in display order for a given week start.
func mwOrderedWeekdays(weekStart0: Int) -> [Int] {
  (0..<7).map { (weekStart0 + $0) % 7 }
}

// MARK: - Overlap layout

struct MWCoreEvent {
  let uid: String
  let start: Int
  let end: Int
}

struct MWPlaced: Equatable {
  let uid: String
  let col: Int
  let cols: Int
  let reserved: Bool
}

struct MWOverflow: Equatable {
  let uids: [String]
  let start: Int
  let end: Int
}

func mwLayoutEvents(_ events: [MWCoreEvent], maxCols: Int) -> (placed: [MWPlaced], overflow: [MWOverflow]) {
  let sorted = events.sorted {
    if $0.start != $1.start { return $0.start < $1.start }
    if $0.end != $1.end { return $0.end > $1.end }
    return $0.uid < $1.uid
  }
  var placed: [MWPlaced] = []
  var overflow: [MWOverflow] = []
  var colEnds: [Int] = []
  var members: [(uid: String, col: Int)] = []
  var hidden: [MWCoreEvent] = []
  var clusterEnd = Int.min

  func close() {
    guard !members.isEmpty || !hidden.isEmpty else { return }
    let cols = max(colEnds.count, 1)
    placed += members.map { MWPlaced(uid: $0.uid, col: $0.col, cols: cols, reserved: !hidden.isEmpty) }
    if !hidden.isEmpty {
      overflow.append(MWOverflow(
        uids: hidden.map(\.uid),
        start: hidden.map(\.start).min() ?? 0,
        end: hidden.map(\.end).max() ?? 0
      ))
    }
    colEnds = []; members = []; hidden = []; clusterEnd = Int.min
  }

  for ev in sorted {
    if ev.start >= clusterEnd { close() }
    if let c = colEnds.firstIndex(where: { $0 <= ev.start }) {
      colEnds[c] = ev.end
      members.append((ev.uid, c))
    } else if colEnds.count < maxCols {
      colEnds.append(ev.end)
      members.append((ev.uid, colEnds.count - 1))
    } else {
      hidden.append(ev)
    }
    clusterEnd = max(clusterEnd, ev.end)
  }
  close()
  return (placed, overflow)
}

// MARK: - Snapping

/// Rounding is floor(x/step + 0.5) — ties toward +∞ — matching the spec.
func mwSnapDelta(_ raw: Double, lo: Int, hi: Int, step: Int = 15) -> Int {
  guard raw.isFinite else { return min(max(0, lo), hi) }
  let clamped = min(max(raw, Double(lo)), Double(hi))
  let snapped = Int((clamped / Double(step) + 0.5).rounded(.down)) * step
  return min(max(snapped, lo), hi)
}

func mwSlotForPress(_ pressedMin: Int, startHour: Int, endHour: Int) -> (start: Int, end: Int) {
  var m = Int((Double(pressedMin) / 30.0).rounded(.down)) * 30
  m = min(max(m, startHour * 60), endHour * 60 - 60)
  return (m, m + 60)
}

// MARK: - Month bars

struct MWSpanEvent {
  let uid: String
  let startKey: String
  let endKey: String
}

struct MWBarSegment: Equatable {
  let uid: String
  let week: Int
  let startCol: Int
  let endCol: Int
  let lane: Int
  let continuesLeft: Bool
  let continuesRight: Bool
}

struct MWMonthBars: Equatable {
  let segments: [MWBarSegment]
  let overflow: [String: Int]
}

func mwLayoutMonthBars(_ dayKeys: [String?], _ events: [MWSpanEvent], maxLanes: Int) -> MWMonthBars {
  let weeks = (dayKeys.count + 6) / 7
  var segments: [MWBarSegment] = []
  var overflow: [String: Int] = [:]
  let sorted = events.sorted {
    if $0.startKey != $1.startKey { return $0.startKey < $1.startKey }
    if $0.endKey != $1.endKey { return $0.endKey > $1.endKey }
    return $0.uid < $1.uid
  }
  for w in 0..<weeks {
    let cells = Array(dayKeys[(w * 7)..<min(w * 7 + 7, dayKeys.count)])
    var laneRanges: [[(Int, Int)]] = []
    for ev in sorted {
      var startCol = -1, endCol = -1
      for c in 0..<cells.count {
        if let key = cells[c], ev.startKey <= key, key <= ev.endKey {
          if startCol < 0 { startCol = c }
          endCol = c
        }
      }
      if startCol < 0 { continue }
      var lane = -1
      for l in 0..<max(0, maxLanes) {
        let ranges = l < laneRanges.count ? laneRanges[l] : []
        if !ranges.contains(where: { !(endCol < $0.0 || startCol > $0.1) }) { lane = l; break }
      }
      if lane >= 0 {
        while laneRanges.count <= lane { laneRanges.append([]) }
        laneRanges[lane].append((startCol, endCol))
        segments.append(MWBarSegment(
          uid: ev.uid, week: w, startCol: startCol, endCol: endCol, lane: lane,
          continuesLeft: ev.startKey < (cells[startCol] ?? ""),
          continuesRight: ev.endKey > (cells[endCol] ?? "")
        ))
      } else {
        for c in startCol...endCol {
          if let key = cells[c] { overflow[key, default: 0] += 1 }
        }
      }
    }
  }
  return MWMonthBars(segments: segments, overflow: overflow)
}
