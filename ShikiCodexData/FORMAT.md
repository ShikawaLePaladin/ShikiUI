# ShikiCodexData - format des donnees (schema 1)

Ce document decrit EXACTEMENT les fichiers de `ShikiCodexData\` pour qu'on puisse ecrire le lecteur Lua 5.0 du Codex sans lire l'outil
qui les genere (`tools/build_codex_data.js`). Les quetes sont dans `ShikiCodexData_Quests\` : voir `FORMAT_QUESTS.md`.
Le bloc "lecteur de reference" (section 12) est du code Lua 5.0 reel : `tests/check_codexdata.js` l'extrait, le charge dans fengari et
verifie qu'il lit correctement les vraies donnees (il sert aussi de point de depart au futur `Mod_Codex`).

Les fichiers sont GENERES : ne jamais les modifier a la main. Pour les regenerer : `node tools/build_codex_data.js` ; pour verifier qu'ils sont a jour :
`node tools/build_codex_data.js --check` (code retour 1 sinon). `FORMAT.md` et `FORMAT_QUESTS.md` sont ecrits a la main (l'outil ne les touche pas).

Version du format : **schema = 1** (entier, `ShikiCodexData.schema`). Un changement de FORME des donnees incremente ce nombre ; un simple
changement de contenu (nouvelle version d'Atlas / pfQuest) ne le change pas (`build` change).

## 1. Fichiers, chargement

| fichier | contenu |
|---|---|
| `ShikiCodexData.toc` | `## LoadOnDemand: 1`, `## OptionalDeps: ShikiUI`, pas de SavedVariables. Liste les fichiers dans l'ordre ci-dessous. |
| `Meta.lua` | cree la table globale `ShikiCodexData` et les sous-tables vides ; metadonnees, profils, detection Auto, listes. |
| `Names_enUS.lua`, `Names_frFR.lua` | noms d'objets : `D.en.i[id]`, `D.fr.i[id]`. |
| `Titles_enUS.lua`, `Titles_frFR.lua` | titres des quetes des chaines d'attunement (et de cles) : `D.en.q[id]`, `D.fr.q[id]`. |
| `Pages.lua` (ou `Pages_1.lua`, `Pages_2.lua` ... si > 380 Ko) | `D.page[cle]` : pages d'objets (sets, reputations, cles, listes de reference). |
| `Rep.lua` | `D.rep` (liste des factions, ordre du menu Atlas) et `D.sets[cle]` (menus de sets par classe). |
| `Attune.lua` | `D.attune[cleInstance]`. |
| `Inst_<Cle>.lua` (un par instance, 69) | `D.inst[cle]` : instance, boss, butin. |
| `LICENSE`, `NOTICE.txt` | GPL v2 (texte complet) ; credits Atlas-CFM + pfQuest/Shagu + pfQuest-octo, versions, date. |
| `FORMAT.md`, `FORMAT_QUESTS.md` | ce document ; le format des quetes. |

Chargement : `LoadAddOn("ShikiCodexData")` (le `.toc` est LoadOnDemand). Tous les fichiers s'executent a ce moment-la ; apres, `ShikiCodexData`
est une table globale en lecture seule par convention. Aucun fichier ne contient de fonction ni d'appel : ce sont uniquement des affectations
`D.xxx[cle] = { ... }` de tableaux, de nombres, de chaines et de booleens. Il n'y a rien a "decoder" a part ce que ce document decrit.

Conventions communes :

* Fichiers en ASCII pur. Les octets UTF-8 (accents) sont ecrits en `\ddd` (decimal, 3 chiffres : `"\195\169"` = e accent aigu). Les textes visibles sont donc de
  l'UTF-8 normal une fois charges. Aucun texte ne contient de code couleur ni de retour a la ligne.
* Lua 5.0 : aucune des constructions interdites (`#`, `%`, `...`). Un fichier = une fonction principale < 200 000 constantes (limite Lua : 262 143) ; chaque fichier fait < 400 Ko.
* Tableaux "paralleles" : un butin est un ensemble de tableaux de meme longueur `n = table.getn(loot.id)` ; la ligne `i` est `id[i]`, `rt[i]`, `fl[i]`, `tr[i]`.
  Une case sans information vaut `false` (jamais `nil` : un `nil` ferait un trou). Un tableau parallele ENTIEREMENT vide de sens (que des `false` / 0) est OMIS.
* Tableaux "clairsemes" : un attribut rare est une table indexee par le numero de ligne : `mk[7] = 6` signifie "la ligne 7 a le masque 6". Une ligne absente de la table = valeur par defaut.
* Les chaines ne sont jamais vides. Absent = `nil` : toujours tester `x ~= nil` / `if x then`.

## 2. Profils de serveur et masques

Atlas filtre ses donnees selon 4 "profils de serveur". `Meta.profiles` les liste, chacun avec un BIT :

```
D.profiles = {
  { id = "classic",   bit = 1, atlas = "Classic" },
  { id = "turtle117", bit = 2, atlas = "Turtle WoW 1.17.2" },
  { id = "turtle118", bit = 4, atlas = "Turtle WoW" },          -- Turtle WoW 1.18.1 (herite du contenu TURTLE1)
  { id = "vplus",     bit = 8, atlas = "Vanilla Plus" },
}
```

`D.default = "classic"` : profil a utiliser si rien n'est choisi. Un MASQUE `m` est la somme des bits des profils pour lesquels l'element est visible.
Les masques ont ete calcules en executant le VRAI `AtlasCFM.Server.IsVisible` d'Atlas pour chaque profil (instance, boss, ligne de butin, element de container, ligne de page, faction).

* `m` ABSENT = visible partout (masque 15). Un `m` n'est ecrit que s'il est different de 15 (donc 1 a 14).
* Test de visibilite pour le profil de bit `b` : `floor(m / b)` est impair (pas d'operateur binaire en Lua 5.0 : voir `R.hasBit` dans le lecteur de reference).
* Les masques se trouvent sur : l'instance (`inst.m`), le boss (`boss.m`), la ligne de butin (`loot.mk[i]`), l'en-tete de section (`loot.hm[i]`), l'element de container
  (3e valeur de chaque triplet de `loot.ct[i]`), la faction (`rep.m`), l'entree de menu de set (`sets[cle][j].m`). Un element cache l'est aussi pour tout ce qu'il contient
  (un boss masque cache ses lignes).

### Choix du profil "Auto" (a reproduire a l'identique)

Le reglage Atlas "Auto" n'est PAS un profil : c'est une detection faite a l'ouverture (fichier `Atlas-CFM\CFMAtlas\AtlasServer.lua`, fonction `Detect`, evaluee dans l'ordre) :

1. `GetBuildInfo()` (1er retour, chaine) egale a `"1.18.1"` -> `turtle118`
2. egale a `"1.17.2"` -> `turtle117`
3. `GetRealmName()` CONTIENT `"Hogger"` (`string.find`, ce texte n'a pas de caractere magique) -> `vplus`
4. sinon -> `classic`

Meta le dit ainsi (l'ordre du tableau est l'ordre d'evaluation) :

```
D.auto = {
  rules = { { b = "1.18.1", p = "turtle118" }, { b = "1.17.2", p = "turtle117" }, { r = "Hogger", p = "vplus" } },
  fallback = "classic",
}
```

Une regle `b` compare le numero de version (egalite stricte), une regle `r` cherche le texte dans le nom du royaume. `p` est un `id` de profil. L'outil verifie, a la generation, que ces regles
donnent le meme resultat que le vrai `Detect()` d'Atlas sur 10 couples (version, royaume).
Le profil choisi est ensuite converti en bit via `D.profiles` (voir `R.detect` et `R.bitOf`).

## 3. Meta.lua : la table `ShikiCodexData` (appelee `D` ci-dessous)

| champ | type | sens |
|---|---|---|
| `schema` | entier | 1 |
| `build` | chaine `"AAAA-MM-JJ"` | date de generation (seul champ qui change sans changement de donnees) |
| `sources` | table | `atlas`, `pfquest`, `octoplus` : `{ name, version, license }` |
| `profiles`, `default`, `auto` | | section 2 |
| `tiers` | table | `{ neutral = 4, friendly = 5, honored = 6, revered = 7, exalted = 8 }` : numerotation de `standingId` de `GetFactionInfo` ; c'est la valeur de `loot.tr[i]` |
| `counts` | table | `inst, boss, loot` (lignes de butin de boss ET de pages), `pages, pageitems, items, named, rep, attune` : sert de controle de coherence |
| `order` | liste de cles | ordre d'affichage conseille des instances : niveau minimum, niveau maximum, nom anglais, cle |
| `disc` | liste de chaines | libelles "disc" d'Atlas (texte anglais court : "Quest Item", "Vendor" ...) ; `loot.dc[i]` est un INDICE dans cette liste |
| `discfr` | table indice -> chaine | traduction francaise ecrite a la main des libelles de `disc` (51 sur 67 ; les autres restent en anglais : repli sur `disc[indice]`) |
| `inst`, `page`, `sets`, `rep`, `attune` | tables | remplies par les autres fichiers |
| `en`, `fr` | `{ i = {}, q = {} }` | noms d'objets (`i`) et titres de quetes d'attunement (`q`) par id |
| `qual`, `icon` | tables VIDES | reserves : qualite et icone par id d'objet (Atlas ne les fournit pas) ; a remplir plus tard ou a l'execution (cache `GetItemInfo`) |

## 4. Instances : `D.inst[cle]`

Une table par fichier `Inst_<cle>.lua`. `cle` est la cle Atlas (`"MoltenCore"`, `"ScarletMonasteryArmory"`, `"BlackrockDepths"` ...). 69 instances (82 dans Atlas ; les 13 sans butin ne sont pas gardees :
BGArathiBasin, BGThornGorge, BGWarsongGulch, BlackfathomDeepsEnt, ScarletMonasteryEnt, TheSunkenTempleEnt, DLEast, DLWest, FPAlliance/Horde East/West, TransportRoutes).

| champ | type | sens |
|---|---|---|
| `n` | chaine | nom anglais (obligatoire) |
| `f` | chaine ou nil | nom francais, seulement s'il existe et differe de `n` (sinon utiliser `n`) |
| `kd` | chaine | `"dungeon"`, `"raid"` (>= 10 joueurs), `"entrance"` (cle finissant par `Ent`), `"world"` (boss de monde, raretes), `"bg"` (champs de bataille) |
| `lv`, `hi` | entiers | niveau minimum et maximum (`lv <= hi`) ; 0 si inconnu |
| `mx` | entier | nombre de joueurs maximum (0 si inconnu) |
| `acr` | chaine ou nil | acronyme (`"MC"`, `"SM Arm"`) |
| `att` | `true` ou nil | Atlas indique qu'un attunement est necessaire (la chaine detaillee est dans `D.attune[cle]`, quand elle existe) |
| `m` | masque ou nil | section 2 |
| `loc`, `lf` | chaines | lieu d'entree en anglais / en francais (`lf` seulement s'il differe) |
| `rp` | liste de cles de page | pages de reputation liees a l'instance (section 7) |
| `ky` | liste `{ n, id?, i? }` | cles de l'instance : `n` nom anglais de la cle, `id` id de l'objet-cle (resolu par le nom dans la page `VanillaKeys`, absent si non trouve : `DragonmawRetreat` et `StormwroughtRuins`), `i` texte d'information anglais |
| `boss` | liste | les boss, dans l'ordre d'Atlas (section 5) |

Les noms francais viennent de pfQuest (`zones`/`units` frFR) en joignant par NOM ANGLAIS : un nom sans correspondance reste en anglais (22 instances, 285 boss sur 653 sont dans ce cas : beaucoup sont identiques
en francais, d'autres sont des regroupements d'Atlas qui ne sont pas des PNJ, par exemple "Mini Bosses", "Class Books").

## 5. Boss et lignes de butin

Un element de `inst.boss` :

| champ | sens |
|---|---|
| `n` | nom anglais (texte d'Atlas : peut etre un regroupement, "Trash Mobs-Zone", "Enchants") |
| `f` | nom francais, si connu et different |
| `px` | suffixe d'affichage anglais d'Atlas (`postfix`), ex. mode difficile |
| `m` | masque, si different de 15 |
| `pg` | clef d'une page `D.page[pg]` : le boss n'a pas de liste propre, il renvoie a une page partagee (par exemple `"LunarFestival"` pour 7 boss, `"Scarlet"`, `"Ironweave"`, `"Strat"`) |
| `sm` | clef d'un menu de sets `D.sets[sm]` (`"T1Set"`, `"T2Set"`, `"T3Set"`, `"T0Set"`, `"T35Set"`, `"AQ20Set"`, `"AQ40Set"`, `"ZGSet"`, `"T1VPSet"`) : le boss affiche un menu de sets par classe |
| (butin) | sinon : les tableaux de lignes ci-dessous, directement dans la table du boss |

Un boss a soit un butin (`id` ...), soit `pg`, soit `sm`. Les 653 boss ont tous l'un des trois.

### Tableaux d'un butin (boss ET page)

`n` = `table.getn(loot.id)`. Pour chaque ligne `i` de 1 a `n` :

| tableau | type | sens |
|---|---|---|
| `id[i]` | entier > 0 | id de l'objet (obligatoire, dense) |
| `rt[i]` | nombre, chaine ou `false` | taux de chute NORMALISE : un nombre en POURCENT (`25`, `0.01`, `33.3`) ; une plage en texte `"0.2-10"` ; `false` = pas de taux (ex. objets de page, taux 0 d'Atlas). Le taux par defaut du boss (`defaults.dropRate`) est DEJA applique. Tableau omis si aucune ligne n'a de taux. |
| `fl[i]` | entier | drapeaux (somme de bits) : **1** = ligne d'un POOL PARTAGE (la meme table d'objets est reutilisee par plusieurs boss de l'instance : par exemple les recettes a 1 % de Molten Core sont listees sous les 10 boss ; ce n'est pas un drop propre a ce boss) ; **2** = le taux `rt[i]` vient du taux par defaut du boss, non d'un taux ecrit sur la ligne. Omis si tout vaut 0. |
| `tr[i]` | entier | palier de reputation (4 a 8, voir `tiers`) ou 0 : seulement dans les pages de reputation ; omis ailleurs |
| `mk[i]` | masque | clairseme : visibilite par profil, absent = 15 |
| `ct[i]` | liste a plat | clairseme : objets lies a la ligne, par TRIPLETS `id, quantite, masque, id, quantite, masque, ...`. Atlas ne precise pas le lien : recette -> objet cree, jeton -> pieces de set, sac -> contenu, objet de quete -> recompense ; dans les pages de reputation : objets a rendre. `quantite` = nombre, ou chaine `"2-4"`, ou 0 (non precise). `masque` = 15 si visible partout. Le libelle `dc[i]` precise souvent ("Quest Item", "Need quest", "Container", "Reagent"). |
| `qt[i]` | nombre ou chaine | clairseme : quantite de l'objet lui-meme (plage `"1-3"` possible) |
| `dc[i]` | entier | clairseme : indice dans `D.disc` (et `D.discfr`) : precision d'Atlas affichee a cote de la ligne |
| `hd[i]` | chaine | clairseme : EN-TETE de section affiche AVANT la ligne `i` (texte d'Atlas, anglais, sans code couleur ; il n'y a pas de traduction) |
| `hm[i]` | masque | clairseme : masque de cet en-tete |
| `hc[i]` | chaine | clairseme : nom de l'icone de l'en-tete, SANS chemin (`"INV_Jewelry_Talisman_08"` = `Interface\Icons\INV_Jewelry_Talisman_08`) |

Les lignes vides d'Atlas (separateurs) ne sont pas conservees. Un en-tete place apres la derniere ligne n'est pas ecrit (aucun cas). Un meme id peut apparaitre deux fois dans une meme liste (23 cas, boss et pages confondus : deux lignes, deux sens) :
ne pas dedoublonner. Les lignes d'Atlas sans `id` ni nom (lignes vides avec seulement un masque, 10 cas) sont ignorees.

Exemple reel (`Inst_Azuregos.lua`, abrege) :

```lua
D.inst["Azuregos"] = {
	n = "Azuregos", kd = "world", lv = 1, hi = 60, mx = 40, acr = "AZ", loc = "Azshara",
	boss = {
		{ n = "Azuregos",
			id = { 19132, 18208, 18541, ... 26021 },                       -- 15 lignes
			rt = { 10, 10, 12, 10, 10, 10, 10, 10, 10, 10, 100, 40, 10, 10, 10 },
			fl = { 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 0, 0, 2, 2, 2 },         -- 2 = taux par defaut du boss
			mk = { [12] = 6, [13] = 8, [14] = 8, [15] = 8 },               -- ligne 12 : profils 2+4 ; lignes 13-15 : Vanilla Plus seul
			ct = { [11] = { 18714, 0, 15 }, [12] = { 65006, 0, 15 } },     -- ligne 11 contient 18714
			dc = { [11] = 45 },                                            -- D.disc[45] = "Quest Item"
		},
		{ n = "Spirit of Azuregos", f = "Esprit d'Azuregos", id = { 20949 }, ct = { [1] = { 21526, 0, 15, 21527, 0, 15 } } },
	},
}
```

## 6. Pages : `D.page[cle]`

Une page est un butin SANS taux (`rt` absent) avec les memes tableaux (`id`, `ct`, `hd`, `hm`, `hc`, `mk`, `dc`, `qt`, `fl` = 0) plus `tr` pour les pages de reputation. 135 pages, 2227 lignes.
Une page est referencee par : `boss.pg`, les entrees de `D.sets[cle]` (`pg`), `D.rep` (`pg`), `inst.rp`. Les pages communes ne sont stockees qu'une fois.

Familles : sets par classe (`T1Warrior`, `AQ20Druid` ...), reputations (`ArgentDawn`, `ZandalarTribe` ...), reference des cles (`VanillaKeys`), pages de reference partagees (`LunarFestival`, `Ironweave`, `Scarlet` ...).

## 7. Reputations : `D.rep` et `loot.tr`

`D.rep` est la liste (ordre du menu d'Atlas) des pages de reputation : 33 entrees.

| champ | sens |
|---|---|
| `pg` | clef de page `D.page[pg]` |
| `n` | nom anglais |
| `f` | nom francais ecrit a la main (13 factions de la version classique ; sinon absent) |
| `sd` | `1` Alliance, `2` Horde (faction reservee a un camp) ; absent = les deux |
| `ex` / `exf` | texte anglais d'Atlas (lieu de la faction, ex. `"Western Plaguelands, Eastern Plaguelands"`) / sa version francaise (noms de zones traduits par la table pfQuest, sinon identique) |
| `m` | masque |

ATTENTION : la cle `pg` n'est pas unique : `StormpikeFrostwolf` apparait deux fois (Alliance `sd = 1`, Horde `sd = 2`) car la meme page sert aux deux camps.

Paliers : dans une page de reputation, Atlas intercale des lignes d'en-tete "Neutral", "Friendly", "Honored", "Revered", "Exalted" ; l'outil les transforme en un palier EXPLICITE par ligne :
`tr[i]` vaut 4, 5, 6, 7 ou 8 (valeur `standingId` de `GetFactionInfo` ; `D.tiers`). ATTENTION : l'ordre des en-tetes dans Atlas n'est pas toujours croissant
(la page `ArgentDawn` place "Exalted" AVANT "Revered") : toujours utiliser `tr[i]`, jamais la position. `tr[i] = 0` : aucun palier connu (avant le premier en-tete de palier ou apres un en-tete de
faction qui n'est pas un palier). Les en-tetes de palier ne sont PAS conserves dans `hd` ; les autres en-tetes (noms de factions dans une page mixte, "Shared") le sont.
28 pages sur 33 ont des paliers ; `DarkmoonFire`, `StormpikeFrostwolf` (x2) , `SilvermoonRemnant`, `RevantuskTrolls` n'en ont pas dans Atlas (`tr` omis).
La page `BroodOfNozdormu` donne le palier dans le champ `disc` d'Atlas : l'outil l'a converti en `tr` et n'a pas garde le libelle.

Lien instance -> faction : `inst.rp` (liste de `pg`). 10 instances en portent un : Alterac Valley Nord et Sud (`StormpikeFrostwolf`), Black Morass (`WardensofTime`), Molten Core (`HydroxianWaterLords`), Naxxramas, Scholomance et Stratholme (`ArgentDawn`),
Ruins of Ahn'Qiraj (`CenarionCircle`), Temple of Ahn'Qiraj (`BroodOfNozdormu`), Zul'Gurub (`ZandalarTribe`).

## 8. Sets : `D.sets[cle]`

Menu de sets par classe : liste ordonnee de `{ pg, n, f, m }` : `pg` page du set (`D.page[pg]`), `n` nom anglais (nom de la classe en general), `f` nom francais de la classe, `m` masque si different de 15.
Les cles sont les valeurs de `boss.sm`. L'ordre est celui du menu d'Atlas.

## 9. Attunements et cles : `D.attune[cleInstance]`

Table MANUELLE de l'outil (13 entrees pour 9 instances), VALIDEE a la generation (la quete finale existe dans pfQuest et son titre anglais est celui attendu), chaine reconstruite avec le graphe `pre` de pfQuest.
Liste de `{ sd, lv, an, ch }` :

* `sd` : 0 = les deux camps, 1 = Alliance, 2 = Horde (Molten Core, Onyxia, Scholomance, Sunken Temple ont une quete par camp).
* `lv` : niveau de la quete finale.
* `an` : nombre total d'ancetres distincts dans le graphe `pre` (toutes les branches).
* `ch` : la chaine, du debut a la quete FINALE, en ids de quetes : on remonte, depuis la quete finale, le prerequis le plus long (en cas d'egalite, l'id le plus petit). Ce n'est qu'UNE branche : `an` dit s'il y en avait d'autres.

Les titres anglais/francais de ces quetes sont dans `D.en.q[id]` / `D.fr.q[id]` (francais seulement s'il est sur). Les details (PNJ, niveaux, epingles) sont dans `ShikiCodexData_Quests`.
Instances couvertes : BlackrockSpireUpper (Seal of Ascension), BlackwingLair, Maraudon, MoltenCore, Naxxramas, OnyxiasLair, Scholomance, TheSunkenTemple, TowerofKarazhan.
NON FAIT : pfQuest n'a pas de prerequis pour l'attunement de Molten Core, de Blackwing Lair et de Naxxramas (`an = 0`, la chaine est la seule quete finale) ; `EmeraldSanctum` est marquee `att` par Atlas mais
aucune quete n'est identifiable dans pfQuest ; les cles d'instances (Dire Maul, Stratholme, Scarlet, Uldaman ...) ne sont PAS des quetes : elles sont dans `inst.ky` (nom et id de la cle).

## 10. Noms et langues

* `D.en.i[id]` : nom anglais de l'objet (`GetItemInfo` n'est pas necessaire). 5590 des 6558 ids cites ont un nom ; les 968 autres restent SANS NOM (pfQuest ne les a pas : ids Turtle recents, objets
  de test) : utiliser `GetItemInfo(id)` a l'execution, ou afficher `"item:" .. id`.
* `D.fr.i[id]` : nom francais, SEULEMENT s'il existe, differe du nom anglais, et que le nom anglais de base de pfQuest (avant fusion Turtle) est identique au nom anglais fusionne (sinon l'entree a ete
  reutilisee par Turtle et le francais decrirait un autre objet). 3608 noms. Repli : `D.fr.i[id] or D.en.i[id]`.
* Noms d'instances et de boss : champs `n` (anglais) et `f` (francais, si different). Pas de repli par id ; repli par champ : `inst.f or inst.n`.
* Textes d'Atlas sans traduction : en-tetes `hd`, `ex`, `loc` (traduits par la table des zones quand le nom est une zone), `px`, noms de boss non PNJ. Les libelles `disc` ont 51 traductions manuelles
  (`discfr`) non verifiees en jeu.
* Aucune qualite ni icone d'objet : `D.qual` et `D.icon` sont des tables vides reservees.

## 11. Ce qui n'est PAS dans les donnees

Gains de reputation, prix, qualite et icone des objets, cartes des instances, positions des boss, raretes autres que le taux de chute, recompenses des quetes hors quetes de donjon d'Atlas, attunements au-dela
de la table manuelle, Emerald Sanctum (chaine), traductions francaises d'Atlas (il n'y en a pas : seule la jointure par nom avec pfQuest donne du francais).

## 12. Lecteur de reference (Lua 5.0)

Code executable, teste par `tests/check_codexdata.js` (chargement dans fengari + verification des resultats sur des donnees reelles + regles Lua 5.0 de `tests/lint50.js`).
`D` est `ShikiCodexData` ; `bit` est le bit du profil choisi ; `lang` vaut `"enUS"` ou `"frFR"` (la locale du client).

```lua reference-reader
local R = {}
local floor = math.floor

-- bit b (puissance de 2) present dans m ? (pas d'operateur binaire en Lua 5.0)
function R.hasBit(m, b)
  local q = floor(m / b)
  return q - floor(q / 2) * 2 == 1
end

-- m == nil : visible partout
function R.visible(m, bit)
  if m == nil then return true end
  return R.hasBit(m, bit)
end

function R.bitOf(D, id)
  local i = 1
  while D.profiles[i] do
    if D.profiles[i].id == id then return D.profiles[i].bit end
    i = i + 1
  end
  return nil
end

-- detection "Auto" d'Atlas : regles evaluees dans l'ordre ; renvoie l'id de profil
function R.detect(D, build, realm)
  local rules = D.auto.rules
  local i = 1
  while rules[i] do
    local r = rules[i]
    if r.b and build == r.b then return r.p end
    if r.r and realm and string.find(realm, r.r, 1, true) then return r.p end
    i = i + 1
  end
  return D.auto.fallback
end

function R.itemName(D, id, lang)
  if lang == "frFR" and D.fr.i[id] then return D.fr.i[id] end
  return D.en.i[id]
end

function R.instName(inst, lang)
  if lang == "frFR" and inst.f then return inst.f end
  return inst.n
end

-- lignes affichables d'un butin (boss ou page) pour un profil ; un en-tete est une ligne { header = texte, icon = nom }
function R.rows(D, loot, bit, lang)
  local out = {}
  local n = table.getn(loot.id)
  local i = 1
  while i <= n do
    local h = loot.hd and loot.hd[i]
    if h and R.visible(loot.hm and loot.hm[i], bit) then
      table.insert(out, { header = h, icon = loot.hc and loot.hc[i] })
    end
    if R.visible(loot.mk and loot.mk[i], bit) then
      local id = loot.id[i]
      local fl = 0
      if loot.fl and loot.fl[i] then fl = loot.fl[i] end
      local row = { id = id, name = R.itemName(D, id, lang), index = i }
      if loot.rt and loot.rt[i] then row.rate = loot.rt[i] end
      row.shared = R.hasBit(fl, 1)
      row.defaultRate = R.hasBit(fl, 2)
      if loot.tr and loot.tr[i] and loot.tr[i] > 0 then row.tier = loot.tr[i] end
      if loot.qt and loot.qt[i] then row.qty = loot.qt[i] end
      local d = loot.dc and loot.dc[i]
      if d then
        row.disc = D.disc[d]
        if lang == "frFR" and D.discfr[d] then row.disc = D.discfr[d] end
      end
      local c = loot.ct and loot.ct[i]
      if c then
        row.ct = {}
        local j = 1
        while c[j] do
          if R.visible(c[j + 2], bit) then
            table.insert(row.ct, { id = c[j], qty = c[j + 1], name = R.itemName(D, c[j], lang) })
          end
          j = j + 3
        end
      end
      table.insert(out, row)
    end
    i = i + 1
  end
  return out
end

-- bosses visibles d'une instance pour un profil (nil si l'instance est masquee)
function R.bosses(inst, bit, lang)
  if not R.visible(inst.m, bit) then return nil end
  local out = {}
  local i = 1
  while inst.boss[i] do
    local b = inst.boss[i]
    if R.visible(b.m, bit) then
      local name = b.n
      if lang == "frFR" and b.f then name = b.f end
      table.insert(out, { name = name, boss = b, page = b.pg, sets = b.sm })
    end
    i = i + 1
  end
  return out
end

-- chaine d'attunement d'une instance pour un camp (1 Alliance, 2 Horde) : liste d'ids de quetes, ou nil
function R.attune(D, key, side)
  local a = D.attune[key]
  if not a then return nil end
  local i = 1
  while a[i] do
    if a[i].sd == 0 or a[i].sd == side then return a[i].ch end
    i = i + 1
  end
  return nil
end

return R
```
