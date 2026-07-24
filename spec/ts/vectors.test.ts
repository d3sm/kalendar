import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  monthGrid,
  orderedWeekdays,
  layoutEvents,
  snapDelta,
  slotForPress,
  layoutMonthBars,
} from '../../src/core.ts';

// The committed fixtures are what the Swift and Kotlin suites assert against.
// If the core changes without regenerating them, the native tests would be
// checking against stale expectations — these tests catch that.
const dir = join(dirname(fileURLToPath(import.meta.url)), '..', 'fixtures');
const read = (file: string) => JSON.parse(readFileSync(join(dir, file), 'utf8'));

test('committed month-grid fixtures match the core', () => {
  for (const c of read('month-grid.json')) {
    if (c.expectedWeekdays) {
      assert.deepEqual(orderedWeekdays(c.input.weekStart0), c.expectedWeekdays, c.name);
    } else {
      assert.deepEqual(monthGrid(c.input.firstDow0, c.input.daysInMonth, c.input.weekStart0), c.expected, c.name);
    }
  }
});

test('committed overlap vectors match the core', () => {
  for (const c of read('overlap.json')) {
    assert.deepEqual(layoutEvents(c.events, c.maxCols), c.expected, c.name);
  }
});

test('committed snap vectors match the core', () => {
  const { snap, slot } = read('snap.json');
  for (const c of snap) assert.equal(snapDelta(c.raw, c.lo, c.hi), c.expected, `snap ${c.raw}`);
  for (const c of slot) assert.deepEqual(slotForPress(c.pressed, c.startHour, c.endHour), c.expected, `slot ${c.pressed}`);
});

test('committed month-bars vectors match the core', () => {
  for (const c of read('month-bars.json')) {
    assert.deepEqual(layoutMonthBars(c.dayKeys, c.events, c.maxLanes), c.expected, c.name);
  }
});
