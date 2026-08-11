# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2026-08-11

### Added

- **`sizeChangeThreshold`** on `SmartMeasurer` / `SimpleMeasurer` — ignores
  measurement deltas smaller than a given number of logical pixels, to
  absorb sub-pixel jitter coming from an animating parent layout instead of
  rebuilding on every one. When a change is filtered out but the
  generation/constraints did change, the previous size is kept rather than
  snapping to the near-identical new one, to avoid visible jitter.

- **`onSizeChanged`** on `SmartMeasurer` / `SimpleMeasurer` — a side-effect
  callback fired on every committed precise measurement, independently of
  `builder`, for cases (analytics, syncing a scroll offset, driving an
  external animation) that shouldn't require rebuilding the whole
  `builder` subtree.

- **`notifyDebounce`** on `SmartMeasurer` / `SimpleMeasurer` — debounces
  rapid successive measurements (screen rotation, keyboard animation) into
  a single update instead of one per frame.

- **`animationDuration` / `animationCurve`** on `SmartMeasurer` /
  `SimpleMeasurer` — animates the *displayed* precise size smoothly
  instead of snapping to it immediately, for a "grow/shrink" transition.
  Has no effect on estimated sizes.

- **`SmartMeasurerController`** — an external `ChangeNotifier` exposing
  `size`, `isPrecise`, and `constraints`, so code outside of `builder` can
  read the current measurement. Pass it via the new `controller` parameter
  on `SmartMeasurer` / `SimpleMeasurer`. Notifications are deferred to a
  post-frame callback, so it's always safe to call `setState` from a
  listener.

- **`estimateStrategy`** (`SmartMeasurerEstimateStrategy`: `zero`,
  `previousSize`, `constraints`, `custom`) on `SmartMeasurer` /
  `SimpleMeasurer` — an explicit, extensible replacement for
  `useConstraintsAsInitialEstimate`, which is now deprecated but still
  honored when `estimateStrategy` is left unset.

- **`ignorePointerDuringEstimate`** on `SmartMeasurer` / `SimpleMeasurer` —
  wraps the result in `IgnorePointer` while `isPrecise` is `false`, so taps
  never land on a provisional layout.

- **`onDebugWarning`** on `SmartMeasurer` / `SimpleMeasurer` — redirects
  the package's internal warnings (invalid estimate, missing
  `measuredChild`, etc.) to a custom sink instead of `debugPrint`, so
  production apps can route them into their own logging pipeline.

- **`placeholderBuilder`** on `SmartMeasurer` / `SimpleMeasurer` — a widget
  shown instead of `builder`'s output until the very first precise
  measurement is ever obtained (e.g. a skeleton). The real child keeps
  measuring offstage in the background so the switch-over happens as soon
  as layout is ready.

- **`debugPaintEstimatedSize`** on `SmartMeasurer` / `SimpleMeasurer` —
  debug-only red/green border around the result depending on `isPrecise`,
  to spot flicker or measurement issues visually. Compiled out entirely
  outside of debug builds.

- **`unconstrained`** on `SmartMeasurer` — auto-wraps `measuredChild` in an
  `UnconstrainedBox`, the same trick `SimpleMeasurer` already used
  internally, so it always reports its natural size.

- **`constrainToAvailableSpace`, `scrollable`, `scrollDirection`** on
  `SmartMeasurer` / `SimpleMeasurer` — optional built-in handling for
  content that might exceed the available space, instead of requiring
  users to combine `LayoutBuilder` + `ConstrainedBox` /
  `SingleChildScrollView` by hand around every measurer.

- **`SmartMeasurerGroup`** — a new, lighter widget that measures a list of
  children at once and hands back their sizes (`List<Size>`) plus an
  `allPrecise` flag, for layout decisions that depend on several sizes at
  once (e.g. equalizing a row of chips) without nesting multiple
  `SmartMeasurer`s.

- **`MeasuredDecoration.onSizeChanged`** — an optional callback fired after
  layout whenever the child's size changes, independent of `painter` and
  without forcing an extra paint. Deferred to the end of the frame, so
  it's always safe to call `setState` from it.

### Changed

- **Breaking: `MeasuredDecoration.painter` signature.** `painter` now
  receives the child's `BoxConstraints` in addition to `Canvas` and `Size`:
  `void Function(Canvas canvas, Size size, BoxConstraints constraints)`.
  Existing painters need one extra parameter added to their signature; no
  other change is required. See the README's "Migrating from 0.1.x"
  section.

### Deprecated

- **`useConstraintsAsInitialEstimate`** on `SmartMeasurer` /
  `SimpleMeasurer` — superseded by `estimateStrategy`
  (`SmartMeasurerEstimateStrategy.constraints`). Still fully functional as
  a fallback when `estimateStrategy` is left unset; no removal planned in
  the near term.

### Notes

- Aside from the `MeasuredDecoration.painter` signature change, every
  addition in this release is optional and additive — existing code using
  `SmartMeasurer`, `SimpleMeasurer`, or `SmartMeasurerController`-less
  setups keeps working unchanged.

## [0.1.2] - 2026-08-11

### Added

- **`debugLabel` on `SmartMeasurer`** (optional, propagated by `SimpleMeasurer`).  
  Provides a human-readable name for the widget, visible in debug error messages
  (duplicate key exceptions) and in the widget inspector, helping to distinguish
  multiple nested `SmartMeasurer` instances.

- **`debugFillProperties` on `RenderMeasuredDecoration`** so the inspector now
  shows `painter` identity and `paintBehindChild` value, matching what
  `_RenderMeasuredChild` already exposes for the measurement infrastructure.

### Changed

- **Simplified `_isValidForConstraints`** – the manual ternary check was
  redundant because `BoxConstraints.maxWidth` / `maxHeight` already return
  `double.infinity` when the axis is unbounded. Replaced by a direct call to
  `constraints.isSatisfiedBy(size)`, which is the canonical method and also
  slightly more efficient.

- **Renamed shadowed parameter in `_scheduleNotification`** from `constraints`
  to `usedConstraints`, avoiding a name conflict with the inherited
  `RenderBox.constraints` getter. No behaviour change.

- **Frame‑detection in the debug “no precise measurement” warning**
  re‑implemented with a `postFrameCallback`‑based flag instead of
  `SchedulerBinding.currentFrameTimeStamp`. This avoids a potential assertion
  error if `_checkMissingChild` is called outside an active frame, and matches
  the pattern already used elsewhere in the file. Debug‑only, no release impact.

### Notes

- All changes are internal to the implementation; the public API is fully
  backward‑compatible with `0.1.1`. The `debugLabel` parameter is an optional
  addition and does not affect existing code.

## [0.1.1] - 2026-08-11

### Fixed

- **`SimpleMeasurer` reported a fake, self-referential size instead of the
  child's real size.** The child was overlaid with `Positioned.fill`, which
  forces tight constraints on it (min == max, derived from the decoration
  `builder` had just returned). Since a `RenderBox` under tight constraints
  must report exactly those constraints back, the "measured" size was really
  just an echo of the previous size plus whatever offset the decoration
  added — never the child's actual natural size. This broke the primary
  use case shown in the README (a decoration that sizes itself to a piece
  of text).
  `measuredChild` is now wrapped in `UnconstrainedBox` instead, guaranteeing
  it is always laid out with no constraints and always reports its true
  natural size, regardless of what `builder` returns or what constraints
  are imposed on `SimpleMeasurer` by its own parent.

- **`MeasuredDecoration` could keep painting a stale decoration.**
  `painter` and `paintBehindChild` were plain field assignments in
  `updateRenderObject`, so replacing `painter` with a new closure (e.g. one
  capturing a different color) did not trigger a repaint — the previous
  frame's drawing stayed on screen until something else happened to
  repaint the render object. `painter` and `paintBehindChild` are now real
  setters that compare the old and new value and call `markNeedsPaint()`
  when they actually change.

### Changed

- **`SimpleMeasurer` gained an `alignment` parameter** (`AlignmentGeometry`,
  default `Alignment.center`), controlling where the child is positioned
  within the decoration now that it's no longer force-fit with
  `Positioned.fill`. This restores (and makes explicit) the centered
  overlay behavior implied by the original README example.

- **The "no precise measurement after 3 frames" debug warning in
  `SmartMeasurer` now counts real frames, not builds.** Previously the
  internal counter incremented on every call to `build()`, so a parent
  that rebuilds more than once per frame could trigger the warning long
  before three actual frames had passed. It's now debounced with a
  `SchedulerBinding.addPostFrameCallback`-based flag, so it only advances
  once per frame regardless of how many times `build()` runs within it.
  Debug-mode only; no effect on release builds.

### Notes

- No public API was removed or had its meaning changed — `SimpleMeasurer`
  gained one new optional named parameter (`alignment`), everything else
  is source- and behavior-compatible for correctly-functioning code.
  Any code that was implicitly relying on `SimpleMeasurer`'s old
  (incorrect) tautological sizing behavior will now see accurate sizes
  instead — if your decoration looked fine before, it will look at least
  as good now; if it looked subtly "stuck" or unresponsive to content
  changes, this is why, and it's now fixed.

## [0.1.0] - Initial release

- Initial release of `smart_measurer`: `SmartMeasurer`, `SimpleMeasurer`,
  and `MeasuredDecoration`.