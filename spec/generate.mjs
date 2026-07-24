// Regenerates spec/fixtures/*.json from the TS reference implementation.
// Run: node --experimental-strip-types spec/generate.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  monthGrid,
  orderedWeekdays,
  layoutEvents,
  snapDelta,
  slotForPress,
  layoutMonthBars,
} from '../src/core.ts';

const out = join(dirname(fileURLToPath(import.meta.url)), 'fixtures');
mkdirSync(out, { recursive: true });

// --- month grid ---------------------------------------------------------
const gridCases = [];
for (const [y, m] of [[2026, 7], [2026, 2], [2024, 2], [2026, 8], [2025, 12], [2026, 1]]) {
  const firstDow0 = new Date(Date.UTC(y, m - 1, 1)).getUTCDay();
  const daysInMonth = new Date(Date.UTC(y, m, 0)).getUTCDate();
  for (const ws of [0, 1, 6]) {
    gridCases.push({
      name: `${y}-${String(m).padStart(2, '0')} ws${ws}`,
      input: { firstDow0, daysInMonth, weekStart0: ws },
      expected: monthGrid(firstDow0, daysInMonth, ws),
    });
  }
}
for (const ws of [0, 1, 3, 6]) {
  gridCases.push({
    name: `weekdays ws${ws}`,
    input: { weekStart0: ws },
    expectedWeekdays: orderedWeekdays(ws),
  });
}
writeFileSync(join(out, 'month-grid.json'), JSON.stringify(gridCases, null, 2));

// --- overlap layout ------------------------------------------------------
const ev = (uid, start, end) => ({ uid, start, end });
const overlapCases = [
  { name: 'empty', maxCols: 2, events: [] },
  { name: 'single', maxCols: 2, events: [ev('a', 570, 630)] },
  { name: 'disjoint', maxCols: 2, events: [ev('a', 540, 600), ev('b', 600, 660), ev('c', 720, 780)] },
  { name: 'pair overlap', maxCols: 2, events: [ev('a', 570, 630), ev('b', 585, 645)] },
  {
    name: 'triple overflow on phone',
    maxCols: 2,
    events: [ev('a', 570, 630), ev('b', 585, 645), ev('c', 600, 660)],
  },
  {
    name: 'triple fits on tablet',
    maxCols: 3,
    events: [ev('a', 570, 630), ev('b', 585, 645), ev('c', 600, 660)],
  },
  {
    name: 'chained cluster (transitive overlap)',
    maxCols: 2,
    events: [ev('a', 540, 600), ev('b', 590, 650), ev('c', 640, 700)],
  },
  {
    name: 'column reuse after gap',
    maxCols: 2,
    events: [ev('a', 540, 600), ev('b', 540, 700), ev('c', 600, 660)],
  },
  {
    name: 'two clusters second overflows',
    maxCols: 2,
    events: [ev('a', 480, 540), ev('b', 600, 720), ev('c', 610, 700), ev('d', 620, 680), ev('e', 630, 690)],
  },
  {
    name: 'zero-length guarded upstream but tolerated',
    maxCols: 2,
    events: [ev('a', 600, 615), ev('b', 600, 615), ev('c', 600, 615)],
  },
  {
    name: 'shared start uses end desc then uid',
    maxCols: 3,
    events: [ev('b', 600, 660), ev('a', 600, 720), ev('c', 600, 630)],
  },
];
writeFileSync(
  join(out, 'overlap.json'),
  JSON.stringify(
    overlapCases.map((c) => ({ ...c, expected: layoutEvents(c.events, c.maxCols) })),
    null,
    2
  )
);

// --- snapping ------------------------------------------------------------
const snapCases = [
  { raw: 0, lo: -570, hi: 810 },
  { raw: 7, lo: -570, hi: 810 },
  { raw: 8, lo: -570, hi: 810 },
  { raw: -7, lo: -570, hi: 810 },
  { raw: -8, lo: -570, hi: 810 },
  { raw: -7.5, lo: -570, hi: 810 },
  { raw: 7.5, lo: -570, hi: 810 },
  { raw: 22.5, lo: -570, hi: 810 },
  { raw: -22.5, lo: -570, hi: 810 },
  { raw: 900, lo: -570, hi: 810 },
  { raw: -900, lo: -570, hi: 810 },
  { raw: 803, lo: -570, hi: 810 },
  { raw: -565, lo: -570, hi: 810 },
];
const slotCases = [
  { pressed: 615, startHour: 0, endHour: 24 },
  { pressed: 629, startHour: 0, endHour: 24 },
  { pressed: 630, startHour: 0, endHour: 24 },
  { pressed: 5, startHour: 7, endHour: 22 },
  { pressed: 1435, startHour: 0, endHour: 24 },
  { pressed: 1439, startHour: 7, endHour: 22 },
];
writeFileSync(
  join(out, 'snap.json'),
  JSON.stringify(
    {
      snap: snapCases.map((c) => ({ ...c, expected: snapDelta(c.raw, c.lo, c.hi) })),
      slot: slotCases.map((c) => ({ ...c, expected: slotForPress(c.pressed, c.startHour, c.endHour) })),
    },
    null,
    2
  )
);

// --- month bars ---------------------------------------------------------
// July 2026 grid, Sunday-first: Jul 1 is a Wednesday → 3 leading blanks.
const julyKeys = [
  null, null, null, '2026-07-01', '2026-07-02', '2026-07-03', '2026-07-04',
  '2026-07-05', '2026-07-06', '2026-07-07', '2026-07-08', '2026-07-09', '2026-07-10', '2026-07-11',
  '2026-07-12', '2026-07-13', '2026-07-14', '2026-07-15', '2026-07-16', '2026-07-17', '2026-07-18',
  '2026-07-19', '2026-07-20', '2026-07-21', '2026-07-22', '2026-07-23', '2026-07-24', '2026-07-25',
  '2026-07-26', '2026-07-27', '2026-07-28', '2026-07-29', '2026-07-30', '2026-07-31', null, null,
];
const span = (uid, s, e) => ({ uid, startKey: s, endKey: e });
const barCases = [
  { name: 'single all-day', dayKeys: julyKeys, maxLanes: 3, events: [span('a', '2026-07-15', '2026-07-15')] },
  { name: 'multi-day within a week', dayKeys: julyKeys, maxLanes: 3, events: [span('a', '2026-07-14', '2026-07-16')] },
  {
    name: 'crosses a week boundary (two segments, continues)',
    dayKeys: julyKeys, maxLanes: 3,
    events: [span('a', '2026-07-17', '2026-07-20')],
  },
  {
    name: 'two overlapping take separate lanes',
    dayKeys: julyKeys, maxLanes: 3,
    events: [span('a', '2026-07-14', '2026-07-16'), span('b', '2026-07-15', '2026-07-17')],
  },
  {
    name: 'overflow past maxLanes counts per day',
    dayKeys: julyKeys, maxLanes: 2,
    events: [
      span('a', '2026-07-15', '2026-07-15'),
      span('b', '2026-07-15', '2026-07-15'),
      span('c', '2026-07-15', '2026-07-15'),
    ],
  },
];
writeFileSync(
  join(out, 'month-bars.json'),
  JSON.stringify(
    barCases.map((c) => ({ ...c, expected: layoutMonthBars(c.dayKeys, c.events, c.maxLanes) })),
    null,
    2
  )
);

console.log('fixtures written to', out);
