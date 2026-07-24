import { processColor } from 'react-native';

import type { KalendarEvent, KalendarViewProps } from './Kalendar.types';
import { DAY_MINUTES, canonicalHex, toMinutes, toTime } from './format.ts';

const WEEKDAYS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

/**
 * Canonicalize a color to lowercase `#RRGGBB(AA)` so both native parsers only
 * ever see plain hex. Non-hex inputs (named colors, `rgba()`, …) go through
 * RN's `processColor`. Invalid input returns undefined.
 */
export function normalizeColor(input?: string): string | undefined {
  if (input == null) return;

  const hex = canonicalHex(input);
  if (hex) return hex;

  const processed = processColor(input);
  if (typeof processed !== 'number') return;

  const argb = processed >>> 0;
  const a = (argb >>> 24) & 0xff;
  const r = (argb >>> 16) & 0xff;
  const g = (argb >>> 8) & 0xff;
  const b = argb & 0xff;
  const h = (n: number) => n.toString(16).padStart(2, '0');

  return a === 0xff ? `#${h(r)}${h(g)}${h(b)}` : `#${h(r)}${h(g)}${h(b)}${h(a)}`;
}

export function normalizeEvent(ev: KalendarEvent): KalendarEvent {
  const startMin = toMinutes(ev.start, 0);
  const endMin = Math.max(toMinutes(ev.end, Math.min(startMin + 60, DAY_MINUTES)), startMin + 15);
  // ISO dates compare lexicographically; keep endDate on or after the start.
  const endDate = ev.endDate && ev.endDate >= ev.date ? ev.endDate : ev.date;

  return {
    ...ev,
    endDate,
    allDay: !!ev.allDay,
    start: toTime(startMin),
    end: toTime(endMin),
    color: normalizeColor(ev.color),
  };
}

const COLOR_PROPS = [
  'accentColor',
  'textColor',
  'mutedColor',
  'backgroundColor',
  'selectedTextColor',
] as const;

/**
 * Canonicalize props once in JS so both natives receive identical values:
 * hex colors, a numeric week start, clamped hours, defaulted event times.
 */
export function normalizeProps(props: KalendarViewProps): KalendarViewProps {
  const out: KalendarViewProps = { ...props };

  for (const key of COLOR_PROPS) {
    if (out[key] != null) out[key] = normalizeColor(out[key]);
  }

  if (out.weekStart) {
    const idx = WEEKDAYS.indexOf(out.weekStart);
    if (idx >= 0) out.firstWeekday = idx + 1;
    delete out.weekStart;
  }

  if (out.dayStartHour != null || out.dayEndHour != null) {
    const start = Math.min(Math.max(Math.trunc(out.dayStartHour ?? 0), 0), 23);
    const end = Math.min(Math.max(Math.trunc(out.dayEndHour ?? 24), start + 1), 24);
    out.dayStartHour = start;
    out.dayEndHour = end;
  }

  if (out.events) out.events = out.events.map(normalizeEvent);

  return out;
}
