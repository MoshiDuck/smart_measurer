# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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