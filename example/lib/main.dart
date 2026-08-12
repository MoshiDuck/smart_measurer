import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:smart_measurer/smart_measurer.dart";

// =============================================================================
// Global debug console — captures all onDebugWarning / onSizeChanged calls
// from the demos below and displays them in a collapsible panel at the
// bottom of the screen, to see live what the package is doing internally.
// =============================================================================

class LogEntry {
  const LogEntry(this.tag, this.message, this.time, this.color);
  final String tag;
  final String message;
  final DateTime time;
  final Color color;
}

class DebugLog extends ChangeNotifier {
  final List<LogEntry> _entries = [];
  List<LogEntry> get entries => List.unmodifiable(_entries);

  void add(String tag, String message, Color color) {
    _entries.insert(0, LogEntry(tag, message, DateTime.now(), color));
    if (_entries.length > 60) {
      _entries.removeLast();
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// Renders the whole log content as plain text, oldest to newest
  /// (natural reading order), for copying to the clipboard.
  String toPlainText() {
    final ordered = _entries.reversed;
    return ordered.map((e) => "[${_fmtTime(e.time)}] ${e.tag}: ${e.message}").join("\n");
  }
}

final DebugLog debugLog = DebugLog();

String _fmtTime(DateTime t) =>
    "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}";

// =============================================================================
// Localization — tiny in-app EN/FR translation system
// =============================================================================

enum AppLang { en, fr }

class AppLocale extends ChangeNotifier {
  AppLang _lang = AppLang.en;
  AppLang get lang => _lang;

  void toggle() {
    _lang = _lang == AppLang.en ? AppLang.fr : AppLang.en;
    notifyListeners();
  }

  String t(String key) => Tr.map[key]?[_lang] ?? key;
}

final AppLocale appLocale = AppLocale();

/// Shorthand translation lookup, e.g. `t('app_title')`.
String t(String key) => appLocale.t(key);

class Tr {
  static const Map<String, Map<AppLang, String>> map = {
    // App / shell
    "app_title": {AppLang.en: "smart_measurer — Test Suite", AppLang.fr: "smart_measurer — Suite de tests"},
    "toggle_theme": {AppLang.en: "Toggle theme", AppLang.fr: "Changer de thème"},
    "toggle_lang": {AppLang.en: "Translate", AppLang.fr: "Traduire"},

    // Hero header
    "hero_desc": {
      AppLang.en: "Interactive test suite covering every widget and every option of the package: "
          "measurement, estimation, animation, groups, delay-free decoration and safety guards.",
      AppLang.fr: "Suite de tests interactive couvrant chaque widget et chaque option du package : "
          "mesure, estimation, animation, groupes, décoration sans délai et garde-fous anti-bug.",
    },
    "chip_no_flicker": {AppLang.en: "No flicker", AppLang.fr: "Sans flicker"},
    "chip_external_controller": {AppLang.en: "External controller", AppLang.fr: "Contrôleur externe"},
    "chip_zero_delay": {AppLang.en: "0-delay (paint)", AppLang.fr: "0 délai (peinture)"},
    "chip_measured_groups": {AppLang.en: "Measured groups", AppLang.fr: "Groupes mesurés"},
    "chip_overflow_safe": {AppLang.en: "Overflow-safe", AppLang.fr: "Anti-débordement"},

    // Card 1
    "title1": {AppLang.en: "1 · SimpleMeasurer", AppLang.fr: "1 · SimpleMeasurer"},
    "subtitle1": {
      AppLang.en: "The bubble resizes itself around the measured text.",
      AppLang.fr: "La bulle se redimensionne toute seule autour du texte mesuré.",
    },
    "footnote1": {
      AppLang.en: "The child is automatically overlaid: you only manage the decoration.",
      AppLang.fr: "Le child est automatiquement superposé : vous ne gérez que la décoration.",
    },

    // Card 2
    "title2": {AppLang.en: "2 · SmartMeasurer + controller", AppLang.fr: "2 · SmartMeasurer + contrôleur"},
    "subtitle2": {
      AppLang.en: "Circle that follows the icon's size, read externally via a SmartMeasurerController.",
      AppLang.fr: "Cercle qui suit la taille de l'icône, lu depuis l'extérieur via un SmartMeasurerController.",
    },
    "footnote2": {
      AppLang.en: "Disable \u201ckeep previous size\u201d then change icon to see the loading placeholder "
          "again (placeholderBuilder).",
      AppLang.fr: "Désactivez « conserver la taille précédente » puis changez d'icône pour revoir le "
          "placeholder de chargement (placeholderBuilder).",
    },

    // Card 3
    "title3": {AppLang.en: "3 · Estimation strategies & debounce", AppLang.fr: "3 · Stratégies d'estimation & debounce"},
    "subtitle3": {
      AppLang.en: "Observe how the size is guessed as long as no precise measurement is available.",
      AppLang.fr: "Observez comment la taille est devinée tant qu'aucune mesure précise n'est disponible.",
    },
    "footnote3": {
      AppLang.en: "Height is not bounded here: the \u201cConstraints\u201d strategy will therefore give an "
          "estimated height of 0 during the estimation phase.",
      AppLang.fr: "La hauteur n'est pas bornée ici : la stratégie « Contraintes » donnera donc une "
          "hauteur estimée de 0 pendant la phase d'estimation.",
    },

    // Card 4
    "title4": {AppLang.en: "4 · SmartMeasurerGroup", AppLang.fr: "4 · SmartMeasurerGroup"},
    "subtitle4": {
      AppLang.en: "A sliding tab indicator, computed from the measured widths of each label.",
      AppLang.fr: "Un indicateur d'onglet glissant, calculé à partir des largeurs mesurées de chaque libellé.",
    },

    // Card 5
    "title5": {AppLang.en: "5 · MeasuredDecoration", AppLang.fr: "5 · MeasuredDecoration"},
    "subtitle5": {
      AppLang.en: "Direct canvas painting, without the one-frame delay typical of widget builders.",
      AppLang.fr: "Peinture directe sur canvas, sans le délai d'une frame propre aux builders de widgets.",
    },

    // Card 6
    "title6": {AppLang.en: "6 · Debug tools", AppLang.fr: "6 · Outils de debug"},
    "subtitle6": {
      AppLang.en: "ignorePointerDuringEstimate + debugPaintEstimatedSize, tested under real conditions.",
      AppLang.fr: "ignorePointerDuringEstimate + debugPaintEstimatedSize, testés en conditions réelles.",
    },

    // Card 7
    "title7": {AppLang.en: "7 · Overflow safety", AppLang.fr: "7 · Anti-débordement"},
    "subtitle7": {
      AppLang.en: "scrollable + constrainToAvailableSpace to never cause a visible overflow.",
      AppLang.fr: "scrollable + constrainToAvailableSpace pour ne jamais provoquer d'overflow visuel.",
    },

    // Card 8
    "title8": {AppLang.en: "8 · Real case: notification badge", AppLang.fr: "8 · Cas réel : badge de notification"},
    "subtitle8": {
      AppLang.en: "The badge widens smoothly as the number goes from 1 to several digits.",
      AppLang.fr: "Le badge s'élargit en douceur quand le nombre passe de 1 à plusieurs chiffres.",
    },

    // Precision pill
    "precise": {AppLang.en: "Precise", AppLang.fr: "Précis"},
    "estimated": {AppLang.en: "Estimated", AppLang.fr: "Estimé"},

    // Demo 1 — messages
    "msg1": {AppLang.en: "Hello!", AppLang.fr: "Bonjour !"},
    "msg2": {AppLang.en: "Nice to see you 👋", AppLang.fr: "Ravi de vous voir 👋"},
    "msg3": {
      AppLang.en: "A noticeably longer message to test stretching",
      AppLang.fr: "Un message nettement plus long pour tester l'étirement",
    },
    "msg4": {AppLang.en: "Short", AppLang.fr: "Court"},
    "message_chip": {AppLang.en: "Message", AppLang.fr: "Message"},
    "keep_previous_size_title": {
      AppLang.en: "Keep previous size on change",
      AppLang.fr: "Conserver la taille précédente au changement",
    },

    // Demo 2
    "measured_size": {AppLang.en: "Measured size", AppLang.fr: "Taille mesurée"},

    // Demo 3
    "strategy_zero": {AppLang.en: "Zero", AppLang.fr: "Zéro"},
    "strategy_previous": {AppLang.en: "Prev. size", AppLang.fr: "Taille préc."},
    "strategy_constraints": {AppLang.en: "Constraints", AppLang.fr: "Contraintes"},
    "strategy_custom": {AppLang.en: "Custom", AppLang.fr: "Personnalisée"},
    "fixed_content": {AppLang.en: "Fixed content\n160 × 60", AppLang.fr: "Contenu fixe\n160 × 60"},
    "debounce_title": {AppLang.en: "Debounce (900 ms)", AppLang.fr: "Debounce (900 ms)"},
    "debounce_subtitle": {
      AppLang.en: "notifyDebounce batches measurements while dragging the slider",
      AppLang.fr: "notifyDebounce regroupe les mesures pendant le glissement du slider",
    },
    "simulate_invalid_title": {
      AppLang.en: "Simulate an invalid estimate (NaN)",
      AppLang.fr: "Simuler une estimation invalide (NaN)",
    },
    "simulate_invalid_subtitle": {
      AppLang.en: "Triggers the automatic fallback + a console warning",
      AppLang.fr: "Déclenche le repli automatique + un avertissement en console",
    },

    // Demo 4 — tabs
    "tab_home": {AppLang.en: "Home", AppLang.fr: "Accueil"},
    "tab_explore": {AppLang.en: "Explore", AppLang.fr: "Explorer"},
    "tab_notifications": {AppLang.en: "Notifications", AppLang.fr: "Notifications"},
    "tab_profile": {AppLang.en: "Profile", AppLang.fr: "Profil"},
    "selected_label": {AppLang.en: "Selected", AppLang.fr: "Sélectionné"},

    // Demo 5
    "text_no_delay": {AppLang.en: "No delay", AppLang.fr: "Aucun délai"},
    "text_instant_paint": {AppLang.en: "Instant paint", AppLang.fr: "Peinture instantanée"},
    "text_glow": {AppLang.en: "Glow", AppLang.fr: "Glow"},
    "paint_behind_title": {AppLang.en: "Paint behind the text", AppLang.fr: "Peindre derrière le texte"},
    "paint_behind_subtitle": {
      AppLang.en: "paintBehindChild — disable for an overlaid outline",
      AppLang.fr: "paintBehindChild — désactivez pour un contour superposé",
    },

    // Demo 6
    "touch_me": {AppLang.en: "Touch me", AppLang.fr: "Toucher-moi"},
    "taps_recorded": {AppLang.en: "Taps recorded", AppLang.fr: "Taps enregistrés"},
    "resize_button": {
      AppLang.en: "Resize (≈700 ms of estimation)",
      AppLang.fr: "Redimensionner (≈700 ms d'estimation)",
    },
    "ignore_taps_title": {
      AppLang.en: "Ignore taps during estimation",
      AppLang.fr: "Ignorer les taps pendant l'estimation",
    },
    "debug_border_title": {AppLang.en: "Debug border (red/green)", AppLang.fr: "Bordure de debug (rouge/vert)"},

    // Demo 7
    "item_label": {AppLang.en: "Item", AppLang.fr: "Élément"},
    "warn_no_scroll_no_constrain": {
      AppLang.en: "⚠️ Without scrolling or constraint, a row that is too wide can overflow "
          "(RenderFlex overflow) — this is exactly what \u201cscrollable\u201d or \u201cconstrain to "
          "available space\u201d prevents.",
      AppLang.fr: "⚠️ Sans défilement ni contrainte, une rangée trop large peut déborder "
          "(RenderFlex overflow) — c'est exactement ce que « scrollable » ou "
          "« contraindre à l'espace disponible » permettent d'éviter.",
    },
    "info_shrink_true": {
      AppLang.en: "ℹ️ Content that is too wide is shrunk (shrinkToFit) to fit the available space, "
          "instead of overflowing or being clipped.",
      AppLang.fr: "ℹ️ Le contenu trop large est rétréci (shrinkToFit) pour tenir dans l'espace disponible, "
          "au lieu de déborder ou d'être découpé.",
    },
    "info_shrink_false": {
      AppLang.en: "ℹ️ Content that is too wide is clipped rather than visually overflowing. "
          "Enable \u201cshrink items\u201d to make it fit by scaling it down instead.",
      AppLang.fr: "ℹ️ Le contenu trop large est découpé (clip) plutôt que de déborder visuellement. "
          "Activez « rétrécir les éléments » pour le faire tenir en le réduisant à la place.",
    },
    "scrollable_title": {AppLang.en: "Scrollable", AppLang.fr: "Scrollable"},
    "constrain_title": {
      AppLang.en: "Constrain to available space",
      AppLang.fr: "Contraindre à l'espace disponible",
    },
    "constrain_subtitle": {
      AppLang.en: "constrainToAvailableSpace — when \u201cscrollable\u201d is on, it limits the axis "
          "perpendicular to scrolling; otherwise it prevents any visible overflow "
          "(clip, or shrinking if enabled below).",
      AppLang.fr: "constrainToAvailableSpace — quand « scrollable » est actif, limite l'axe "
          "perpendiculaire au défilement ; sinon, empêche tout débordement visuel "
          "(clip, ou rétrécissement si activé ci-dessous).",
    },
    "shrink_to_fit_title": {AppLang.en: "Shrink items (shrinkToFit)", AppLang.fr: "Rétrécir les éléments (shrinkToFit)"},
    "shrink_to_fit_subtitle": {
      AppLang.en: "Only has an effect without scrolling and with \u201cconstrain\u201d enabled: instead of "
          "clipping content that is too wide, it is scaled down to fit.",
      AppLang.fr: "N'a d'effet que sans défilement et avec « contraindre » activé : "
          "au lieu de découper le contenu trop large, il est mis à l'échelle pour tenir.",
    },

    // Demo 8
    "clear_button": {AppLang.en: "Clear", AppLang.fr: "Vider"},

    // Debug console
    "debug_console": {AppLang.en: "Debug console", AppLang.fr: "Console de debug"},
    "copy_all": {AppLang.en: "Copy all", AppLang.fr: "Copier tout"},
    "console_copied": {AppLang.en: "Console copied.", AppLang.fr: "Console copiée."},
    "clear_console": {AppLang.en: "Clear", AppLang.fr: "Vider"},
    "no_events_yet": {
      AppLang.en: "No events yet — trigger a test above.",
      AppLang.fr: "Aucun évènement pour le moment — déclenchez un test ci-dessus.",
    },

    // Debug log tags
    "tag_strategies": {AppLang.en: "Strategies", AppLang.fr: "Stratégies"},
    "tag_debug_tools": {AppLang.en: "Debug tools", AppLang.fr: "Outils debug"},
    "tag_overflow_safe": {AppLang.en: "Overflow-safe", AppLang.fr: "Anti-débordement"},
    "new_size_prefix": {AppLang.en: "New size", AppLang.fr: "Nouvelle taille"},
  };
}

// =============================================================================
// App
// =============================================================================

void main() => runApp(const TestApp());

class TestApp extends StatefulWidget {
  const TestApp({super.key});

  @override
  State<TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "smart_measurer — tests",
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true, brightness: Brightness.dark),
      home: HomePage(themeMode: _themeMode, onToggleTheme: _toggleTheme),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.themeMode, required this.onToggleTheme});

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    // Listening to appLocale here rebuilds the whole page (and every t('key')
    // call within it) whenever the language is toggled, while the nested
    // StatefulWidgets below keep their own state (slider values, indices...).
    return AnimatedBuilder(
      animation: appLocale,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(t("app_title")),
            actions: [
              IconButton(
                tooltip: t("toggle_lang"),
                onPressed: appLocale.toggle,
                icon: Text(
                  appLocale.lang == AppLang.en ? "FR" : "EN",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: t("toggle_theme"),
                onPressed: onToggleTheme,
                icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  children: [
                    const _HeroHeader(),
                    const SizedBox(height: 20),
                    _DemoCard(
                      icon: Icons.chat_bubble_outline,
                      color: Colors.indigo,
                      title: t("title1"),
                      subtitle: t("subtitle1"),
                      footnote: t("footnote1"),
                      child: const _SimpleMeasurerDemo(),
                    ),
                    _DemoCard(
                      icon: Icons.circle_outlined,
                      color: Colors.deepPurple,
                      title: t("title2"),
                      subtitle: t("subtitle2"),
                      footnote: t("footnote2"),
                      child: const _IconCircleDemo(),
                    ),
                    _DemoCard(
                      icon: Icons.tune,
                      color: Colors.teal,
                      title: t("title3"),
                      subtitle: t("subtitle3"),
                      footnote: t("footnote3"),
                      child: const _EstimateStrategyDemo(),
                    ),
                    _DemoCard(
                      icon: Icons.view_carousel_outlined,
                      color: Colors.pink,
                      title: t("title4"),
                      subtitle: t("subtitle4"),
                      child: const _SlidingTabsDemo(),
                    ),
                    _DemoCard(
                      icon: Icons.brush_outlined,
                      color: Colors.deepOrange,
                      title: t("title5"),
                      subtitle: t("subtitle5"),
                      child: const _GlowDecorationDemo(),
                    ),
                    _DemoCard(
                      icon: Icons.bug_report_outlined,
                      color: Colors.blue,
                      title: t("title6"),
                      subtitle: t("subtitle6"),
                      child: const _DebugToolsDemo(),
                    ),
                    _DemoCard(
                      icon: Icons.swipe_outlined,
                      color: Colors.brown,
                      title: t("title7"),
                      subtitle: t("subtitle7"),
                      child: const _OverflowSafeDemo(),
                    ),
                    _DemoCard(
                      icon: Icons.notifications_active_outlined,
                      color: Colors.redAccent,
                      title: t("title8"),
                      subtitle: t("subtitle8"),
                      child: const _NotificationBadgeDemo(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const _DebugConsole(),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Header
// =============================================================================

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.shade600, Colors.deepPurple.shade400],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.straighten, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "smart_measurer",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t("hero_desc"),
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(t("chip_no_flicker")),
              _HeroChip(t("chip_external_controller")),
              _HeroChip(t("chip_zero_delay")),
              _HeroChip(t("chip_measured_groups")),
              _HeroChip(t("chip_overflow_safe")),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// =============================================================================
// Shared components
// =============================================================================

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footnote,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
          if (footnote != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(footnote!, style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrecisionPill extends StatelessWidget {
  const _PrecisionPill({required this.isPrecise});
  final bool isPrecise;

  @override
  Widget build(BuildContext context) {
    final Color c = isPrecise ? Colors.green : Colors.orange;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPrecise ? Icons.check_circle : Icons.hourglass_top, size: 14, color: c.shade700_(isPrecise)),
          const SizedBox(width: 6),
          Text(
            isPrecise ? t("precise") : t("estimated"),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.shade700_(isPrecise)),
          ),
        ],
      ),
    );
  }
}

extension on Color {
  // Small helper to get a darker, readable shade on a light background,
  // without depending on MaterialColor.shade700 (unavailable for plain
  // Colors.green / Colors.orange depending on the import context).
  Color shade700_(bool isPrecise) => isPrecise ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
}

// =============================================================================
// 1 · SimpleMeasurer
// =============================================================================

class _SimpleMeasurerDemo extends StatefulWidget {
  const _SimpleMeasurerDemo();

  @override
  State<_SimpleMeasurerDemo> createState() => _SimpleMeasurerDemoState();
}

class _SimpleMeasurerDemoState extends State<_SimpleMeasurerDemo> {
  double _fontSize = 18;
  int _messageIndex = 0;
  bool _keepPrevious = true;
  final SmartMeasurerController _controller = SmartMeasurerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> messages = [t("msg1"), t("msg2"), t("msg3"), t("msg4")];

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Center(
            child: SimpleMeasurer(
              controller: _controller,
              keepPreviousSizeOnChildChange: _keepPrevious,
              debugLabel: "MessageBubble",
              onDebugWarning: (m) => debugLog.add("SimpleMeasurer", m, Colors.orange),
              child: Padding(
                key: ValueKey(_messageIndex),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  messages[_messageIndex],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              builder: (context, size, isPrecise, constraints) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: size.width + 40,
                  height: size.height + 26,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPrecise
                          ? [Colors.indigo, Colors.indigo.shade300]
                          : [Colors.grey.shade400, Colors.grey.shade300],
                    ),
                    borderRadius: BorderRadius.circular((size.height + 26) / 2),
                    boxShadow: [
                      BoxShadow(color: Colors.indigo.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _PrecisionPill(isPrecise: _controller.isPrecise),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.format_size, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(value: _fontSize, min: 12, max: 34, onChanged: (v) => setState(() => _fontSize = v)),
            ),
            SizedBox(width: 32, child: Text("${_fontSize.round()}")),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < messages.length; i++)
              ChoiceChip(
                label: Text("${t("message_chip")} ${i + 1}"),
                selected: _messageIndex == i,
                onSelected: (_) => setState(() => _messageIndex = i),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(t("keep_previous_size_title")),
          subtitle: const Text("keepPreviousSizeOnChildChange"),
          value: _keepPrevious,
          onChanged: (v) => setState(() => _keepPrevious = v),
        ),
      ],
    );
  }
}

// =============================================================================
// 2 · SmartMeasurer + controller + placeholder
// =============================================================================

class _IconCircleDemo extends StatefulWidget {
  const _IconCircleDemo();

  @override
  State<_IconCircleDemo> createState() => _IconCircleDemoState();
}

class _IconCircleDemoState extends State<_IconCircleDemo> {
  static const List<IconData> _icons = [Icons.star, Icons.favorite, Icons.bolt, Icons.emoji_emotions];

  double _iconSize = 48;
  int _iconIndex = 0;
  bool _keepPrevious = true;
  final SmartMeasurerController _controller = SmartMeasurerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Center(
            child: SmartMeasurer(
              controller: _controller,
              unconstrained: true,
              keepPreviousSizeOnChildChange: _keepPrevious,
              animationDuration: const Duration(milliseconds: 280),
              animationCurve: Curves.easeOutBack,
              debugLabel: "IconCircle",
              onDebugWarning: (m) => debugLog.add("SmartMeasurer", m, Colors.orange),
              placeholderBuilder: (context, constraints) => Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.deepPurple.shade50, shape: BoxShape.circle),
                child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
              ),
              child: Icon(_icons[_iconIndex], key: ValueKey(_iconIndex), size: _iconSize, color: Colors.white),
              builder: (context, measuredChild, size, isPrecise, constraints) {
                final double d = math.max(size.width, size.height) + 42;
                return Container(
                  width: d,
                  height: d,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isPrecise
                          ? [Colors.deepPurple.shade400, Colors.deepPurple.shade700]
                          : [Colors.grey.shade400, Colors.grey.shade500],
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: measuredChild,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            children: [
              _PrecisionPill(isPrecise: _controller.isPrecise),
              const SizedBox(height: 6),
              Text(
                "${t("measured_size")}: ${_controller.size.width.toStringAsFixed(1)} × ${_controller.size.height.toStringAsFixed(1)}",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.zoom_out_map, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(value: _iconSize, min: 24, max: 88, onChanged: (v) => setState(() => _iconSize = v)),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            for (int i = 0; i < _icons.length; i++)
              GestureDetector(
                onTap: () => setState(() => _iconIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _iconIndex == i ? Colors.deepPurple.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _iconIndex == i ? Colors.deepPurple : Colors.transparent, width: 2),
                  ),
                  child: Icon(_icons[i], color: _iconIndex == i ? Colors.deepPurple : Colors.grey.shade600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(t("keep_previous_size_title")),
          subtitle: const Text("keepPreviousSizeOnChildChange"),
          value: _keepPrevious,
          onChanged: (v) => setState(() => _keepPrevious = v),
        ),
      ],
    );
  }
}

// =============================================================================
// 3 · Estimation strategies & debounce
// =============================================================================

class _EstimateStrategyDemo extends StatefulWidget {
  const _EstimateStrategyDemo();

  @override
  State<_EstimateStrategyDemo> createState() => _EstimateStrategyDemoState();
}

class _EstimateStrategyDemoState extends State<_EstimateStrategyDemo> {
  SmartMeasurerEstimateStrategy _strategy = SmartMeasurerEstimateStrategy.previousSize;
  double _wrapperWidth = 260;
  bool _useDebounce = true;
  bool _simulateInvalidEstimate = false;
  final SmartMeasurerController _controller = SmartMeasurerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Size _customEstimate(BoxConstraints constraints, Size? previousSize) {
    if (_simulateInvalidEstimate) {
      // Deliberately invalid (NaN) to observe the widget's automatic fallback.
      return const Size(double.nan, 34);
    }
    return const Size(92, 34);
  }

  @override
  Widget build(BuildContext context) {
    final Map<SmartMeasurerEstimateStrategy, String> labels = {
      SmartMeasurerEstimateStrategy.zero: t("strategy_zero"),
      SmartMeasurerEstimateStrategy.previousSize: t("strategy_previous"),
      SmartMeasurerEstimateStrategy.constraints: t("strategy_constraints"),
      SmartMeasurerEstimateStrategy.custom: t("strategy_custom"),
    };

    return Column(
      children: [
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _wrapperWidth,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SmartMeasurer(
              controller: _controller,
              estimateStrategy: _strategy,
              estimateBuilder: _strategy == SmartMeasurerEstimateStrategy.custom ? _customEstimate : null,
              notifyDebounce: _useDebounce ? const Duration(milliseconds: 900) : null,
              sizeChangeThreshold: 0.5,
              debugLabel: "StrategyDemo",
              onDebugWarning: (m) => debugLog.add(t("tag_strategies"), m, Colors.deepOrange),
              child: Container(
                key: const ValueKey("fixed-content"),
                width: 160,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.teal.shade600, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  t("fixed_content"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              builder: (context, measuredChild, size, isPrecise, constraints) {
                final double w = math.max(size.width, 44);
                final double h = math.max(size.height, 44);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: w,
                  height: h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isPrecise ? Colors.teal.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
                    border: Border.all(color: isPrecise ? Colors.teal : Colors.grey.shade500, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRect(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(opacity: isPrecise ? 1 : 0.25, child: measuredChild),
                        if (!isPrecise)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "≈ ${size.width.toStringAsFixed(0)}×${size.height.toStringAsFixed(0)}",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _PrecisionPill(isPrecise: _controller.isPrecise),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final entry in labels.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _strategy == entry.key,
                onSelected: (_) => setState(() => _strategy = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.swap_horiz, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(value: _wrapperWidth, min: 140, max: 380, onChanged: (v) => setState(() => _wrapperWidth = v)),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(t("debounce_title")),
          subtitle: Text(t("debounce_subtitle")),
          value: _useDebounce,
          onChanged: (v) => setState(() => _useDebounce = v),
        ),
        if (_strategy == SmartMeasurerEstimateStrategy.custom)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(t("simulate_invalid_title")),
            subtitle: Text(t("simulate_invalid_subtitle")),
            value: _simulateInvalidEstimate,
            onChanged: (v) => setState(() => _simulateInvalidEstimate = v),
          ),
      ],
    );
  }
}

// =============================================================================
// 4 · SmartMeasurerGroup — sliding tab indicator
// =============================================================================

class _SlidingTabsDemo extends StatefulWidget {
  const _SlidingTabsDemo();

  @override
  State<_SlidingTabsDemo> createState() => _SlidingTabsDemoState();
}

class _SlidingTabsDemoState extends State<_SlidingTabsDemo> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final List<String> tabs = [
      t("tab_home"),
      t("tab_explore"),
      t("tab_notifications"),
      t("tab_profile"),
    ];

    return Column(
      children: [
        SmartMeasurerGroup(
          debugLabel: "TabsIndicator",
          children: [
            for (int i = 0; i < tabs.length; i++) _TabLabel(text: tabs[i], selected: i == _selected),
          ],
          builder: (context, measuredChildren, sizes, allPrecise, constraints) {
            const double spacing = 4;
            double indicatorLeft = 0;
            for (int i = 0; i < _selected; i++) {
              indicatorLeft += sizes[i].width + spacing;
            }
            final double indicatorWidth = sizes[_selected].width;
            final double indicatorHeight = sizes[_selected].height;

            return Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
              // The total width of the labels (measured) is only known after
              // the first layout, and can exceed the available space on a
              // narrow screen (or with long labels). A Row with
              // mainAxisSize.min doesn't constrain itself to `constraints`
              // on its own: without this SingleChildScrollView, we get a
              // RenderFlex overflow as soon as the total exceeds the card's
              // width. It changes nothing visually when everything already fits.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Stack(
                  children: [
                    if (allPrecise)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        left: indicatorLeft,
                        top: 0,
                        child: Container(
                          width: indicatorWidth,
                          height: indicatorHeight,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < measuredChildren.length; i++)
                          Padding(
                            padding: EdgeInsets.only(right: i == measuredChildren.length - 1 ? 0 : spacing),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _selected = i),
                              child: measuredChildren[i],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text("${t("selected_label")}: ${tabs[_selected]}", style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.text, required this.selected});
  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        color: selected ? Colors.white : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        fontSize: 14,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(text),
      ),
    );
  }
}

// =============================================================================
// 5 · MeasuredDecoration — delay-free bubble
// =============================================================================

class _GlowDecorationDemo extends StatefulWidget {
  const _GlowDecorationDemo();

  @override
  State<_GlowDecorationDemo> createState() => _GlowDecorationDemoState();
}

class _GlowDecorationDemoState extends State<_GlowDecorationDemo> {
  double _fontSize = 20;
  double _radius = 18;
  bool _paintBehind = true;
  String _textKey = "text_no_delay";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Center(
            child: MeasuredDecoration(
              paintBehindChild: _paintBehind,
              onSizeChanged: (size) => debugLog.add(
                "MeasuredDecoration",
                "${t("new_size_prefix")}: ${size.width.toStringAsFixed(1)} × ${size.height.toStringAsFixed(1)}",
                Colors.teal,
              ),
              painter: (canvas, size, constraints) {
                final Rect rect = Rect.fromLTWH(-18, -14, size.width + 36, size.height + 28);
                final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(_radius));

                if (_paintBehind) {
                  final Paint glow = Paint()
                    ..color = Colors.deepOrange.withValues(alpha: 0.45)
                    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
                  canvas.drawRRect(rrect, glow);

                  final Paint fill = Paint()
                    ..shader = LinearGradient(colors: [Colors.deepOrange.shade400, Colors.orange.shade300])
                        .createShader(rect);
                  canvas.drawRRect(rrect, fill);
                } else {
                  final Paint stroke = Paint()
                    ..color = Colors.deepOrange
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2.5;
                  canvas.drawRRect(rrect, stroke);

                  final Paint dot = Paint()..color = Colors.deepOrange;
                  canvas.drawCircle(Offset(rect.right - 10, rect.top + 10), 4, dot);
                }
              },
              child: Text(
                t(_textKey),
                style: TextStyle(
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w700,
                  color: _paintBehind ? Colors.white : Colors.deepOrange.shade700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.format_size, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(value: _fontSize, min: 14, max: 32, onChanged: (v) => setState(() => _fontSize = v)),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.rounded_corner, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(value: _radius, min: 0, max: 40, onChanged: (v) => setState(() => _radius = v)),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in ["text_no_delay", "text_instant_paint", "text_glow"])
              ChoiceChip(label: Text(t(key)), selected: _textKey == key, onSelected: (_) => setState(() => _textKey = key)),
          ],
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(t("paint_behind_title")),
          subtitle: Text(t("paint_behind_subtitle")),
          value: _paintBehind,
          onChanged: (v) => setState(() => _paintBehind = v),
        ),
      ],
    );
  }
}

// =============================================================================
// 6 · Debug tools
// =============================================================================

class _DebugToolsDemo extends StatefulWidget {
  const _DebugToolsDemo();

  @override
  State<_DebugToolsDemo> createState() => _DebugToolsDemoState();
}

class _DebugToolsDemoState extends State<_DebugToolsDemo> {
  double _panelWidth = 220;
  bool _ignoreDuringEstimate = true;
  bool _debugPaint = true;
  int _tapCount = 0;
  final SmartMeasurerController _controller = SmartMeasurerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: SizedBox(
            width: _panelWidth,
            child: SmartMeasurer(
              controller: _controller,
              ignorePointerDuringEstimate: _ignoreDuringEstimate,
              debugPaintEstimatedSize: _debugPaint,
              estimateStrategy: SmartMeasurerEstimateStrategy.previousSize,
              notifyDebounce: const Duration(milliseconds: 700),
              debugLabel: "DebugToolsButton",
              onDebugWarning: (m) => debugLog.add(t("tag_debug_tools"), m, Colors.deepOrange),
              child: Container(
                key: const ValueKey("tap-target"),
                height: 52,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(t("touch_me"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              builder: (context, measuredChild, size, isPrecise, constraints) {
                return GestureDetector(
                  onTap: () => setState(() => _tapCount++),
                  child: Container(
                    width: size.width,
                    height: math.max(size.height, 40),
                    decoration: BoxDecoration(
                      color: isPrecise ? Colors.blue.shade600 : Colors.blueGrey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: measuredChild,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _PrecisionPill(isPrecise: _controller.isPrecise),
        ),
        const SizedBox(height: 8),
        Text("${t("taps_recorded")}: $_tapCount", style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _panelWidth = _panelWidth == 220 ? 260 : 220),
          icon: const Icon(Icons.swap_horiz),
          label: Text(t("resize_button")),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(t("ignore_taps_title")),
          subtitle: const Text("ignorePointerDuringEstimate"),
          value: _ignoreDuringEstimate,
          onChanged: (v) => setState(() => _ignoreDuringEstimate = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(t("debug_border_title")),
          subtitle: const Text("debugPaintEstimatedSize"),
          value: _debugPaint,
          onChanged: (v) => setState(() => _debugPaint = v),
        ),
      ],
    );
  }
}

// =============================================================================
// 7 · Overflow safety
// =============================================================================

class _OverflowSafeDemo extends StatefulWidget {
  const _OverflowSafeDemo();

  @override
  State<_OverflowSafeDemo> createState() => _OverflowSafeDemoState();
}

class _OverflowSafeDemoState extends State<_OverflowSafeDemo> {
  int _itemCount = 8;
  bool _scrollable = true;
  bool _constrain = true;
  bool _shrinkToFit = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
          child: SmartMeasurer(
            scrollable: _scrollable,
            scrollDirection: Axis.horizontal,
            constrainToAvailableSpace: _constrain,
            shrinkToFit: _shrinkToFit,
            debugLabel: "OverflowSafeRow",
            onDebugWarning: (m) => debugLog.add(t("tag_overflow_safe"), m, Colors.deepOrange),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _itemCount; i++)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.pink.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.pink.shade200),
                    ),
                    child: Text("${t("item_label")} ${i + 1}"),
                  ),
              ],
            ),
            builder: (context, measuredChild, size, isPrecise, constraints) => measuredChild,
          ),
        ),
        const SizedBox(height: 12),
        if (!_scrollable && !_constrain)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Text(t("warn_no_scroll_no_constrain"), style: const TextStyle(fontSize: 12)),
          ),
        if (!_scrollable && _constrain)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Text(
              _shrinkToFit ? t("info_shrink_true") : t("info_shrink_false"),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.view_column, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: _itemCount.toDouble(),
                min: 2,
                max: 16,
                divisions: 14,
                label: "$_itemCount",
                onChanged: (v) => setState(() => _itemCount = v.round()),
              ),
            ),
            SizedBox(width: 24, child: Text("$_itemCount")),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(t("scrollable_title")),
          value: _scrollable,
          onChanged: (v) => setState(() => _scrollable = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(t("constrain_title")),
          subtitle: Text(t("constrain_subtitle")),
          value: _constrain,
          onChanged: (v) => setState(() => _constrain = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(t("shrink_to_fit_title")),
          subtitle: Text(t("shrink_to_fit_subtitle")),
          value: _shrinkToFit,
          onChanged: _scrollable ? null : (v) => setState(() => _shrinkToFit = v),
        ),
      ],
    );
  }
}

// =============================================================================
// 8 · Real case: notification badge
// =============================================================================

class _NotificationBadgeDemo extends StatefulWidget {
  const _NotificationBadgeDemo();

  @override
  State<_NotificationBadgeDemo> createState() => _NotificationBadgeDemoState();
}

class _NotificationBadgeDemoState extends State<_NotificationBadgeDemo> {
  int _count = 3;

  void _set(int value) {
    setState(() {
      _count = value < 0 ? 0 : (value > 999 ? 999 : value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 100,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: Colors.blueGrey.shade100, shape: BoxShape.circle),
                  child: Icon(Icons.notifications, size: 30, color: Colors.blueGrey.shade700),
                ),
                if (_count > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: SmartMeasurer(
                      unconstrained: true,
                      animationDuration: const Duration(milliseconds: 240),
                      animationCurve: Curves.easeOutBack,
                      debugLabel: "NotifBadge",
                      onDebugWarning: (m) => debugLog.add("Badge", m, Colors.orange),
                      child: Padding(
                        key: ValueKey(_count),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          _count > 99 ? "99+" : "$_count",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      builder: (context, measuredChild, size, isPrecise, constraints) {
                        final double w = math.max(size.width + 14, 22);
                        final double h = math.max(size.height + 8, 22);
                        return Container(
                          width: w,
                          height: h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(h / 2),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: measuredChild,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton(onPressed: () => _set(_count - 1), child: const Text("-1")),
            OutlinedButton(onPressed: () => _set(_count + 1), child: const Text("+1")),
            OutlinedButton(onPressed: () => _set(_count + 25), child: const Text("+25")),
            OutlinedButton(onPressed: () => _set(_count + 200), child: const Text("+200")),
            OutlinedButton(onPressed: () => _set(0), child: Text(t("clear_button"))),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Debug console (UI)
// =============================================================================

class _DebugConsole extends StatefulWidget {
  const _DebugConsole();

  @override
  State<_DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<_DebugConsole> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([debugLog, appLocale]),
      builder: (context, _) {
        final entries = debugLog.entries;
        final onSurface = Theme.of(context).colorScheme.onSurface;
        return Material(
          elevation: 8,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.terminal, size: 18),
                        const SizedBox(width: 8),
                        Text(t("debug_console"), style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(width: 8),
                        if (entries.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              "${entries.length}",
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const Spacer(),
                        if (entries.isNotEmpty)
                          IconButton(
                            iconSize: 18,
                            tooltip: t("copy_all"),
                            icon: const Icon(Icons.copy_all_outlined),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: debugLog.toPlainText()));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(t("console_copied")), duration: const Duration(seconds: 1)),
                                );
                              }
                            },
                          ),
                        if (entries.isNotEmpty)
                          IconButton(
                            iconSize: 18,
                            tooltip: t("clear_console"),
                            icon: const Icon(Icons.clear_all),
                            onPressed: debugLog.clear,
                          ),
                        Icon(_expanded ? Icons.expand_more : Icons.expand_less),
                      ],
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _expanded ? 180 : 0,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: entries.isEmpty
                      ? Center(
                    child: Text(
                      t("no_events_yet"),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        // SelectableText.rich (rather than RichText) to allow
                        // touch/mouse selection and line-by-line copying, in
                        // addition to the "copy all" button above.
                        child: SelectableText.rich(
                          TextSpan(
                            style: TextStyle(fontFamily: "monospace", fontSize: 12, color: onSurface),
                            children: [
                              TextSpan(
                                text: "[${_fmtTime(e.time)}] ",
                                style: TextStyle(color: onSurface.withValues(alpha: 0.5)),
                              ),
                              TextSpan(text: "${e.tag}: ", style: TextStyle(color: e.color, fontWeight: FontWeight.bold)),
                              TextSpan(text: e.message),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}