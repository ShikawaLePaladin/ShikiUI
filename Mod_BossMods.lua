-- ShikiUI BossMods : alarmes de raid (module "bossmods"), moteur maison inspire des PRINCIPES de BigWigs (aucun code copie) :
-- des barres de compte a rebours et des annonces quand un evenement de boss arrive.
--
-- Fonctionnement :
--   1. la cible du joueur (ou la souris) est reconnue comme un boss connu : nom plie (accents FR ignores) ;
--   2. l'entree en combat avec ce boss fixe t0 ; chaque evenement du boss est RELATIF au combat
--      (t = premier declenchement en secondes, every = repetition) ;
--   3. "lead" secondes avant l'evenement : la barre s'allume ("Nom - 10s") et l'annonce part (canal au choix) ;
--   4. a 0 la barre part : l'effet arrive, la barre disparait ; les repetitions replanifient tout seuls.
-- Donnees vanilla d'abord (MC, Onyxia, BWL, ZG, AQ20, AQ40, Naxxramas, boss monde) : valeurs publies des guides,
-- NON VERIFIEES EN JEU (variations de serveurs possibles). La table M.BOSSES est publique et documentee pour ajouter
-- des boss / instances custom OctoWow (cle = nom du boss plie, valeurs identite EN acceptees pour les mobs non traduits).
-- Cout declare : "medium" (balayage 0,25 s tant qu'un boss connu est vise ou la fenetre ouverte ; sinon 0).
-- Lua 5.0 : pas de '#', '%', '...', select, string.match ; au plus 32 upvalues par fonction ; aucune globale non declaree.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.BossMods = M

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local floor, mmin, mmax = math.floor, math.min, math.max
local sfind, slower, sgsub, strsub = string.find, string.lower, string.gsub, string.sub
local EMPTY = ""

M.on = false
M.win = nil
M.task = nil
M.cur = nil            -- cle pliee du boss courant, ou nil
M.curLabel = EMPTY
M.combatAt = nil       -- instant d'entree en combat avec ce boss
M.armed = {}           -- barres en cours : { name, endsAt, dur, ev, phase, pull }
M.narmed = 0
M.flash = nil          -- frame de flash d'ecran (creee hors combat)
M.flashUntil = nil
M.pullIgnore = nil     -- ignore les pulls recus juste apres avoir lance le notre
M.next = {}             -- [evenement] = moment du prochain declenchement
M.warns = {}            -- [evenement] = instant de l'annonce lead (antidoublon)

M.BARH = 15
M.GAP = 2
M.MAXBARS = 8

-- ---------------------------------------------------------------- donnees vanilla
-- Chaque boss : label (affichage) + ev = liste d'evenements :
--   t     : premier declenchement relatif a l'entree en combat (secondes)
--   every : repetition (toutes les N secondes)
--   dur   : duree de l'effet (longueur de barre apres le lancement)
--   warn  : annonce RAID au moment de la mise en place
-- Valeurs = guides vanilla publies, NON VERIFIEES EN JEU (voir entete).
M.BOSSES = {
	["antnormi"] = {
		label = "Antnormi",
		ev = {
			{ t = 20, every = 20, name = "Fear CD", dur = 3, warn = true },
			{ t = 5, every = 5, name = "Feared!", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Shadow Shock CD", dur = 3, warn = true },
		},
	},
	["anubisath defender"] = {
		label = "Anubisath Defender",
		ev = {
			{ t = 600, every = 600, name = "Fire & Arcane Reflect", dur = 3, icon = "Interface\\Icons\\spell_arcane_portaldarnassus", warn = true },
			{ t = 600, every = 600, name = "Shadow & Frost Reflect", dur = 3, icon = "Interface\\Icons\\spell_arcane_portalundercity", warn = true },
			{ t = 40, every = 40, name = "Plagued", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", warn = true },
			{ t = 600, every = 600, name = "Thunder Clap", dur = 3, icon = "Interface\\Icons\\Ability_ThunderClap", warn = true },
			{ t = 600, every = 600, name = "Shadow Storm", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadowbolt", warn = true },
			{ t = 600, every = 600, name = "Meteor", dur = 3, icon = "Interface\\Icons\\Spell_Fire_Fireball02", warn = true },
			{ t = 6, every = 6, name = "Exploding!", dur = 3, icon = "Interface\\Icons\\spell_fire_selfdestruct", warn = true },
		},
	},
	["anubisath guardian"] = {
		label = "Anubisath Guardian",
		ev = {
			{ t = 600, every = 600, name = "Fire & Arcane Reflect", dur = 3, icon = "Interface\\Icons\\spell_arcane_portaldarnassus", warn = true },
			{ t = 600, every = 600, name = "Shadow & Frost Reflect", dur = 3, icon = "Interface\\Icons\\spell_arcane_portalundercity", warn = true },
			{ t = 40, every = 40, name = "Plagued", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", warn = true },
			{ t = 600, every = 600, name = "Thunder Clap CD", dur = 3, icon = "Interface\\Icons\\Ability_ThunderClap", warn = true },
			{ t = 600, every = 600, name = "Shadow Storm CD", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadowbolt", warn = true },
			{ t = 600, every = 600, name = "Meteor CD", dur = 3, icon = "Interface\\Icons\\Spell_Fire_Fireball02", warn = true },
			{ t = 6, every = 6, name = "Exploding!", dur = 3, icon = "Interface\\Icons\\spell_fire_selfdestruct", warn = true },
		},
	},
	["anubisath sentinel"] = {
		label = "Anubisath Sentinel",
		ev = {
			{ t = 600, every = 600, name = "has Knockback", dur = 3, icon = "Interface\\Icons\\Inv_Gauntlets_05", warn = true },
			{ t = 600, every = 600, name = "has Mana Burn", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_Manaburn", warn = true },
			{ t = 600, every = 600, name = "has Mending", dur = 3, icon = "Interface\\Icons\\spell_nature_resistnature", warn = true },
			{ t = 600, every = 600, name = "has Mortal Strike", dur = 3, icon = "Interface\\Icons\\ability_warrior_savageblow", warn = true },
			{ t = 600, every = 600, name = "has Shadow Storm", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadowbolt", warn = true },
			{ t = 600, every = 600, name = "has Thorns", dur = 3, icon = "Interface\\Icons\\Spell_Nature_Thorns", warn = true },
			{ t = 600, every = 600, name = "has Thunderclap", dur = 3, icon = "Interface\\Icons\\Ability_ThunderClap", warn = true },
			{ t = 600, every = 600, name = "reflect Fire & Arcane", dur = 3, icon = "Interface\\Icons\\spell_arcane_portaldarnassus", warn = true },
			{ t = 600, every = 600, name = "reflect Shadow & Frost", dur = 3, icon = "Interface\\Icons\\spell_arcane_portalundercity", warn = true },
		},
	},
	["atiesh"] = {
		label = "Atiesh",
		ev = {
			{ t = 2, every = 2, name = "Unholy Aura", dur = 3, icon = "Interface\\Icons\\spell_shadow_unholystrength", warn = true },
		},
	},
	["ayamiss the hunter"] = {
		label = "Ayamiss",
		ev = {
			{ t = 25, every = 25, name = "Stinger Spray", dur = 3 },
		},
	},
	-- ===== AQ40 =====
	["the prophet skeram"] = {
		label = "Skeram",
		ev = {
			{ t = 25, every = 25, name = "Earth Shock", dur = 3 },
		},
	},
	["azuregos"] = {
		label = "Azuregos",
		ev = {
			{ t = 24, every = 24, name = "Chill CD", dur = 3, warn = true },
			{ t = 30, every = 30, name = "Arcane Vacuum CD", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Arcane Vacuum Ready...", dur = 3, warn = true },
		},
	},
	["baron geddon"] = {
		label = "Baron Geddon",
		ev = {
			{ t = 8, every = 8, name = "Bomb!", dur = 3, icon = "Interface\\Icons\\inv_enchant_essenceastralsmall", warn = true },
		},
	},
	["battleguard sartura"] = {
		label = "Sartura",
		ev = {
			{ t = 45, every = 45, name = "Whirlwind", dur = 5, warn = true },
		},
	},
	["bloodlord mandokir"] = {
		label = "Bloodlord Mandokir",
		ev = {
			{ t = 12, every = 12, name = "Threatening Gaze CD", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Gaze!", dur = 3, warn = true },
			{ t = 18, every = 18, name = "Whirlwind CD", dur = 3, warn = true },
		},
	},
	["brood queen araxxna"] = {
		label = "Brood Queen Araxxna",
		ev = {
			{ t = 8, every = 8, name = "Brood Venom Volley", dur = 3, icon = "Interface\\Icons\\Spell_Nature_InsectSwarm", warn = true },
			{ t = 10, every = 10, name = "Leeching Bite", dur = 3, icon = "Interface\\Icons\\ability_poisonsting", warn = true },
			{ t = 20, every = 20, name = "Skitterweb Egg Hatch", dur = 3, icon = "Interface\\Icons\\inv_egg_02", warn = true },
		},
	},
	["broodlord lashlayer"] = {
		label = "Broodlord Lashlayer",
		ev = {
			{ t = 20, every = 20, name = "Mortal Strike CD", dur = 3, warn = true },
		},
	},
	["broodlord lushwing"] = {
		label = "Broodlord",
		ev = {
			{ t = 30, every = 30, name = "Blast Wave", dur = 3 },
		},
	},
	["buru the gorger"] = {
		label = "Buru the Gorger",
		ev = {
			{ t = 10, every = 10, name = "Dismember", dur = 3, icon = "Interface\\Icons\\ability_backstab", warn = true },
		},
	},
	["c'thun"] = {
		label = "C'Thun",
		ev = {
			{ t = 45, every = 45, name = "Eye Beam", dur = 3, warn = true },
			{ t = 40, every = 40, name = "Dark Glare", dur = 3, warn = true },
		},
	},
	-- ===== NAXX =====
	["anub'rekhan"] = {
		label = "Anub'Rekhan",
		ev = {
			{ t = 20, every = 20, name = "Locust Swarm", dur = 12, warn = true },
		},
	},
	["chieftain partath"] = {
		label = "Chieftain Partath",
		ev = {
			{ t = 15, every = 15, name = "Immune", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker", warn = true },
		},
	},
	["chromaggus"] = {
		label = "Chromaggus",
		ev = {
			{ t = 12, every = 12, name = "Breath", dur = 3, warn = true },
		},
	},
	["chronar"] = {
		label = "Chronar",
		ev = {
			{ t = 10, every = 10, name = "Spell Reflect", dur = 3, icon = "Interface\\Icons\\Spell_Arcane_Blink", warn = true },
			{ t = 5, every = 5, name = "Mortal Strike", dur = 3, icon = "Interface\\Icons\\ability_warrior_savageblow", warn = true },
		},
	},
	["core hound"] = {
		label = "Core Hound",
		ev = {
			{ t = 10, every = 10, name = "Respawn", dur = 3, icon = "Interface\\Icons\\spell_holy_resurrection", warn = true },
			{ t = 11, every = 11, name = "Despawn", dur = 3, icon = "Interface\\Icons\\inv_misc_pocketwatch_01", warn = true },
		},
	},
	["cthun"] = {
		label = "C'Thun",
		ev = {
			{ t = 8, every = 8, name = "Start of Random Beams!", dur = 3, warn = true },
			{ t = 39, every = 39, name = "Dark Glare!", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Small Claw Spawn", dur = 3, icon = "Interface\\Icons\\spell_nature_thorns", warn = true },
		},
	},
	["dark reaver of karazhan"] = {
		label = "Dark Reaver of Karazhan",
		ev = {
			{ t = 22, every = 22, name = "4 Forlorn Spirit", dur = 3, icon = "Interface\\Icons\\spell_shadow_burningspirit", warn = true },
			{ t = 10, every = 10, name = "Lurking Shadow", dur = 3, icon = "Interface\\Icons\\ability_creature_poison_05", warn = true },
			{ t = 6, every = 6, name = "Unbalancing", dur = 3, icon = "Interface\\Icons\\ability_warrior_decisivestrike", warn = true },
			{ t = 20, every = 20, name = "Pierce Armor", dur = 3, icon = "Interface\\Icons\\spell_shadow_vampiricaura", warn = true },
		},
	},
	["dark rider champion"] = {
		label = "Dark Rider Champion",
		ev = {
			{ t = 5.5, every = 5.5, name = "Reaver Storm CD", dur = 3, warn = true },
			{ t = 1.5, every = 1.5, name = "Reaver Storm Cast", dur = 3, warn = true },
		},
	},
	["deathknight cavalier"] = {
		label = "Deathknight Cavalier",
		ev = {
			{ t = 3, every = 3, name = "Death Coil", dur = 3, icon = "Interface\\Icons\\spell_shadow_deathcoil", warn = true },
		},
	},
	["doctor weavil"] = {
		label = "Doctor Weavil",
		ev = {
			{ t = 10, every = 10, name = "Mind Shatter CD", dur = 3, warn = true },
			{ t = 6, every = 6, name = "Mind Shatter Soon...", dur = 3, warn = true },
		},
	},
	["drifting avatar of sand"] = {
		label = "Drifting Avatar of Sand",
		ev = {
			{ t = 5, every = 5, name = "Blinded", dur = 3, icon = "Interface\\Icons\\spell_shadow_mindsteal", warn = true },
		},
	},
	["ebonroc"] = {
		label = "Ebonroc",
		ev = {
			{ t = 29, every = 29, name = "Wing Buffet CD", dur = 3, warn = true },
			{ t = 14, every = 14, name = "Shadow Flame CD", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Shadow of Ebonroc CD", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Shadow of Ebonroc", dur = 3, warn = true },
		},
	},
	["echo of medivh"] = {
		label = "Echo of Medivh",
		ev = {
			{ t = 12, every = 12, name = "Corruption of Medivh", dur = 3, icon = "Interface\\Icons\\INV_Misc_ShadowEgg", warn = true },
		},
	},
	["emperor vek'lor"] = {
		label = "Vek'lor",
		ev = {
			{ t = 30, every = 30, name = "Explode Bug", dur = 3 },
		},
	},
	["epidamu"] = {
		label = "Epidamu",
		ev = {
			{ t = 5, every = 5, name = "Drain Mana", dur = 3, icon = "Interface\\Icons\\spell_shadow_siphonmana", warn = true },
			{ t = 15, every = 15, name = "Temporal Conflux", dur = 3, icon = "Interface\\Icons\\spell_holy_borrowedtime", warn = true },
		},
	},
	["erennius"] = {
		label = "Erennius",
		ev = {
			{ t = 6, every = 6, name = "Wail Casting", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
			{ t = 3, every = 3, name = "Wail Afflicted", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
			{ t = 26, every = 26, name = "Wail of Erennius CD", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
		},
	},
	["fankriss the unyielding"] = {
		label = "Fankriss the Unyielding",
		ev = {
			{ t = 8, every = 8, name = "Entangled", dur = 3, icon = "Interface\\Icons\\Spell_Nature_Web", warn = true },
			{ t = 15, every = 15, name = "Wounds", dur = 3, icon = "Interface\\Icons\\ability_criticalstrike", warn = true },
		},
	},
	["firemaw"] = {
		label = "Firemaw",
		ev = {
			{ t = 29, every = 29, name = "Wing Buffet CD", dur = 3, warn = true },
			{ t = 14, every = 14, name = "Shadow Flame CD", dur = 3, warn = true },
		},
	},
	["flame imp"] = {
		label = "Flame Imp",
		ev = {
			{ t = 420, every = 420, name = "Respawn", dur = 3, icon = "Interface\\Icons\\inv_misc_pocketwatch_01", warn = true },
		},
	},
	["flamegor"] = {
		label = "Flamegor",
		ev = {
			{ t = 29, every = 29, name = "Wing Buffet CD", dur = 3, warn = true },
			{ t = 14, every = 14, name = "Shadow Flame CD", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Frenzy CD", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Frenzy!", dur = 3, warn = true },
		},
	},
	["gahzranka"] = {
		label = "Gahz'ranka",
		ev = {
			{ t = 2, every = 2, name = "FrostBreath Dmg+ManaBurn", dur = 3, warn = true },
			{ t = 7, every = 7, name = "Frost Breath CD", dur = 3, warn = true },
			{ t = 1.5, every = 1.5, name = "knockUP - Aggro Drop", dur = 3, warn = true },
			{ t = 19, every = 19, name = "knockUP AggroDrop CD", dur = 3, warn = true },
			{ t = 15, every = 15, name = "knockBACK - CD", dur = 3, icon = "Interface\\Icons\\ability_devour", warn = true },
		},
	},
	["garr"] = {
		label = "Garr",
		ev = {
			{ t = 20, every = 20, name = "Antimagic Pulse", dur = 3, icon = "Interface\\Icons\\spell_holy_dispelmagic", warn = true },
		},
	},
	["gehennas"] = {
		label = "Gehennas",
		ev = {
			{ t = 12, every = 30, name = "Gehennas' Curse", dur = 3 },
			{ t = 10, every = 10, name = "Shadow Bolt", dur = 3 },
		},
	},
	["general drakkisath"] = {
		label = "General Drakkisath",
		ev = {
			{ t = 10, every = 10, name = "Conflag", dur = 3, icon = "Interface\\Icons\\spell_fire_incinerate", warn = true },
		},
	},
	["general rajaxx"] = {
		label = "General Rajaxx",
		ev = {
			{ t = 34.72, every = 34.72, name = "Encounter begins", dur = 3, icon = "Interface\\Icons\\Inv_Misc_PocketWatch_01", warn = true },
			{ t = 10, every = 10, name = "Marked", dur = 3, icon = "Interface\\Icons\\Ability_Hunter_SniperShot", warn = true },
		},
	},
	["gluth"] = {
		label = "Gluth",
		ev = {
			{ t = 105, every = 105, name = "Decimate", dur = 3, icon = "Interface\\Icons\\INV_Shield_01", warn = true },
			{ t = 330, every = 330, name = "Enrage", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
			{ t = 15, every = 15, name = "Wounds", dur = 3, icon = "Interface\\Icons\\ability_criticalstrike", warn = true },
		},
	},
	["golemagg the incinerator"] = {
		label = "Golemagg the Incinerator",
		ev = {
			{ t = 3, every = 3, name = "Earthquake", dur = 3, icon = "Interface\\Icons\\spell_nature_earthquake", warn = true },
		},
	},
	["gothik the harvester"] = {
		label = "Gothik the Harvester",
		ev = {
			{ t = 20, every = 20, name = "Trainee - ", dur = 3, icon = "Interface\\Icons\\Ability_Seal", warn = true },
			{ t = 30, every = 30, name = "Rider - ", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_DeathPact", warn = true },
		},
	},
	["grand widow faerlina"] = {
		label = "Grand Widow Faerlina",
		ev = {
			{ t = 30, every = 30, name = "Boss Silenced", dur = 3, icon = "Interface\\Icons\\Spell_Holy_Silence", warn = true },
			{ t = 8, every = 8, name = "Raid member Silenced", dur = 3, warn = true },
		},
	},
	["grilek"] = {
		label = "Gri'lek",
		ev = {
			{ t = 10, every = 10, name = "Avatar CD", dur = 3, warn = true },
			{ t = 15, every = 15, name = "Avatar!", dur = 3, warn = true },
			{ t = 2, every = 2, name = "Gri'lek Stunned", dur = 3, icon = "Interface\\Icons\\spell_frost_stun", warn = true },
			{ t = 18, every = 18, name = "Ground Tremor CD", dur = 3, warn = true },
			{ t = 2, every = 2, name = "Ground Tremor Stun", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Rooted", dur = 3, icon = "Interface\\Icons\\spell_nature_stranglevines", warn = true },
			{ t = 20, every = 20, name = "Sweeping Strikes!", dur = 3, icon = "Interface\\Icons\\ability_rogue_slicedice", warn = true },
		},
	},
	["grizikil"] = {
		label = "Grizikil",
		ev = {
			{ t = 9, every = 9, name = "Flamewave", dur = 3, icon = "Interface\\Icons\\spell_fire_incinerate", warn = true },
		},
	},
	["grobbulus"] = {
		label = "Grobbulus",
		ev = {
			{ t = 12, every = 12, name = "Poison Cloud", dur = 3, warn = true },
		},
	},
	["gurubashi berserker"] = {
		label = "Gurubashi Berserker",
		ev = {
			{ t = 25, every = 25, name = "Fear CD", dur = 3, icon = "Interface\\Icons\\Ability_GolemThunderClap", warn = true },
			{ t = 10, every = 10, name = "KnockAway CD", dur = 3, icon = "Interface\\Icons\\INV_Gauntlets_05", warn = true },
			{ t = 15, every = 15, name = "Thunderclap CD", dur = 3, icon = "Interface\\Icons\\Ability_ThunderClap", warn = true },
		},
	},
	["hakkar"] = {
		label = "Hakkar",
		ev = {
			{ t = 11, every = 11, name = "MC CD", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Blood Siphon!", dur = 3, warn = true },
			{ t = 600, every = 600, name = "Enrage", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
		},
	},
	["hazzarah"] = {
		label = "Hazza'rah",
		ev = {
			{ t = 24, every = 24, name = "Adds Spawn", dur = 3, icon = "Interface\\Icons\\spell_magic_lesserinvisibilty", warn = true },
			{ t = 18, every = 18, name = "Sleep CD", dur = 3, warn = true },
			{ t = 6, every = 6, name = "Sleeping!", dur = 3, warn = true },
			{ t = 60, every = 60, name = "AoE Mana Burn CD", dur = 3, icon = "Interface\\Icons\\spell_shadow_manaburn", warn = true },
		},
	},
	["heigan the unclean"] = {
		label = "Heigan",
		ev = {
			{ t = 15, every = 15, name = "Eruption", dur = 3 },
		},
	},
	["high priest thekal"] = {
		label = "High Priest Thekal",
		ev = {
			{ t = 6, every = 6, name = "Silenced", dur = 3, icon = "Interface\\Icons\\Spell_Holy_Silence", warn = true },
			{ t = 6, every = 6, name = "Disarmed", dur = 3, icon = "Interface\\Icons\\Ability_Warrior_Disarm", warn = true },
			{ t = 10, every = 10, name = "Blinded", dur = 3, icon = "Interface\\Icons\\spell_shadow_mindsteal", warn = true },
			{ t = 4, every = 4, name = "Gouged", dur = 3, icon = "Interface\\Icons\\ability_gouge", warn = true },
			{ t = 5, every = 5, name = "Mortal Cleave", dur = 3, icon = "Interface\\Icons\\Ability_Warrior_SavageBlow", warn = true },
			{ t = 30, every = 30, name = "Bloodlust", dur = 3, icon = "Interface\\Icons\\Spell_Nature_BloodLust", warn = true },
			{ t = 10, every = 10, name = "Resurrect", dur = 3, icon = "Interface\\Icons\\spell_holy_resurrection", warn = true },
		},
	},
	["high priest venoxis"] = {
		label = "High Priest Venoxis",
		ev = {
			{ t = 15, every = 15, name = "Renew", dur = 3, icon = "Interface\\Icons\\Spell_Holy_Renew", warn = true },
			{ t = 8, every = 8, name = "Holy Fire", dur = 3, warn = true },
		},
	},
	["high priestess arlokk"] = {
		label = "High Priestess Arlokk",
		ev = {
			{ t = 120, every = 120, name = "Marked", dur = 3, icon = "Interface\\Icons\\Ability_Hunter_Snipershot", warn = true },
			{ t = 16, every = 16, name = "Whirlwind CD", dur = 3, icon = "Interface\\Icons\\Ability_Whirlwind", warn = true },
			{ t = 2, every = 2, name = "Ravage Stun", dur = 3, icon = "Interface\\Icons\\spell_frost_stun", warn = true },
			{ t = 4, every = 4, name = "Gouged", dur = 3, icon = "Interface\\Icons\\ability_gouge", warn = true },
			{ t = 18, every = 18, name = "Shadow Word: Pain", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadowwordpain", warn = true },
		},
	},
	["high priestess jeklik"] = {
		label = "High Priestess Jeklik",
		ev = {
			{ t = 4, every = 4, name = "Heal - Interrupt!", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Heal CD", dur = 3, warn = true },
			{ t = 25, every = 25, name = "Mind Flay - Interrupt!", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_SiphonMana", warn = true },
			{ t = 10, every = 10, name = "Silence CD", dur = 3, warn = true },
			{ t = 10, every = 10, name = "People Silenced", dur = 3, warn = true },
		},
	},
	["incindis"] = {
		label = "Incindis",
		ev = {
			{ t = 5.5, every = 5.5, name = "Fire Nova!", dur = 3, icon = "Interface\\Icons\\spell_fire_selfdestruct", warn = true },
		},
	},
	["instructor razuvious"] = {
		label = "Instructor Razuvious",
		ev = {
			{ t = 25, every = 25, name = "Disrupting Shout", dur = 3, icon = "Interface\\Icons\\Ability_Warrior_WarCry", warn = true },
			{ t = 30, every = 30, name = "Unbalancing Strike", dur = 3, icon = "Interface\\Icons\\Ability_Warrior_DecisiveStrike", warn = true },
		},
	},
	["jindo the hexxer"] = {
		label = "Jindo",
		ev = {
			{ t = 25, every = 25, name = "Hex", dur = 3, warn = true },
		},
	},
	-- ===== AQ20 =====
	["general rajaxx"] = {
		label = "General Rajaxx",
		ev = {
			{ t = 30, every = 30, name = "Wave", dur = 5, warn = true },
		},
	},
	["karrsh the sentinel"] = {
		label = "Karrsh the Sentinel",
		ev = {
			{ t = 12, every = 12, name = "Furious Roar", dur = 3, icon = "Interface\\Icons\\Ability_Druid_DemoralizingRoar", warn = true },
		},
	},
	["kazzak"] = {
		label = "Kazzak",
		ev = {
			{ t = 30, every = 30, name = "Shadow Bolt Volley", dur = 3 },
		},
	},
	["keeper gnarlmoon"] = {
		label = "Keeper Gnarlmoon",
		ev = {
			{ t = 5, every = 5, name = "Lunar Shift Casting!", dur = 3, warn = true },
			{ t = 60, every = 60, name = "Owls Enrage", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
		},
	},
	["kel'thuzad"] = {
		label = "Kel'Thuzad",
		ev = {
			{ t = 20, every = 20, name = "Shadow Fissure", dur = 3 },
			{ t = 30, every = 30, name = "Frost Blast", dur = 3, warn = true },
		},
	},
	["king"] = {
		label = "King",
		ev = {
			{ t = 5, every = 5, name = "King's Fury - Hide!", dur = 3, icon = "Interface\\Icons\\Spell_Holy_HolyNova", warn = true },
			{ t = 11, every = 11, name = "Shield Bash", dur = 3, icon = "Interface\\Icons\\Ability_Warrior_ShieldBash", warn = true },
		},
	},
	["kurinnaxx"] = {
		label = "Kurinnaxx",
		ev = {
			{ t = 15, every = 15, name = "Wounds", dur = 3, icon = "Interface\\Icons\\ability_criticalstrike", warn = true },
			{ t = 20, every = 20, name = "Sand Trap", dur = 3, icon = "Interface\\Icons\\inv_misc_dust_02", warn = true },
		},
	},
	["lethon"] = {
		label = "Lethon",
		ev = {
			{ t = 20, every = 20, name = "Shadow Bolt Whirl", dur = 3 },
		},
	},
	["loatheb"] = {
		label = "Loatheb",
		ev = {
			{ t = 60, every = 60, name = "Your Corrupted Mind", dur = 3, icon = "Interface\\Icons\\spell_shadow_auraofdarkness", warn = true },
		},
	},
	["lord blackwald ii"] = {
		label = "Lord Blackwald II",
		ev = {
			{ t = 5.5, every = 5.5, name = "Reaver Storm CD", dur = 3, warn = true },
			{ t = 1.5, every = 1.5, name = "Reaver Storm Cast", dur = 3, warn = true },
			{ t = 15, every = 15, name = "Boon on ", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ChillTouch", warn = true },
			{ t = 10, every = 10, name = "Empowered", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_Haunting", warn = true },
			{ t = 45, every = 45, name = "Summons add", dur = 3, icon = "Interface\\Icons\\inv_misc_bone_orcskull_01", warn = true },
		},
	},
	["lord kazzak"] = {
		label = "Lord Kazzak",
		ev = {
			{ t = 180, every = 180, name = "Berserk", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
			{ t = 10, every = 10, name = "Mark of Kazzak CD", dur = 3, warn = true },
			{ t = 60, every = 60, name = "Mark of Kazzak", dur = 3, warn = true },
			{ t = 14, every = 14, name = "Twisted Reflection CD", dur = 3, warn = true },
			{ t = 45, every = 45, name = "Twisted Reflect", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Void Bolt CD", dur = 3, warn = true },
			{ t = 4, every = 4, name = "Void Bolt!", dur = 3, warn = true },
		},
	},
	["lucifron"] = {
		label = "Lucifron",
		ev = {
			{ t = 8, every = 8, name = "MC CD", dur = 3, warn = true },
			{ t = 15, every = 15, name = "MC ", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate", warn = true },
		},
	},
	["mad servant"] = {
		label = "Mad Servant",
		ev = {
			{ t = 11, every = 11, name = "Void Spawn - Portal ", dur = 3, icon = "Interface\\Icons\\spell_shadow_sealofkings", warn = true },
		},
	},
	["maexxna"] = {
		label = "Maexxna",
		ev = {
			{ t = 20, every = 20, name = "Cocoon CD", dur = 3, warn = true },
			{ t = 30, every = 30, name = "Spiderlings", dur = 3, icon = "Interface\\Icons\\INV_Misc_MonsterSpiderCarapace_01", warn = true },
		},
	},
	["magmadar"] = {
		label = "Magmadar",
		ev = {
			{ t = 30, every = 30, name = "Fear CD", dur = 3, warn = true },
			{ t = 5, every = 5, name = "Fear Soon...", dur = 3, warn = true },
		},
	},
	["majordomo executus"] = {
		label = "Majordomo Executus",
		ev = {
			{ t = 20, every = 20, name = "Reflection CD", dur = 3, warn = true },
		},
	},
	["mandokir"] = {
		label = "Mandokir",
		ev = {
			{ t = 60, every = 60, name = "Frightening Shout", dur = 3, warn = true },
		},
	},
	["mar'li"] = {
		label = "Mar'li",
		ev = {
			{ t = 20, every = 20, name = "Enrage", dur = 3 },
		},
	},
	["moam"] = {
		label = "Moam",
		ev = {
			{ t = 90, every = 90, name = "Mana Burn", dur = 3, warn = true },
		},
	},
	["moroes"] = {
		label = "Moroes",
		ev = {
			{ t = 10, every = 10, name = "Players Smoke Bombed", dur = 3, icon = "Interface\\Icons\\Ability_Vanish", warn = true },
			{ t = 5, every = 5, name = "Spell Reflect!", dur = 3, icon = "Interface\\Icons\\Spell_Arcane_Blink", warn = true },
			{ t = 4, every = 4, name = "Kicked", dur = 3, icon = "Interface\\Icons\\Ability_Kick", warn = true },
			{ t = 10, every = 10, name = "Dusted", dur = 3, icon = "Interface\\Icons\\Ability_Hibernation", warn = true },
		},
	},
	["mossheart"] = {
		label = "Mossheart",
		ev = {
			{ t = 180, every = 180, name = "Moss", dur = 3, icon = "Interface\\Icons\\spell_nature_magicimmunity", warn = true },
			{ t = 25, every = 25, name = "Entangling Roots CD", dur = 3, icon = "Interface\\Icons\\spell_nature_stranglevines", warn = true },
			{ t = 12, every = 12, name = "Rejuvenation", dur = 3, icon = "Interface\\Icons\\spell_nature_rejuvenation", warn = true },
		},
	},
	["nefarian"] = {
		label = "Nefarian",
		ev = {
			{ t = 12.4, every = 12.4, name = "AoE Shadow Flame", dur = 3, warn = true },
		},
	},
	["nerubian overseer"] = {
		label = "Nerubian Overseer",
		ev = {
			{ t = 10, every = 10, name = "Shadow Shock", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadowbolt", warn = true },
			{ t = 30, every = 30, name = "Venom Spit", dur = 3, icon = "Interface\\Icons\\spell_nature_corrosivebreath", warn = true },
			{ t = 30, every = 30, name = "Corrosive Poison", dur = 3, icon = "Interface\\Icons\\Corrosive Acid Spit", warn = true },
			{ t = 30, every = 30, name = "Necrotic Poison", dur = 3, icon = "Interface\\Icons\\ability_creature_poison_03", warn = true },
			{ t = 10, every = 10, name = "Web Spray", dur = 3, icon = "Interface\\Icons\\inv_egg_04", warn = true },
		},
	},
	["noth the plaguebringer"] = {
		label = "Noth",
		ev = {
			{ t = 25, every = 25, name = "Curse of the Plaguebringer", dur = 3, warn = true },
			{ t = 90, every = 90, name = "Blink", dur = 3 },
		},
	},
	["onyxia"] = {
		label = "Onyxia",
		ev = {
			{ t = 30, every = 30, name = "Deep Breath", dur = 3, warn = true },
		},
	},
	["ossirian the unscarred"] = {
		label = "Ossirian",
		ev = {
			{ t = 20, every = 20, name = "Tornado", dur = 3 },
		},
	},
	["ostarius"] = {
		label = "Ostarius",
		ev = {
			{ t = 10, every = 10, name = "Conflag", dur = 3, icon = "Interface\\Icons\\spell_fire_incinerate", warn = true },
			{ t = 12, every = 12, name = "Stomped", dur = 3, icon = "Interface\\Icons\\ability_warstomp", warn = true },
		},
	},
	["ouro"] = {
		label = "Ouro",
		ev = {
			{ t = 20, every = 20, name = "Sand Blast", dur = 3, warn = true },
		},
	},
	["patchwerk"] = {
		label = "Patchwerk",
		ev = {
			{ t = 420, every = 420, name = "Enrage", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
		},
	},
	["princess huhuran"] = {
		label = "Huhuran",
		ev = {
			{ t = 30, every = 30, name = "Wyvern Sting", dur = 3, warn = true },
			{ t = 30, every = 30, name = "Frenzy", dur = 3 },
		},
	},
	["pyroguard emberseer"] = {
		label = "Pyroguard Emberseer",
		ev = {
			{ t = 6, every = 6, name = "Fire Nova", dur = 3, icon = "Interface\\Icons\\spell_fire_sealoffire", warn = true },
		},
	},
	["qiraji brainwasher"] = {
		label = "Qiraji Brainwasher",
		ev = {
			{ t = 8, every = 8, name = "Mind Flay", dur = 3, icon = "Interface\\Icons\\spell_shadow_siphonmana", warn = true },
		},
	},
	["qiraji mindslayer"] = {
		label = "Qiraji Mindslayer",
		ev = {
			{ t = 8, every = 8, name = "Mind Flay", dur = 3, icon = "Interface\\Icons\\spell_shadow_siphonmana", warn = true },
			{ t = 8, every = 8, name = "Mana Burn & Disorient", dur = 3, icon = "Interface\\Icons\\spell_shadow_manaburn", warn = true },
		},
	},
	["ragnaros"] = {
		label = "Ragnaros",
		ev = {
			{ t = 90, every = 90, name = "Emerge", dur = 3, warn = true },
			{ t = 25, every = 25, name = "Knockback CD", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Knockback Soon...", dur = 3, warn = true },
		},
	},
	["razorgore the untamed"] = {
		label = "Razorgore the Untamed",
		ev = {
			{ t = 10, every = 10, name = "Slowed", dur = 3, icon = "Interface\\Icons\\spell_nature_slow", warn = true },
			{ t = 90, every = 90, name = "Orb Control", dur = 3, icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_03", warn = true },
			{ t = 60, every = 60, name = "Mind Exhaustion", dur = 3, icon = "Interface\\Icons\\spell_shadow_teleport", warn = true },
		},
	},
	["renataki"] = {
		label = "Renataki",
		ev = {
			{ t = 28, every = 28, name = "Vanish", dur = 3, icon = "Interface\\Icons\\ability_vanish", warn = true },
			{ t = 20, every = 20, name = "Return", dur = 3, icon = "Interface\\Icons\\ability_rogue_ambush", warn = true },
			{ t = 9, every = 9, name = "Gouge CD", dur = 3, icon = "Interface\\Icons\\ability_gouge", warn = true },
		},
	},
	["rotmaw"] = {
		label = "Rotmaw",
		ev = {
			{ t = 240, every = 240, name = "Contagion", dur = 3, icon = "Interface\\Icons\\spell_shadow_callofbone", warn = true },
			{ t = 15, every = 15, name = "Consumed", dur = 3, icon = "Interface\\Icons\\spell_nature_drowsy", warn = true },
		},
	},
	["sanctum dragonkin"] = {
		label = "Sanctum Dragonkin",
		ev = {
			{ t = 5, every = 5, name = "Dragonkin Spell Reflect", dur = 3, icon = "Interface\\Icons\\Spell_Arcane_Blink", warn = true },
		},
	},
	["sanctum dreamer"] = {
		label = "Sanctum Dreamer",
		ev = {
			{ t = 10, every = 10, name = "People Sleeping", dur = 3, icon = "Interface\\Icons\\Spell_Nature_Sleep", warn = true },
		},
	},
	["sanctum supressor"] = {
		label = "Sanctum Supressor",
		ev = {
			{ t = 12, every = 12, name = "Supression", dur = 3, icon = "Interface\\Icons\\Spell_Nature_MagicImmunity", warn = true },
		},
	},
	["sanctum wyrm"] = {
		label = "Sanctum Wyrm",
		ev = {
			{ t = 15, every = 15, name = "Poison Bolt Volley", dur = 3, icon = "Interface\\Icons\\Spell_Nature_CorrosiveBreath", warn = true },
		},
	},
	["sanctum wyrmkin"] = {
		label = "Sanctum Wyrmkin",
		ev = {
			{ t = 30, every = 30, name = "Venom", dur = 3, icon = "Interface\\Icons\\Ability_Creature_Poison_03", warn = true },
		},
	},
	["sanv tasdal"] = {
		label = "Sanv Tas'dal",
		ev = {
			{ t = 6, every = 6, name = "Overflowing Hatred", dur = 3, warn = true },
		},
	},
	["sapphiron"] = {
		label = "Sapphiron",
		ev = {
			{ t = 7, every = 7, name = "Frost Breath Exploding!", dur = 3, icon = "Interface\\Icons\\spell_frost_frostward", warn = true },
			{ t = 24, every = 24, name = "Life Drain", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_LifeDrain02", warn = true },
		},
	},
	["shazzrah"] = {
		label = "Shazzrah",
		ev = {
			{ t = 16, every = 16, name = "Counterspell CD", dur = 3, warn = true },
			{ t = 3, every = 3, name = "Counterspell Soon...", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Shazzrah's Curse CD", dur = 3, warn = true },
		},
	},
	["solakar flamewreath"] = {
		label = "Solakar Flamewreath",
		ev = {
			{ t = 40, every = 40, name = "Solakar spawns", dur = 3, warn = true },
			{ t = 5, every = 5, name = "Stun!", dur = 3, icon = "Interface\\Icons\\ability_bullrush", warn = true },
		},
	},
	["solnius"] = {
		label = "Solnius",
		ev = {
			{ t = 600, every = 600, name = "Solnius is Immune", dur = 3, icon = "Interface\\Icons\\Inv_Misc_Pocketwatch_01", warn = true },
			{ t = 45, every = 45, name = "Solnius is Sleeping", dur = 3, icon = "Interface\\Icons\\Inv_Misc_Pocketwatch_01", warn = true },
			{ t = 6, every = 6, name = "Wail Casting", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
			{ t = 3, every = 3, name = "Wail Afflicted", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
			{ t = 26, every = 26, name = "Wail of Erennius CD", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
		},
	},
	["sulfuron harbinger"] = {
		label = "Sulfuron Harbinger",
		ev = {
			{ t = 10, every = 10, name = "Hand of Ragnaros CD", dur = 3, warn = true },
			{ t = 2, every = 2, name = "Hand of Ragnaros Stun", dur = 3, warn = true },
		},
	},
	["taerar"] = {
		label = "Taerar",
		ev = {
			{ t = 20, every = 20, name = "Bane of Awakening", dur = 3 },
		},
	},
	["thaddius"] = {
		label = "Thaddius",
		ev = {
			{ t = 10, every = 10, name = "Power Surge", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
			{ t = 20.5, every = 20.5, name = "Magnetic Pull", dur = 3, icon = "Interface\\Icons\\spell_nature_groundingtotem", warn = true },
			{ t = 300, every = 300, name = "Enrage", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
		},
	},
	["the beast"] = {
		label = "The Beast",
		ev = {
			{ t = 10, every = 10, name = "Fear CD", dur = 3, warn = true },
			{ t = 5, every = 5, name = "Fear Duration", dur = 3, warn = true },
		},
	},
	["the bug family"] = {
		label = "The Bug Family",
		ev = {
			{ t = 20, every = 20, name = "Panic CD", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_DeathScream", warn = true },
			{ t = 2, every = 2, name = "Great Heal", dur = 3, icon = "Interface\\Icons\\Spell_Holy_Heal", warn = true },
		},
	},
	["the four horsemen"] = {
		label = "Four Horsemen",
		ev = {
			{ t = 12, every = 12, name = "Mark", dur = 3, warn = true },
		},
	},
	-- ===== MONDE =====
	["emeriss"] = {
		label = "Emeriss",
		ev = {
			{ t = 15, every = 15, name = "Volatile Infection", dur = 3 },
		},
	},
	["time-lord epochronos"] = {
		label = "Time-Lord Epochronos",
		ev = {
			{ t = 2, every = 2, name = "Sand Breath Cast", dur = 3, warn = true },
			{ t = 13, every = 13, name = "Sand Breath CD", dur = 3, warn = true },
			{ t = 30, every = 30, name = "Banish", dur = 3, icon = "Interface\\Icons\\spell_shadow_cripple", warn = true },
			{ t = 30, every = 30, name = "Devouring Plague", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadetruesight", warn = true },
			{ t = 3, every = 3, name = "Death Coil", dur = 3, icon = "Interface\\Icons\\spell_shadow_deathcoil", warn = true },
		},
	},
	["twilight corrupter"] = {
		label = "Twilight Corrupter",
		ev = {
			{ t = 8, every = 8, name = "MC CD", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Soul Corruption CD", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Soul Corruption Soon...", dur = 3, warn = true },
			{ t = 600, every = 600, name = "AP Buff", dur = 3, icon = "Interface\\Icons\\spell_nature_strength", warn = true },
		},
	},
	["twin golems"] = {
		label = "Twin Golems",
		ev = {
			{ t = 15, every = 15, name = "X Bulwark", dur = 3, icon = "Interface\\Icons\\ability_mage_moltenarmor", warn = true },
		},
	},
	["ursol"] = {
		label = "Ursol",
		ev = {
			{ t = 30, every = 30, name = "RP - Immune", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_Cripple", warn = true },
			{ t = 92, every = 92, name = "Add Phase", dur = 3, icon = "Interface\\Icons\\Spell_Holy_PowerInfusion", warn = true },
			{ t = 5, every = 5, name = "Roar of Terror", dur = 3, icon = "Interface\\Icons\\Ability_Druid_ChallangingRoar", warn = true },
		},
	},
	["vaelastrasz"] = {
		label = "Vaelastrasz",
		ev = {
			{ t = 15, every = 15, name = "Fire Burning", dur = 3, warn = true },
		},
	},
	["vaelastrasz the corrupt"] = {
		label = "Vaelastrasz the Corrupt",
		ev = {
			{ t = 15, every = 15, name = "Burning Adrenaline CD", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Burning!", dur = 3, icon = "Interface\\Icons\\spell_shadow_mindbomb", warn = true },
		},
	},
	["viscidus"] = {
		label = "Viscidus",
		ev = {
			{ t = 15, every = 15, name = "Poison Bolt Volley", dur = 3 },
		},
	},
	["warchief rend blackhand"] = {
		label = "Warchief Rend Blackhand",
		ev = {
			{ t = 36.5, every = 36.5, name = "Gyth", dur = 3, warn = true },
		},
	},
	["ysondre"] = {
		label = "Ysondre",
		ev = {
			{ t = 20, every = 20, name = "Lightning Wave", dur = 3 },
		},
	},

	-- ===== OCTOWOW / TURTLE (donnees extraites de BigWigs TW installe) =====
	["brood queen araxxna"] = {
		label = "Brood Queen Araxxna",
		ev = {
			{ t = 8, every = 8, name = "Brood Venom Volley", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Leeching Bite", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Skitterweb Egg Hatch", dur = 3, warn = true },
		},
	},
}

M.bossByKey = {}

local PLAIN = {
	["\195\160"] = "a", ["\195\162"] = "a", ["\195\164"] = "a", ["\195\167"] = "c", ["\195\168"] = "e",
	["\195\169"] = "e", ["\195\170"] = "e", ["\195\171"] = "e", ["\195\174"] = "i", ["\195\175"] = "i",
	["\195\180"] = "o", ["\195\182"] = "o", ["\195\185"] = "u", ["\195\187"] = "u", ["\195\188"] = "u",
	["\195\156"] = "u", ["\195\138"] = "e", ["\195\137"] = "e", ["\195\136"] = "e", ["\195\139"] = "e",
	["\195\135"] = "c", ["\195\142"] = "i", ["\195\143"] = "i", ["\195\148"] = "o", ["\195\150"] = "o",
	["\195\153"] = "u", ["\195\128"] = "a", ["\195\130"] = "a", ["\195\132"] = "a", ["\195\147"] = "o",
	["\195\146"] = "a", ["\195\149"] = "o", ["\195\154"] = "u", ["\195\177"] = "n",
}
local function fold(s)
	local out = slower(s)
	out = sgsub(out, "\195[\128-\191]", function(seq) return PLAIN[seq] or seq end)
	return out
end
M.fold = fold

local function indexBosses()
	local k
	for k in pairs(M.bossByKey) do M.bossByKey[k] = nil end
	local b
	for b in pairs(M.BOSSES) do M.bossByKey[fold(b)] = M.BOSSES[b] end
end
indexBosses()

-- ---------------------------------------------------------------- detection du boss
-- Unite visee = cible du joueur, sinon souris.
local function targetUnit()
	if UnitExists("target") and UnitCanAttack("player", "target") then return "target" end
	if UnitExists("mouseover") and UnitCanAttack("player", "mouseover") then return "mouseover" end
	return nil
end

function M.Detect()
	local unit = targetUnit()
	local nm = unit and UnitName(unit) or nil
	local key = nil
	if nm and nm ~= EMPTY and not UnitIsPlayer(unit) then
		key = fold(nm)
		if not M.BOSSES[key] then
			-- tolerance client FR : "Le Recousu" -> "recousu"
			local cut = sfind(key, "^l[ae] ")
			if cut then
				local alt = strsub(key, cut + 3)
				if M.BOSSES[alt] then key = alt end
			end
		end
	end
	if key and M.BOSSES[key] then
		if M.cur ~= key then
			M.cur = key
			M.curLabel = M.BOSSES[key].label or nm
			M.combatAt = nil
			M.armed = {}
			M.narmed = 0
			M.next = {}
			M.warns = {}
		end
	else
		if M.cur then
			M.cur = nil
			M.curLabel = EMPTY
			M.combatAt = nil
			-- les barres de PULL survivent : elles ne dependent pas du boss vise
			local keep, n = {}, 0
			local k
			for k = 1, M.narmed do
				if M.armed[k].pull then
					n = n + 1
					keep[n] = M.armed[k]
				end
			end
			M.armed = keep
			M.narmed = n
			M.next = {}
			M.warns = {}
		end
	end
end

-- ---------------------------------------------------------------- annonce
function M.ShowMsg(main, sub)
	local mf = M.msg
	if not mf or not C.Get("bossmods.showmsg") then return end
	mf.txt1:SetText(main or EMPTY)
	mf.txt2:SetText(sub or EMPTY)
	mf:Show()
	M.msgHideAt = GetTime() + 4
	if not M.msgTask then
		M.msgTask = SUI.Every(0.25, M.MsgTick, "bossmods.msg", true)
	end
end

function M.MsgTick()
	local mf = M.msg
	if not mf then M.MsgStop() return end
	if M.msgHideAt and GetTime() >= M.msgHideAt then M.MsgStop() end
end

function M.MsgStop()
	if M.msgTask then
		SUI.Cancel(M.msgTask)
		M.msgTask = nil
	end
	if M.msg then M.msg:Hide() end
end

function M.Announce(name, secs)
	local chan = C.Get("bossmods.channel") or "self"
	if C.Get("bossmods.showmsg") and M.msg then M.ShowMsg(name, L("msg.bossmods.soon", name, secs)) end
	if chan == "raid" and GetNumRaidMembers() > 0 then
		SendChatMessage(L("msg.bossmods.soon", name, secs), "RAID_WARNING")
	elseif chan == "party" and GetNumPartyMembers() > 0 then
		SendChatMessage(L("msg.bossmods.soon", name, secs), "PARTY")
	else
		SUI.Print(L("msg.bossmods.soon", name, secs))
	end
	if C.Get("bossmods.sound") then
		PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
	end
end

-- ---------------------------------------------------------------- cycle
local function inCombat()
	return UnitAffectingCombat("player") and true or false
end

function M.Tick()
	if not M.on then return end
	if M.testing then
		if M.win and M.win:IsShown() then M.Paint() end
		return
	end
	local nowP = GetTime()
	local p = M.armed[1]
	if p and p.pull then M.PullTick(nowP) end
	M.Detect()
	local d = M.cur and M.BOSSES[M.cur]
	if not d then return end
	local now = GetTime()
	if not M.combatAt and inCombat() then
		M.combatAt = now
	end
	if not M.combatAt then return end
	local lead = C.Get("bossmods.lead") or 10
	-- armement / planification des evenements relatifs, deux phases comme BigWigs :
	--   "lead"   : barre de compte a rebours vers l'evenement (fenetre lead), annonce au depart
	--   "active" : barre de l'effet en cours (dur secondes) une fois l'evenement arrive
	local i, ev
	for i = 1, getn(d.ev) do
		ev = d.ev[i]
		local nxt = M.next[ev] or (M.combatAt + (ev.t or 0))
		local leadOn = C.Get("bossmods.incoming") ~= false
		local activeOn = C.Get("bossmods.active") ~= false
		-- phase lead
		if leadOn and not M.armedHas(ev.name, "lead") and now >= nxt - lead and now < nxt and not M.warns[ev] then
			M.warns[ev] = now
			tinsert(M.armed, { name = ev.name, icon = ev.icon, endsAt = nxt, ev = ev, phase = "lead" })
			M.narmed = M.narmed + 1
			M.Announce(ev.name, floor(nxt - now + 0.5))
			if M.win and M.win:IsShown() then M.Paint() end
		end
		-- l'evenement est arrive : barre active (si duree) puis repetition planifiee
		if now >= nxt then
			local k
			for k = M.narmed, 1, -1 do
				if M.armed[k].ev == ev and M.armed[k].phase == "lead" then
					tremove(M.armed, k)
					M.narmed = M.narmed - 1
				end
			end
			M.next[ev] = nxt + (ev.every or 3600)
			M.warns[ev] = nil
			local dur = ev.dur or 0
			if activeOn and dur > 0 then
				tinsert(M.armed, { name = ev.name, icon = ev.icon, endsAt = now + dur, ev = ev, phase = "active" })
				M.narmed = M.narmed + 1
			end
			if M.win and M.win:IsShown() then M.Paint() end
		end
	end
	-- purge des barres arrivees a expiration (le pull est purge par PullTick, pas ici)
	local i
	for i = M.narmed, 1, -1 do
		if now >= M.armed[i].endsAt then
			tremove(M.armed, i)
			M.narmed = M.narmed - 1
		end
	end
	if M.win and M.win:IsShown() then M.Paint() end
end

-- La barre est-elle deja armee pour ce nom ? (antidoublon pendant le lead)
function M.armedHas(name, phase)
	local i
	for i = 1, M.narmed do
		if M.armed[i].name == name and (not phase or M.armed[i].phase == phase) then return true end
	end
	return false
end

-- ---------------------------------------------------------------- fenetre et barres
function M.Build()
	if M.win then return end
	local wbar = C.Get("bossmods.width") or 220
	local f = CreateFrame("Frame", "ShikiUI_BossModsWin", UIParent)
	f:SetWidth(wbar)
	f:SetHeight(M.BARH * M.MAXBARS + 26)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:SetFrameStrata("LOW")
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:Hide()
	M.win = f
	f.title = T.Text(f, 12, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
	f.title:SetText(L("mod.bossmods.title"))
	f.status = T.Text(f, 10, T.c.dim, "RIGHT")
	f.status:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -7)
	f.close = T.Button(f, "x", 16, 14, function() M.Close() end)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -22)
	local i
	for i = 1, M.MAXBARS do
		local row = CreateFrame("Frame", nil, f)
		row:SetWidth(204)
		row:SetHeight(M.BARH)
		row:Hide()
		row.bar = T.Bar(row)
		row.bar:SetAllPoints(row)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetWidth(15)
		row.icon:SetHeight(15)
		row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.icon:Hide()
		row.name = T.Text(row, 10, T.c.text, "LEFT", true)
		row.name:SetPoint("LEFT", row, "LEFT", 19, 0)
		row.name:SetWidth(140)
		row.time = T.Text(row, 10, T.c.text, "RIGHT", true)
		row.time:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
		row.time:SetWidth(44)
		row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -24 - (i - 1) * (M.BARH + M.GAP))
		M["row" .. i] = row
	end
	SUI.Layout.Register(f, "bossmods.win", "BOTTOMRIGHT", -20, 260)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("bossmods.win", f, { label = L("mod.bossmods.title"), scale = false })
	end
	-- ancre des annonces a l'ecran : un cadre separe, deplacable independamment (comme les ancres BigWigs)
	local mf = CreateFrame("Frame", "ShikiUI_BossModsMsg", UIParent)
	mf:SetWidth(260)
	mf:SetHeight(54)
	T.Backdrop(mf, T.c.panel, T.c.border)
	mf:SetFrameStrata("HIGH")
	mf:EnableMouse(true)
	mf:SetClampedToScreen(true)
	mf:Hide()
	M.msg = mf
	mf.txt1 = T.Text(mf, 13, T.c.warn, "CENTER", true)
	mf.txt1:SetPoint("TOP", mf, "TOP", 0, -8)
	mf.txt1:SetWidth(250)
	mf.txt2 = T.Text(mf, 11, T.c.text, "CENTER", true)
	mf.txt2:SetPoint("BOTTOM", mf, "BOTTOM", 0, 8)
	mf.txt2:SetWidth(250)
	SUI.Layout.Register(mf, "bossmods.msg", "CENTER", 0, 180)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("bossmods.msg", mf, { label = L("mod.bossmods.msgtitle"), scale = false })
	end
	T.OnAccent(function()
		if M.win and M.win:IsShown() then M.Paint() end
	end)
end

function M.Open()
	if not M.on then return end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		M.win:Show()
		M.EnsureTask()
		M.Paint()
	end)
end

function M.Close()
	if M.win then M.win:Hide() end
end

function M.ToggleWin()
	if M.win and M.win:IsShown() then M.Close() else M.Open() end
end

function M.ApplySize()
	if not M.win then return end
	local wbar = C.Get("bossmods.width") or 220
	local rows = C.Get("bossmods.rows") or 6
	local i
	for i = 1, M.MAXBARS do
		local row = M["row" .. i]
		row:SetWidth(wbar - 16)
		if i <= rows then row:SetPoint("TOPLEFT", M.win, "TOPLEFT", 8, -24 - (i - 1) * (M.BARH + M.GAP)) end
	end
	M.win:SetWidth(wbar)
	M.win:SetHeight(M.BARH * M.MAXBARS + 26)
end

function M.EnsureTask()
	if not M.task then
		M.task = SUI.Every(0.25, M.Tick, "bossmods.tick", true)
	end
end

-- ---------------------------------------------------------------- peinture
-- Barres triees du plus proche au plus lointain ; purge des evenements arrives a expiration.
function M.Paint()
	local f = M.win
	if not f or not f:IsShown() then return end
	local now = GetTime()
	local i
	for i = M.narmed, 1, -1 do
		if now >= M.armed[i].endsAt then
			tremove(M.armed, i)
			M.narmed = M.narmed - 1
		end
	end
	-- tri par temps restant croissant
	local order = {}
	for i = 1, M.narmed do order[i] = i end
	local swapped = true
	while swapped do
		swapped = false
		for i = 2, M.narmed do
			if M.armed[order[i]].endsAt < M.armed[order[i - 1]].endsAt then
				local tmp = order[i - 1]
				order[i - 1] = order[i]
				order[i] = tmp
				swapped = true
			end
		end
	end
	local rows = C.Get("bossmods.rows") or 6
	local shown = 0
	for i = 1, M.narmed do
		if shown < M.MAXBARS and shown < rows then
			local e = M.armed[order[i]]
			shown = shown + 1
			local row = M["row" .. shown]
			row:Show()
			row.name:SetText(e.name)
			-- icone du sort (option) : texture du jeu ou point d'interrogation
			if C.Get("bossmods.icons") ~= false and e.icon then
				row.icon:SetTexture(e.icon)
				row.icon:Show()
			else
				row.icon:Hide()
			end
			local left = mmax(0, e.endsAt - now)
			row.time:SetText(string.format("%.0f", left))
			local span, cr, cg, cb
			if e.phase == "active" then
				span = mmax(1, e.ev.dur or 3)
				cr, cg, cb = T.c.bad[1], T.c.bad[2], T.c.bad[3]
			elseif e.ev.warn then
				span = mmax(1, C.Get("bossmods.lead") or 10)
				cr, cg, cb = T.Accent()
			else
				span = mmax(1, C.Get("bossmods.lead") or 10)
				cr, cg, cb = T.c.text[1], T.c.text[2], T.c.text[3]
			end
			row.bar:SetStatusBarColor(cr, cg, cb, 0.8)
			row.bar:SetValue(mmin(1, left / span))
		end
	end
	local j
	for j = shown + 1, M.MAXBARS do
		M["row" .. j]:Hide()
	end
end

-- ---------------------------------------------------------------- flash d'ecran
function M.DoFlash()
	if M.flashUntil and GetTime() < M.flashUntil then return end
	if not M.flash then
		local f = CreateFrame("Frame", "ShikiUI_BossModsFlash", UIParent)
		f:SetFrameStrata("FULLSCREEN")
		f:SetAllPoints(f)
		f:EnableMouse(false)
		f.tex = f:CreateTexture(nil, "BACKGROUND")
		f.tex:SetTexture(T.tex.white)
		f.tex:SetAllPoints(f)
		M.flash = f
	end
	M.flashUntil = GetTime() + 0.6
	M.flash:Show()
	M.flash.tex:SetVertexColor(T.c.bad[1], T.c.bad[2], T.c.bad[3], 0.18)
	if not M.flashTask then
		M.flashTask = SUI.Every(0.1, function()
			local f2 = M.flash
			if not f2 or not M.flashUntil then M.FlashStop() return end
			local left = M.flashUntil - GetTime()
			if left <= 0 then M.FlashStop() return end
			f2.tex:SetAlpha((SUI.Mod(left, 0.2) < 0.1) and 0.18 or 0.05)
		end, "bossmods.flash", true)
	end
end

function M.FlashStop()
	if M.flashTask then
		SUI.Cancel(M.flashTask)
		M.flashTask = nil
	end
	if M.flash then M.flash:Hide() end
	M.flashUntil = nil
end

-- ---------------------------------------------------------------- pull timer synchronise
M.PREFIX = "ShikiUIBW"

-- /sui pull [secs] : lance le compte a rebours d'engage, diffuse au raid via le canal addon.
-- Reserves au chef / assistant en raid (comme BigWigs), libre hors raid.
function M.Pull(secs)
	if not M.on then return end
	secs = tonumber(secs) or 10
	if secs < 3 then secs = 3 end
	if secs > 60 then secs = 60 end
	if GetNumRaidMembers() > 0 and not M.CanLead() then
		SUI.Print(L("msg.bossmods.nolead"))
		return
	end
	M.PullStart(secs, UnitName("player"))
	local chan = "RAID"
	if GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 then chan = "PARTY" end
	if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
		SendChatMessage(L("msg.bossmods.pullchat", secs), chan)
		if C.Get("bossmods.pull") and type(SendAddonMessage) == "function" then
			SendAddonMessage(M.PREFIX, "pull:" .. secs .. ":" .. tostring(UnitName("player")), "RAID")
		end
	end
end

function M.CanLead()
	if GetNumRaidMembers() > 0 then
		local off = getglobal("IsRaidOfficer")
		return IsRaidLeader() or (off and off()) or false
	end
	if GetNumPartyMembers() > 0 then return IsPartyLeader() or false end
	return true
end

-- Demarre la barre de pull localement (lanceur ou reception).
function M.PullStart(secs, from)
	M.testing = false
	M.cur = "pull"
	M.curLabel = from and (L("mod.bossmods.title") .. " (" .. from .. ")") or L("mod.bossmods.title")
	local now = GetTime()
	-- purge des barres de boss : le pull les remplace
	M.armed = {}
	M.narmed = 0
	M.combatAt = nil
	M.pullAnnounced = {}
	tinsert(M.armed, { name = "PULL", endsAt = now + secs, ev = { dur = secs, t = secs }, phase = "lead", pull = true })
	M.narmed = 1
	if M.win and M.win:IsShown() then M.Paint() end
	if not M.pullAnnounced then
		M.pullAnnounced = {}
	end
	M.EnsureTask()
end

-- Decompte (5..1 puis GO) et expiration du pull. PullTick gere tout lui-meme : le pull survit au changement
-- de cible et Tick retourne tot sans boss vise, donc la purge generale ne verrait jamais la barre expiree.
function M.PullTick(now)
	local e = M.armed[1]
	if not e or not e.pull then return end
	if now >= e.endsAt then
		if not e.goDone then
			e.goDone = true
			if C.Get("bossmods.pull") then
				local chan = (GetNumRaidMembers() > 0) and "RAID_WARNING" or nil
				if chan then SendChatMessage(L("msg.bossmods.pullgo"), chan) else SUI.Print(L("msg.bossmods.pullgo")) end
				if C.Get("bossmods.sound") then PlaySoundFile("Sound\\Interface\\RaidWarning.wav") end
			end
		end
		tremove(M.armed, 1)
		M.narmed = M.narmed - 1
		if M.win and M.win:IsShown() then M.Paint() end
		return
	end
	local left = e.endsAt - now
	local chan = (GetNumRaidMembers() > 0) and "RAID_WARNING" or nil
	local n
	for n = 1, 5 do
		if left <= n and not M.pullAnnounced[n] then
			M.pullAnnounced[n] = true
			if C.Get("bossmods.pull") then
				if chan then SendChatMessage(L("msg.bossmods.pullin", n), chan) else SUI.Print(L("msg.bossmods.pullin", n)) end
			end
		end
	end
end

-- Reception du canal addon : pull d'un autre officier.
function M.OnAddonComm(ev, a1, a2, a3, a4)
	if not M.on or type(a2) ~= "string" then return end
	local _, _, who, secs = sfind(a2, "^pull:(%d+):(.+)$")
	if not who or who == UnitName("player") then return end
	if M.pullIgnore and GetTime() < M.pullIgnore then return end
	M.PullStart(tonumber(secs) or 10, who)
end

-- Fin de combat : les barres de boss disparaissent (les pulls continuent).
function M.OnCombatEnd()
	if M.combatAt then
		M.combatAt = nil
		local i
		for i = M.narmed, 1, -1 do
			if not M.armed[i].pull then
				tremove(M.armed, i)
				M.narmed = M.narmed - 1
			end
		end
		if M.win and M.win:IsShown() then M.Paint() end
	end
end

-- ---------------------------------------------------------------- cycle de vie
-- ---------------------------------------------------------------- cycle de vie
function M.Enable()
	M.on = true
	if not M.watching then
		M.watching = true
		C.Watch("bossmods.", M.OnKey)
	end
	SUI.On("CHAT_MSG_ADDON", M.OnAddonComm)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnCombatEnd)
	M.EnsureTask()
end

function M.Disable()
	M.on = false
	M.testing = false
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	SUI.Off("CHAT_MSG_ADDON", M.OnAddonComm)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnCombatEnd)
	M.FlashStop()
	M.MsgStop()
	M.armed = {}
	M.narmed = 0
	M.Close()
end

function M.OnKey(key)
	if key == nil or string.find(key or EMPTY, "^bossmods%.") then
		if key == "bossmods.width" or key == "bossmods.rows" or key == nil then M.ApplySize() end
		if M.win and M.win:IsShown() then M.Paint() end
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("bossmods", 70)

local function opt(key, typ, order, def, extra)
	local o = { key = "bossmods." .. key, type = typ, cat = "bossmods", label = "opt.bossmods." .. key, tip = "tip.bossmods." .. key, default = def, order = order }
	if extra then
		for k, v in pairs(extra) do o[k] = v end
	end
	return o
end

local function chanText(o, v) return L("choice.bossmods.channel." .. v) end

SUI.RegisterModule("bossmods", {
	default = true,
	cost = "medium",
	options = {
		opt("lead", "number", 10, 10, { min = 0, max = 30, step = 1 }),
		opt("channel", "choice", 20, "self", { choices = { "self", "raid", "party" }, choiceText = chanText }),
		opt("sound", "bool", 30, true),
		opt("width", "number", 40, 220, { min = 120, max = 400, step = 10 }),
		opt("rows", "number", 50, 6, { min = 1, max = 8, step = 1 }),
		opt("showmsg", "bool", 60, true),
		opt("icons", "bool", 70, true),
		opt("incoming", "bool", 80, true),
		opt("active", "bool", 90, true),
		opt("pull", "bool", 100, true),
		opt("flash", "bool", 110, false),
		opt("pull", "bool", 120, true),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Mode test : barres et annonces FICTIVES pour placer l'interface sans etre en raid.
function M.Test()
	M.testing = not M.testing
	if not M.testing then
		M.armed = {}
		M.narmed = 0
		M.cur = nil
		M.curLabel = EMPTY
		M.MsgStop()
		if M.win then M.Paint() end
		SUI.Print(L("msg.bossmods.testoff"))
		return
	end
	SUI.WhenSafe(function()
		if not M.testing then return end
		M.Build()
		M.win:Show()
		M.ApplySize()
		M.cur = "test"
		M.curLabel = "TEST"
		M.armed = {}
		M.narmed = 0
		local now = GetTime()
		local samples = {
			{ name = "Exemple : cast important", endsAt = 20, dur = 8, warn = true },
			{ name = "Exemple : debuff a dissiper", endsAt = 14, dur = 6, warn = true },
			{ name = "Exemple : add a tuer", endsAt = 9, dur = 9, warn = true },
			{ name = "Exemple : evenement urgent", endsAt = 5, dur = 5, warn = true },
		}
		local i
		for i = 1, getn(samples) do
			local e = samples[i]
			tinsert(M.armed, { name = e.name, endsAt = now + e.endsAt, dur = e.dur, ev = { dur = e.endsAt }, test = true })
			M.narmed = M.narmed + 1
			if e.warn then M.ShowMsg(e.name, L("mod.bossmods.title")) end
		end
		if C.Get("bossmods.sound") then PlaySoundFile("Sound\\Interface\\RaidWarning.wav") end
		M.Paint()
		SUI.Print(L("msg.bossmods.teston"))
	end)
end

-- /sui bossmods [open|close|test] : la fenetre d'alarmes de raid.
SUI.RegisterCommand("bossmods", function(rest)
	if not M.on then
		C.Set("modules.bossmods", true)
	end
	rest = rest or EMPTY
	if rest == "open" then
		M.Open()
	elseif rest == "close" then
		M.Close()
	elseif rest == "test" then
		M.Test()
	elseif strfind(rest, "pull", 1, true) then
		local secs = tonumber(strsub(rest, 6)) or 10
		M.Pull(secs)
	else
		M.ToggleWin()
	end
end, "help.bossmods")
