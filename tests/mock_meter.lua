-- mock_meter : extension de simulation du module "meter" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : MET_SETUP() (appele par t_meter.lua seulement) definit les chaines globales du journal de combat,
-- SendChatMessage, GameTooltip et une classe de couleur. Les chaines ci-dessous sont les formats ANGLAIS vanilla tels que cites en commentaire
-- par ShaguDPS (parser-vanilla.lua) ; ce sont des DONNEES DE TEST (un client francais a d'autres formats : voir le test des formats positionnels).
ALLOW("MET")

MET_STRINGS = {
	COMBATHITSELFOTHER = "You hit %s for %d.",
	COMBATHITCRITSELFOTHER = "You crit %s for %d.",
	COMBATHITSCHOOLSELFOTHER = "You hit %s for %d %s damage.",
	COMBATHITCRITSCHOOLSELFOTHER = "You crit %s for %d %s damage.",
	COMBATHITOTHERSELF = "%s hits you for %d.",
	COMBATHITCRITOTHERSELF = "%s crits you for %d.",
	COMBATHITSCHOOLOTHERSELF = "%s hits you for %d %s damage.",
	COMBATHITCRITSCHOOLOTHERSELF = "%s crits you for %d %s damage.",
	COMBATHITOTHEROTHER = "%s hits %s for %d.",
	COMBATHITCRITOTHEROTHER = "%s crits %s for %d.",
	COMBATHITSCHOOLOTHEROTHER = "%s hits %s for %d %s damage.",
	COMBATHITCRITSCHOOLOTHEROTHER = "%s crits %s for %d %s damage.",
	SPELLLOGSELFOTHER = "Your %s hits %s for %d.",
	SPELLLOGCRITSELFOTHER = "Your %s crits %s for %d.",
	SPELLLOGSCHOOLSELFOTHER = "Your %s hits %s for %d %s damage.",
	SPELLLOGCRITSCHOOLSELFOTHER = "Your %s crits %s for %d %s damage.",
	SPELLLOGOTHERSELF = "%s's %s hits you for %d.",
	SPELLLOGCRITOTHERSELF = "%s's %s crits you for %d.",
	SPELLLOGSCHOOLOTHERSELF = "%s's %s hits you for %d %s damage.",
	SPELLLOGCRITSCHOOLOTHERSELF = "%s's %s crits you for %d %s damage.",
	SPELLLOGOTHEROTHER = "%s's %s hits %s for %d.",
	SPELLLOGCRITOTHEROTHER = "%s's %s crits %s for %d.",
	SPELLLOGSCHOOLOTHEROTHER = "%s's %s hits %s for %d %s damage.",
	SPELLLOGCRITSCHOOLOTHEROTHER = "%s's %s crits %s for %d %s damage.",
	DAMAGESHIELDSELFOTHER = "You reflect %d %s damage to %s.",
	DAMAGESHIELDOTHERSELF = "%s reflects %d %s damage to you.",
	DAMAGESHIELDOTHEROTHER = "%s reflects %d %s damage to %s.",
	PERIODICAURADAMAGESELFOTHER = "%s suffers %d %s damage from your %s.",
	PERIODICAURADAMAGEOTHEROTHER = "%s suffers %d %s damage from %s's %s.",
	PERIODICAURADAMAGEOTHERSELF = "You suffer %d %s damage from %s's %s.",
	HEALEDCRITSELFSELF = "Your %s critically heals you for %d.",
	HEALEDSELFSELF = "Your %s heals you for %d.",
	HEALEDCRITSELFOTHER = "Your %s critically heals %s for %d.",
	HEALEDSELFOTHER = "Your %s heals %s for %d.",
	HEALEDCRITOTHERSELF = "%s's %s critically heals you for %d.",
	HEALEDOTHERSELF = "%s's %s heals you for %d.",
	HEALEDCRITOTHEROTHER = "%s's %s critically heals %s for %d.",
	HEALEDOTHEROTHER = "%s's %s heals %s for %d.",
	PERIODICAURAHEALSELFOTHER = "%s gains %d health from your %s.",
	PERIODICAURAHEALOTHEROTHER = "%s gains %d health from %s's %s.",
	PERIODICAURAHEALSELFSELF = "You gain %d health from %s.",
	PERIODICAURAHEALOTHERSELF = "You gain %d health from %s's %s.",
	MISSEDSELFOTHER = "You miss %s.",
	VSDODGESELFOTHER = "You attack. %s dodges.",
	VSPARRYSELFOTHER = "You attack. %s parries.",
	SPELLMISSSELFOTHER = "Your %s missed %s.",
	SPELLDODGEDSELFOTHER = "Your %s was dodged by %s.",
	SPELLPARRIEDSELFOTHER = "Your %s is parried by %s.",
	SPELLRESISTSELFOTHER = "Your %s was resisted by %s.",
	SPELLEVADEDSELFOTHER = "Your %s was evaded by %s.",
}

function MET_SETUP(withStrings)
	local function G(k, v) rawset(_G, k, v) end
	rawset(_G, "MET", { chat = {}, tip = {}, spells = {}, loaded = {} })
	if withStrings ~= false then
		for k, v in pairs(MET_STRINGS) do G(k, v) end
	end
	G("SendChatMessage", function(msg, chan) table.insert(MET.chat, chan .. "|" .. msg) end)
	RAID_CLASS_COLORS.ROGUE = { r = 1, g = 0.96, b = 0.41 }
	RAID_CLASS_COLORS.PRIEST = { r = 1, g = 1, b = 1 }
	if not rawget(_G, "GameTooltip") then
		local gt = CreateFrame("GameTooltip", "GameTooltip", UIParent)
	end
	local gt = rawget(_G, "GameTooltip")
	gt.lines = {}
	gt.SetOwner = function(self, o, a) self.owner = o; self.lines = {} end
	gt.AddLine = function(self, t) table.insert(MET.tip, t); table.insert(self.lines, t) end
	gt.Show = function(self) self.shown = true end
	gt.Hide = function(self) self.shown = false end
	G("IsAddOnLoaded", function(n) return MET.loaded[n] and 1 or nil end)
end

-- SuperWoW : SpellInfo(sortId) -> nom (donnees de test)
function MET_SPELLINFO()
	MET.spells = { [1766] = "Kick", [6552] = "Pummel", [527] = "Dispel Magic", [4987] = "Cleanse", [133] = "Fireball", [8042] = "Earth Shock" }
	rawset(_G, "SpellInfo", function(id) return MET.spells[id] end)
end

-- Un petit groupe : le joueur (PALADIN), Bob (WARRIOR) + son familier, Eve (MAGE). Le familier du joueur s'appelle Fido.
function MET_GROUP()
	MKPLAYER()
	W.units.player.name = "Shikiwa"
	W.units.player.class = "PALADIN"
	W.units.party1 = { name = "Bob", class = "WARRIOR", hp = 4000, hpMax = 5000 }
	W.units.party2 = { name = "Eve", class = "MAGE", hp = 2000, hpMax = 3000 }
	W.units.partypet1 = { name = "Rex" }
	W.units.pet = { name = "Fido" }
	W.partyMembers = 2
	W.raidMembers = 0
end

-- Un raid de n membres (le joueur est raid1) : noms Raid2..Raidn, classes alternees.
function MET_RAID(n)
	MKPLAYER()
	W.units.player.name = "Shikiwa"
	W.units.player.class = "PALADIN"
	local cls = { "WARRIOR", "MAGE", "ROGUE", "PRIEST" }
	W.units.raid1 = W.units.player
	for i = 2, n do
		W.units["raid" .. i] = { name = "Raid" .. i, class = cls[SUI_MOD4(i) + 1], hp = 3000, hpMax = 4000 }
	end
	W.raidMembers = n
	W.partyMembers = 0
end

function SUI_MOD4(i) return i - 4 * math.floor(i / 4) end

-- ---------------------------------------------------------------- Nampower (DONNEES DE TEST : ordre des arguments tel que lu dans OctoMeter, non observe en jeu)
-- MET_NP() : version de Nampower, CVar (GetCVar / SetCVar), champs d'unite (GetUnitField : proprietaire d'un garde), fiches de sorts
-- (GetSpellRecField : nom, type de dissipation). Les guids sont des cles de W.units (UnitName(guid) -> nom).
MET_STRINGS.UNITDIESOTHER = "%s dies."
function MET_NP()
	local function G(k, v) rawset(_G, k, v) end
	EXT.nampower(true)
	MET.cvars = { NP_EnableAutoAttackEvents = "0", NP_EnableSpellHealEvents = "1" }
	MET.setcv = {}
	MET.fields = {}
	MET.rec = { [133] = { name = "Fireball" }, [635] = { name = "Holy Light" }, [2878] = { name = "Curse of Weakness", dispel = 2 },
		[527] = { name = "Frost Armor", dispel = 1 }, [1019] = { name = "Corruption" }, [9] = { name = "Shadow Bolt" } }
	G("GetCVar", function(k) return MET.cvars[k] end)
	G("SetCVar", function(k, v) MET.cvars[k] = tostring(v); table.insert(MET.setcv, k) end)
	G("GetUnitField", function(g, f) local t = MET.fields[g]; return t and t[f] or nil end)
	G("GetSpellRecField", function(id, f) local r = MET.rec[id]; return r and r[f] or nil end)
	W.units["0xBOB"] = W.units.party1
	W.units["0xEVE"] = W.units.party2
	W.units["0xME"] = W.units.player
	W.units["0xF13000ORC"] = { name = "Orc", level = 60 }
	W.units["0xF13000WLF"] = { name = "Wolf", level = 60 }
	W.units["0xF14000TOT"] = { name = "Searing Totem" }     -- garde d'un joueur (guid 0xF1...)
	W.units["0xF14000IMP"] = { name = "Imp" }               -- garde du joueur
	W.units["0xF14000XXX"] = { name = "Stray" }             -- garde sans proprietaire connu
	MET.fields["0xF14000TOT"] = { summonedBy = "0xBOB" }
	MET.fields["0xF14000IMP"] = { createdBy = "0xME" }
end

-- Evenement Nampower avec jusqu'a 8 arguments (Fire() n'en pose que 5 : arg6.. via rawset, remis a zero apres).
function MET_FIRE(ev, a1, a2, a3, a4, a5, a6, a7)
	rawset(_G, "arg6", a6)
	rawset(_G, "arg7", a7)
	Fire(ev, a1, a2, a3, a4, a5)
	rawset(_G, "arg6", nil)
	rawset(_G, "arg7", nil)
end
