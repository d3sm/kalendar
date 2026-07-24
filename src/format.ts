// Pure time/color helpers, free of any React Native import so they can be
// unit-tested directly. normalize.ts builds on these.

export const DAY_MINUTES = 24 * 60;

const TIME = /^(\d{1,2}):(\d{2})$/;
const HEX = /^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;

/** Parse "HH:mm" to minutes-from-midnight, clamped; `fallback` if absent/malformed. */
export function toMinutes(input: string | undefined, fallback: number): number {
  const m = input ? TIME.exec(input) : null;
  if (!m) return fallback;

  return Math.min(Math.max(parseInt(m[1], 10) * 60 + parseInt(m[2], 10), 0), DAY_MINUTES);
}

export function toTime(total: number): string {
  const t = Math.min(Math.max(total, 0), DAY_MINUTES);

  return `${String(Math.floor(t / 60)).padStart(2, '0')}:${String(t % 60).padStart(2, '0')}`;
}

/** `#RRGGBB` / `#RRGGBBAA` (hash optional) → lowercase `#…`; null if not plain hex. */
export function canonicalHex(input: string): string | null {
  const m = HEX.exec(input);

  return m ? `#${m[1].toLowerCase()}` : null;
}
