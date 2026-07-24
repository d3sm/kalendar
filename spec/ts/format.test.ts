import assert from 'node:assert/strict';
import { test } from 'node:test';

import { canonicalHex, toMinutes, toTime } from '../../src/format.ts';

test('toMinutes parses HH:mm', () => {
  assert.equal(toMinutes('00:00', -1), 0);
  assert.equal(toMinutes('09:30', -1), 570);
  assert.equal(toMinutes('9:05', -1), 545);
  assert.equal(toMinutes('23:59', -1), 1439);
});

test('toMinutes clamps out-of-range and falls back on garbage', () => {
  assert.equal(toMinutes('30:00', -1), 1440);
  assert.equal(toMinutes(undefined, 42), 42);
  assert.equal(toMinutes('nope', 42), 42);
  assert.equal(toMinutes('1230', 42), 42);
});

test('toTime formats and clamps', () => {
  assert.equal(toTime(0), '00:00');
  assert.equal(toTime(570), '09:30');
  assert.equal(toTime(1440), '24:00');
  assert.equal(toTime(9999), '24:00');
  assert.equal(toTime(-5), '00:00');
});

test('canonicalHex lowercases and drops non-hex', () => {
  assert.equal(canonicalHex('#FF8A00'), '#ff8a00');
  assert.equal(canonicalHex('ff8a00'), '#ff8a00');
  assert.equal(canonicalHex('#00C2FF80'), '#00c2ff80');
  assert.equal(canonicalHex('red'), null);
  assert.equal(canonicalHex('#fff'), null);
  assert.equal(canonicalHex('rgba(0,0,0,1)'), null);
});
