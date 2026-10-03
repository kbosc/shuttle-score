# ShuttleScore

Score de badminton (3×15, simple et double) sur Apple Watch : saisie d'un tap,
serveur et case affichés, matchs sauvegardés point par point pour de futures stats.

Prérequis : Xcode 27, `brew install xcodegen`.

```sh
make verify    # lint + build + tests du domaine
make project   # génère le projet Xcode, puis ouvre ShuttleScore.xcodeproj
```

Spec : [SPEC.md](SPEC.md).
