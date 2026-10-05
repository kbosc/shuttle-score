# ShuttleScore

## Problème

Pendant un match de badminton, on perd le fil du score, et surtout de qui sert et
depuis quelle case, et rien ne garde de trace des matchs pour en tirer des stats.

## Usage

Kévin joue en club, en simple ou en double, presque toujours avec les mêmes
personnes. Il porte une Apple Watch Ultra 2 au poignet de la main libre. Avant le
match, il indique le format et qui sert en premier, en quelques taps. Entre
deux échanges, en sueur et la raquette dans l'autre main, il tape une moitié de
l'écran pour donner le point à son camp ou au camp adverse. La montre affiche le
score, qui sert et depuis quelle case. Si un point est mal saisi, il l'annule d'un
geste. À la fin, le match est sauvegardé point par point sur la montre, puis
envoyé à l'iPhone. Plus tard, au calme, Kévin ouvre l'app iPhone : il retrouve ses
matchs, ses stats en graphiques, et peut, s'il s'en souvient, nommer les joueurs
d'un match. La montre sert au match, l'iPhone à tout le reste.

## MVP

Chaque comportement est vérifiable (test unitaire dans `ShuttleCore`, ou
manipulation sur le simulateur ou la montre).

1. **Démarrer un match** en simple (Moi contre 1 adversaire) ou en double (Moi +
   partenaire contre 2 adversaires), en choisissant qui sert en premier et, en
   double, qui reçoit en premier.
2. **Saisir un point** en tapant la moitié basse de l'écran (mon camp) ou la
   moitié haute (le camp adverse). Chaque moitié couvre la moitié de l'écran.
3. **Afficher** le score du set en cours, les sets gagnés de chaque camp, et la
   position de chaque joueur sur le terrain, vue depuis ma place : serveur mis en
   évidence, receveur souligné (voir Règles métier, « Positions à l'écran »).
4. **Annuler** le dernier point, sans limite jusqu'au début du match, y compris
   au-delà d'une fin de set.
5. **Appliquer les règles 3×15** (voir Règles métier) : fin de set, fin de match.
   Une fois le match terminé, plus aucun point n'est accepté (seule l'annulation
   reste possible).
6. **Signaler** par un retour haptique et un message la pause à 8 points, ainsi
   que le changement de côté à 8 points au 3e set.
7. **Séance HealthKit « Badminton »** pendant tout le match : elle démarre avec le
   match et se termine quand on quitte le match (détail dans Règles métier,
   « Séance HealthKit »). L'app reste ainsi au premier plan. Si l'accès à
   HealthKit est refusé, le match se joue quand même, sans séance.
8. **Sauvegarder** chaque match sur la montre (SwiftData) : joueurs, règles,
   journal de chaque échange (gagnant, serveur, horodatage) et statut (`terminé`
   ou `interrompu`). Les matchs en 5 points ne sont **jamais** sauvegardés.
9. **Reprendre** un match en cours après un crash ou la fermeture de l'app : il
   est persisté à chaque point et proposé à la reprise au relancement.
10. **Arrêter** un match avant la fin : il est sauvegardé avec le statut
    `interrompu`.
11. **Synchro vers l'iPhone** : chaque match terminé ou interrompu est envoyé à
    l'app iPhone, même si l'iPhone n'est pas à portée à ce moment-là (envoi mis en
    file d'attente).
12. **Historique sur l'iPhone** : la liste des matchs, du plus récent au plus
    ancien (date, format, score par set, statut). La montre n'a pas d'historique.
13. **Stats et graphiques sur l'iPhone** : victoires et défaites, pourcentage de
    points gagnés au service et à la réception, évolution par semaine, simple
    contre double (voir Règles métier, « Stats »).
14. **Nommer les joueurs après coup** sur l'iPhone, match par match, si on s'en
    souvient. Facultatif : un match sans noms reste valable.

## Hors périmètre

- Noms des joueurs **sur la montre** (liste, choix au démarrage). Abandonné après
  test en match : chaque tap avant le match coûte sur le terrain. Sur la montre, les
  joueurs restent Moi, Partenaire, Adv. 1 et Adv. 2 ; les noms se donnent après coup
  sur l'iPhone (MVP n°14).
- Synchro iCloud (compte développeur payant), export, partage des stats.
- Modifier le score d'un match depuis l'iPhone : l'iPhone ne fait que lire et
  nommer.
- Formats autres que le 3×15 et le 5 points en simple dans l'UI (3×21, 5×11,
  formats libres, 5 points en double). Le moteur les accepte déjà en paramètre,
  mais aucun écran ne permet de les choisir.
- Saisie par le bouton Action de l'Ultra, complications, Smart Stack.
- Matchs où Kévin ne joue pas (« Moi » est toujours dans un camp).
- Fautes, lets, cartons et durée des pauses (aucun minuteur de 60 s).

## Stack

| Choix | Raison |
|---|---|
| App **watchOS**, SwiftUI, Swift 6 (concurrence stricte), cible watchOS 26 minimum (l’iPhone de Kévin est en iOS 26) | Une app watchOS est forcément en Swift. Elle reste utilisable sans l'iPhone pendant le match. |
| App **iPhone compagnon**, SwiftUI, iOS 26 minimum | Les stats ont besoin d'un vrai écran. Installation par câble, fiable, contrairement à la montre. |
| **WatchConnectivity** (`transferUserInfo` ou `transferFile`) | Canal officiel et gratuit montre → iPhone, avec file d'attente : rien à gérer si l'iPhone est loin. |
| **Swift Charts** | Graphiques natifs, déclaratifs. |
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
- À l'écran : vibration distincte de celle d'un point et message plein écran
  « Pause » (« Pause · Changez de côté » au 3e set). Un tap le ferme **sans marquer
  de point** ; sinon il se ferme seul après 5 secondes. L'annonce suit l'action de
  marquer : annuler le 8e point puis le remarquer la redéclenche, mais annuler un 9e
  point (retour à 8) ne la relance pas.

### Simple en 5 points

- Usage : petits matchs à 3 en attendant d'autres joueurs. Simple uniquement.
- Un seul set, sec : le premier à 5 gagne, même à 5-4 (4-4 → 5-4 : fin du match).
- Pas de pause. Service et positions suivent les règles du simple.
- Jamais sauvegardé (ni stats, ni historique). La séance HealthKit tourne quand
  même, pour garder l'app au premier plan : elle apparaît dans Santé.

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

### Sauvegarde et reprise

- Un match est sauvegardé à partir de son premier point, puis à chaque changement
  (point, annulation, choix du service). Annuler tous les points le supprime.
- Statut : `en cours` ; `terminé` dès qu'il y a un vainqueur (une annulation qui le
  rouvre le repasse `en cours`) ; `interrompu` quand on l'arrête.
- Arrêter : bouton ■ pendant le match, avec confirmation (un tap raté ne l'arrête pas).
- Au lancement, le dernier match `en cours` est proposé : « Reprendre » ou « Arrêter »
  (refuser revient à l'arrêter : il passe `interrompu`).
- Séance HealthKit : à la reprise, la séance laissée active par le plantage est
  récupérée ; si la reprise est refusée, elle est terminée et enregistrée.
- Joueurs : sauvegardés par rôle (Moi, Partenaire, Adv. 1, Adv. 2).
- Matchs en 5 points : jamais sauvegardés, jamais proposés.

### Positions à l'écran

- Chaque moitié de l'écran montre les cases de son camp, vues depuis ma place :
  je regarde les adversaires, donc leur case droite apparaît à ma gauche.
  - Moi à droite, Partenaire à gauche : en bas, « Partenaire » à gauche, « Moi » à droite.
  - Adv. 1 à droite, Adv. 2 à gauche (vu de leur camp) : en haut, « Adv. 1 » à
    gauche, « Adv. 2 » à droite.
- En simple, chaque joueur se tient dans la case de service (parité du score du
  serveur) ; l'autre case de son camp reste vide.
- Le serveur est en gras avec l'icône, le receveur est souligné.

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

### Séance HealthKit

- Elle démarre avec le match. La demande d'accès à Santé n'apparaît qu'au premier match.
- Elle est mise en pause quand le match se termine, et reprend si une annulation
  rouvre le match (un tap raté sur le dernier point ne la casse pas).
- Elle se termine quand on quitte le match (« Nouveau ») : enregistrée dans Santé
  si au moins un point a été joué, jetée sinon (annulation avant le premier point).
- Accès refusé ou HealthKit indisponible : le match se joue normalement, sans séance.

### Joueurs

- Pas de noms : Moi, Partenaire (en double), Adversaire (en simple), Adv. 1 et
  Adv. 2 (en double).
- Convention pour savoir qui est Adv. 1 sans rien saisir (Découpage n°8), au
  **premier set** uniquement :
  - mon camp sert le premier échange : **Adv. 1 est celui qui le reçoit** (en
    diagonale du serveur) ; l'app ne demande plus le receveur ;
  - le camp adverse sert : **Adv. 1 est celui qui sert** ; l'app demande seulement
    qui reçoit chez nous (Moi ou Partenaire).
- À partir du 2e set, Adv. 1 et Adv. 2 restent les mêmes personnes qu'au 1er set :
  le choix du serveur et du receveur se fait comme avant.

### Stats (sur l'iPhone)

- Seuls les matchs **terminés** comptent dans les victoires et défaites ; les
  matchs interrompus apparaissent dans l'historique et leurs points comptent dans
  les pourcentages. Les 5 points n'existent pas côté iPhone (jamais sauvegardés).
- Points gagnés au service = échanges servis par mon camp et gagnés par mon camp,
  divisés par les échanges servis par mon camp. Même calcul à la réception.
  - Exemple : 40 échanges servis par mon camp, 26 gagnés → 65 % au service.
- En double, « mon camp » compte (Moi et Partenaire ensemble).
- Évolution par semaine : victoires et défaites par semaine (lundi au dimanche).
- Simple contre double : les mêmes chiffres, séparés par format.
- Affichage : écran Stats ouvert depuis l'historique ; une valeur sans donnée
  (aucun match terminé, aucun échange servi) s'affiche « — » et n'a pas de barre,
  pour ne pas être confondue avec 0 %. Le graphique par semaine montre les 12
  dernières semaines où un match a été terminé.

### Noms après coup (sur l'iPhone)

- Pour un match, on peut nommer Partenaire, Adversaire, Adv. 1 et Adv. 2. Chaque
  nom est facultatif.
- L'écran rappelle la convention : Adv. 1 est celui qui a reçu (si mon camp a servi
  en premier) ou servi (si les adversaires ont servi en premier) le premier échange.
- Les noms déjà utilisés sont proposés. Espaces retirés aux bords ; « Lucas » et
  « lucas » sont la même personne.
- Les noms restent sur l'iPhone : ils ne sont ni renvoyés à la montre, ni dans le
  dépôt Git.

## Découpage

Une tranche verticale par `/feature`, dans cet ordre. ✅ = livrée.

1. ✅ **Score en simple** : moteur 3×15 dans `ShuttleCore` (sets, prolongation,
   plafond, fin de match, service et case en simple, annulation), écran de match
   coupé en deux, choix du premier serveur. Les joueurs sont nommés « Moi » et
   « Adversaire », rien n'est persisté.
2. ✅ **Double** (le format principal au club) : rotation du service à 4 joueurs dans
   `ShuttleCore`, choix serveur et receveur à chaque set, affichage du serveur et
   de sa case.
3. ✅ **Séance HealthKit** pendant le match, avec repli si l'accès est refusé.
4. ✅ **Positions sur le terrain** (ajout après test en match) : chaque joueur
   dans sa case, vue depuis ma place.
5. ✅ **Simple en 5 points** (ajout après test en match) : un set sec, jamais
   sauvegardé.
6. ✅ **Persistance** : sauvegarde du match et de son journal, statuts `terminé` et
   `interrompu`, arrêt anticipé, reprise d'un match en cours au relancement
   (hors matchs en 5 points, qui ne sont jamais proposés à la reprise).
7. ✅ **Pause et changement de côté** à 8 points : retour haptique et message.
8. **Convention Adv. 1** (remplace la liste de joueurs, abandonnée) : au premier
   set d'un double, Adv. 1 est l'adversaire qui reçoit (si mon camp sert) ou qui
   sert (si les adversaires servent) ; une question de moins au démarrage, et un
   rappel de la convention à l'écran.
9. ✅ **App iPhone et synchro** : app iPhone compagnon, envoi des matchs terminés
   et interrompus depuis la montre, historique sur l'iPhone (MVP n°11 et 12).
   Remplace l'historique sur la montre.
10. ✅ **Stats et graphiques** : calculs dans `ShuttleCore`, graphiques Swift Charts
    (MVP n°13).
11. **Nommer les joueurs après coup** sur l'iPhone, avec suggestion des noms déjà
    utilisés, puis bilan par joueur (MVP n°14).
