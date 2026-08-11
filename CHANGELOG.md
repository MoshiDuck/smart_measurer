# Changelog

## 0.1.0

- Version initiale.
- `SmartMeasurer` : mesure de widget avec accès manuel à `measuredChild`,
  suivi de génération pour invalider proprement l'estimation lors d'un
  changement de contraintes externes.
- `SimpleMeasurer` : variante simplifiée avec enfant auto-superposé.
- `MeasuredDecoration` : dessin dépendant de la taille de l'enfant en une
  seule passe de layout/paint, sans délai d'une frame.
