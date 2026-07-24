import type { KalendarEvent } from './Kalendar.types';

/**
 * Minimal ICS (RFC 5545) parser: VEVENT blocks with DTSTART/DTEND/SUMMARY/UID.
 * UTC times (`…Z`) are converted to local time; floating and TZID times are
 * taken as-is. All-day and multi-day events become `allDay`/`endDate` spans.
 * Recurrence rules are not expanded. Good enough to bulk-import a typical
 * exported calendar; not a full RFC implementation.
 */
export function parseICS(ics: string): KalendarEvent[] {
  // Unfold continuation lines (a line break followed by space/tab).
  const lines = ics.replace(/\r?\n[ \t]/g, '').split(/\r?\n/);
  const events: KalendarEvent[] = [];
  let current: Record<string, string> | null = null;

  for (const line of lines) {
    if (line === 'BEGIN:VEVENT') {
      current = {};
      continue;
    }

    if (line === 'END:VEVENT') {
      if (current) {
        const ev = toEvent(current);
        if (ev) events.push(ev);
      }
      current = null;
      continue;
    }

    if (!current) continue;
    const idx = line.indexOf(':');

    if (idx < 0) continue;
    const name = line.slice(0, idx).split(';')[0].toUpperCase();
    current[name] = line.slice(idx + 1);
  }

  return events;
}

function toEvent(fields: Record<string, string>): KalendarEvent | null {
  const start = parseStamp(fields['DTSTART']);
  if (!start) return null;
  const end = parseStamp(fields['DTEND']);
  const base = {
    id: fields['UID'] || undefined,
    date: start.date,
    title: unescapeText(fields['SUMMARY'] ?? 'Untitled'),
  };

  if (start.time == null) {
    const last = end ? minusOneDay(end.date) : start.date;
    return { ...base, allDay: true, endDate: last >= start.date ? last : start.date };
  }

  if (end && end.date > start.date) {
    return { ...base, start: start.time, endDate: end.date };
  }

  return { ...base, start: start.time, end: end && end.date === start.date ? end.time : undefined };
}

const pad = (n: number) => String(n).padStart(2, '0');

function minusOneDay(dateKey: string): string {
  const [y, m, d] = dateKey.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d - 1));

  return `${dt.getUTCFullYear()}-${pad(dt.getUTCMonth() + 1)}-${pad(dt.getUTCDate())}`;
}

function parseStamp(raw?: string): { date: string; time?: string } | null {
  if (!raw) return null;
  const m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/.exec(raw.trim());

  if (!m) return null;
  const [, y, mo, d, hh, mm, , z] = m;

  if (hh == null) return { date: `${y}-${mo}-${d}` };

  if (z) {
    const local = new Date(Date.UTC(+y, +mo - 1, +d, +hh, +mm));

    return {
      date: `${local.getFullYear()}-${pad(local.getMonth() + 1)}-${pad(local.getDate())}`,
      time: `${pad(local.getHours())}:${pad(local.getMinutes())}`,
    };
  }

  return { date: `${y}-${mo}-${d}`, time: `${hh}:${mm}` };
}

function unescapeText(s: string): string {
  return s.replace(/\\n/gi, '\n').replace(/\\([,;\\])/g, '$1');
}
