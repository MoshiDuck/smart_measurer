/// Measure a widget's real size and react to it — with estimation during the
/// one-frame measurement delay, and a zero-delay variant for pure drawing.
///
/// Four widgets are exposed:
/// - [SmartMeasurer] : full control, the `builder` receives the measured
///   child and must insert it exactly once.
/// - [SimpleMeasurer] : simplified variant, the child is automatically
///   overlaid in a [Stack].
/// - [SmartMeasurerGroup] : measures several children at once and hands
///   back their sizes as a list.
/// - [MeasuredDecoration] : paints a decoration that depends on the child's
///   size in a single layout/paint pass, with no frame delay.
///
/// [SmartMeasurerController] gives external, read-only access to a
/// [SmartMeasurer]'s current size outside of its `builder`.
library;

export 'src/smart_measurer_base.dart'
    show
        SmartMeasurer,
        SimpleMeasurer,
        SmartMeasurerGroup,
        MeasuredDecoration,
        MeasuredDecorationPainter,
        RenderMeasuredDecoration,
        SmartMeasurerController,
        SmartMeasurerEstimateStrategy;
