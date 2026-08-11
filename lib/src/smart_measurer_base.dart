import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

// ---------------------------------------------------------------------------
// SmartMeasurer (advanced version, with access to measuredChild)
// ---------------------------------------------------------------------------

/// Strategy used by [SmartMeasurer] to produce a size estimate for frames
/// where no precise measurement is available yet (before the first
/// measurement, or right after the constraints changed).
///
/// This replaces the old `useConstraintsAsInitialEstimate` boolean with an
/// explicit, extensible set of strategies. It only applies when
/// [SmartMeasurer.estimateBuilder] is either absent or fails/returns an
/// invalid size — [estimateBuilder] always takes priority when it succeeds.
enum SmartMeasurerEstimateStrategy {
  /// Always estimate [Size.zero] until a precise measurement lands.
  zero,

  /// Reuse the last precise size if it still satisfies the current
  /// constraints, otherwise fall back to [Size.zero]. This is the default
  /// behavior (equivalent to the historical implicit strategy).
  previousSize,

  /// Estimate using the maximum bounded constraints (0 on any unbounded
  /// axis). Useful when the child is expected to expand to fill its parent.
  constraints,

  /// Signals that [SmartMeasurer.estimateBuilder] is expected to always
  /// provide a valid estimate. If it doesn't, [Size.zero] is used and a
  /// warning is emitted, since this strategy has no built-in fallback logic
  /// of its own.
  custom,
}

/// An external handle to a [SmartMeasurer]'s current size, for code that
/// needs to read the measured size outside of the [SmartMeasurer.builder]
/// (e.g. to drive a sibling widget, a scroll offset, or a state manager).
///
/// Create one, pass it to [SmartMeasurer.controller] (or
/// [SimpleMeasurer.controller]), and listen to it like any other
/// [ChangeNotifier]. Remember to [dispose] it yourself — [SmartMeasurer]
/// only reads from it, it never owns or disposes a controller you created.
class SmartMeasurerController extends ChangeNotifier {
  Size _size = Size.zero;
  bool _isPrecise = false;
  BoxConstraints? _constraints;

  /// The most recently reported size (precise or estimated).
  Size get size => _size;

  /// Whether [size] comes from an actual measurement (`true`) or from the
  /// estimation logic (`false`).
  bool get isPrecise => _isPrecise;

  /// The constraints [SmartMeasurer] last received from its parent.
  BoxConstraints? get constraints => _constraints;

  // Guards against scheduling more than one notifyListeners() dispatch per
  // frame. Without this, a parent that rebuilds SmartMeasurer several times
  // within the same frame (each time with a genuinely different value) would
  // queue one addPostFrameCallback per call, and every one of them would
  // fire notifyListeners() at the end of the frame — harmless (listeners
  // just re-read the current getters, which are always up to date), but
  // wasteful. A single scheduled dispatch per frame is enough since
  // listeners only care about the final state, not every intermediate one.
  bool _notifyScheduled = false;

  void _update(Size size, bool isPrecise, BoxConstraints constraints) {
    if (_size == size &&
        _isPrecise == isPrecise &&
        _constraints == constraints) {
      return;
    }
    _size = size;
    _isPrecise = isPrecise;
    _constraints = constraints;
    // Deferred to after the current frame: `_update` is called from
    // `build()`, and listeners are free to call setState in response to
    // notifyListeners(), which must not happen mid-build.
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }
}

/// Measures the actual size of its child and calls [builder] on every change.
///
/// ## How it works
/// - A private [RenderObject] measures the child. After every layout where
///   the size or constraints change, the definitive size is passed to [builder].
/// - Notifications are limited to one per frame.
/// - The `measuredChild` parameter **must be inserted exactly once** in the
///   tree returned by [builder]. Inserting it multiple times triggers a Flutter
///   key error (duplicate GlobalKey).
///
/// ## One-frame delay (an unavoidable limitation)
/// Flutter always runs *build* before *layout* within a frame. For [builder]
/// to return a [Widget] that depends on the child's size, that size must have
/// been measured in a previous frame. This is a constraint of the Flutter
/// pipeline, not a limitation of this widget: any mechanism that returns an
/// arbitrary [Widget] based on a measured size has the same delay. If you only
/// need to *paint* (not build new widgets) based on the size, see
/// [MeasuredDecoration], which has no delay at all.
///
/// ## Estimation
/// - During the window between a constraint change and the next measurement,
///   the size is **estimated** (`isPrecise` = false). This guarantees that no
///   stale size is presented as precise.
/// - If [estimateBuilder] is provided, it is used for the estimation. If it
///   throws an exception or returns an invalid [Size] (NaN, infinite, or
///   negative), the error is caught (with a warning in debug mode) and the
///   default estimation falls back.
/// - Otherwise, the estimation follows [estimateStrategy] (see that enum).
///   [useConstraintsAsInitialEstimate] is kept for backward compatibility but
///   is ignored whenever [estimateStrategy] is set.
///
/// ## Performance cost
/// Every precise measurement triggers an internal `setState`, which rebuilds
/// everything returned by [builder]. If [builder] builds an expensive but
/// otherwise static subtree, wrap it in a [RepaintBoundary] or extract it into
/// a `const`/separate widget. [sizeChangeThreshold] and [notifyDebounce] can
/// also help reduce rebuild frequency during noisy or fast-changing layouts.
///
/// ## Example
/// ```dart
/// SmartMeasurer(
///   child: Text('Hello World'),
///   builder: (context, measuredChild, size, isPrecise, constraints) {
///     return Container(
///       width: size.width + 24,
///       height: size.height + 24,
///       decoration: BoxDecoration(
///         color: isPrecise ? Colors.blue.shade100 : Colors.grey.shade200,
///         borderRadius: BorderRadius.circular(8),
///       ),
///       padding: const EdgeInsets.all(12),
///       child: measuredChild,
///     );
///   },
/// )
/// ```
class SmartMeasurer extends StatefulWidget {
  /// The widget whose size should be measured.
  final Widget child;

  /// Builds the displayed result. `measuredChild` must be inserted exactly
  /// once in the returned tree.
  ///
  /// Not called at all while a [placeholderBuilder] is active and no precise
  /// measurement has ever been obtained.
  final Widget Function(
    BuildContext context,
    Widget measuredChild,
    Size size,
    bool isPrecise,
    BoxConstraints constraints,
  ) builder;

  /// Provides a custom size estimation during frames without a precise
  /// measurement available. Takes priority over [estimateStrategy].
  final Size Function(BoxConstraints constraints, Size? previousSize)?
      estimateBuilder;

  /// If true (the default), the last measured precise size is reused as an
  /// estimation when [child] changes, rather than resetting to zero.
  final bool keepPreviousSizeOnChildChange;

  /// Deprecated: use [estimateStrategy] instead
  /// (`SmartMeasurerEstimateStrategy.constraints`). Still honored when
  /// [estimateStrategy] is left unset, for backward compatibility.
  final bool useConstraintsAsInitialEstimate;

  /// Explicit estimation strategy for frames without a precise measurement.
  /// When null, falls back to [useConstraintsAsInitialEstimate] for
  /// backward compatibility (`constraints` if true, `previousSize` if
  /// false).
  final SmartMeasurerEstimateStrategy? estimateStrategy;

  /// Minimum size delta (in logical pixels, applied independently to width
  /// and height) required for a new measurement to trigger a rebuild.
  /// Defaults to `0.0`, meaning any change triggers a rebuild — set this to
  /// e.g. `0.5` to absorb sub-pixel jitter coming from an animating parent
  /// layout. When a change is filtered out by the threshold but the
  /// generation/constraints did change, the previous size is kept (rather
  /// than snapping to the new, near-identical one) to avoid visible jitter.
  final double sizeChangeThreshold;

  /// Called every time a new precise measurement is committed (after
  /// [sizeChangeThreshold] filtering), independently of [builder]. Useful
  /// for side effects — analytics, syncing a scroll offset, driving an
  /// external animation — that shouldn't require rebuilding the whole
  /// [builder] subtree.
  final ValueChanged<Size>? onSizeChanged;

  /// If set, precise measurements are debounced by this duration: rapid
  /// successive layout changes (e.g. a screen rotation or a keyboard
  /// animation) only produce a single update once things settle, instead of
  /// one update per frame. Left null (the default), every measurement is
  /// applied immediately.
  final Duration? notifyDebounce;

  /// If set, changes to the *displayed* precise size are animated over this
  /// duration instead of snapping immediately, producing a smooth
  /// grow/shrink transition. Has no effect on estimated (non-precise)
  /// sizes. Requires [animationCurve] to be interpreted; defaults to
  /// [Curves.linear] when null.
  final Duration? animationDuration;

  /// Curve used when [animationDuration] is set. Ignored otherwise.
  final Curve? animationCurve;

  /// Optional external handle exposing the current size/precision outside
  /// of [builder]. See [SmartMeasurerController].
  final SmartMeasurerController? controller;

  /// If true, `measuredChild` is automatically wrapped in an
  /// [UnconstrainedBox] before being handed to [builder], so it always
  /// reports its natural size regardless of incoming constraints — the
  /// same trick [SimpleMeasurer] uses internally. Convenient when you don't
  /// need fine control over how the child is constrained.
  final bool unconstrained;

  /// If true, interaction (taps, gestures, etc.) with the widget returned by
  /// [builder] is disabled via [IgnorePointer] for as long as `isPrecise` is
  /// false, preventing taps from landing on a provisional layout.
  final bool ignorePointerDuringEstimate;

  /// If provided, replaces `debugPrint` as the sink for this widget's
  /// internal warnings (invalid estimates, missing `measuredChild`, etc.),
  /// so production apps can redirect them to their own logging pipeline.
  final void Function(String message)? onDebugWarning;

  /// If provided, shown instead of [builder]'s output until the *first*
  /// precise measurement is ever obtained (e.g. a skeleton or a
  /// [CircularProgressIndicator]). `measuredChild` is still measured in the
  /// background (offstage) while the placeholder is visible, so the
  /// transition to the real content happens as soon as layout is ready.
  final Widget Function(BuildContext context, BoxConstraints constraints)?
      placeholderBuilder;

  /// Debug-only: when true, paints a colored border around the result of
  /// [builder] — red while `isPrecise` is false, green once precise — to
  /// help spot flicker or measurement issues visually. Stripped out
  /// entirely outside of debug builds.
  final bool debugPaintEstimatedSize;

  /// If true, the widget returned by [builder] is constrained to the space
  /// available from the parent (via a loosened [BoxConstraints]), so it can
  /// never request more room than it was given.
  final bool constrainToAvailableSpace;

  /// If true, wraps the result of [builder] in a [SingleChildScrollView]
  /// along [scrollDirection], so content larger than the available space
  /// scrolls instead of overflowing. Combine with
  /// [constrainToAvailableSpace] to also cap the cross-axis size.
  final bool scrollable;

  /// Scroll axis used when [scrollable] is true. Defaults to
  /// [Axis.vertical].
  final Axis? scrollDirection;

  /// Optional label for the internal [GlobalKey] that tracks `measuredChild`
  /// across rebuilds. Purely for debugging: it shows up in the
  /// duplicate-key error message if `measuredChild` is accidentally
  /// inserted twice, and in widget tree dumps. Defaults to `'SmartMeasurer'`;
  /// override it when nesting several [SmartMeasurer] instances so error
  /// messages and dumps tell them apart.
  final String? debugLabel;

  /// Creates a [SmartMeasurer] that measures [child] and delegates rendering
  /// to [builder].
  const SmartMeasurer({
    super.key,
    required this.child,
    required this.builder,
    this.estimateBuilder,
    this.keepPreviousSizeOnChildChange = true,
    this.useConstraintsAsInitialEstimate = false,
    this.estimateStrategy,
    this.sizeChangeThreshold = 0.0,
    this.onSizeChanged,
    this.notifyDebounce,
    this.animationDuration,
    this.animationCurve,
    this.controller,
    this.unconstrained = false,
    this.ignorePointerDuringEstimate = false,
    this.onDebugWarning,
    this.placeholderBuilder,
    this.debugPaintEstimatedSize = false,
    this.constrainToAvailableSpace = false,
    this.scrollable = false,
    this.scrollDirection,
    this.debugLabel,
  });

  @override
  State<SmartMeasurer> createState() => _SmartMeasurerState();
}

/// Holds everything that defines a valid precise measurement: the obtained
/// size, the constraints actually used to obtain it, and the external
/// generation at the time of that measurement.
///
/// Combining these three values into a single immutable object prevents any
/// partial desynchronization: they are always replaced together in a single
/// `setState`.
@immutable
class _PreciseMeasurement {
  final Size size;
  final BoxConstraints usedConstraints;
  final int generation;

  const _PreciseMeasurement({
    required this.size,
    required this.usedConstraints,
    required this.generation,
  });
}

class _SmartMeasurerState extends State<SmartMeasurer>
    with TickerProviderStateMixin {
  _PreciseMeasurement? _precise;
  Size? _lastMeasuredSize;

  int _currentGeneration = 0;
  BoxConstraints? _lastExternalConstraints;

  bool _hasEverBeenPrecise = false;

  Timer? _debounceTimer;

  AnimationController? _sizeAnimController;
  Size? _displayedSize;
  Size? _animFrom;
  Size? _animTo;

  // `late final` so we can read `widget.debugLabel` (unavailable in field
  // initializers, since `widget` isn't attached yet at that point) while
  // still keeping the key's identity stable for the whole State lifetime.
  late final GlobalKey _measuredChildKey =
      GlobalKey(debugLabel: widget.debugLabel ?? 'SmartMeasurer');

  // Debug-only bookkeeping for "no precise measurement" warnings. Tracked by
  // *frame*, not by build: a parent can trigger several rebuilds inside the
  // same frame, and counting builds would make the warning fire far earlier
  // than "3 frames" actually implies. A postFrameCallback flag (rather than
  // SchedulerBinding.currentFrameTimeStamp) is used to detect frame
  // boundaries, since that getter can assert if ever called outside an
  // active frame — this flag can't.
  int _framesWithoutPreciseSize = 0;
  bool _countedThisFrame = false;

  @override
  void didUpdateWidget(covariant SmartMeasurer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != oldWidget.child) {
      _precise = null;
      if (!widget.keepPreviousSizeOnChildChange) {
        _lastMeasuredSize = null;
        // A content swap with no size to fall back on is exactly the case
        // the placeholder is meant for, so let it reappear too.
        _hasEverBeenPrecise = false;
      }
      _resetDebugCounter();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _sizeAnimController?.dispose();
    super.dispose();
  }

  void _warn(String message) {
    (widget.onDebugWarning ?? debugPrint)(message);
  }

  bool _withinThreshold(Size a, Size b, double threshold) {
    if (threshold <= 0) return a == b;
    return (a.width - b.width).abs() <= threshold &&
        (a.height - b.height).abs() <= threshold;
  }

  void _onLayoutDone(
      Size size, BoxConstraints usedConstraints, int generation) {
    if (!mounted) return;
    _resetDebugCounter();

    final _PreciseMeasurement? previous = _precise;
    final bool structuralChange = previous == null ||
        previous.usedConstraints != usedConstraints ||
        previous.generation != generation;
    final bool sizeStable = previous != null &&
        _withinThreshold(previous.size, size, widget.sizeChangeThreshold);

    _lastMeasuredSize = size;

    if (!structuralChange && sizeStable) {
      return;
    }

    // If only the generation/constraints changed but the size itself is
    // within the noise threshold, keep the previous size value to avoid a
    // visible jitter, while still recording the new generation so
    // `isPrecise` reflects the current layout pass.
    final Size finalSize = sizeStable ? previous.size : size;

    void commit() {
      if (!mounted) return;
      final Size? previousSize = _precise?.size;
      setState(() {
        _precise = _PreciseMeasurement(
          size: finalSize,
          usedConstraints: usedConstraints,
          generation: generation,
        );
      });
      _hasEverBeenPrecise = true;
      widget.onSizeChanged?.call(finalSize);
      _maybeStartSizeAnimation(previousSize, finalSize);
    }

    final Duration? debounce = widget.notifyDebounce;
    if (debounce == null || debounce == Duration.zero) {
      commit();
    } else {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, commit);
    }
  }

  void _maybeStartSizeAnimation(Size? fromSize, Size toSize) {
    final Duration? duration = widget.animationDuration;
    if (duration == null || duration == Duration.zero) {
      // animationDuration may have been toggled off dynamically while an
      // animation from a previous measurement was still running. Stop it
      // explicitly — otherwise its listener keeps ticking and overwriting
      // `_displayedSize` in the background for no purpose (build() ignores
      // `_displayedSize` whenever `widget.animationDuration` is null, so
      // this was harmless for correctness, but wasted ticks/rebuilds).
      _sizeAnimController?.stop();
      _animFrom = null;
      _animTo = null;
      _displayedSize = toSize;
      return;
    }

    _animFrom = _displayedSize ?? fromSize ?? toSize;
    _animTo = toSize;
    _sizeAnimController ??= AnimationController(vsync: this)
      ..addListener(() {
        if (!mounted) return;
        setState(() {
          final double t = (widget.animationCurve ?? Curves.linear)
              .transform(_sizeAnimController!.value);
          _displayedSize = Size.lerp(_animFrom, _animTo, t);
        });
      });
    _sizeAnimController!.duration = duration;
    _sizeAnimController!.forward(from: 0);
  }

  void _resetDebugCounter() {
    _framesWithoutPreciseSize = 0;
    _countedThisFrame = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_lastExternalConstraints != constraints) {
          _currentGeneration++;
          _lastExternalConstraints = constraints;
        }

        final _PreciseMeasurement? precise = _precise;
        final bool isPrecise =
            precise != null && precise.generation == _currentGeneration;

        Size size = isPrecise
            ? precise.size
            : _resolveEstimate(constraints, _lastMeasuredSize);

        if (isPrecise &&
            widget.animationDuration != null &&
            _displayedSize != null) {
          size = _displayedSize!;
        }

        Widget measuredChild = _MeasuredChildWidget(
          key: _measuredChildKey,
          generation: _currentGeneration,
          onLayoutDone: _onLayoutDone,
          child: widget.child,
        );

        if (widget.unconstrained) {
          measuredChild = UnconstrainedBox(child: measuredChild);
        }

        widget.controller?._update(size, isPrecise, constraints);

        Widget result;
        if (widget.placeholderBuilder != null && !_hasEverBeenPrecise) {
          result = Stack(
            children: [
              widget.placeholderBuilder!(context, constraints),
              // Keeps measuring in the background so the real builder can
              // take over the moment layout is ready, without the
              // placeholder participating in paint or hit-testing.
              Offstage(offstage: true, child: measuredChild),
            ],
          );
        } else {
          result = widget.builder(
            context,
            measuredChild,
            size,
            isPrecise,
            constraints,
          );
        }

        if (widget.ignorePointerDuringEstimate && !isPrecise) {
          result = IgnorePointer(child: result);
        }

        if (widget.scrollable) {
          final Axis direction = widget.scrollDirection ?? Axis.vertical;
          Widget scrollChild = result;
          if (widget.constrainToAvailableSpace) {
            scrollChild = ConstrainedBox(
              constraints: direction == Axis.vertical
                  ? BoxConstraints(maxWidth: constraints.maxWidth)
                  : BoxConstraints(maxHeight: constraints.maxHeight),
              child: scrollChild,
            );
          }
          result = SingleChildScrollView(
            scrollDirection: direction,
            child: scrollChild,
          );
        } else if (widget.constrainToAvailableSpace) {
          result = ConstrainedBox(
            constraints: constraints.loosen(),
            child: result,
          );
        }

        assert(() {
          if (widget.debugPaintEstimatedSize) {
            result = Stack(
              children: [
                result,
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isPrecise
                              ? const Color(0xFF2ECC71)
                              : const Color(0xFFE74C3C),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return true;
        }());

        assert(() {
          if (!isPrecise) _checkMissingChild();
          return true;
        }());

        return result;
      },
    );
  }

  Size _resolveEstimate(BoxConstraints constraints, Size? previousSize) {
    if (widget.estimateBuilder != null) {
      Size? estimated;
      try {
        estimated = widget.estimateBuilder!(constraints, previousSize);
      } catch (error, stackTrace) {
        assert(() {
          FlutterError.reportError(FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'smart_measurer',
            context:
                ErrorDescription('when calling SmartMeasurer.estimateBuilder'),
          ));
          return true;
        }());
        estimated = null;
      }

      if (estimated != null && _isFiniteAndNonNegative(estimated)) {
        return estimated;
      }

      if (estimated != null) {
        assert(() {
          _warn(
            '⚠ SmartMeasurer: estimateBuilder returned an invalid '
            'size ($estimated). Falling back to default estimation.',
          );
          return true;
        }());
      }
    }

    final SmartMeasurerEstimateStrategy strategy = widget.estimateStrategy ??
        (widget.useConstraintsAsInitialEstimate
            ? SmartMeasurerEstimateStrategy.constraints
            : SmartMeasurerEstimateStrategy.previousSize);

    switch (strategy) {
      case SmartMeasurerEstimateStrategy.zero:
        return Size.zero;

      case SmartMeasurerEstimateStrategy.previousSize:
        // BoxConstraints.isSatisfiedBy already treats an unbounded max as
        // effectively infinite, so no separate hasBoundedWidth/Height
        // handling is needed here.
        if (previousSize != null && constraints.isSatisfiedBy(previousSize)) {
          return previousSize;
        }
        return Size.zero;

      case SmartMeasurerEstimateStrategy.constraints:
        return _estimateFromConstraints(constraints);

      case SmartMeasurerEstimateStrategy.custom:
        assert(() {
          _warn(
            '⚠ SmartMeasurer: estimateStrategy is .custom but no valid '
            'estimateBuilder was provided/returned a valid size. '
            'Falling back to Size.zero.',
          );
          return true;
        }());
        return Size.zero;
    }
  }

  Size _estimateFromConstraints(BoxConstraints constraints) {
    final bool unboundedW = !constraints.hasBoundedWidth;
    final bool unboundedH = !constraints.hasBoundedHeight;
    if (unboundedW && unboundedH) return Size.zero;
    return Size(
      unboundedW ? 0.0 : constraints.maxWidth,
      unboundedH ? 0.0 : constraints.maxHeight,
    );
  }

  bool _isFiniteAndNonNegative(Size size) {
    return size.width.isFinite &&
        size.height.isFinite &&
        size.width >= 0 &&
        size.height >= 0;
  }

  void _checkMissingChild() {
    // Only count once per real frame, even if this build() runs several
    // times within that frame (e.g. because an ancestor rebuilds twice).
    // The flag is cleared by a postFrameCallback, so the next real frame
    // is free to count again.
    if (_countedThisFrame) return;
    _countedThisFrame = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _countedThisFrame = false;
    });

    _framesWithoutPreciseSize++;
    if (_framesWithoutPreciseSize == 3) {
      _warn(
        '⚠ SmartMeasurer: no precise measurement obtained after 3 frames.\n'
        'Possible causes:\n'
        '  • measuredChild was not inserted in the tree returned by the builder.\n'
        '  • measuredChild is inserted but in a subtree that never receives '
        'layout (e.g. Offstage, Visibility(visible: false), etc.).\n'
        '  • The child layout is simply slow to stabilize — in that case '
        'this message is informational, not necessarily an error.',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// SimpleMeasurer (simplified version, child is displayed automatically)
// ---------------------------------------------------------------------------

/// A simplified version of [SmartMeasurer] where the child is automatically
/// overlaid on top of the decoration returned by [builder].
///
/// [builder] only needs to return the decoration/background that adapts to
/// the child's size; the child itself is handled for you and is always
/// measured at its natural size — it is never constrained by the size of the
/// decoration you return, even if that decoration is itself derived from the
/// child's measured size. (An earlier version of this widget used
/// `Positioned.fill`, which forced tight constraints on the child and made
/// the measurement a tautology — the reported size was really just the size
/// of the container computed *from* that same size. `UnconstrainedBox` fixes
/// this: the child is always laid out with no constraints at all, regardless
/// of what [builder] returns or what constraints the parent of
/// [SimpleMeasurer] imposes.)
///
/// Most optional behaviors of [SmartMeasurer] (threshold, debounce,
/// animation, controller, placeholder, debug painting, scroll/constrain)
/// are forwarded as-is — see the corresponding fields on [SmartMeasurer]
/// for details.
///
/// ## Example
/// ```dart
/// SimpleMeasurer(
///   child: Text('Hello'),
///   builder: (context, size, isPrecise, constraints) {
///     return Container(
///       width: size.width + 16,
///       height: size.height + 16,
///       color: Colors.amber.shade100,
///     );
///   },
/// )
/// ```
class SimpleMeasurer extends StatelessWidget {
  /// The widget whose size should be measured, automatically overlaid on
  /// the decoration returned by [builder].
  final Widget child;

  /// Builds only the decoration/background; the child is managed
  /// automatically and overlaid on top of it.
  final Widget Function(
    BuildContext context,
    Size size,
    bool isPrecise,
    BoxConstraints constraints,
  ) builder;

  /// Where [child] is positioned within the decoration returned by
  /// [builder]. Defaults to [Alignment.center].
  final AlignmentGeometry alignment;

  /// Provides a custom size estimation during frames without a precise
  /// measurement available. See [SmartMeasurer.estimateBuilder].
  final Size Function(BoxConstraints constraints, Size? previousSize)?
      estimateBuilder;

  /// If true (default), the last precise measured size is reused as an
  /// estimation when [child] changes.
  final bool keepPreviousSizeOnChildChange;

  /// Deprecated: use [estimateStrategy]. See [SmartMeasurer].
  final bool useConstraintsAsInitialEstimate;

  /// See [SmartMeasurer.estimateStrategy].
  final SmartMeasurerEstimateStrategy? estimateStrategy;

  /// See [SmartMeasurer.sizeChangeThreshold].
  final double sizeChangeThreshold;

  /// See [SmartMeasurer.onSizeChanged].
  final ValueChanged<Size>? onSizeChanged;

  /// See [SmartMeasurer.notifyDebounce].
  final Duration? notifyDebounce;

  /// See [SmartMeasurer.animationDuration].
  final Duration? animationDuration;

  /// See [SmartMeasurer.animationCurve].
  final Curve? animationCurve;

  /// See [SmartMeasurer.controller].
  final SmartMeasurerController? controller;

  /// See [SmartMeasurer.ignorePointerDuringEstimate].
  final bool ignorePointerDuringEstimate;

  /// See [SmartMeasurer.onDebugWarning].
  final void Function(String message)? onDebugWarning;

  /// Shown instead of [builder]'s decoration (with [child] still overlaid on
  /// top, once available) until the first precise measurement ever lands.
  /// See [SmartMeasurer.placeholderBuilder].
  final Widget Function(BuildContext context, BoxConstraints constraints)?
      placeholderBuilder;

  /// See [SmartMeasurer.debugPaintEstimatedSize].
  final bool debugPaintEstimatedSize;

  /// See [SmartMeasurer.constrainToAvailableSpace].
  final bool constrainToAvailableSpace;

  /// See [SmartMeasurer.scrollable].
  final bool scrollable;

  /// See [SmartMeasurer.scrollDirection].
  final Axis? scrollDirection;

  /// Forwarded to the internal [SmartMeasurer]. See
  /// [SmartMeasurer.debugLabel].
  final String? debugLabel;

  /// Creates a [SimpleMeasurer] that measures [child] and delegates the
  /// decoration to [builder].
  const SimpleMeasurer({
    super.key,
    required this.child,
    required this.builder,
    this.alignment = Alignment.center,
    this.estimateBuilder,
    this.keepPreviousSizeOnChildChange = true,
    this.useConstraintsAsInitialEstimate = false,
    this.estimateStrategy,
    this.sizeChangeThreshold = 0.0,
    this.onSizeChanged,
    this.notifyDebounce,
    this.animationDuration,
    this.animationCurve,
    this.controller,
    this.ignorePointerDuringEstimate = false,
    this.onDebugWarning,
    this.placeholderBuilder,
    this.debugPaintEstimatedSize = false,
    this.constrainToAvailableSpace = false,
    this.scrollable = false,
    this.scrollDirection,
    this.debugLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SmartMeasurer(
      estimateBuilder: estimateBuilder,
      keepPreviousSizeOnChildChange: keepPreviousSizeOnChildChange,
      useConstraintsAsInitialEstimate: useConstraintsAsInitialEstimate,
      estimateStrategy: estimateStrategy,
      sizeChangeThreshold: sizeChangeThreshold,
      onSizeChanged: onSizeChanged,
      notifyDebounce: notifyDebounce,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      controller: controller,
      ignorePointerDuringEstimate: ignorePointerDuringEstimate,
      onDebugWarning: onDebugWarning,
      debugPaintEstimatedSize: debugPaintEstimatedSize,
      constrainToAvailableSpace: constrainToAvailableSpace,
      scrollable: scrollable,
      scrollDirection: scrollDirection,
      debugLabel: debugLabel,
      placeholderBuilder: placeholderBuilder == null
          ? null
          : (context, constraints) => placeholderBuilder!(context, constraints),
      builder: (context, measuredChild, size, isPrecise, constraints) {
        return Stack(
          alignment: alignment,
          children: [
            builder(context, size, isPrecise, constraints),
            // UnconstrainedBox strips away incoming constraints entirely, so
            // measuredChild always reports its true natural size — never a
            // size derived from the decoration that was itself derived from
            // the measurement. `alignment` on the Stack takes care of
            // positioning it (e.g. centered) within the decoration.
            UnconstrainedBox(child: measuredChild),
          ],
        );
      },
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// SmartMeasurerGroup (measure several children at once)
// ---------------------------------------------------------------------------

/// Measures several children at once and hands back their sizes as a list,
/// in the same order as [children].
///
/// A lighter-weight sibling of [SmartMeasurer]: no estimation strategies, no
/// animation, no threshold — just "lay these N widgets out and tell me how
/// big each one turned out to be". Useful for equalizing a row of cards, or
/// positioning an indicator relative to several tab labels, without nesting
/// several [SmartMeasurer]s by hand.
///
/// Like [SmartMeasurer], every entry of `measuredChildren` returned by
/// [builder] must be inserted exactly once in the returned tree for its
/// size to ever become available.
///
/// ## Example
/// ```dart
/// SmartMeasurerGroup(
///   children: [Text('Short'), Text('A longer label'), Text('Mid')],
///   builder: (context, measuredChildren, sizes, allPrecise, constraints) {
///     final maxWidth = sizes.map((s) => s.width).fold(0.0, math.max);
///     return Row(
///       children: [
///         for (final child in measuredChildren)
///           SizedBox(width: allPrecise ? maxWidth : null, child: child),
///       ],
///     );
///   },
/// )
/// ```
class SmartMeasurerGroup extends StatefulWidget {
  /// The widgets to measure, in order.
  final List<Widget> children;

  /// Builds the result. `measuredChildren` mirrors [children] one-to-one and
  /// must each be inserted exactly once; `sizes` mirrors them too, using
  /// [Size.zero] for any entry not yet measured. `allPrecise` is true only
  /// once every child has reported a real measurement for the current
  /// layout pass.
  final Widget Function(
    BuildContext context,
    List<Widget> measuredChildren,
    List<Size> sizes,
    bool allPrecise,
    BoxConstraints constraints,
  ) builder;

  /// Optional label prefix for the internal per-child [GlobalKey]s. See
  /// [SmartMeasurer.debugLabel].
  final String? debugLabel;

  /// Creates a [SmartMeasurerGroup] that measures every widget in [children].
  const SmartMeasurerGroup({
    super.key,
    required this.children,
    required this.builder,
    this.debugLabel,
  });

  @override
  State<SmartMeasurerGroup> createState() => _SmartMeasurerGroupState();
}

class _SmartMeasurerGroupState extends State<SmartMeasurerGroup> {
  late List<GlobalKey> _keys = _makeKeys(widget.children.length);
  late List<Size?> _sizes =
      List<Size?>.filled(widget.children.length, null, growable: false);

  int _generation = 0;
  BoxConstraints? _lastConstraints;

  List<GlobalKey> _makeKeys(int count) => List.generate(
        count,
        (i) => GlobalKey(
          debugLabel: '${widget.debugLabel ?? 'SmartMeasurerGroup'}[$i]',
        ),
      );

  @override
  void didUpdateWidget(covariant SmartMeasurerGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.length != oldWidget.children.length) {
      _keys = _makeKeys(widget.children.length);
      _sizes =
          List<Size?>.filled(widget.children.length, null, growable: false);
    }
  }

  void _onChildLayoutDone(
      int index, Size size, BoxConstraints usedConstraints, int generation) {
    if (!mounted || generation != _generation) return;
    if (_sizes[index] == size) return;
    setState(() {
      _sizes[index] = size;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_lastConstraints != constraints) {
          _generation++;
          _lastConstraints = constraints;
          _sizes =
              List<Size?>.filled(widget.children.length, null, growable: false);
        }

        final measuredChildren = <Widget>[
          for (int i = 0; i < widget.children.length; i++)
            _MeasuredChildWidget(
              key: _keys[i],
              generation: _generation,
              onLayoutDone: (size, usedConstraints, generation) =>
                  _onChildLayoutDone(i, size, usedConstraints, generation),
              child: widget.children[i],
            ),
        ];

        final sizes = <Size>[for (final s in _sizes) s ?? Size.zero];
        final bool allPrecise = _sizes.every((s) => s != null);

        return widget.builder(
          context,
          measuredChildren,
          sizes,
          allPrecise,
          constraints,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// MeasuredDecoration (zero delay — pure drawing, no new widgets)
// ---------------------------------------------------------------------------

/// Signature for [MeasuredDecoration.painter]: draws on [canvas] using the
/// child's exact [size] and the [constraints] it was laid out with.
typedef MeasuredDecorationPainter = void Function(
  Canvas canvas,
  Size size,
  BoxConstraints constraints,
);

/// Paints a decoration that depends on [child]'s size, in a single
/// layout/paint pass — unlike [SmartMeasurer] / [SimpleMeasurer], there is
/// **no one-frame delay** here, because [painter] does not build a [Widget]:
/// it draws directly on a [Canvas] during the paint phase, once the child's
/// size is already known in the same layout pass.
///
/// Limitation in exchange: [painter] cannot produce new interactive widgets
/// (buttons, selectable text, etc.), only drawing (shapes, gradients,
/// shadows...). For a subtree of widgets reactive to the size, use
/// [SmartMeasurer]. If you additionally need to react to size changes with
/// non-drawing logic (without paying for a rebuild), see [onSizeChanged].
///
/// ## Example
/// ```dart
/// MeasuredDecoration(
///   painter: (canvas, size, constraints) {
///     final paint = Paint()..color = Colors.deepPurple.shade100;
///     canvas.drawRRect(
///       RRect.fromRectAndRadius(
///         Rect.fromLTWH(-12, -12, size.width + 24, size.height + 24),
///         const Radius.circular(12),
///       ),
///       paint,
///     );
///   },
///   child: const Text('Without delay'),
/// )
/// ```
class MeasuredDecoration extends SingleChildRenderObjectWidget {
  /// Draws behind (or in front of) the child. `size` is the exact size of
  /// the child and `constraints` are the constraints it was laid out with,
  /// both already known at the time of the call.
  final MeasuredDecorationPainter painter;

  /// If true (the default), [painter] is called before the child (background
  /// decoration). If false, after (overlay on top of the child).
  final bool paintBehindChild;

  /// Called after layout whenever the child's size changes, independently
  /// of [painter] and without forcing an extra paint. Useful for side
  /// effects (e.g. notifying a controller) that don't belong in a drawing
  /// function. Deferred to the end of the frame, so it's always safe to call
  /// `setState` from it.
  final ValueChanged<Size>? onSizeChanged;

  /// Creates a [MeasuredDecoration] that draws [painter] around [child],
  /// with no frame delay.
  const MeasuredDecoration({
    super.key,
    required Widget child,
    required this.painter,
    this.paintBehindChild = true,
    this.onSizeChanged,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMeasuredDecoration(
        painter: painter,
        paintBehindChild: paintBehindChild,
        onSizeChanged: onSizeChanged,
      );

  @override
  void updateRenderObject(
      BuildContext context, RenderMeasuredDecoration renderObject) {
    // These are real setters (see below) that call markNeedsPaint() when the
    // value actually changes, so a rebuild that only swaps out `painter`
    // (e.g. a new closure capturing a different color) is guaranteed to be
    // repainted instead of silently keeping the previous frame's drawing.
    renderObject
      ..painter = painter
      ..paintBehindChild = paintBehindChild
      ..onSizeChanged = onSizeChanged;
  }
}

/// A [RenderObject] that paints a decoration depending on the size of its
/// child.
///
/// Used internally by [MeasuredDecoration].
class RenderMeasuredDecoration extends RenderProxyBox {
  /// Creates a [RenderMeasuredDecoration].
  RenderMeasuredDecoration({
    required MeasuredDecorationPainter painter,
    required bool paintBehindChild,
    this.onSizeChanged,
  })  : _painter = painter,
        _paintBehindChild = paintBehindChild;

  MeasuredDecorationPainter _painter;

  /// The drawing function called with the actual size and constraints of
  /// the child.
  MeasuredDecorationPainter get painter => _painter;
  set painter(MeasuredDecorationPainter value) {
    if (_painter == value) return;
    _painter = value;
    markNeedsPaint();
  }

  bool _paintBehindChild;

  /// If `true`, the decoration is painted behind the child (background);
  /// if `false`, it is painted in front (overlay).
  bool get paintBehindChild => _paintBehindChild;
  set paintBehindChild(bool value) {
    if (_paintBehindChild == value) return;
    _paintBehindChild = value;
    markNeedsPaint();
  }

  /// Called after layout whenever the child's size changes. Does not affect
  /// painting — setting it never triggers `markNeedsPaint`.
  ValueChanged<Size>? onSizeChanged;

  Size? _lastNotifiedSize;
  bool _notifyScheduled = false;

  // Holds the size that will actually be handed to `onSizeChanged` once the
  // already-scheduled postFrameCallback fires. Storing it in a field (read
  // at dispatch time) rather than capturing it in the callback's closure is
  // essential: if `performLayout` runs more than once within the same frame
  // (multi-pass layouts, e.g. under a Flex or anything querying intrinsic
  // sizes), only the *first* call schedules the callback, but every call
  // must still be able to update what value that callback eventually
  // reports — otherwise a stale, superseded size would be reported instead
  // of the size the child actually ended up with by the end of the frame.
  Size? _pendingSize;

  @override
  void performLayout() {
    super.performLayout();
    if (onSizeChanged != null && _lastNotifiedSize != size) {
      _lastNotifiedSize = size;
      _pendingSize = size;
      if (!_notifyScheduled) {
        _notifyScheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _notifyScheduled = false;
          final Size? sizeToReport = _pendingSize;
          _pendingSize = null;
          if (attached && sizeToReport != null) {
            onSizeChanged?.call(sizeToReport);
          }
        });
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (paintBehindChild) {
      _paintDecoration(context, offset);
    }

    super.paint(context, offset);

    if (!paintBehindChild) {
      _paintDecoration(context, offset);
    }
  }

  void _paintDecoration(PaintingContext context, Offset offset) {
    context.canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    try {
      painter(context.canvas, size, constraints);
    } finally {
      context.canvas.restore();
    }
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void detach() {
    _pendingSize = null;
    super.detach();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty(
      'paintBehindChild',
      value: paintBehindChild,
      ifTrue: 'paints behind child',
      ifFalse: 'paints in front of child',
    ));
  }
}

// ============================================================================
// Private measurement infrastructure (used by SmartMeasurer / SmartMeasurerGroup)
// ============================================================================

class _MeasuredChildWidget extends SingleChildRenderObjectWidget {
  final void Function(Size size, BoxConstraints constraints, int generation)
      onLayoutDone;
  final int generation;

  const _MeasuredChildWidget({
    super.key,
    required Widget child,
    required this.onLayoutDone,
    required this.generation,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasuredChild(
        onLayoutDone: onLayoutDone,
        generation: generation,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasuredChild renderObject,
  ) {
    renderObject.onLayoutDone = onLayoutDone;
    renderObject.generation = generation;
  }
}

class _RenderMeasuredChild extends RenderProxyBox {
  void Function(Size size, BoxConstraints constraints, int generation)
      onLayoutDone;

  int _generation;
  int get generation => _generation;
  set generation(int value) {
    if (_generation != value) {
      _generation = value;
      if (hasSize) {
        _notify(size, constraints, _generation);
      }
    }
  }

  Size? _lastNotifiedSize;
  BoxConstraints? _lastNotifiedConstraints;
  int _lastNotifiedGeneration = -1;

  bool _callbackScheduled = false;
  Size? _pendingSize;
  BoxConstraints? _pendingConstraints;
  int? _pendingGeneration;

  _RenderMeasuredChild({
    required this.onLayoutDone,
    required int generation,
  }) : _generation = generation;

  void _notify(Size currentSize, BoxConstraints currentConstraints, int gen) {
    if (currentSize == _lastNotifiedSize &&
        currentConstraints == _lastNotifiedConstraints &&
        gen == _lastNotifiedGeneration) {
      return;
    }
    _lastNotifiedSize = currentSize;
    _lastNotifiedConstraints = currentConstraints;
    _lastNotifiedGeneration = gen;
    _scheduleNotification(currentSize, currentConstraints, gen);
  }

  @override
  void performLayout() {
    super.performLayout();
    _notify(size, constraints, _generation);
  }

  void _scheduleNotification(
      Size newSize, BoxConstraints usedConstraints, int gen) {
    _pendingSize = newSize;
    _pendingConstraints = usedConstraints;
    _pendingGeneration = gen;
    if (_callbackScheduled) return;
    _callbackScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(
      (_) {
        _callbackScheduled = false;
        if (owner == null) return;
        final Size? s = _pendingSize;
        final BoxConstraints? c = _pendingConstraints;
        final int? gen = _pendingGeneration;
        _pendingSize = null;
        _pendingConstraints = null;
        _pendingGeneration = null;
        if (s != null && c != null && gen != null) {
          onLayoutDone(s, c, gen);
        }
      },
      debugLabel: 'SmartMeasurer.notifyLayoutDone',
    );
  }

  @override
  void detach() {
    _pendingSize = null;
    _pendingConstraints = null;
    _pendingGeneration = null;
    super.detach();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('generation', _generation));
    properties.add(DiagnosticsProperty<Size>(
        'lastNotifiedSize', _lastNotifiedSize,
        defaultValue: null));
    properties.add(FlagProperty('callbackScheduled',
        value: _callbackScheduled, ifTrue: 'notification pending'));
  }
}
