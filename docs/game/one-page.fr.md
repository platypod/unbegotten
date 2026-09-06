# La ligne de courbure — conception en une page (français)

![Unbegotten, conception en une page : la ligne de courbure, avec les dix espaces, les sept verbes, les quatre fils et les trois dénouements](one-page.fr.svg)

---

## Ce que c'est, et pourquoi

Une **conception en une page**, au sens où [Stone Librande](https://gdcvault.com/play/1012356/One-Page)
l'entendait à la GDC 2010 : non pas un document plus court, mais un document
*visuel* — une seule image annotée qui tient sur une page, qui est datée, et
qu'on a envie d'afficher au mur.

Son diagnostic portait sur la lecture, pas sur la longueur. Les gros
documents de conception ne sont pas lus, et les wikis cassent les
**relations** entre les éléments — or une conception est surtout faite de
relations. Le diagnostic s'applique ici : [`docs/`](README.md) fait environ
3 500 lignes réparties sur seize fichiers, [`world.md`](world.md) en fait
plus de 800 à lui seul, et tout cela est bon — c'est exactement l'objet
qu'il décrivait.

Cette page est donc **soustractive**, selon sa règle : *quelle est la seule
chose vraiment essentielle à communiquer ?* Ici, la réponse ne fait pas de
doute, et c'est déjà la première ligne de `world.md` — **le monde est une
droite graduée**. Tout le reste de la page annote cette colonne vertébrale.
Ce qui ne le faisait pas a été coupé.

## Ce qui change en v2

La v1 est conservée telle quelle dans
[../archive/one-page/one-page.2026-09-06.fr.svg](../archive/one-page/one-page.2026-09-06.fr.svg).
C'était un bon énoncé du *thème* et un mauvais énoncé de la *conception* ;
les six changements ci-dessous comblent cet écart. Cinq d'entre eux sont des
promotions : le contenu était déjà dans `docs/`, simplement pas sur la page.

- **Il y a des figures.** La v1 invoquait la règle de Librande — *le visuel
  d'abord* — dans son propre pied de page, et ne contenait aucun dessin :
  145 nœuds de texte, et chaque rectangle était un cadre ou une barre. Il
  fallait déjà savoir à quoi ressemble un pavage heptagonal pour lire la
  page qui en parle. Il y a maintenant dix figures, et elles sont
  **calculées et non croquées** (voir [one-page/](one-page/README.md)) : La
  Prolifération est un vrai `{7,3}` dans le disque de Poincaré, Le Ruban est
  la vraie règle 110, La Volte une vraie paramétrisation de Möbius.

- **La falaise est la figure dominante.** La carte est une droite graduée,
  mais ce qui compte vraiment — moyennable contre non moyennable — est un
  *seuil*, pas une pente : κ > 0 et κ = 0 portent le même contenu moral. La
  v1 le disait en gris de 10 px, la flèche pointant hors de la page. C'est
  désormais une rupture pleine hauteur dans l'axe, les deux régimes mis en
  accolade de part et d'autre — ce qui explique aussi pourquoi la colonne
  κ > 0 n'a plus à faire semblant d'être aussi remplie que les autres.

- **La boucle de jeu est sur la page.** La v1 donnait un verbe d'un mot à
  chaque espace et ne disait jamais en quoi consiste une minute de jeu. Les
  sept verbes de [systems.md](systems.md) y figurent avec leur état de
  construction, les deux échelles aussi, et surtout **l'antagoniste** — le
  monde qui se fige — qui était le plus gros manque : la v1 le portait comme
  une constante de direction artistique (*vivant émet, mort est mat*) sans
  jamais dire que c'était là toute la pression.

- **L'ouverture des portes est expliquée, non plus affirmée.** « Sur la
  compréhension, jamais sur une permission » est une affirmation sur le
  problème le plus difficile du projet. `LIRE` et les trois chaînes
  détaillées de la toile de savoir disent maintenant comment.

- **L'état de construction est scindé en *espace* et *mécanique*.** Une seule
  pastille ne pouvait pas distinguer « la géométrie tourne » de « la chose
  pour laquelle la géométrie existe existe » — or c'est exactement la
  distinction qui compte pour six des dix. La figure du Jardin est un cadre
  tireté vide, parce que c'est le dessin honnête d'un espace qui n'existe
  pas, et le bandeau de portée honnête, en bas, le redit en chiffres.

- **Le « quatre en un » devient trois.** La v1 affirmait que l'axe était à
  la fois la carte, la courbe de difficulté, l'arc narratif et la direction
  artistique. Deux de ces quatre ne tiennent pas aujourd'hui : κ < 0
  *supprime* un savoir-faire au lieu d'élever une pente, et « la teinte
  encode κ » est une proposition que
  [`graphics.Colours`](../../src/graphics/Colours.hx) remplace pour l'instant
  par un budget de contraste monochrome (voir l'encadré d'état de
  [art-and-audio.md](art-and-audio.md)). Les deux sont nommés comme ouverts
  plutôt que gardés en silence.

Une question de conception a été *tranchée* plutôt que promue, et elle est
signalée ici parce qu'elle change `world.md` : l'entrée du Jardin y dit « là
où vivent les trois dénouements », mais le dénouement 2 exige de rester dans
le monde **moyennable** — il ne peut donc pas se prendre dans un espace qui
ne l'est pas. La page dit maintenant : Le Jardin **pose** le choix ;
Autonomie et Repos s'y prennent, et **Héritage se prend en faisant
demi-tour**. C'est un meilleur dénouement de toute façon — celui qu'on
atteint en refaisant le chemin à l'envers — mais c'est un changement, pas une
transcription.

## Comment la lire

- **L'horizontale est la courbure**, de κ > 0 à gauche vers κ < 0 à droite.
  C'est aussi l'ordre de jeu et l'arc émotionnel.
- **La falaise, entre Le Défaut et La Prolifération, est là où le théorème
  tombe.** Tout ce qui est à sa gauche est moyennable et la liberté y coûte
  un prédécesseur ; tout ce qui est à sa droite ne l'est pas, et personne ne
  paie.
- **La Nature Morte et Le Ruban sont hors de la ligne** — l'un est le hub,
  l'autre un espace dont le second axe est le temps, et aucun n'a sa place
  sur un axe de courbure. Les deux portent quand même : le hub est la barre
  de progression, et Le Ruban est le tutoriel de la fin.
- **Chaque espace porte sa propre loi de lisibilité**, dans l'encadré. Aucune
  ne se ressemble ; c'est tout l'intérêt d'en avoir dix.
- **L'état de construction figure sur chaque carte, deux fois**, parce qu'un
  document qui laisserait croire que Le Jardin existe serait précisément le
  travers que ce format sert à corriger.

## Conventions

La palette vient de [`graphics.Colours`](../../src/graphics/Colours.hx) et
n'a pas été inventée : la rampe de valeurs porte toute la structure, et les
quatre couleurs de signal servent chacune à un seul sens, comme l'exige le
budget de contraste de la palette — `SIGNAL_LIVE` sur ce qui tourne (le côté
non moyennable, et *construit*), `SIGNAL_ACT` sur ce que le joueur peut faire
(les verbes), `SIGNAL_DENY` sur ce qui refuse (*non construit*, et le
figement), `SIGNAL_MARK` sur ce qui vaut la traversée d'un espace (Le Jardin,
et les trois dénouements).

`one-page.fr.svg` est du SVG simple, attributs de présentation uniquement —
pas de `<style>`, pas de script, pas de police web, pas de `<defs>`, aucune
référence externe — pour que GitHub le rende intact, que `outline-sync` puisse
le reprendre, et qu'il s'imprime en vectoriel à n'importe quelle taille. C'est
du texte : il se diffe comme du code.

Il fait **2688 × 2196**, dimensionné pour du A1/A2 à l'italienne avec environ
6 % de marge. C'est délibérément plus grand que le 1600 × 1850 de la v1 :
à cette taille, le corps de texte de 11 px fait environ 2 mm en A3, soit un
document d'écran qui se dit affichable.

## Les noms

Les noms d'espaces ne sont pas des calques : l'anglais fait presque toujours
un double sens, et le français doit en faire un aussi. **La Trame** garde le
tissage *et* la trame narrative ; **Le Repli** garde le pli géométrique *et*
l'abri où l'on se replie, qui est tout le sujet du Fil 3 ; **Le Motif** dit
le motif répété *et* la cause, qui est exactement la leçon de cet espace ;
**Le Nœud** dit le nœud topologique *et* le nœud dramatique ; **La Nature
Morte** est le terme français consacré du jeu de la vie, et dit « nature
morte » pour le seul lieu qui ne tourne pas.

Le vocabulaire technique suit les termes français réels — *moyennable* pour
*amenable*, *nature morte* pour *still life*, *planeur* pour *glider*,
*orphelin* pour *orphan* — et non des anglicismes.

**Encore ouverts :** *La Volte* (The Turn) et *La Prolifération* (The Sprawl)
sont des titres de travail, à revoir selon ce que ces deux espaces deviennent.
*La Volte* dit le demi-tour d'escrime et de manège, d'où vient *volte-face* —
juste de sens, mais soudain, là où le retournement möbien est graduel et se
produit sans qu'on le remarque. *La Prolifération* dit la multiplication qui
gagne du terrain, ce que *L'Étalement* (trop administratif) et *Le
Foisonnement* (trop plaisant) ne disaient pas. *Le Défaut* et *Le Ruban* aussi, plus faiblement :
*La Faille* dirait mieux le défaut mais évoque une fissure linéaire là où il
s'agit d'un point, et *La Frise* dirait la ligne du temps si cet espace la
rendait un jour visible.

Le sous-titre **Inengendré** ne figure que sur l'édition française : c'est le
terme nicéen exact, le même emprunt théologique que l'anglais *unbegotten*.

L'édition anglaise est à côté, dans [one-page.en.md](one-page.en.md) ; les
deux sont la même conception et doivent être modifiées ensemble.

**Datez-la quand vous la changez.** Le tampon de révision est en haut à
droite, et c'est la règle de Librande plutôt qu'une coquetterie : une page
affichée au mur ne vaut rien si personne ne peut dire quelle version il
regarde.
