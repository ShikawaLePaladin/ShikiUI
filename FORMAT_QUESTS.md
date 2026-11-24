# ShikiCodexData_Quests - format des donnees (schema 1)

Ce document decrit les fichiers de l'addon `ShikiCodexData_Quests\` (quetes) : un addon LoadOnDemand DISTINCT de `ShikiCodexData`, charge a la premiere recherche de quete
(`## Dependencies: ShikiCodexData` : le jeu charge le premier avec le second). Les listes de butin sont decrites dans `FORMAT.md` (meme dossier). Les fichiers sont
GENERES par `node tools/build_codex_data.js` (`--check` pour verifier qu'ils sont a jour) ; ce document est ecrit a la main. Le bloc "lecteur de reference" (section 9) est du Lua 5.0 reel,
execute par `tests/check_codexdata.js` sur les vraies donnees.

Source : base `pfQuest` fusionnee comme le fait `pfQuest-octo-plus` (les fichiers `*-turtle` REMPLACENT l'entree d'un meme id ; la valeur `"_"` SUPPRIME l'entree ; le dossier `extra` ajoute seulement ce qui manque),
soit 6658 quetes, 13360 PNJ, 20902 objets du monde, 22642 objets. Les recompenses des quetes de donjon viennent d'Atlas-CFM (`QuestData`).

## 1. Fichiers

| fichier | contenu |
|---|---|
| `ShikiCodexData_Quests.toc` | LoadOnDemand, `## Dependencies: ShikiCodexData`, pas de SavedVariables |
| `Meta.lua` | cree la table globale `ShikiCodexQuests` (appelee `Q`) : metadonnees, zones, regles de recompense |
| `Titles_enUS.lua`, `Titles_frFR.lua` | `Q.en.t[id]`, `Q.fr.t[id]` : titres de quetes |
| `Names_enUS.lua`, `Names_frFR.lua` | `Q.en.u/o/i[id]`, `Q.fr.u/o/i[id]` : noms de PNJ (`u`), d'objets du monde (`o`), d'objets (`i`) |
| `Quests_01.lua`, `Quests_02.lua` | `Q.q[id]` : une chaine empaquetee par quete ; un fichier par tranche d'ids (l'en-tete du fichier donne la tranche) ; chacun < 400 Ko |
| `LICENSE`, `NOTICE.txt` | GPL v2 (texte complet : donnees derivees d'Atlas) ; credits et licences (pfQuest MIT, pfQuest-octo MIT) |

Les fichiers sont en ASCII pur (octets UTF-8 ecrits `\ddd`), sans fonction ni appel (uniquement des affectations `Q.xxx[id] = valeur`), Lua 5.0 (pas de `#`, `%`, `...`). Les 4 fichiers de noms/titres contiennent
UNE affectation par id. Le fichier `Quests_NN.lua` commence par `local q = ShikiCodexQuests.q`.
Convention : une table absente ou un id absent = pas d'information (`nil`) ; une table de noms ne contient JAMAIS la chaine vide.

## 2. Meta.lua : la table `ShikiCodexQuests` (`Q`)

| champ | type | sens |
|---|---|---|
| `schema` | entier | 1 |
| `build` | `"AAAA-MM-JJ"` | date de generation |
| `counts` | table | `quests` (6610), `units`, `objects`, `items`, `zones` : nombres de noms/zones de ce jeu (controle de coherence) |
| `en.z`, `fr.z` | table id de zone -> nom | NOM ANGLAIS (tous les ids de zone utilises) et nom francais (SEULEMENT s'il differe : 56 sur 116) |
| `zk` | table id de zone -> 1 ou 2 | zone qui a une CARTE du monde : `1` = zone vanilla (46), `2` = zone ajoutee par Turtle (5 : Hyjal, Moonwhisper Coast, Alah'Thalas, Balor, Gilneas). Absent = pas de carte (donjon, sous-zone, ile de GM) : ne pas epingler. |
| `rr` | table id de quete -> texte anglais | regle de choix des recompenses de quetes de donjon ("1 and 2 or 3", 12 quetes) : voir section 5 |
| `en`/`fr` `.t .u .o .i` | tables | remplies par `Titles_*` / `Names_*` |
| `q` | table | remplie par `Quests_NN.lua` |

Pourquoi des noms de zone ANGLAIS : le Codex doit retrouver la carte du monde avec `GetMapZones(continent)` ; ce nom y est localise : sur un client francais, comparer avec `Q.fr.z[id] or Q.en.z[id]`,
sur un client anglais avec `Q.en.z[id]` (sans tenir compte de la casse ni des espaces de fin). 46 zones vanilla + 5 zones Turtle dont le nom est prouve par le code des addons installes. Le nom d'une zone Turtle
absent des cartes du client tombe simplement sans correspondance : ne pas epingler (jamais d'erreur). Le prefixe `"Northwind "` de pfQuest est retire.
65 des 116 zones utilisees n'ont pas de carte du monde (`zk` absent : interieurs d'instances, sous-zones comme Darkshire, Blackrock Mountain, ile de GM) ; 6427 des 29392 epingles (22 %) sont dans ces zones et ne sont pas epinglables sur une carte du monde : tester `Q.zk[zone]` avant d'epingler.

## 3. Titres et noms

* `Q.en.t[id]` : titre anglais de la quete (6610). `Q.fr.t[id]` : titre francais, SEULEMENT s'il existe et differe de l'anglais. Deux origines : (1) le titre francais de pfQuest, garde quand le titre anglais de BASE de pfQuest est identique au titre anglais FUSIONNE
  (Turtle reecrit souvent le texte d'une quete sans changer son titre ; si le titre change, le francais decrirait l'ancienne quete) ; (2) une traduction faite pour ce projet (les quetes ajoutees par Turtle n'ont aucun francais), ecrite dans `tools/fr_extra/t*.tsv` et fusionnee par l'outil. 6508 titres francais. Repli : `Q.fr.t[id] or Q.en.t[id]`.
* `Q.en.u[id]`, `Q.fr.u[id]` : PNJ ; `Q.en.o[id]`, `Q.fr.o[id]` : objets du monde (coffres, plantes...) ; `Q.en.i[id]`, `Q.fr.i[id]` : objets cites par les quetes (depart, objectifs, recompenses).
  Un objet DEJA nomme dans `ShikiCodexData` (`D.en.i`) n'est PAS repete ici (945 ids) : pour un objet, chercher d'abord `Q.xx.i[id]`, puis `ShikiCodexData.xx.i[id]` (voir `R.entityName`).
  Une quete a un nom francais seulement si le francais correspond encore (meme regle) ; sinon repli sur l'anglais.
* Quetes ecartees : 45 quetes dont le titre est un marqueur de test ou obsolete (`[DEPRECATED]`, `<NYI>`, `<TXT>`, `DND`, `zzOLD`, `UNUSED`, `[OLD]`) et 3 entrees vides. Les prerequis (`pre`) qui pointent vers une quete ecartee sont retires (5), ainsi qu'une auto-reference de pfQuest (la quete 8223 se cite elle-meme : donnee amont erronee).

## 4. Enregistrement de quete : `Q.q[id]`

Une CHAINE de sections separees par `;`. Aucune section ne contient `;`. Les sections vides de fin sont omises (une quete a entre 2 et 12 sections). Section vide = valeur inconnue/absente.

| n | section | forme |
|---|---|---|
| 1 | niveau | entier (0 / vide = inconnu) |
| 2 | niveau minimum du joueur | entier |
| 3 | races | MASQUE de pfQuest (vide = toutes) : 1 Humain, 2 Orc, 4 Nain, 8 Elfe de la nuit, 16 Mort-vivant, 32 Tauren, 64 Gnome, 128 Troll, 256 Goblin, 512 Elfe de sang / haut-elfe (Turtle) ; `589` = Alliance, `434` = Horde |
| 4 | classes | MASQUE de pfQuest (vide = toutes) : 1 Guerrier, 2 Paladin, 4 Chasseur, 8 Voleur, 16 Pretre, 64 Chaman, 128 Mage, 256 Demoniste, 1024 Druide |
| 5 | zone principale | id de zone (`Q.en.z`) : zone du PNJ de depart (sinon de fin, sinon des objectifs) ; vide = aucune (154 quetes) |
| 6 | predecesseurs | ids de quetes separes par `,` : il suffit d'EN avoir fait UN (OU) ; ne contient que des quetes conservees |
| 7 | depart | references (voir ci-dessous), 4 au plus |
| 8 | fin | references, 4 au plus |
| 9 | objectifs | references, 8 au plus ; un `+` final = liste tronquee |
| 10 | epingles | voir section 6 |
| 11 | recompenses de donjon | voir section 5 |
| 12 | divers | jetons separes par `,` : `s<id>` competence requise (id de competence de pfQuest, ex. `s164` forge), `e<id>` evenement du jeu (id d'evenement de pfQuest, ex. `e7`) |

Les masques de race et de classe sont les masques de pfQuest (pas ceux de l'API Blizzard) : voir `R.raceBit` / `R.classBit` du lecteur pour la correspondance avec `UnitRace` / `UnitClass`.

### Reference d'entite

`<lettre><id>` :

| lettre | sens |
|---|---|
| `u` | PNJ (nom dans `Q.xx.u`) : donne la quete, la recoit, ou est une cible a tuer / a qui parler |
| `o` | objet du monde (nom dans `Q.xx.o`) : coffre, plante... |
| `i` | objet (nom dans `Q.xx.i` puis `D.xx.i`) : objet qui DEMARRE la quete (section 7) ou objet a RAMASSER (section 9) |
| `r` | objet requis (`IR` de pfQuest : objet a posseder / utiliser, non ramasse) ; section 9 uniquement |

Exemple : `"u12696"` = le PNJ 12696 ; `"i5692,i5693,r5692,+"` = objets a ramasser 5692 et 5693, objet requis 5692, et d'autres objectifs non listes.
L'ordre des references est l'ordre de pfQuest : PNJ, puis objets du monde, puis objets (puis objets requis pour les objectifs). Les `.n` des epingles renvoient a la position `n` (a partir de 1) dans la liste de la meme section
(`S` -> section 7, `E` -> section 8, `O` -> section 9).

## 5. Recompenses des quetes de donjon (section 11)

Seulement 304 quetes (celles d'Atlas `QuestData` dont l'id existe dans pfQuest ; 21 id d'Atlas n'existent pas dans pfQuest : leurs recompenses ne sont pas gardees) : `<mode>:<id>,<id>,...`.

| mode | sens |
|---|---|
| `a` | toutes les recompenses sont donnees (texte Atlas vide, "all", ou numeros listes) |
| `p` | une seule a choisir ("Pick one") |
| `x` | regle speciale : voir `Q.rr[idQuete]` (texte anglais d'Atlas : `"1 and 2 or 3"` = les recompenses 1 et 2 sont donnees, ou la 3 ; les numeros sont les positions dans la liste) |

Un id peut etre suivi de `@<masque>` pour un masque de profil de serveur (comme `FORMAT.md` section 2) ; l'outil n'en produit aucun aujourd'hui (Atlas n'en met pas sur les recompenses), un lecteur doit
cependant l'accepter. Noms des objets : `R.entityName` (les recompenses sont des objets). 638 objets de recompense au total.

## 6. Epingles de carte (section 10)

Forme : `zone:jeton,jeton,.../zone:jeton,...` : les epingles sont GROUPEES par zone (ids croissants), jamais une table par point. Jeton = `<type><valeur>[.<ref>]` :

* `type` : `S` (depart), `E` (fin), `O` (objectif) ;
* `valeur` : `round(x * 10) * 1024 + round(y * 10)` ou `x` et `y` sont des POURCENTAGES de la carte de la zone (0 a 100, une decimale) : on decode `xi = floor(valeur / 1024)`, `yi = valeur - xi * 1024`, `x = xi / 10`, `y = yi / 10`.
  Coordonnees pfQuest : 0..100 depuis le coin haut-gauche de la carte de la zone (meme convention que `GetPlayerMapPosition` * 100) ;
* `ref` : numero (a partir de 1) de l'entite de la section 7 / 8 / 9 qui est a l'origine de l'epingle (absent ou 0 = inconnu) : permet d'afficher son nom.

Plafonds : 2 epingles de depart, 2 de fin, 8 d'objectif par quete. Elles sont ISSUES d'un regroupement par zone et par cellule (1,5 % de carte pour depart et fin, 8 % pour les objectifs) :
tous les points d'une cellule sont fusionnes en un seul (moyenne), les cellules les plus peuplees sont gardees. Une epingle est donc une APPROXIMATION a quelques % pres, pas une position exacte.
Si la quete n'a pas de PNJ ou d'objet de depart mais un objet de depart (`i` section 7), les epingles de depart viennent des 3 meilleures sources de cet objet (106 quetes). Les objectifs `i` utilisent aussi les 3
meilleures sources de l'objet. Au total 29392 epingles (depart 7767, fin 7915, objectifs 13710) ; 6456 quetes en ont au moins une ; 0 coordonnee hors de 0..100.
Epingler seulement si `Q.zk[zone]` est present (carte du monde connue) ; sinon proposer le nom de la zone sans epingle.

## 7. Exemples reels

```
q[6]  = "5;2;589;;12;18;u823;u823;i182;12:S493997.1,E493997.1,O589283.1"
q[1079] = "22;17;589;;406;1074,1077;u4077;u4077;i5692,i5693,i5694,i5695,i5718,r5692,r5693,r5694,+;406:S609951.1,E609951.1,O677377.5"
```

`q[6]` : niveau 5, niveau minimum 2, Alliance (589), toutes classes, zone 12 (Elwynn Forest), predecesseur 18 ; demarre et finit chez le PNJ 823 ; objectif = l'objet 182 ; epingles
(zone 12) : depart a x=`floor(493997/1024)/10 = 48,2`, y=`(493997 - 482*1024)/10 = 42,9`, fin au meme endroit, objectif a 57,5 / 48,3 (vient de la 1re entite de la section 9).
`q[1079]` : objectifs tronques (`+`), la 5e epingle `O677377.5` (x = 66,1 ; y = 51,3) renvoie au 5e objectif (`i5718`).

## 8. Ce qui n'est PAS dans les donnees

Textes de quete (description, objectif, recompense en or ou en experience), recompenses hors quetes de donjon, repetabilite, partage de groupe, quetes de PvP, coordonnees exactes (epingles approchees),
lien quete -> instance, noms francais des quetes ajoutees par Turtle (pfQuest n'en a pas : repli sur l'anglais), PNJ sans nom, quetes ecartees (section 3).

## 9. Lecteur de reference (Lua 5.0)

`Q` est `ShikiCodexQuests`, `D` est `ShikiCodexData` (pour les noms d'objets), `lang` vaut `"enUS"` ou `"frFR"`.

```lua reference-reader-quests
local R = {}
local floor = math.floor

local RACE_BIT = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128 }
local CLASS_BIT = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }

function R.raceBit(englishRace) return RACE_BIT[englishRace] end
function R.classBit(classToken) return CLASS_BIT[classToken] end

function R.hasBit(m, b)
  local q = floor(m / b)
  return q - floor(q / 2) * 2 == 1
end

-- decoupe sur un separateur litteral ; garde les champs vides ; "" donne { "" }
function R.split(s, sep)
  local out = {}
  local pos = 1
  local a = string.find(s, sep, pos, true)
  while a do
    table.insert(out, string.sub(s, pos, a - 1))
    pos = a + string.len(sep)
    a = string.find(s, sep, pos, true)
  end
  table.insert(out, string.sub(s, pos))
  return out
end

-- "u12,o5,i7,r9,+" -> { { kind = "u", id = 12 }, ... }, tronque (true si un "+" final)
function R.refs(s)
  local out = {}
  local more = false
  if not s or s == "" then return out, more end
  local t = R.split(s, ",")
  local i = 1
  while t[i] do
    if t[i] == "+" then
      more = true
    else
      table.insert(out, { kind = string.sub(t[i], 1, 1), id = tonumber(string.sub(t[i], 2)) })
    end
    i = i + 1
  end
  return out, more
end

-- "12:S493997.1,E493997.1/40:O685330.1" -> liste de { kind = "S"|"E"|"O", zone = id, x = %, y = %, ref = n (0 = inconnu) }
function R.pins(s)
  local out = {}
  if not s or s == "" then return out end
  local groups = R.split(s, "/")
  local g = 1
  while groups[g] do
    local c = string.find(groups[g], ":", 1, true)
    local zone = tonumber(string.sub(groups[g], 1, c - 1))
    local toks = R.split(string.sub(groups[g], c + 1), ",")
    local k = 1
    while toks[k] do
      local tok = toks[k]
      local dot = string.find(tok, ".", 1, true)
      local ref = 0
      local v
      if dot then
        ref = tonumber(string.sub(tok, dot + 1))
        v = tonumber(string.sub(tok, 2, dot - 1))
      else
        v = tonumber(string.sub(tok, 2))
      end
      local xi = floor(v / 1024)
      table.insert(out, { kind = string.sub(tok, 1, 1), zone = zone, x = xi / 10, y = (v - xi * 1024) / 10, ref = ref })
      k = k + 1
    end
    g = g + 1
  end
  return out
end

-- "a:1,2" / "p:3,4" / "x:5,6,7" (ids suivis de @masque possible) -> { mode = "a"|"p"|"x", items = { id, ... } }
function R.reward(s)
  if not s or s == "" then return nil end
  local out = { mode = string.sub(s, 1, 1), items = {} }
  local t = R.split(string.sub(s, 3), ",")
  local i = 1
  while t[i] do
    local at = string.find(t[i], "@", 1, true)
    if at then
      table.insert(out.items, { id = tonumber(string.sub(t[i], 1, at - 1)), mask = tonumber(string.sub(t[i], at + 1)) })
    else
      table.insert(out.items, { id = tonumber(t[i]) })
    end
    i = i + 1
  end
  return out
end

-- decode complet d'une quete (nil si absente)
function R.quest(Q, id)
  local s = Q.q[id]
  if not s then return nil end
  local f = R.split(s, ";")
  local q = { id = id }
  q.lvl = tonumber(f[1]) or 0
  q.min = tonumber(f[2]) or 0
  q.race = tonumber(f[3]) or 0
  q.class = tonumber(f[4]) or 0
  q.zone = tonumber(f[5]) or 0
  q.pre = {}
  if f[6] and f[6] ~= "" then
    local p = R.split(f[6], ",")
    local i = 1
    while p[i] do
      table.insert(q.pre, tonumber(p[i]))
      i = i + 1
    end
  end
  q.start = R.refs(f[7])
  q.finish = R.refs(f[8])
  q.obj, q.objMore = R.refs(f[9])
  q.pins = R.pins(f[10])
  q.reward = R.reward(f[11])
  if f[12] and f[12] ~= "" then
    local m = R.split(f[12], ",")
    local i = 1
    while m[i] do
      local kind = string.sub(m[i], 1, 1)
      if kind == "s" then q.skill = tonumber(string.sub(m[i], 2)) end
      if kind == "e" then q.event = tonumber(string.sub(m[i], 2)) end
      i = i + 1
    end
  end
  return q
end

-- le joueur peut-il prendre la quete ? raceBit / classBit : voir R.raceBit / R.classBit ; level : niveau du joueur
function R.eligible(q, level, raceBit, classBit)
  if q.min > 0 and level < q.min then return false end
  if q.race ~= 0 and raceBit and not R.hasBit(q.race, raceBit) then return false end
  if q.class ~= 0 and classBit and not R.hasBit(q.class, classBit) then return false end
  return true
end

function R.title(Q, id, lang)
  if lang == "frFR" and Q.fr.t[id] then return Q.fr.t[id] end
  return Q.en.t[id]
end

-- kind : "u" PNJ, "o" objet du monde, "i" objet, "r" objet requis (= "i")
function R.entityName(Q, D, kind, id, lang)
  if kind == "r" then kind = "i" end
  if lang == "frFR" and Q.fr[kind][id] then return Q.fr[kind][id] end
  if Q.en[kind][id] then return Q.en[kind][id] end
  if kind == "i" and D then
    if lang == "frFR" and D.fr.i[id] then return D.fr.i[id] end
    return D.en.i[id]
  end
  return nil
end

-- nom de zone a comparer avec GetMapZones (client localise) ; nil + 0 si la zone n'a pas de carte du monde
function R.zoneName(Q, z, lang)
  if lang == "frFR" and Q.fr.z[z] then return Q.fr.z[z], Q.zk[z] or 0 end
  return Q.en.z[z], Q.zk[z] or 0
end

return R
```
