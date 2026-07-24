import assert from 'node:assert/strict';
import { mock, test } from 'node:test';

import { canonicalHex } from '../../src/format.ts';

// normalizeEvent calls normalizeColor which calls processColor from react-native;
// stub it so the module loads in a plain Node environment.
mock.module('react-native', { namedExports: { processColor: () => null } });
const { normalizeEvent } = await import('../../src/normalize.ts');

test('normalizeEvent: end < start + 15 is clamped to start + 15', () => {
  const ev = { date: '2026-07-15', title: 'Short', start: '10:00', end: '10:05' };
  const out = normalizeEvent(ev);
  assert.equal(out.start, '10:00');
  assert.equal(out.end, '10:15');
});

test('normalizeEvent: end exactly at start is clamped to start + 15', () => {
  const ev = { date: '2026-07-15', title: 'Zero', start: '09:00', end: '09:00' };
  const out = normalizeEvent(ev);
  assert.equal(out.end, '09:15');
});

test('normalizeEvent: end >= start + 15 is left unchanged', () => {
  const ev = { date: '2026-07-15', title: 'Fine', start: '09:00', end: '09:30' };
  const out = normalizeEvent(ev);
  assert.equal(out.end, '09:30');
});

test('normalizeEvent: endDate before date is clamped to date', () => {
  const ev = { date: '2026-07-15', title: 'Multi', start: '09:00', endDate: '2026-07-10' };
  const out = normalizeEvent(ev);
  assert.equal(out.endDate, '2026-07-15');
});

test('normalizeEvent: endDate equal to date is kept', () => {
  const ev = { date: '2026-07-15', title: 'Same', start: '09:00', endDate: '2026-07-15' };
  const out = normalizeEvent(ev);
  assert.equal(out.endDate, '2026-07-15');
});

test('normalizeEvent: endDate after date is kept', () => {
  const ev = { date: '2026-07-15', title: 'Span', start: '09:00', endDate: '2026-07-20' };
  const out = normalizeEvent(ev);
  assert.equal(out.endDate, '2026-07-20');
});

test('canonicalHex: valid 6-char hex is returned lowercase with #', () => {
  assert.equal(canonicalHex('#6366F1'), '#6366f1');
  assert.equal(canonicalHex('6366f1'), '#6366f1');
  assert.equal(canonicalHex('#FF0000'), '#ff0000');
});

test('canonicalHex: valid 8-char hex is returned lowercase with #', () => {
  assert.equal(canonicalHex('#6366F1FF'), '#6366f1ff');
});

test('canonicalHex: non-hex input returns null', () => {
  assert.equal(canonicalHex('red'), null);
  assert.equal(canonicalHex(''), null);
  assert.equal(canonicalHex('not-a-color'), null);
});
