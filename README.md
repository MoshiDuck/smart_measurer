# smart_measurer

Mesurez la taille réelle d'un widget Flutter et réagissez-y, sans le flash
visible typique d'un `GlobalKey` associé à `addPostFrameCallback` écrit à la
main.

Le package expose quatre widgets, du plus simple au plus complet.

| Widget | Usage | Délai d'une frame |
| --- | --- | --- |
| `MeasuredDecoration` | Dessiner un décor (fond, bordure) dépendant de la taille, sans reconstruire de widgets | Non |
| `SimpleMeasurer` | Un décor qui s'adapte à la taille d'un enfant, celui-ci étant superposé automatiquement | Oui |
| `SmartMeasurer` | Contrôle complet : vous insérez vous-même `measuredChild` où vous le souhaitez | Oui |
| `SmartMeasurerGroup` | Mesurer plusieurs enfants à la fois, par exemple pour aligner des largeurs | Oui |

## Installation

```yaml
dependencies:
  smart_measurer: ^1.0.4
```

```dart
import 'package:smart_measurer/smart_measurer.dart';
```

## Le délai d'une frame (une limitation incontournable)

Flutter exécute toujours la construction avant la mise en page au sein d'une
même frame. Pour que `builder` retourne un `Widget` qui dépende de la taille
de l'enfant, cette taille doit avoir été mesurée lors d'une frame
précédente. C'est une contrainte du pipeline de Flutter, et non une limite
propre à ce package : tout mécanisme qui retourne un `Widget` arbitraire en
fonction d'une taille mesurée subit le même délai.

Si vous avez seulement besoin de dessiner, et non de construire de nouveaux
widgets, en fonction de la taille, utilisez plutôt `MeasuredDecoration`, qui
n'a aucun délai.

## SmartMeasurer

C'est le widget le plus complet. `measuredChild` doit être inséré
**exactement une fois** dans l'arbre retourné par `builder`.

```dart
Widget buildSmartMeasurerExample() {
  return SmartMeasurer(
    child: const Text('Hello World'),
    builder: (context, measuredChild, size, isPrecise, constraints) {
      return Container(
        width: size.width + 24,
        height: size.height + 24,
        decoration: BoxDecoration(
          color: isPrecise ? Colors.blue.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: measuredChild,
      );
    },
  );
}
```

### Estimation

Entre un changement de contraintes et la prochaine mesure précise, la taille
est **estimée** (`isPrecise` vaut `false`). Cela garantit qu'aucune taille
périmée n'est jamais présentée comme précise.

- Si `estimateBuilder` est fourni, il est utilisé pour l'estimation. S'il
  lève une exception ou retourne une `Size` invalide (NaN, infinie ou
  négative), l'erreur est capturée, avec un avertissement en mode debug, et
  l'estimation par défaut prend le relais.
- Sinon, l'estimation suit `estimateStrategy` :
    - `zero` : toujours `Size.zero` tant qu'aucune mesure précise n'est
      arrivée ;
    - `previousSize` (comportement par défaut) : réutilise la dernière taille
      précise si elle satisfait toujours les contraintes actuelles, sinon
      `Size.zero` ;
    - `constraints` : utilise les contraintes maximales bornées, avec 0 sur
      tout axe non borné ;
    - `custom` : signale que `estimateBuilder` est censé toujours fournir une
      estimation valide ; à défaut, `Size.zero` est utilisé, avec un
      avertissement.

`useConstraintsAsInitialEstimate` est conservé pour la compatibilité
ascendante, mais il est ignoré dès que `estimateStrategy` est défini.

### Coût de performance

Chaque mesure précise déclenche un `setState` interne, qui reconstruit tout
ce que retourne `builder`. Si `builder` construit un sous-arbre coûteux mais
par ailleurs statique, enveloppez-le dans un `RepaintBoundary`, ou extrayez-le
dans un widget `const` séparé. `sizeChangeThreshold` et `notifyDebounce`
permettent aussi de réduire la fréquence des reconstructions lors de mises en
page bruyantes ou qui changent rapidement.

### Paramètres principaux

| Paramètre | Rôle |
| --- | --- |
| `estimateBuilder` | Fournit une estimation personnalisée, prioritaire sur `estimateStrategy` |
| `keepPreviousSizeOnChildChange` | Réutilise la dernière taille précise comme estimation quand `child` change (`true` par défaut) |
| `sizeChangeThreshold` | Delta minimal, en pixels logiques, requis pour déclencher une reconstruction |
| `onSizeChanged` | Appelé à chaque mesure précise commise, indépendamment de `builder` |
| `notifyDebounce` | Regroupe les mesures rapprochées en une seule notification |
| `animationDuration` / `animationCurve` | Anime la transition entre deux tailles précises |
| `controller` | `SmartMeasurerController` externe pour lire la taille hors de `builder` |
| `unconstrained` | Enveloppe `measuredChild` dans un `UnconstrainedBox` |
| `ignorePointerDuringEstimate` | Désactive les interactions tant que `isPrecise` vaut `false` |
| `placeholderBuilder` | Affiché tant qu'aucune mesure précise n'a jamais été obtenue |
| `debugPaintEstimatedSize` | Bordure rouge ou verte de debug, selon que la mesure est estimée ou précise |
| `constrainToAvailableSpace` | Empêche le résultat de dépasser visuellement l'espace du parent (clip ou, si `shrinkToFit` est vrai, mise à l'échelle) |
| `shrinkToFit`               | Quand `constrainToAvailableSpace` est actif, réduit le contenu pour qu'il tienne dans l'espace disponible au lieu de le découper |
| `scrollable` / `scrollDirection` | Enveloppe le résultat dans un `SingleChildScrollView` |
| `debugLabel` | Étiquette de la `GlobalKey` interne, utile en debug avec plusieurs `SmartMeasurer` imbriqués |

## SimpleMeasurer

Version simplifiée : l'enfant est automatiquement superposé sur le décor
retourné par `builder`. Vous n'écrivez que le décor.

```dart
Widget buildSimpleMeasurerExample() {
  return SimpleMeasurer(
    child: const Text('Hello'),
    builder: (context, size, isPrecise, constraints) {
      return Container(
        width: size.width + 16,
        height: size.height + 16,
        color: Colors.amber.shade100,
      );
    },
  );
}
```

L'enfant est toujours mesuré à sa taille naturelle : il n'est jamais
contraint par la taille du décor retourné, même quand ce décor est lui-même
dérivé de la taille mesurée, grâce à un `UnconstrainedBox` interne.

`SimpleMeasurer` transmet la plupart des options facultatives de
`SmartMeasurer` (`sizeChangeThreshold`, `notifyDebounce`, `animationDuration`,
`controller`, `placeholderBuilder`, `debugPaintEstimatedSize`,
`scrollable`/`constrainToAvailableSpace`, etc.) — voir le tableau ci-dessus.

## SmartMeasurerGroup

Ce widget mesure plusieurs widgets à la fois et renvoie leurs tailles sous
forme de liste, dans le même ordre que `children`. Il est plus léger que
`SmartMeasurer` : pas de stratégie d'estimation, pas d'animation, pas de
seuil, juste la mesure de N widgets et le rapport de leur taille.

```dart
Widget buildSmartMeasurerGroupExample() {
  return SmartMeasurerGroup(
    children: const [
      Text('Court'),
      Text('Un peu plus long'),
      Text('Moyen'),
    ],
    builder: (context, measuredChildren, sizes, allPrecise, constraints) {
      final double maxWidth = sizes.isEmpty
          ? 0.0
          : sizes.map((s) => s.width).reduce((a, b) => a > b ? a : b);
      return Wrap(
        spacing: 8,
        children: [
          for (final child in measuredChildren)
            Container(
              width: allPrecise ? maxWidth + 24 : null,
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              alignment: Alignment.center,
              child: child,
            ),
        ],
      );
    },
  );
}
```

`measuredChildren` correspond un à un à `children`, et chaque élément doit
être inséré exactement une fois. `sizes` utilise `Size.zero` pour toute
entrée pas encore mesurée. `allPrecise` n'est vrai qu'une fois que chaque
enfant a rapporté une mesure réelle pour la passe de mise en page en cours.

## MeasuredDecoration

Ce widget n'a aucun délai d'une frame : `painter` ne construit pas de
`Widget`, il dessine directement sur un `Canvas` pendant la phase de peinture,
une fois que la taille de l'enfant est déjà connue dans la même passe de mise
en page.

```dart
Widget buildMeasuredDecorationExample() {
  return MeasuredDecoration(
    painter: (canvas, size, constraints) {
      final paint = Paint()..color = Colors.deepPurple.shade100;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-12, -12, size.width + 24, size.height + 24),
          const Radius.circular(12),
        ),
        paint,
      );
    },
    child: const Text('Sans délai'),
  );
}
```

En contrepartie, `painter` ne peut pas produire de nouveaux widgets
interactifs, comme des boutons ou du texte sélectionnable : il ne peut que
dessiner (formes, dégradés, ombres...). Pour un sous-arbre de widgets réactif
à la taille, utilisez plutôt `SmartMeasurer`. `onSizeChanged` permet de
réagir aux changements de taille sans provoquer de reconstruction.

## SmartMeasurerController

Il s'agit d'un handle externe vers la taille courante d'un `SmartMeasurer`,
pour du code qui doit lire la taille mesurée en dehors de `builder`, par
exemple pour piloter un widget frère, un décalage de défilement, ou un
gestionnaire d'état.

```dart
class ControllerExample extends StatefulWidget {
  const ControllerExample({super.key});

  @override
  State<ControllerExample> createState() => _ControllerExampleState();
}

class _ControllerExampleState extends State<ControllerExample> {
  final SmartMeasurerController controller = SmartMeasurerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SmartMeasurer(
          controller: controller,
          child: const Icon(Icons.star, size: 48),
          builder: (context, measuredChild, size, isPrecise, constraints) {
            return measuredChild;
          },
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Text('${controller.size}'),
        ),
      ],
    );
  }
}
```

Pensez à appeler `controller.dispose()` vous-même : `SmartMeasurer` se
contente de le lire, il ne le possède jamais et ne le libère donc jamais à
votre place.

## Tests

Les notifications de mesure sont livrées via
`SchedulerBinding.addPostFrameCallback`. Dans les tests de widgets, la
séquence est donc la suivante :

1. `pumpWidget()` exécute la première frame : une taille *estimée* est
   construite, puis la mise en page se déroule et programme le
   post-frame callback.
2. Un premier `pump()` supplémentaire exécute la deuxième frame : le
   post-frame callback se déclenche et commet la mesure précise via
   `setState`.
3. Un second `pump()` supplémentaire, quand il apparaît, laisse un effet
   post-frame additionnel, comme `SmartMeasurerController.notifyListeners`,
   se stabiliser.

```dart
void main() {
  testWidgets('SmartMeasurer starts estimated and becomes precise',
      (tester) async {
    bool? lastIsPrecise;

    await tester.pumpWidget(
      MaterialApp(
        home: SmartMeasurer(
          child: const SizedBox(width: 120, height: 40),
          builder: (context, measuredChild, size, isPrecise, constraints) {
            lastIsPrecise = isPrecise;
            return measuredChild;
          },
        ),
      ),
    );

    // Première frame : aucune mesure n'est encore arrivée.
    expect(lastIsPrecise, isFalse);

    await tester.pump();

    expect(lastIsPrecise, isTrue);
  });
}
```

## Dépannage : « isn't defined » pour `SmartMeasurerGroup` ou `SmartMeasurerController`

Si votre projet ne trouve pas ces symboles après un `flutter pub get`
classique, vérifiez ceci, dans l'ordre :

1. Le fichier `lib/smart_measurer.dart` doit contenir tout le code du
   package, et non une version tronquée. Si c'est un fichier « barrel » qui
   se contente de ré-exporter un fichier `src/`, vérifiez que l'`export` ne
   restreint pas la liste avec un `show` incomplet : les quatre classes
   publiques (`SmartMeasurer`, `SimpleMeasurer`, `SmartMeasurerGroup`,
   `MeasuredDecoration`), ainsi que `SmartMeasurerController`, doivent toutes
   y figurer.
2. Le champ `name:` de `pubspec.yaml` doit valoir `smart_measurer`, afin que
   `import 'package:smart_measurer/smart_measurer.dart'` pointe bien vers le
   bon package.
3. Si le projet contient un dossier `example/`, sachez qu'il s'agit d'un
   package Flutter à part entière, avec son propre cache. Lancez
   `flutter clean && flutter pub get` aussi bien à la racine que depuis
   `example/`.
4. Redémarrez l'Analysis Server de votre IDE : il arrive qu'il conserve en
   cache un ancien arbre de symboles, même après un `pub get` réussi.