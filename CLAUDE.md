# ShuttleScore

App Apple Watch (watchOS 27, autonome) de suivi de score de badminton en 3×15,
en simple et en double. Le périmètre, les règles métier et le découpage des
features sont dans `SPEC.md` : c'est la référence, ne la recopie pas ici.

## Commandes

- `make verify` : lint swift-format + build + tests de `ShuttleCore`, en ~10 s. Doit passer avant de finir une tâche.
- `make format` : reformate le code en place.
- `make project` : régénère `ShuttleScore.xcodeproj` depuis `project.yml`.
- `make app` : build complet de l'app sur simulateur watchOS. Lent, tourne en CI.

## Où vit quoi

- `ShuttleCore/` : Swift Package pur, sans SwiftUI, SwiftData ni HealthKit.
  **Toutes les règles métier vivent ici** (score, sets, service, cases, annulation)
  et sont testées avec Swift Testing (`import Testing`).
- `ShuttleScore/` : app watchOS en SwiftUI. Une UI fine qui appelle `ShuttleCore`.
  La persistance (SwiftData) et la séance HealthKit vivent aussi ici.
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
