# ShikiCodexData_Mobs - format

`ShikiCodexMobs.m[id] = "min;max;zone:tok,tok/zone:tok"` : niveaux du monstre (0 = inconnu) puis points par zone (jeton = round(x*10)*1024 + round(y*10), x et y en % de la carte de la zone, meme codage que FORMAT_QUESTS.md section 6). Les zones sont celles de ShikiCodexQuests.zk.

`ShikiCodexMobs.d[itemId] = "monstre:pourcent,monstre:pourcent"` : les monstres qui lachent l'objet, du plus frequent au moins frequent.

`ShikiCodexMobs.n.en[id]` / `.fr[id]` : noms (le francais seulement quand il est sur).
