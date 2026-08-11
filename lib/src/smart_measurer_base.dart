import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

// ---------------------------------------------------------------------------
// SmartMeasurer (version avancée, avec accès au measuredChild)
// ---------------------------------------------------------------------------

/// Mesure la taille réelle de son enfant et appelle [builder] à chaque changement.
///
/// ## Fonctionnement
/// - Un [RenderObject] privé mesure l'enfant. Après chaque layout où la taille
///   ou les contraintes ont changé, la taille définitive est transmise au [builder].
/// - La notification est limitée à une par frame.
/// - Le paramètre `measuredChild` **doit être inséré exactement une fois** dans
///   l'arbre retourné par le [builder]. Une insertion multiple déclenche une
///   erreur de clé Flutter (GlobalKey dupliquée).
///
/// ## Délai d'une frame (limitation incompressible)
/// Flutter exécute toujours *build* avant *layout* au sein d'une frame. Pour
/// que [builder] retourne un [Widget] dépendant de la taille de l'enfant, il
/// faut donc que cette taille ait été mesurée lors d'une frame précédente.
/// C'est une contrainte du pipeline Flutter, pas une limitation propre à ce
/// widget : tout mécanisme retournant un [Widget] arbitraire basé sur une
/// taille mesurée a ce même délai. Si vous n'avez besoin que de *dessiner*
/// (pas de construire de nouveaux widgets) en fonction de la taille, voir
/// [MeasuredDecoration], qui n'a aucun délai.
///
/// ## Estimation
/// - Pendant le laps de temps entre un changement de contraintes et la mesure
///   suivante, la taille est **estimée** (`isPrecise` = false). Cela garantit
///   qu'aucune taille obsolète n'est présentée comme précise.
/// - Si [estimateBuilder] est fourni, il est utilisé pour l'estimation. S'il
///   lève une exception ou retourne une [Size] invalide (NaN, infinie ou
///   négative), l'erreur est capturée (avec avertissement en debug) et on
///   retombe sur l'estimation par défaut plutôt que de faire planter le
///   layout de toute l'application.
/// - Sinon, l'estimation repart de [Size.zero] (ou de la dernière taille
///   compatible si [keepPreviousSizeOnChildChange] est vrai).
/// - Pour retrouver une estimation basée sur les contraintes max, activez
///   [useConstraintsAsInitialEstimate].
///
/// ## Coût de performance
/// Chaque mesure précise déclenche un `setState` interne, donc un rebuild
/// complet de tout ce que retourne [builder]. Si ce dernier construit un
/// sous-arbre coûteux et par ailleurs statique, enveloppez-le dans un
/// [RepaintBoundary] ou extrayez-le en widget `const`/séparé.
///
/// ## Exemple
/// ```dart
/// SmartMeasurer(
///   child: Text('Bonjour le monde'),
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
  /// Le widget dont la taille doit être mesurée.
  final Widget child;

  /// Construit le résultat affiché. `measuredChild` doit être inséré
  /// exactement une fois dans l'arbre retourné.
  final Widget Function(
    BuildContext context,
    Widget measuredChild,
    Size size,
    bool isPrecise,
    BoxConstraints constraints,
  ) builder;

  /// Fournit une estimation de taille personnalisée pendant les frames sans
  /// mesure précise disponible.
  final Size Function(BoxConstraints constraints, Size? previousSize)?
      estimateBuilder;

  /// Si vrai (par défaut), la dernière taille précise mesurée est réutilisée
  /// comme estimation lors d'un changement de [child], plutôt que de
  /// repartir de zéro.
  final bool keepPreviousSizeOnChildChange;

  /// Si vrai, l'estimation initiale (avant toute mesure) se base sur les
  /// contraintes maximales plutôt que sur [Size.zero].
  final bool useConstraintsAsInitialEstimate;

  /// Crée un [SmartMeasurer] mesurant [child] et déléguant le rendu à
  /// [builder].
  const SmartMeasurer({
    super.key,
    required this.child,
    required this.builder,
    this.estimateBuilder,
    this.keepPreviousSizeOnChildChange = true,
    this.useConstraintsAsInitialEstimate = false,
  });

  @override
  State<SmartMeasurer> createState() => _SmartMeasurerState();
}

/// Regroupe tout ce qui définit une mesure précise valide : la taille
/// obtenue, les contraintes réellement utilisées pour l'obtenir, et la
/// génération externe au moment de cette mesure.
///
/// Fusionner ces trois valeurs dans un seul objet immuable évite toute
/// désynchronisation partielle : elles sont toujours remplacées ensemble,
/// dans un seul `setState`.
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

  final GlobalKey _measuredChildKey = GlobalKey(debugLabel: 'SmartMeasurer');
  int _framesWithoutPreciseSize = 0;

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
            context: ErrorDescription(
                'lors de l\'appel à SmartMeasurer.estimateBuilder'),
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
            '⚠ SmartMeasurer : estimateBuilder a retourné une taille '
            'invalide ($estimated). Repli sur l\'estimation par défaut.',
          );
          return true;
        }());
      }
    }

    if (previousSize != null &&
        _isValidForConstraints(previousSize, constraints)) {
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

  bool _isValidForConstraints(Size size, BoxConstraints constraints) {
    final double maxW =
        constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity;
    final double maxH =
        constraints.hasBoundedHeight ? constraints.maxHeight : double.infinity;

    if (size.width < constraints.minWidth || size.width > maxW) return false;
    if (size.height < constraints.minHeight || size.height > maxH) {
      return false;
    }
    return true;
  }

  void _checkMissingChild() {
    _framesWithoutPreciseSize++;
    if (_framesWithoutPreciseSize == 3) {
      debugPrint(
        '⚠ SmartMeasurer : aucune mesure précise obtenue après 3 frames.\n'
        'Causes possibles :\n'
        '  • measuredChild n\'a pas été inséré dans l\'arbre retourné par le builder.\n'
        '  • measuredChild est inséré mais dans un sous-arbre qui ne reçoit\n'
        '    jamais de layout (ex: Offstage, Visibility(visible: false), etc.).\n'
        '  • Le layout de l\'enfant est simplement lent à se stabiliser — dans ce\n'
        '    cas ce message est informatif, pas nécessairement une erreur.',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// SimpleMeasurer (version simplifiée, l'enfant est affiché automatiquement)
// ---------------------------------------------------------------------------

/// Version simplifiée de [SmartMeasurer] où l'enfant est automatiquement
/// superposé en [Positioned.fill] dans un [Stack].
///
/// Le [builder] retourne uniquement le décor/fond qui s'adapte à la taille
/// de l'enfant ; l'enfant lui-même est géré pour vous.
///
/// ## Exemple
/// ```dart
/// SimpleMeasurer(
///   child: Text('Bonjour'),
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
  /// Le widget dont la taille doit être mesurée, superposé automatiquement
  /// au décor retourné par [builder].
  final Widget child;

  /// Construit uniquement le décor/fond ; l'enfant est géré automatiquement
  /// et superposé en [Positioned.fill].
  final Widget Function(
    BuildContext context,
    Size size,
    bool isPrecise,
    BoxConstraints constraints,
  ) builder;

  /// Fournit une estimation de taille personnalisée pendant les frames sans
  /// mesure précise disponible. Voir [SmartMeasurer.estimateBuilder].
  final Size Function(BoxConstraints constraints, Size? previousSize)?
      estimateBuilder;

  /// Si vrai (par défaut), la dernière taille précise mesurée est réutilisée
  /// comme estimation lors d'un changement de [child].
  final bool keepPreviousSizeOnChildChange;

  /// Si vrai, l'estimation initiale (avant toute mesure) se base sur les
  /// contraintes maximales plutôt que sur [Size.zero].
  final bool useConstraintsAsInitialEstimate;

  /// Crée un [SimpleMeasurer] mesurant [child] et déléguant le décor à
  /// [builder].
  const SimpleMeasurer({
    super.key,
    required this.child,
    required this.builder,
    this.estimateBuilder,
    this.keepPreviousSizeOnChildChange = true,
    this.useConstraintsAsInitialEstimate = false,
  });

  @override
  Widget build(BuildContext context) {
    return SmartMeasurer(
      estimateBuilder: estimateBuilder,
      keepPreviousSizeOnChildChange: keepPreviousSizeOnChildChange,
      useConstraintsAsInitialEstimate: useConstraintsAsInitialEstimate,
      builder: (context, measuredChild, size, isPrecise, constraints) {
        return Stack(
          children: [
            builder(context, size, isPrecise, constraints),
            Positioned.fill(child: measuredChild),
          ],
        );
      },
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// MeasuredDecoration (zéro délai — dessin pur, pas de nouveaux widgets)
// ---------------------------------------------------------------------------

/// Peint un décor dépendant de la taille de [child], en une seule passe de
/// layout/paint — contrairement à [SmartMeasurer] / [SimpleMeasurer], il n'y
/// a ici **aucun délai d'une frame**, car [painter] ne construit pas de
/// [Widget] : il dessine directement sur un [Canvas] pendant la phase de
/// paint, une fois que la taille de l'enfant est déjà connue dans la même
/// passe de layout.
///
/// Limitation en contrepartie : [painter] ne peut pas produire de nouveaux
/// widgets interactifs (boutons, texte sélectionnable, etc.), seulement du
/// dessin (formes, dégradés, ombres...). Pour un besoin de sous-arbre de
/// widgets réactif à la taille, utilisez [SmartMeasurer].
///
/// ## Exemple
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
///   child: const Text('Sans délai'),
/// )
/// ```
class MeasuredDecoration extends SingleChildRenderObjectWidget {
  /// Dessine derrière (ou devant) l'enfant. `size` est la taille exacte de
  /// l'enfant, déjà connue au moment de l'appel.
  final void Function(Canvas canvas, Size size) painter;

  /// Si vrai (par défaut), [painter] est appelé avant l'enfant (décor en
  /// arrière-plan). Si faux, après (overlay au-dessus de l'enfant).
  final bool paintBehindChild;

  /// Crée un [MeasuredDecoration] dessinant [painter] autour de [child],
  /// sans délai d'une frame.
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
    renderObject
      ..painter = painter
      ..paintBehindChild = paintBehindChild;
  }
}

class RenderMeasuredDecoration extends RenderProxyBox {
  void Function(Canvas canvas, Size size) painter;
  bool paintBehindChild;

  RenderMeasuredDecoration({
    required this.painter,
    required this.paintBehindChild,
  });

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
}

// ============================================================================
// Infrastructure de mesure privée (utilisée par SmartMeasurer)
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
      Size newSize, BoxConstraints constraints, int gen) {
    _pendingSize = newSize;
    _pendingConstraints = constraints;
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
