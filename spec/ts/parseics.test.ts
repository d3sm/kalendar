import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseICS } from '../../src/parseICS.ts';

const vevent = (...lines: string[]) => ['BEGIN:VEVENT', ...lines, 'END:VEVENT'].join('\r\n');

test('timed same-day event', () => {
  const [e] = parseICS(vevent('UID:1', 'SUMMARY:Standup', 'DTSTART:20260715T090000', 'DTEND:20260715T093000'));
  assert.deepEqual(e, { id: '1', date: '2026-07-15', start: '09:00', end: '09:30', title: 'Standup' });
});

test('all-day event maps to an all-day span (DTEND is exclusive)', () => {
  const [e] = parseICS(vevent('SUMMARY:Holiday', 'DTSTART:20260715', 'DTEND:20260716'));
  assert.equal(e.allDay, true);
  assert.equal(e.date, '2026-07-15');
  assert.equal(e.endDate, '2026-07-15');
});

test('multi-day all-day event spans inclusive days', () => {
  const [e] = parseICS(vevent('SUMMARY:Trip', 'DTSTART:20260715', 'DTEND:20260718'));
  assert.equal(e.allDay, true);
  assert.equal(e.endDate, '2026-07-17');
});

test('multi-day timed event becomes a span with endDate', () => {
  const [e] = parseICS(vevent('SUMMARY:Conf', 'DTSTART:20260715T090000', 'DTEND:20260717T170000'));
  assert.equal(e.date, '2026-07-15');
  assert.equal(e.start, '09:00');
  assert.equal(e.endDate, '2026-07-17');
});

test('UTC times convert to local (TZ=UTC in the test runner)', () => {
  const [e] = parseICS(vevent('SUMMARY:Sync', 'DTSTART:20260715T090000Z', 'DTEND:20260715T100000Z'));
  assert.equal(e.date, '2026-07-15');
  assert.equal(e.start, '09:00');
  assert.equal(e.end, '10:00');
});

test('unfolds continuation lines with either CRLF or LF', () => {
  const crlf = ['BEGIN:VEVENT', 'SUMMARY:Hello', ' World', 'DTSTART:20260715T090000', 'END:VEVENT'].join('\r\n');
  const lf = ['BEGIN:VEVENT', 'SUMMARY:Hello', ' World', 'DTSTART:20260715T090000', 'END:VEVENT'].join('\n');
  assert.equal(parseICS(crlf)[0].title, 'HelloWorld');
  assert.equal(parseICS(lf)[0].title, 'HelloWorld');
});

test('escaped characters in SUMMARY are unescaped', () => {
  const [e] = parseICS(vevent('SUMMARY:Lunch\\, then gym', 'DTSTART:20260715T120000'));
  assert.equal(e.title, 'Lunch, then gym');
});

test('an event without DTSTART is skipped', () => {
  assert.equal(parseICS(vevent('SUMMARY:Ghost')).length, 0);
});

test('timed event without DTEND has undefined end', () => {
  const [e] = parseICS(vevent('SUMMARY:Open', 'DTSTART:20260715T090000'));
  assert.equal(e.start, '09:00');
  assert.equal(e.end, undefined);
});

test('two VEVENTs in one string both parse', () => {
  const input = [
    vevent('UID:1', 'SUMMARY:First', 'DTSTART:20260715T090000', 'DTEND:20260715T100000'),
    vevent('UID:2', 'SUMMARY:Second', 'DTSTART:20260716T090000', 'DTEND:20260716T100000'),
  ].join('\r\n');
  assert.equal(parseICS(input).length, 2);
});

test('\\n escape in SUMMARY becomes a newline character', () => {
  const [e] = parseICS(vevent('SUMMARY:Line one\\nLine two', 'DTSTART:20260715T090000'));
  assert.equal(e.title, 'Line one\nLine two');
});
