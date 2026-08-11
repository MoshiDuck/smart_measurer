# smart_measurer

Mesurez la taille réelle d'un widget Flutter et réagissez-y — avec
estimation propre pendant le court délai de mesure, et une variante **sans
délai** pour les cas où vous avez seulement besoin de dessiner.

## Pourquoi ce package

Flutter exécute toujours *build* avant *layout* au sein d'une frame. Il est
donc structurellement impossible de connaître la taille d'un widget au
moment où on le construit pour la première fois — toute solution qui
retourne un nouveau `Widget` basé sur une taille mesurée a nécessairement un
délai d'une frame. `smart_measurer` ne cache pas cette contrainte : il vous
donne un flag `isPrecise` explicite pour savoir, à chaque frame, si la
taille affichée est mesurée ou estimée.

Pour les cas où vous n'avez besoin que de *dessiner* un décor dépendant de
la taille (pas de construire de nouveaux widgets), `MeasuredDecoration`
évite complètement ce délai en restant dans la couche `RenderObject`.

## Les trois widgets

| Widget | Délai | Usage |
|---|---|---|
| `SmartMeasurer` | 1 frame | Contrôle complet, accès à `measuredChild` |
| `SimpleMeasurer` | 1 frame | Variante simplifiée (enfant auto-superposé) |
| `MeasuredDecoration` | Aucun | Dessin pur (`Canvas`) dépendant de la taille |

## Installation

```yaml
dependencies:
  smart_measurer: ^0.1.0
```

## Utilisation

### SimpleMeasurer — décor qui s'adapte à la taille d'un texte

```dart
import 'package:smart_measurer/smart_measurer.dart';

SimpleMeasurer(
  child: const Text('Bonjour le monde'),
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

`isPrecise` vaut `false` pendant la (courte) fenêtre où la taille affichée
est une estimation — par exemple juste après un changement de contraintes
externes, avant que la mesure suivante n'arrive. Utilisez ce flag pour, par
exemple, ne pas animer une transition tant que la taille n'est pas certaine.

### SmartMeasurer — contrôle complet

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
        Center(child: measuredChild), // measuredChild inséré une seule fois
      ],
    );
  },
)
```

⚠️ `measuredChild` doit apparaître **exactement une fois** dans l'arbre
retourné par `builder`. Une insertion multiple lève une erreur Flutter de
clé dupliquée (comportement voulu : signal immédiat plutôt qu'un bug
silencieux).

### MeasuredDecoration — dessin sans délai

Quand vous n'avez besoin que de peindre un fond/halo/bordure dépendant de la
taille (pas de construire un widget), évitez le délai d'une frame :

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
  child: const Text('Sans délai, jamais de flicker'),
)
```

## Estimation personnalisée

Par défaut, l'estimation pendant le délai de mesure réutilise la dernière
taille précise connue (si compatible avec les nouvelles contraintes), sinon
retombe sur `Size.zero`. Personnalisez ce comportement avec
`estimateBuilder` :

```dart
SimpleMeasurer(
  estimateBuilder: (constraints, previousSize) {
    // Ex: estimation basée sur le nombre de caractères d'un texte connu,
    // une largeur moyenne de police, etc.
    return previousSize ?? const Size(100, 40);
  },
  child: const Text('...'),
  builder: (context, size, isPrecise, constraints) => /* ... */ Container(),
)
```

## Voir aussi

Consultez le dossier [`example/`](example) pour une démo complète des trois
widgets.

## Limitations connues

- `SmartMeasurer` / `SimpleMeasurer` ont un délai d'une frame après tout
  changement de contraintes externes ou de `child` — c'est une contrainte du
  pipeline Flutter, pas un bug (voir section "Pourquoi ce package").
- `MeasuredDecoration` ne peut que dessiner (`Canvas`), pas insérer de
  nouveaux widgets interactifs.

## Contribuer

Les issues et pull requests sont bienvenues sur le dépôt GitHub du projet.
