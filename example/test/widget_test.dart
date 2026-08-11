// Tests for the smart_measurer package.
//
// A note on frame timing: SmartMeasurer's measurement notifications are
// delivered via SchedulerBinding.addPostFrameCallback (see README — "One-
// frame delay"), so the sequence in every test below is intentional:
//   1. pumpWidget() runs the first frame: an *estimated* size is built, then
//      layout happens and schedules the post-frame callback.
//   2. A first extra pump() runs the second frame: the post-frame callback
//      fires, commits the precise measurement via setState, which marks the
//      widget dirty for the *next* frame.
//   3. Where a second extra pump() appears, it's to let a further
//      post-frame effect (e.g. SmartMeasurerController.notifyListeners)
//      settle — harmless even where not strictly required.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_measurer/smart_measurer.dart';

void main() {
  testWidgets('SmartMeasurer starts estimated and becomes precise',
      (tester) async {
    bool? lastIsPrecise;
    Size? lastSize;

    await tester.pumpWidget(
      MaterialApp(
        home: SmartMeasurer(
          child: const SizedBox(width: 120, height: 40),
          builder: (context, measuredChild, size, isPrecise, constraints) {
            lastSize = size;
            lastIsPrecise = isPrecise;
            return SizedBox(
              width: size.width,
              height: size.height,
              child: measuredChild,
            );
          },
        ),
      ),
    );

    // First frame: no measurement has landed yet.
    expect(lastIsPrecise, isFalse);

    await tester.pump();

    expect(lastIsPrecise, isTrue);
    expect(lastSize, const Size(120, 40));
  });

  testWidgets('SimpleMeasurer sizes its decoration to the child, not to itself',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SimpleMeasurer(
          child: const SizedBox(width: 80, height: 30),
          builder: (context, size, isPrecise, constraints) {
            return Container(
              key: const Key('decoration'),
              width: size.width + 20,
              height: size.height + 20,
              color: Colors.blue,
            );
          },
        ),
      ),
    );

    await tester.pump();

    final decorationSize = tester.getSize(find.byKey(const Key('decoration')));
    expect(decorationSize, const Size(100, 50));
  });

  testWidgets('MeasuredDecoration paints without a one-frame delay',
      (tester) async {
    Size? paintedSize;
    BoxConstraints? paintedConstraints;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: MeasuredDecoration(
            painter: (canvas, size, constraints) {
              paintedSize = size;
              paintedConstraints = constraints;
            },
            child: const SizedBox(width: 60, height: 20),
          ),
        ),
      ),
    );

    // No extra pump needed: MeasuredDecoration paints in the very same
    // frame it is laid out in.
    expect(paintedSize, const Size(60, 20));
    expect(paintedConstraints, isNotNull);
  });

  testWidgets('MeasuredDecoration.onSizeChanged fires when the size changes',
      (tester) async {
    final sizes = <Size>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MeasuredDecoration(
          painter: (canvas, size, constraints) {},
          onSizeChanged: sizes.add,
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    );

    // onSizeChanged is deferred to a post-frame callback.
    await tester.pump();

    expect(sizes, [const Size(40, 40)]);
  });

  testWidgets('SmartMeasurerController mirrors the measured size',
      (tester) async {
    final controller = SmartMeasurerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SmartMeasurer(
          controller: controller,
          child: const SizedBox(width: 50, height: 50),
          builder: (context, measuredChild, size, isPrecise, constraints) =>
              measuredChild,
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(controller.isPrecise, isTrue);
    expect(controller.size, const Size(50, 50));
  });

  testWidgets('SmartMeasurerGroup measures every child independently',
      (tester) async {
    late List<Size> sizes;
    late bool allPrecise;

    await tester.pumpWidget(
      MaterialApp(
        home: SmartMeasurerGroup(
          children: const [
            SizedBox(width: 10, height: 10),
            SizedBox(width: 20, height: 20),
          ],
          builder: (context, measuredChildren, s, precise, constraints) {
            sizes = s;
            allPrecise = precise;
            return Column(children: measuredChildren);
          },
        ),
      ),
    );

    await tester.pump();

    expect(allPrecise, isTrue);
    expect(sizes, [const Size(10, 10), const Size(20, 20)]);
  });

  testWidgets('placeholderBuilder is shown until the first precise size',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SmartMeasurer(
          placeholderBuilder: (context, constraints) =>
              const Text('loading', key: Key('placeholder')),
          child: const SizedBox(width: 30, height: 30),
          builder: (context, measuredChild, size, isPrecise, constraints) =>
              const Text('ready', key: Key('ready')),
        ),
      ),
    );

    expect(find.byKey(const Key('placeholder')), findsOneWidget);
    expect(find.byKey(const Key('ready')), findsNothing);

    await tester.pump();

    expect(find.byKey(const Key('placeholder')), findsNothing);
    expect(find.byKey(const Key('ready')), findsOneWidget);
  });
}
