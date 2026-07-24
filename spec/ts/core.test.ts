import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  monthGrid,
  orderedWeekdays,
  layoutEvents,
  snapDelta,
  slotForPress,
  isSpanning,
  spansDay,
  layoutMonthBars,
} from '../../src/core.ts';

// July 2026 starts on a Wednesday (day-of-week 3).
test('monthGrid: leading blanks depend on week start', () => {
  assert.deepEqual(monthGrid(3, 31, 0).slice(0, 5), [null, null, null, 1, 2]); // Sunday start
  assert.deepEqual(monthGrid(3, 31, 1).slice(0, 3), [null, null, 1]); // Monday start
  assert.equal(monthGrid(3, 31, 0).length, 34);
});

test('monthGrid: no leading nulls when first day is on the week start', () => {
  // June 2025: firstDow0=0 (Sunday), weekStart0=0 → lead = 0
  const grid = monthGrid(0, 30, 0);
  assert.equal(grid[0], 1);
  assert.equal(grid.length, 30);
});

test('orderedWeekdays rotates from the week start', () => {
  assert.deepEqual(orderedWeekdays(0), [0, 1, 2, 3, 4, 5, 6]);
  assert.deepEqual(orderedWeekdays(1), [1, 2, 3, 4, 5, 6, 0]);
});

const ev = (uid: string, start: number, end: number) => ({ uid, start, end });
const cols = (r: ReturnType<typeof layoutEvents>) => r.placed.map((p) => [p.uid, p.col, p.cols]);

test('overlap: disjoint events keep full width', () => {
  const r = layoutEvents([ev('a', 540, 600), ev('b', 600, 660)], 2);
  assert.equal(r.overflow.length, 0);
  assert.deepEqual(cols(r), [['a', 0, 1], ['b', 0, 1]]);
});

test('overlap: two concurrent split into columns', () => {
  const r = layoutEvents([ev('a', 570, 630), ev('b', 585, 645)], 2);
  assert.deepEqual(cols(r), [['a', 0, 2], ['b', 1, 2]]);
});

test('overlap: third concurrent overflows on phone but fits on tablet', () => {
  const events = [ev('a', 570, 630), ev('b', 585, 645), ev('c', 600, 660)];
  const phone = layoutEvents(events, 2);
  assert.equal(phone.placed.length, 2);
  assert.deepEqual(phone.overflow[0].uids, ['c']);
  assert.ok(phone.placed.every((p) => p.reserved));

  const tablet = layoutEvents(events, 3);
  assert.equal(tablet.overflow.length, 0);
  assert.deepEqual(tablet.placed.map((p) => p.cols), [3, 3, 3]);
});

test('overlap: a column is reused once it frees', () => {
  // Same start, so the longer b sorts first into col 0 and a into col 1;
  // c (10–11) then reuses a's freed col 1, while b (9–11) still occupies col 0.
  const r = layoutEvents([ev('a', 540, 600), ev('b', 540, 660), ev('c', 600, 660)], 2);
  const col = Object.fromEntries(r.placed.map((p) => [p.uid, p.col]));
  assert.equal(col.b, 0);
  assert.equal(col.a, 1);
  assert.equal(col.c, 1);
});

test('snapDelta rounds to 15 with ties toward +infinity', () => {
  assert.equal(snapDelta(7, -600, 600), 0);
  assert.equal(snapDelta(8, -600, 600), 15);
  assert.equal(snapDelta(7.5, -600, 600), 15);
  assert.equal(snapDelta(-7.5, -600, 600), 0);
  assert.equal(snapDelta(-8, -600, 600), -15);
});

test('snapDelta clamps to range', () => {
  assert.equal(snapDelta(9999, -600, 600), 600);
  assert.equal(snapDelta(-9999, -600, 600), -600);
});

test('slotForPress snaps to 30 and stays in bounds', () => {
  assert.deepEqual(slotForPress(615, 0, 24), { start: 600, end: 660 });
  assert.deepEqual(slotForPress(5, 7, 22), { start: 420, end: 480 });
  assert.deepEqual(slotForPress(24 * 60, 0, 24), { start: 23 * 60, end: 24 * 60 });
});

test('spansDay covers the inclusive range by ISO string comparison', () => {
  assert.equal(spansDay('2026-07-15', '2026-07-17', '2026-07-15'), true);
  assert.equal(spansDay('2026-07-15', '2026-07-17', '2026-07-16'), true);
  assert.equal(spansDay('2026-07-15', '2026-07-17', '2026-07-17'), true);
  assert.equal(spansDay('2026-07-15', '2026-07-17', '2026-07-14'), false);
  assert.equal(spansDay('2026-07-15', '2026-07-17', '2026-07-18'), false);
});

test('isSpanning is true for all-day or a later end day', () => {
  assert.equal(isSpanning(true, '2026-07-15', '2026-07-15'), true);
  assert.equal(isSpanning(false, '2026-07-15', '2026-07-16'), true);
  assert.equal(isSpanning(false, '2026-07-15', '2026-07-15'), false);
});

const isoGrid = (n: number) => Array.from({ length: n }, (_, i) => `2026-07-${String(i + 1).padStart(2, '0')}`);

test('month bars: a multi-week event splits into continuing segments', () => {
  const { segments } = layoutMonthBars(isoGrid(14), [{ uid: 'a', startKey: '2026-07-05', endKey: '2026-07-10' }], 3);
  assert.equal(segments.length, 2);
  assert.deepEqual(segments[0], { uid: 'a', week: 0, startCol: 4, endCol: 6, lane: 0, continuesLeft: false, continuesRight: true });
  assert.deepEqual(segments[1], { uid: 'a', week: 1, startCol: 0, endCol: 2, lane: 0, continuesLeft: true, continuesRight: false });
});

test('month bars: overlapping events take separate lanes', () => {
  const { segments } = layoutMonthBars(
    isoGrid(7),
    [{ uid: 'a', startKey: '2026-07-02', endKey: '2026-07-04' }, { uid: 'b', startKey: '2026-07-03', endKey: '2026-07-05' }],
    3
  );
  const lane = Object.fromEntries(segments.map((s) => [s.uid, s.lane]));
  assert.notEqual(lane.a, lane.b);
});

test('month bars: event wider than the grid has continuesLeft and continuesRight on every segment', () => {
  // Event starts before grid and ends after — all 7 days are interior
  const { segments } = layoutMonthBars(
    isoGrid(7),
    [{ uid: 'wide', startKey: '2026-06-28', endKey: '2026-07-12' }],
    2
  );
  assert.equal(segments.length, 1);
  assert.equal(segments[0].continuesLeft, true);
  assert.equal(segments[0].continuesRight, true);
  assert.equal(segments[0].startCol, 0);
  assert.equal(segments[0].endCol, 6);
});

test('month bars: events past maxLanes overflow per day', () => {
  const evs = [1, 2, 3].map((n) => ({ uid: `e${n}`, startKey: '2026-07-03', endKey: '2026-07-03' }));
  const { segments, overflow } = layoutMonthBars(isoGrid(7), evs, 2);
  assert.equal(segments.length, 2);
  assert.equal(overflow['2026-07-03'], 1);
});
