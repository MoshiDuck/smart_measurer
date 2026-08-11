import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

// ---------------------------------------------------------------------------
// SmartMeasurer (advanced version, with access to measuredChild)
// ---------------------------------------------------------------------------

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
/// - Otherwise, the estimation starts from [Size.zero] (or the last
///   compatible size if [keepPreviousSizeOnChildChange] is true).
/// - To get the old-style estimation based on max constraints, enable
///   [useConstraintsAsInitialEstimate].
///
/// ## Performance cost
/// Every precise measurement triggers an internal `setState`, which rebuilds
/// everything returned by [builder]. If [builder] builds an expensive but
/// otherwise static subtree, wrap it in a [RepaintBoundary] or extract it into
/// a `const`/separate widget.
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
  final Widget Function(
    BuildContext context,
    Widget measuredChild,
    Size size,
    bool isPrecise,
    BoxConstraints constraints,
  ) builder;

  /// Provides a custom size estimation during frames without a precise
  /// measurement available.
  final Size Function(BoxConstraints constraints, Size? previousSize)?
      estimateBuilder;

  /// If true (the default), the last measured precise size is reused as an
  /// estimation when [child] changes, rather than resetting to zero.
  final bool keepPreviousSizeOnChildChange;

  /// If true, the initial estimation (before any measurement) uses the
  /// maximum constraints instead of [Size.zero].
  final bool useConstraintsAsInitialEstimate;

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

class _SmartMeasurerState extends State<SmartMeasurer> {
  _PreciseMeasurement? _precise;
  Size? _lastMeasuredSize;

  int _currentGeneration = 0;
  BoxConstraints? _lastExternalConstraints;

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
      }
      _resetDebugCounter();
    }
  }

  void _onLayoutDone(
      Size size, BoxConstraints usedConstraints, int generation) {
    if (!mounted) return;
    _resetDebugCounter();

    final bool changed = _precise == null ||
        _precise!.size != size ||
        _precise!.usedConstraints != usedConstraints ||
        _precise!.generation != generation;

    if (!changed) {
      _lastMeasuredSize = size;
      return;
    }

    setState(() {
      _lastMeasuredSize = size;
      _precise = _PreciseMeasurement(
        size: size,
        usedConstraints: usedConstraints,
        generation: generation,
      );
    });
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

        final Size size = isPrecise
            ? precise.size
            : _resolveEstimate(constraints, _lastMeasuredSize);

        final measuredChild = _MeasuredChildWidget(
          key: _measuredChildKey,
          generation: _currentGeneration,
          onLayoutDone: _onLayoutDone,
          child: widget.child,
        );

        final result = widget.builder(
          context,
          measuredChild,
          size,
          isPrecise,
          constraints,
        );

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
          debugPrint(
            '⚠ SmartMeasurer: estimateBuilder returned an invalid '
            'size ($estimated). Falling back to default estimation.',
          );
          return true;
        }());
      }
    }

    // BoxConstraints.isSatisfiedBy already treats an unbounded max as
    // effectively infinite (maxWidth/maxHeight *are* double.infinity when
    // unbounded), so no separate hasBoundedWidth/hasBoundedHeight handling
    // is needed here.
    if (previousSize != null && constraints.isSatisfiedBy(previousSize)) {
      return previousSize;
    }

    if (widget.useConstraintsAsInitialEstimate) {
      final bool unboundedW = !constraints.hasBoundedWidth;
      final bool unboundedH = !constraints.hasBoundedHeight;
      if (unboundedW && unboundedH) return Size.zero;
      return Size(
        unboundedW ? 0.0 : constraints.maxWidth,
        unboundedH ? 0.0 : constraints.maxHeight,
      );
    }

    return Size.zero;
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
      debugPrint(
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

  /// If true, the initial estimation (before any measurement) uses the
  /// maximum constraints instead of [Size.zero].
  final bool useConstraintsAsInitialEstimate;

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
    this.debugLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SmartMeasurer(
      estimateBuilder: estimateBuilder,
      keepPreviousSizeOnChildChange: keepPreviousSizeOnChildChange,
      useConstraintsAsInitialEstimate: useConstraintsAsInitialEstimate,
      debugLabel: debugLabel,
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
// MeasuredDecoration (zero delay — pure drawing, no new widgets)
// ---------------------------------------------------------------------------

/// Paints a decoration that depends on [child]'s size, in a single
/// layout/paint pass — unlike [SmartMeasurer] / [SimpleMeasurer], there is
/// **no one-frame delay** here, because [painter] does not build a [Widget]:
/// it draws directly on a [Canvas] during the paint phase, once the child's
/// size is already known in the same layout pass.
///
/// Limitation in exchange: [painter] cannot produce new interactive widgets
/// (buttons, selectable text, etc.), only drawing (shapes, gradients,
/// shadows...). For a subtree of widgets reactive to the size, use
/// [SmartMeasurer].
///
/// ## Example
/// ```dart
/// MeasuredDecoration(
///   painter: (canvas, size) {
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
  /// the child, already known at the time of the call.
  final void Function(Canvas canvas, Size size) painter;

  /// If true (the default), [painter] is called before the child (background
  /// decoration). If false, after (overlay on top of the child).
  final bool paintBehindChild;

  /// Creates a [MeasuredDecoration] that draws [painter] around [child],
  /// with no frame delay.
  const MeasuredDecoration({
    super.key,
    required Widget child,
    required this.painter,
    this.paintBehindChild = true,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMeasuredDecoration(
        painter: painter,
        paintBehindChild: paintBehindChild,
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
      ..paintBehindChild = paintBehindChild;
  }
}

/// A [RenderObject] that paints a decoration depending on the size of its
/// child.
///
/// Used internally by [MeasuredDecoration].
class RenderMeasuredDecoration extends RenderProxyBox {
  /// Creates a [RenderMeasuredDecoration].
  RenderMeasuredDecoration({
    required void Function(Canvas canvas, Size size) painter,
    required bool paintBehindChild,
  })  : _painter = painter,
        _paintBehindChild = paintBehindChild;

  void Function(Canvas canvas, Size size) _painter;

  /// The drawing function called with the actual size of the child.
  void Function(Canvas canvas, Size size) get painter => _painter;
  set painter(void Function(Canvas canvas, Size size) value) {
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
      painter(context.canvas, size);
    } finally {
      context.canvas.restore();
    }
  }

  @override
  bool hitTestSelf(Offset position) => false;

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
// Private measurement infrastructure (used by SmartMeasurer)
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
        value: _callbackScheduled, ifTrue: 'notification en attente'));
  }
}
