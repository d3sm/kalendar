# Contributing

Thanks for helping out! This is an Expo native module: one JS API backed by a
SwiftUI view on iOS and a Jetpack Compose view on Android. The month-grid,
event-overlap, and month-bar math is implemented three times — TypeScript, Swift,
and Kotlin — and all three are tested against shared fixtures in `spec/`.

## Setup

This is a Yarn workspace, so a single install at the root sets up both the library
and the example (the pinned Yarn version comes from `packageManager` in
`package.json`):

```sh
corepack enable   # first time only, to use the pinned Yarn
yarn
```

Run the example on a device or simulator:

```sh
cd example
yarn expo run:ios      # or: yarn expo run:android
```

## Tests

```sh
yarn spec:ts        # TypeScript reference + fixtures
yarn spec:ios       # swift test (SPM)
yarn spec:android   # ./gradlew :d3sm-kalendar:testDebugUnitTest
yarn spec           # all three
```

If you change any of the shared layout logic, keep the three ports in lockstep
and regenerate the fixtures:

```sh
yarn spec:generate
```

## Lint

```sh
yarn lint                             # ESLint (src/)
swiftlint                             # iOS — config in .swiftlint.yml
ktlint "android/src/main/**/*.kt"     # Android — config in .editorconfig
```

CI runs the tests and all three linters on every pull request.

## Pull requests

- PR titles follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`fix:`, `feat:`, `docs:`, …) — the title becomes the squash-merge subject and
  is checked in CI.
- Update the docs and `CHANGELOG.md` when you change the public API.
- Mention which platforms you tested on.
