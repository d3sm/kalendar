# Changelog

## [0.1.2] — 2026-07-31

### Fixed

- **iOS event payload** — `id` and `color` were always sent as `null` when absent, so `"id" in event.nativeEvent` was always `true` on iOS. Both keys are now omitted when nil, matching Android.
- **Android nav accessibility** — previous/next month, previous/next year, and back chevrons had no accessibility labels. They now read from `labels.prevMonth`, `labels.nextMonth`, `labels.prevYear`, `labels.nextYear`, and `labels.back`.

### Removed

- **`hasEvents`** — redundant label key in `KalendarLabels`.

## [0.1.1] — 2026-07-30

### Added

- **`onRangeChange`** — fires on every tap in range mode with `{ start, end? }`.

### Fixed

- **Android event editor title** — wrong label key (`"title"` vs `"eventTitle"`).
- **Android range mode** — tapping a day updated native state without notifying JS. Now fires `onRangeChange` on each tap.
- **Android drag reset mid-drag** — drag offsets were in local composable state and got cleared on recompose. Moved to `KalendarState`, same as iOS.
- **`accessibilityLabel` on Android** — the prop was wired but forgot to apply. Now sets `contentDescription`.
- **`package.json` cleanup** — removed self-dependency, added `files` (publish tarball included example/media/fixtures), added `exports` (fixes bundler and Bundlephobia resolution).

## [0.1.0] — 2026-07-24

Initial release.

[0.1.2]: https://github.com/d3sm/kalendar/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/d3sm/kalendar/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/d3sm/kalendar/releases/tag/v0.1.0
