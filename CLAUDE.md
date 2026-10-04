# ShuttleScore

App Apple Watch (watchOS 26 minimum, autonome) de suivi de score de badminton en 3×15,
en simple et en double. Le périmètre, les règles métier et le découpage des
features sont dans `SPEC.md` : c'est la référence, ne la recopie pas ici.

## Commandes

- `make verify` : lint swift-format + build + tests de `ShuttleCore`, en ~10 s. Doit passer avant de finir une tâche.
- `make format` : reformate le code en place.
- `make project` : régénère `ShuttleScore.xcodeproj` depuis `project.yml`.
- `make app` : build complet de l'app sur simulateur watchOS. Lent, tourne en CI.
- `make ui-test` : tests de bout en bout XCUITest sur simulateur Apple Watch Ultra (~1 min). Lent, tourne en CI.
  Les éléments testés sont repérés par `accessibilityIdentifier` (`match.half.me`, `match.undo`, …).

## Où vit quoi

- `ShuttleCore/` : Swift Package pur, sans SwiftUI, SwiftData ni HealthKit.
  **Toutes les règles métier vivent ici** (score, sets, service, cases, annulation)
  et sont testées avec Swift Testing (`import Testing`).
- `ShuttleScore/` : app watchOS en SwiftUI. Une UI fine qui appelle `ShuttleCore`.
  La persistance (SwiftData) et la séance HealthKit vivent aussi ici.
- `ShuttleScoreUITests/` : tests de bout en bout du parcours principal.
- `project.yml` : source de vérité du projet Xcode (XcodeGen).

## Pièges

- **Ne modifie jamais `.xcodeproj` à la main** : il est généré et gitignoré.
  Les réglages (capabilities, entitlements, clés Info.plist) vont dans
  `project.yml`. Les fichiers ajoutés dans `ShuttleScore/` sont pris en compte
  automatiquement après `make project`.
- **Le score est calculé à partir du journal** des échanges, par une fonction pure.
  Ne stocke pas un score mutable à côté : l'annulation et les stats en
  dépendent.
- **Le service en double** est la règle la plus piégeuse. Les exemples chiffrés
  de `SPEC.md` doivent tous exister comme tests.
- Kévin relit peu le Swift : les tests de `ShuttleCore` sont le filet principal.
  Explique les choix propres à SwiftUI, SwiftData ou HealthKit dans le résumé
  de fin de tâche.
- Kévin a un compte développeur gratuit : l'app installée sur la montre expire
  au bout de 7 jours. Évite les capabilities qui exigent un compte payant
  (iCloud, push).
- Le format doit rester paramétré par `ScoringRules` : n'écris jamais 15, 21 ou 8
  en dur dans le moteur.
- Quand la vraie montre de Kévin est connectée à Xcode, `xcodebuild test` peut ne
  jamais rendre la main une fois les tests finis : surveille la ligne
  `Test Suite 'All tests' passed|failed` dans la sortie plutôt que d'attendre la fin.
- Les boutons secondaires (annuler, nouveau) font au moins 44 pt de haut : en match,
  un tap raté tombe dans une moitié de score et ajoute un point.
- Les clés Info.plist de type tableau (`WKBackgroundModes`) ne passent pas par
  `INFOPLIST_KEY_*` : elles vont dans `info.properties` de `project.yml`. `make app`
  vérifie que le mode `workout-processing` est bien présent.
- Les tests UI lancent l'app avec `-UITests` : la séance HealthKit est alors
  remplacée par une séance factice, sinon la demande d'accès bloquerait l'écran.
  La vraie séance ne se vérifie que sur la montre.
- La logique de la séance (quand démarrer, mettre en pause, terminer) vit dans
  `ShuttleCore/WorkoutTracker.swift`, derrière le protocole `WorkoutSession` ;
  seul `HealthKitWorkoutSession` importe HealthKit.
