import type { LayoutChangeEvent, StyleProp, ViewStyle } from 'react-native';

/**
 * A day was tapped or long-pressed. `events` covers that day — all-day/multi-day
 * first, then timed by start — enough to render your own day view.
 */
export type DayPressEvent = { nativeEvent: { date: string; events: KalendarEvent[] } };
export type DayOpenEvent = { nativeEvent: { date: string } };

export type KalendarLevel = 'year' | 'month' | 'day';

export type KalendarLabels = {
  /** Day-view chip for the current day (also the "today" accessibility suffix). */
  today?: string;
  /** Day-view gutter label above the all-day / multi-day event chips. */
  allDay?: string;
  /** Week-strip agenda: shown when the selected day has no events. */
  noEvents?: string;
  /** Day sheet: button that jumps to the full day timeline. */
  openDay?: string;
  /** Day sheet: accessibility label for the add-event button. */
  addEvent?: string;
  /** Title of the sheet listing overlapping events. */
  sameTime?: string;
  /** iOS day view: label on the chip that opens the overflow sheet when events overlap. */
  moreEvents?: string;
  /** Event editor: sheet title. */
  editEvent?: string;
  /** Event editor: title field. */
  eventTitle?: string;
  /** Event editor: start-time row. */
  starts?: string;
  /** Event editor: end-time row. */
  ends?: string;
  /** Event editor: color row. */
  color?: string;
  /** Event editor: delete button. */
  delete?: string;
  /** Event editor: cancel button. */
  cancel?: string;
  /** Event editor: save button. */
  save?: string;
  /** Accessibility label for the previous-month chevron. */
  prevMonth?: string;
  /** Accessibility label for the next-month chevron. */
  nextMonth?: string;
  /** Accessibility label for the previous-year chevron. */
  prevYear?: string;
  /** Accessibility label for the next-year chevron. */
  nextYear?: string;
  /** Accessibility label for the day view's back button. */
  back?: string;
  /** Accessibility label for the title button that zooms out to the year grid. */
  showYear?: string;
  /** Accessibility label for the grabber when it will expand to the full month. */
  expand?: string;
  /** Accessibility label for the grabber when it will collapse to the week strip. */
  collapse?: string;
  /** Accessibility action that nudges an event 15 minutes later. */
  moveLater?: string;
  /** Accessibility action that nudges an event 15 minutes earlier. */
  moveEarlier?: string;
};
export type RangeChangeEvent = { nativeEvent: { start: string; end?: string } };
export type LevelChangeEvent = { nativeEvent: { level: KalendarLevel } };
/** Fired when the displayed month changes from a swipe or the chevrons. `month` is `yyyy-MM-01`. */
export type MonthChangeEvent = { nativeEvent: { month: string } };

export type ExpandedChangeEvent = { nativeEvent: { expanded: boolean } };

export type KalendarEvent = {
  /** Stable identifier, echoed back in `onEventPress`. */
  id?: string;
  /** Start day, ISO `yyyy-MM-dd`. */
  date: string;
  /** Last day the event covers, ISO `yyyy-MM-dd` (inclusive). Defaults to `date`. */
  endDate?: string;
  /** No times — spans the whole day(s). `start`/`end` are ignored. */
  allDay?: boolean;
  /** `HH:mm` (24h). Defaults to `00:00`. */
  start?: string;
  /** `HH:mm` (24h). Defaults to one hour after `start`. */
  end?: string;
  title: string;
  /** Hex string, e.g. `#ff8a00`. Falls back to the accent color. */
  color?: string;
};

export type EventPressEvent = {
  nativeEvent: {
    id?: string;
    date: string;
    /** When true the event is whole-day; `start`/`end` should be ignored. */
    allDay: boolean;
    title: string;
    start: string;
    end: string;
    color?: string;
  };
};
/** Same payload as `EventPressEvent`, with the event's new values. */
export type EventChangeEvent = EventPressEvent;
export type EventDeleteEvent = { nativeEvent: { id?: string; date: string } };
export type SlotPressEvent = {
  nativeEvent: { date: string; start: string; end: string };
};

export type SelectionShape = 'circle' | 'rounded' | 'square';
export type SelectionMode = 'single' | 'range' | 'multiple';
export type FontDesign = 'default' | 'rounded' | 'serif' | 'monospaced';
/** `glass` = Liquid Glass on iOS 26+ (falls back to solid below); `solid` = flat fills. */
export type Material = 'glass' | 'solid';
/** `regular` = frosted/adaptive glass; `clear` = maximally transparent. */
export type GlassVariant = 'regular' | 'clear';
export type WeekStart =
  'sunday' | 'monday' | 'tuesday' | 'wednesday' | 'thursday' | 'friday' | 'saturday';
/** `locale` follows the locale's hour cycle; `12h`/`24h` force one. */
export type TimeFormat = 'locale' | '12h' | '24h';

export type KalendarViewProps = {
  /** Any date within the month to show, ISO `yyyy-MM-dd`. */
  month?: string;
  /** 1 = Sunday, 2 = Monday, … (defaults to the device locale). */
  firstWeekday?: number;
  /** Named week start; wins over `firstWeekday` when set. */
  weekStart?: WeekStart;
  /** BCP-47 tag (e.g. `uk-UA`) for month/weekday/time formatting. Defaults to the device locale. */
  locale?: string;
  /** Formatting of hour labels and event times on the day view. */
  timeFormat?: TimeFormat;
  /** Localized text for everything the calendar renders itself (UI + accessibility). */
  labels?: KalendarLabels;

  /** Tap the month title to zoom out to a 12-month year grid. */
  yearView?: boolean;
  /** Tap a day (single mode) to zoom into a day view with an event timeline. */
  dayView?: boolean;
  /**
   * Tap a day to open a bottom sheet with that day's events (view, add, edit),
   * Apple Calendar style, instead of zooming. Takes precedence over `dayView`;
   * if `dayView` is also set, the sheet offers a jump to the full timeline.
   */
  daySheet?: boolean;
  /**
   * Month navigation: `paged` (default) swipes left/right a month at a time;
   * `continuous` scrolls vertically through weeks without breaks, Apple Calendar
   * style. In `continuous` the month chevrons and the `expandable` grabber are
   * hidden (you scroll instead); the header month tracks the scroll on iOS 17+.
   */
  scroll?: 'paged' | 'continuous';
  /**
   * Show a grabber that collapses the month to a single-week strip (and back).
   * When collapsed, swipes and the chevrons page by week.
   */
  expandable?: boolean;
  /**
   * Control the expand/collapse state from JS (true = month, false = week).
   * Pair with `onExpandedChange` to keep it in sync with the grabber.
   */
  expanded?: boolean;
  /**
   * Drive the view level from JS (year/month/day). `day` opens `selectedDate`
   * (or the shown month's first day). Pair with `onLevelChange` to keep it in
   * sync with taps.
   */
  level?: KalendarLevel;
  /** Tap an event to open a native edit sheet (title, times, color, delete). */
  eventEditor?: boolean;
  /**
   * Read-only: suppress all day-view editing gestures — drag-to-reschedule,
   * long-press to create a slot, and opening the editor. Taps still fire read
   * callbacks (`onEventPress`, `onDayPress`).
   */
  readOnly?: boolean;
  /** Haptic feedback on drag, snap, and create interactions (default true). */
  haptics?: boolean;
  /** Events rendered on the day view timeline; also dot the month grid. */
  events?: KalendarEvent[];
  /** First hour shown on the day timeline (0–23, default 0). */
  dayStartHour?: number;
  /** Last hour shown on the day timeline (1–24, default 24). */
  dayEndHour?: number;
  /** Show the live "now" line on today's day view (default true). */
  showNowIndicator?: boolean;

  selectionMode?: SelectionMode;
  /** `single` mode. */
  selectedDate?: string;
  /** `multiple` mode. */
  selectedDates?: string[];
  /** `range` mode. */
  rangeStart?: string;
  rangeEnd?: string;

  /** Days that get an event dot. */
  markedDates?: string[];
  /** Days that are non-selectable and muted. */
  disabledDates?: string[];
  minDate?: string;
  maxDate?: string;

  accentColor?: string;
  textColor?: string;
  mutedColor?: string;
  backgroundColor?: string;
  selectedTextColor?: string;
  cornerRadius?: number;
  selectionShape?: SelectionShape;
  fontDesign?: FontDesign;
  /** Defaults to `glass` (Liquid Glass, iOS 26+). Use `solid` for flat fills. */
  material?: Material;
  /** Glass variant: `regular` (frosted) or `clear` (maximally transparent). */
  glassVariant?: GlassVariant;

  onRangeChange?: (event: RangeChangeEvent) => void;
  onDayPress?: (event: DayPressEvent) => void;
  /** Fires when the native day view opens — handy for lazily loading that day's events. */
  onDayOpen?: (event: DayOpenEvent) => void;
  /** Fires when the view level changes from a tap (title → year, day → day, back). */
  onLevelChange?: (event: LevelChangeEvent) => void;
  /** Fires when the shown month changes from a swipe or the chevrons. */
  onMonthChange?: (event: MonthChangeEvent) => void;
  /** Fired when the grabber expands (month) or collapses (week strip). */
  onExpandedChange?: (event: ExpandedChangeEvent) => void;
  /** Fires on long-pressing a day in the month grid — e.g. to create an event. */
  onDayLongPress?: (event: DayPressEvent) => void;
  /** Fires on long-pressing empty timeline space in the day view, with a proposed slot. */
  onSlotPress?: (event: SlotPressEvent) => void;
  /** Fires when an event chip on the day timeline is tapped. */
  onEventPress?: (event: EventPressEvent) => void;
  /** Fires on long-pressing an event chip — e.g. to show a context menu. */
  onEventLongPress?: (event: EventPressEvent) => void;
  /**
   * Fires after drag-to-reschedule (new times) or an editor save (new
   * title/times/color). Update your `events` state — the view is controlled.
   */
  onEventChange?: (event: EventChangeEvent) => void;
  /** Fires when the native editor's delete button is used. */
  onEventDelete?: (event: EventDeleteEvent) => void;
  /** Days of the week that are always non-selectable and muted (0 = Sunday, 6 = Saturday). */
  disabledDaysOfWeek?: number[];
  /**
   * Override the day view's auto-scroll position on open. `"HH:MM"` (24h),
   * e.g. `"08:00"`. Defaults to 1 hour before the current time (or 8am for past days).
   */
  initialScrollTime?: string;

  accessibilityLabel?: string;
  accessibilityHint?: string;
  onLayout?: (event: LayoutChangeEvent) => void;
  style?: StyleProp<ViewStyle>;
};
