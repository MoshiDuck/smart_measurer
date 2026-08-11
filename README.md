# smart_measurer

Measure a widget's real size in Flutter and react to it — with a clean
estimate during the one-frame measurement delay, and a **zero-delay**
variant for when you only need to draw.

## Why this package

Flutter always runs *build* before *layout* within a frame. It is
structurally impossible to know a widget's size when building it for the
first time — any solution that returns a new `Widget` based on a measured
size necessarily has a one-frame delay. `smart_measurer` doesn't hide this
constraint: it gives you an explicit `isPrecise` flag so you know, every
frame, whether the displayed size is measured or estimated.

For cases where you only need to *paint* a size-dependent decoration (not
build new widgets), `MeasuredDecoration` avoids that delay entirely by
staying inside the `RenderObject` layer.

## The three widgets

| Widget | Delay | Use case |
|---|---|---|
| `SmartMeasurer` | 1 frame | Full control, access to `measuredChild` |
| `SimpleMeasurer` | 1 frame | Simplified variant (auto-overlaid child) |
| `MeasuredDecoration` | None | Pure `Canvas` drawing based on child size |

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  smart_measurer: ^0.1.0
```

## Usage

### SimpleMeasurer — decoration that adapts to a text's size

```dart
import 'package:smart_measurer/smart_measurer.dart';

SimpleMeasurer(
  child: const Text('Hello world'),
  builder: (context, size, isPrecise, constraints) {
    return Container(
      width: size.width + 24,
      height: size.height + 24,
      decoration: BoxDecoration(
        color: isPrecise ? Colors.blue.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  },
)
```

`isPrecise` is `false` during the (brief) window where the displayed size
is an estimate — for example, right after an external constraint change,
before the next measurement arrives. Use this flag to, for instance, avoid
animating a transition until the size is certain.

### SmartMeasurer — full control

```dart
SmartMeasurer(
  child: const Icon(Icons.star, size: 48),
  builder: (context, measuredChild, size, isPrecise, constraints) {
    return Stack(
      children: [
        CustomPaint(
          size: size,
          painter: HaloPainter(),
        ),
        Center(child: measuredChild), // measuredChild inserted exactly once
      ],
    );
  },
)
```

⚠️ `measuredChild` must appear **exactly once** in the tree returned by
`builder`. Inserting it multiple times triggers a Flutter duplicate-key
error (this is intended behavior: an immediate signal rather than a silent
bug).

### MeasuredDecoration — drawing with no delay

When you only need to paint a background/halo/border that depends on the
size (not build a widget), avoid the one-frame delay:

```dart
MeasuredDecoration(
  painter: (canvas, size) {
    final paint = Paint()..color = Colors.deepPurple.shade100;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-12, -12, size.width + 24, size.height + 24),
        const Radius.circular(12),
      ),
      paint,
    );
  },
  child: const Text('No delay, never a flicker'),
)
```

## Custom estimation

By default, the estimate used during the measurement delay reuses the last
known precise size (if compatible with the new constraints), otherwise it
falls back to `Size.zero`. Customize this behavior with `estimateBuilder`:

```dart
SimpleMeasurer(
  estimateBuilder: (constraints, previousSize) {
    // E.g.: estimate based on the character count of known text,
    // an average font width, etc.
    return previousSize ?? const Size(100, 40);
  },
  child: const Text('...'),
  builder: (context, size, isPrecise, constraints) => /* ... */ Container(),
)
```

## See also

Check out the [`example/`](example) folder for a full demo of all three
widgets.

## Known limitations

- `SmartMeasurer` / `SimpleMeasurer` have a one-frame delay after any
  change to external constraints or to `child` — this is a constraint of
  the Flutter pipeline, not a bug (see the "Why this package" section).
- `MeasuredDecoration` can only draw (`Canvas`), it cannot insert new
  interactive widgets.

## Contributing

Issues and pull requests are welcome on the project's GitHub repository.