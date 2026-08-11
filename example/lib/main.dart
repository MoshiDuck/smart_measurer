import 'package:flutter/material.dart';
import 'package:smart_measurer/smart_measurer.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'smart_measurer demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  double _fontSize = 16;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('smart_measurer — démo')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Section(
            title: 'SimpleMeasurer',
            subtitle: 'Le fond s\'adapte à la taille réelle du texte, dont la '
                'taille de police change ci-dessous.',
            child: SimpleMeasurer(
              child: Text(
                'Bonjour le monde',
                style: TextStyle(fontSize: _fontSize),
              ),
              builder: (context, size, isPrecise, constraints) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: size.width + 32,
                  height: size.height + 24,
                  decoration: BoxDecoration(
                    color: isPrecise
                        ? Colors.indigo.shade100
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              },
            ),
          ),
          Slider(
            value: _fontSize,
            min: 12,
            max: 40,
            onChanged: (v) => setState(() => _fontSize = v),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'SmartMeasurer',
            subtitle: 'Contrôle complet : le texte mesuré est inséré '
                'manuellement au centre du décor.',
            child: SmartMeasurer(
              child: const Icon(Icons.star, size: 48, color: Colors.amber),
              builder: (context, measuredChild, size, isPrecise, constraints) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPrecise ? Colors.amber : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: measuredChild,
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'MeasuredDecoration',
            subtitle: 'Décor dessiné sans délai d\'une frame — jamais de flash '
                'visible, même à la première frame.',
            child: MeasuredDecoration(
              painter: (canvas, size) {
                final paint = Paint()..color = Colors.teal.shade100;
                canvas.drawRRect(
                  RRect.fromRectAndRadius(
                    Rect.fromLTWH(-16, -12, size.width + 32, size.height + 24),
                    const Radius.circular(16),
                  ),
                  paint,
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Text('Aucun flicker possible'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Center(child: child),
      ],
    );
  }
}
