/// Measure a widget's real size and react to it — with estimation during the
/// one-frame measurement delay, and a zero-delay variant for pure drawing.
///
/// Three widgets are exposed:
/// - [SmartMeasurer] : full control, the `builder` receives the measured
///   child and must insert it exactly once.
/// - [SimpleMeasurer] : simplified variant, the child is automatically
///   overlaid in a [Stack].
/// - [MeasuredDecoration] : paints a decoration that depends on the child's
///   size in a single layout/paint pass, with no frame delay.
library;

export 'src/smart_measurer_base.dart'
    show SmartMeasurer, SimpleMeasurer, MeasuredDecoration;
