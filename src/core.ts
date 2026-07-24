/**
 * Shared layout spec — the reference implementation.
 *
 * The month grid, event overlap, day-bar packing, and drag-snap math live here
 * in TypeScript and, byte-for-byte, in the Swift and Kotlin cores; all three are
 * checked against the fixtures in `spec/`. The shipped calendar renders
 * with the native ports — this copy backs the tests and the vector generator.
 */

/** Lexicographic compare returning -1 / 0 / 1, for stable multi-key sorts. */
const cmp = (a: string, b: string): number => (a < b ? -1 : a > b ? 1 : 0);

// --- Month grid -------------------------------------------------------------

/**
 * 0 = Sunday … 6 = Saturday for both `firstDow0` (weekday of the month's first
 * day) and `weekStart0` (which weekday leads the grid). Returns day numbers with
 * `null` for the leading blanks. The caller resolves its platform calendar into
 * these primitives, so the shared logic is pure arithmetic.
 */
export function monthGrid(
  firstDow0: number,
  daysInMonth: number,
  weekStart0: number,
): (number | null)[] {
  const lead = (firstDow0 - weekStart0 + 7) % 7;

  return [
    ...Array.from({ length: lead }, () => null),
    ...Array.from({ length: daysInMonth }, (_, i) => i + 1),
  ];
}

export function orderedWeekdays(weekStart0: number): number[] {
  return Array.from({ length: 7 }, (_, i) => (weekStart0 + i) % 7);
}

// --- Multi-day coverage -----------------------------------------------------
// ISO `yyyy-MM-dd` strings sort lexicographically the same as chronologically,
// so a day falls inside a span by plain string comparison — no date library.

export function spansDay(startKey: string, endKey: string, dayKey: string): boolean {
  return startKey <= dayKey && dayKey <= endKey;
}

export function isSpanning(allDay: boolean, startKey: string, endKey: string): boolean {
  return allDay || endKey > startKey;
}

// --- Drag snapping ----------------------------------------------------------
// Rounding is floor(x/step + 0.5) — ties toward +∞ — because the three
// platforms' default "round" functions disagree on negative half-ticks.

export function snapDelta(raw: number, lo: number, hi: number, step = 15): number {
  const clamped = Math.min(Math.max(raw, lo), hi);
  const snapped = Math.floor(clamped / step + 0.5) * step;
  return Math.min(Math.max(snapped, lo), hi);
}

export function slotForPress(
  pressedMin: number,
  startHour: number,
  endHour: number,
): { start: number; end: number } {
  let m = Math.floor(pressedMin / 30) * 30;
  m = Math.min(Math.max(m, startHour * 60), endHour * 60 - 60);

  return { start: m, end: m + 60 };
}

// --- Overlap layout (Apple Calendar-style columns) --------------------------
// Overlapping events form a cluster; each takes the first free column; past
// `maxCols` they collapse into an overflow group anchored at the hidden events'
// time span. Deterministic order: start asc, end desc, uid asc.

export type CoreEvent = { uid: string; start: number; end: number };

export type PlacedEvent = {
  uid: string;
  col: number;
  cols: number;
  /** Cluster has an overflow group, so columns leave room for its card. */
  reserved: boolean;
};

export type OverflowGroup = { uids: string[]; start: number; end: number };

export function layoutEvents(
  events: CoreEvent[],
  maxCols: number,
): { placed: PlacedEvent[]; overflow: OverflowGroup[] } {
  const sorted = [...events].sort(
    (a, b) => a.start - b.start || b.end - a.end || cmp(a.uid, b.uid),
  );
  const placed: PlacedEvent[] = [];
  const overflow: OverflowGroup[] = [];
  let colEnds: number[] = [];
  let members: { uid: string; col: number }[] = [];
  let hidden: CoreEvent[] = [];
  let clusterEnd = -Infinity;

  const close = () => {
    if (members.length === 0 && hidden.length === 0) return;

    const cols = Math.max(colEnds.length, 1);
    for (const m of members) {
      placed.push({ uid: m.uid, col: m.col, cols, reserved: hidden.length > 0 });
    }

    if (hidden.length > 0) {
      overflow.push({
        uids: hidden.map((h) => h.uid),
        start: Math.min(...hidden.map((h) => h.start)),
        end: Math.max(...hidden.map((h) => h.end)),
      });
    }
    colEnds = [];
    members = [];
    hidden = [];
    clusterEnd = -Infinity;
  };

  for (const ev of sorted) {
    if (ev.start >= clusterEnd) close();
    const c = colEnds.findIndex((end) => end <= ev.start);
    if (c >= 0) {
      colEnds[c] = ev.end;
      members.push({ uid: ev.uid, col: c });
    } else if (colEnds.length < maxCols) {
      colEnds.push(ev.end);
      members.push({ uid: ev.uid, col: colEnds.length - 1 });
    } else {
      hidden.push(ev);
    }
    clusterEnd = Math.max(clusterEnd, ev.end);
  }
  close();

  return { placed, overflow };
}

// --- Month event-bar layout -------------------------------------------------
// Spanning events (all-day / multi-day) draw as horizontal bars across the days
// they cover. Per week row, each event becomes one segment, segments in a lane
// never overlap, and anything past `maxLanes` becomes a per-day overflow count
// ("+n"). Lanes are assigned independently per week — a multi-week event may sit
// in a different lane each week. Rendering is the platform's job; this is the
// pure placement.

export type SpanEvent = { uid: string; startKey: string; endKey: string };

export type BarSegment = {
  uid: string;
  week: number;
  startCol: number;
  /** Inclusive. */
  endCol: number;
  lane: number;
  /** The event began before this week's segment (round only the true ends). */
  continuesLeft: boolean;
  continuesRight: boolean;
};

export type MonthBars = {
  segments: BarSegment[];
  /** dayKey → count of spanning events on that day that didn't fit in `maxLanes`. */
  overflow: Record<string, number>;
};

type Span = [start: number, end: number];

export function layoutMonthBars(
  dayKeys: (string | null)[],
  events: SpanEvent[],
  maxLanes: number,
): MonthBars {
  // Longest events first (then uid) so bars pack top-down deterministically.
  const sorted = [...events].sort(
    (a, b) => cmp(a.startKey, b.startKey) || cmp(b.endKey, a.endKey) || cmp(a.uid, b.uid),
  );

  const segments: BarSegment[] = [];
  const overflow: Record<string, number> = {};
  const weeks = Math.ceil(dayKeys.length / 7);

  for (let week = 0; week < weeks; week++) {
    const cells = dayKeys.slice(week * 7, week * 7 + 7);
    const lanes: Span[][] = [];

    for (const ev of sorted) {
      const span = coveredColumns(cells, ev);
      if (!span) continue;
      const [startCol, endCol] = span;

      const lane = firstFreeLane(lanes, span, maxLanes);
      if (lane < 0) {
        addOverflow(overflow, cells, span);
        continue;
      }

      (lanes[lane] ??= []).push(span);
      segments.push({
        uid: ev.uid,
        week,
        startCol,
        endCol,
        lane,
        continuesLeft: ev.startKey < (cells[startCol] as string),
        continuesRight: ev.endKey > (cells[endCol] as string),
      });
    }
  }

  return { segments, overflow };
}

function coveredColumns(cells: (string | null)[], ev: SpanEvent): Span | null {
  let start = -1;
  let end = -1;
  for (let col = 0; col < cells.length; col++) {
    const key = cells[col];
    if (key != null && ev.startKey <= key && key <= ev.endKey) {
      if (start < 0) start = col;
      end = col;
    }
  }
  return start < 0 ? null : [start, end];
}

function firstFreeLane(lanes: Span[][], [start, end]: Span, maxLanes: number): number {
  for (let lane = 0; lane < maxLanes; lane++) {
    const taken = lanes[lane] ?? [];
    const overlaps = taken.some(([s, e]) => start <= e && end >= s);
    if (!overlaps) return lane;
  }
  return -1;
}

function addOverflow(
  overflow: Record<string, number>,
  cells: (string | null)[],
  [start, end]: Span,
): void {
  for (let col = start; col <= end; col++) {
    const key = cells[col];
    if (key != null) overflow[key] = (overflow[key] ?? 0) + 1;
  }
}
