# ShuttleScore

## Problème

Pendant un match de badminton, on perd le fil du score, et surtout de qui sert et
depuis quelle case, et rien ne garde de trace des matchs pour en tirer des stats.

## Usage

Kévin joue en club, en simple ou en double, presque toujours avec les mêmes
personnes. Il porte une Apple Watch Ultra 2 au poignet de la main libre. Avant le
match, il choisit dans une liste les joueurs et celui qui sert en premier. Entre
deux échanges, en sueur et la raquette dans l'autre main, il tape une moitié de
l'écran pour donner le point à son camp ou au camp adverse. La montre affiche le
score, qui sert et depuis quelle case. Si un point est mal saisi, il l'annule d'un
geste. À la fin, le match est sauvegardé point par point sur la montre.

## MVP

Chaque comportement est vérifiable (test unitaire dans `ShuttleCore`, ou
manipulation sur le simulateur ou la montre).

1. **Démarrer un match** en simple (Moi contre 1 adversaire) ou en double (Moi +
   partenaire contre 2 adversaires), en choisissant qui sert en premier et, en
   double, qui reçoit en premier.
2. **Saisir un point** en tapant la moitié basse de l'écran (mon camp) ou la
   moitié haute (le camp adverse). Chaque moitié couvre la moitié de l'écran.
3. **Afficher** le score du set en cours, les sets gagnés de chaque camp, le joueur
   qui sert et sa case (droite ou gauche).
4. **Annuler** le dernier point, sans limite jusqu'au début du match, y compris
   au-delà d'une fin de set.
5. **Appliquer les règles 3×15** (voir Règles métier) : fin de set, fin de match.
   Une fois le match terminé, plus aucun point n'est accepté (seule l'annulation
   reste possible).
6. **Signaler** par un retour haptique et un message la pause à 8 points, ainsi
   que le changement de côté à 8 points au 3e set.
7. **Séance HealthKit « Badminton »** pendant tout le match : elle démarre avec le
   match et s'arrête à sa fin. L'app reste ainsi au premier plan. Si l'accès à
   HealthKit est refusé, le match se joue quand même, sans séance.
8. **Sauvegarder** chaque match sur la montre (SwiftData) : joueurs, règles,
   journal de chaque échange (gagnant, serveur, horodatage) et statut (`terminé`
   ou `interrompu`).
9. **Reprendre** un match en cours après un crash ou la fermeture de l'app : il
   est persisté à chaque point et proposé à la reprise au relancement.
10. **Arrêter** un match avant la fin : il est sauvegardé avec le statut
    `interrompu`.
11. **Liste de joueurs** : créer, renommer et supprimer des joueurs sur la montre
    (dictée, scribble ou clavier). Le joueur « Moi » existe toujours et ne se
    supprime pas.
12. **Historique** : la liste des matchs passés (date, joueurs, score par set,
    statut).

## Hors périmètre

- Stats et moyennes (pourcentage au service, séries, bilan par adversaire). Le
  journal point par point est conçu pour les calculer plus tard.
- App iPhone compagnon, synchro iCloud, export.
- Formats autres que le 3×15 dans l'UI (3×21, 5×11, formats libres). Le moteur
  les accepte déjà en paramètre, mais aucun écran ne permet de les choisir.
- Saisie par le bouton Action de l'Ultra, complications, Smart Stack.
- Matchs où Kévin ne joue pas (« Moi » est toujours dans un camp).
- Fautes, lets, cartons et durée des pauses (aucun minuteur de 60 s).

## Stack

| Choix | Raison |
|---|---|
| App **watchOS autonome**, SwiftUI, Swift 6 (concurrence stricte), cible watchOS 26 minimum (l’iPhone de Kévin est en iOS 26) | Une app watchOS est forcément en Swift. Pas de compagnon iPhone, donc une seule UI. |
| **`ShuttleCore`**, Swift Package local, sans UI ni framework Apple | Porte toutes les règles métier. Ses tests tournent avec `swift test` sur le Mac en quelques secondes, sans simulateur. |
| Score modélisé en **event sourcing** : réglages initiaux + liste des échanges, état calculé par une fonction pure | L'annulation revient à retirer le dernier échange. Le journal est exactement ce que demandent les stats futures. Il n'y a pas d'état incohérent possible. |
| **SwiftData** pour la persistance | API native. Les données survivent au redémarrage, pas à une désinstallation (accepté). |
| **HealthKit** (`HKWorkoutSession`, `.badminton`) | C'est ce qui garde l'app au premier plan entre deux échanges. |
| **XcodeGen** (`project.yml`) pour générer le `.xcodeproj` | Un YAML lisible et versionné au lieu d'un `project.pbxproj` illisible. C'est un **outil à installer** (`brew install xcodegen`), pas une dépendance de l'app. |
| **swift-format** (fourni avec la toolchain Xcode) | Format et lint sans rien installer. |

Relecture : tu ne pourras pas relire le Swift avec ton recul habituel en TS. Les
concepts se transposent bien pour l'essentiel : `struct` correspond à un objet
immuable, `protocol` à une interface, et un `enum` avec valeurs associées à une
union discriminée. En revanche, SwiftUI, SwiftData et HealthKit ont des pièges que
tu ne verras pas. Les tests de `ShuttleCore` sont le vrai filet.

Compte développeur gratuit : l'app installée sur la montre expire au bout de
7 jours, il faut donc la réinstaller depuis Xcode. Il reste à confirmer que
HealthKit est bien signé avec une équipe personnelle au premier déploiement.

## Règles métier

### Set (3×15, BWF, en vigueur en France depuis le 1er septembre 2026)

- Chaque échange rapporte un point à son gagnant (rally point), que ce camp ait
  servi ou non.
- Un set se gagne à **15 points**. À **14-14**, il faut **2 points d'écart**.
  Le plafond est à **21** : à 20-20, le point suivant gagne le set.
  - 15-13 : fin du set.
  - 15-14 : le set continue.
  - 14-14 → 16-14 : fin du set.
  - 19-19 → 20-19 → 20-20 → 21-20 : fin du set (21 est le plafond).
- Le match se joue en **2 sets gagnants** (au plus 3 sets). Fin de match à 2-0
  ou 2-1.
- **Pause** quand un camp atteint **8** pour la première fois dans le set (8-3 ou
  7-8, par exemple). Le message n'apparaît qu'une fois par set, même si l'autre
  camp atteint 8 ensuite.
- Au **3e set**, **changement de côté** quand un camp atteint 8 pour la première
  fois (le même moment que la pause).

### Service en simple

- Le gagnant d'un échange sert l'échange suivant.
- Le serveur sert depuis la case **droite** si son propre score est **pair**
  (0 compris), depuis la case **gauche** s'il est **impair**. Le receveur est en
  diagonale.
  - Moi 0 - 0 Adv, je sers : Moi à droite.
  - Moi 5 - 3 Adv, je gagne le point (6-3) : je sers, à droite.
  - Moi 6 - 3 Adv, l'adversaire gagne (6-4) : l'adversaire sert, à droite (4
    est pair).
- Le gagnant d'un set sert le premier échange du set suivant.

### Service en double

- On suit la position (droite ou gauche) des 4 joueurs. Au premier échange d'un
  set, le serveur et le receveur choisis sont à **droite**, leurs partenaires à
  gauche.
- **Le camp qui sert gagne l'échange** : le même joueur sert à nouveau, et son
  équipe et lui **permutent** de case. Le camp adverse ne bouge pas.
- **Le camp qui reçoit gagne l'échange** : il prend le service, **personne ne
  bouge**, et c'est le joueur placé dans la case correspondant à la parité du
  nouveau score de son camp qui sert (pair à droite, impair à gauche).
- Le receveur est toujours le joueur adverse placé en diagonale du serveur.
- Exemple, Moi (M) + Partenaire (P) contre A1 + A2. M sert, A1 reçoit. Au départ :
  M à droite, P à gauche ; A1 à droite, A2 à gauche.
  1. 0-0, M sert depuis la droite et gagne : 1-0. M et P permutent (M à gauche),
     M sert depuis la gauche (1 est impair).
  2. 1-0, M sert et perd : 1-1. Personne ne bouge. Le camp adverse a 1 point
     (impair), donc sert le joueur adverse à gauche, A2.
  3. 1-1, A2 sert et gagne : 1-2. A1 et A2 permutent (A2 à droite), A2 sert depuis
     la droite (2 est pair).
  4. 1-2, A2 sert et perd : 2-2. Personne ne bouge. Mon camp a 2 points (pair),
     donc sert le joueur de mon camp à droite, P.
- Entre deux sets, le camp qui a gagné le set sert en premier. Comme il peut
  choisir son serveur et le camp adverse son receveur, la montre **redemande**
  serveur et receveur au début de chaque set.

### Annulation

- Annuler revient à retirer la dernière entrée du journal (un échange, ou un
  choix de service) et à recalculer l'état. Cela peut rouvrir un set terminé, ou
  un match terminé.
- En double, à partir du 2e set : annuler le premier échange ramène à 0-0 avec le
  service choisi ; annuler encore ramène au choix serveur et receveur ; annuler
  encore rouvre le set précédent. L'écran de choix propose donc aussi l'annulation,
  car un tap raté a pu terminer le set.
- Annuler avant le tout premier échange du match ramène à l'écran de choix du
  premier service, dans le même format (un mauvais premier serveur se corrige
  donc sans quitter l'app).

### Joueurs

- Un nom est obligatoire. Les espaces de début et de fin sont retirés, et un nom
  ne peut pas être en double, sans tenir compte de la casse : « Lucas » et
  « lucas » sont considérés comme le même nom, ce qui est refusé.
- Un même joueur ne peut pas figurer deux fois dans un match.
- Supprimer un joueur le retire de la liste de sélection. Il reste dans
  l'historique, sous son nom, pour les matchs auxquels il a participé.
- « Moi » est toujours présent dans mon camp, n'est jamais supprimable et ne
  s'affiche pas dans la liste de sélection des adversaires.

## Découpage

Une tranche verticale par `/feature`, dans cet ordre :

1. **Score en simple** : moteur 3×15 dans `ShuttleCore` (sets, prolongation,
   plafond, fin de match, service et case en simple, annulation), écran de match
   coupé en deux, choix du premier serveur. Les joueurs sont nommés « Moi » et
   « Adversaire », rien n'est persisté.
2. **Double** (le format principal au club) : rotation du service à 4 joueurs dans
   `ShuttleCore`, choix serveur et receveur à chaque set, affichage du serveur et
   de sa case.
3. **Séance HealthKit** pendant le match, avec repli si l'accès est refusé.
4. **Persistance** : sauvegarde du match et de son journal, statuts `terminé` et
   `interrompu`, arrêt anticipé, reprise d'un match en cours au relancement.
5. **Pause et changement de côté** à 8 points : retour haptique et message.
6. **Liste de joueurs** : création, renommage et suppression, puis sélection
   au démarrage d'un match à la place de « Adversaire ».
7. **Historique** des matchs.
