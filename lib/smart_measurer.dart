/// Mesurez la taille réelle d'un widget et réagissez-y — avec estimation
/// pendant le délai de mesure, et une variante sans délai pour le dessin pur.
///
/// Trois widgets sont exposés :
/// - [SmartMeasurer] : contrôle complet, `builder` reçoit le widget mesuré
///   à insérer manuellement.
/// - [SimpleMeasurer] : variante simplifiée, l'enfant est automatiquement
///   superposé dans un [Stack].
/// - [MeasuredDecoration] : dessine un décor dépendant de la taille de
///   l'enfant en une seule passe de layout/paint, sans délai d'une frame.

export 'src/smart_measurer_base.dart'
    show SmartMeasurer, SimpleMeasurer, MeasuredDecoration;
