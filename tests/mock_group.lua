-- mock_group : extension de simulation des modules "group", "raid" et "clickheal" (chargee automatiquement apres mock_wow.lua, AVANT le mode
-- strict). Rien n'est pose au chargement : GRP_SETUP() (appele par les suites t_group / t_raid / t_clickheal seulement) definit les
-- fonctions du client utilisees par ces modules. Noms d'API releves dans des addons installes : UnitBuff / UnitDebuff (Puppeteer PTUnit.lua :
-- texture, applications, type), GetRaidRosterInfo (RosterLib de BigWigs), UnitIsVisible (Puppeteer Util.lua), GetRaidTargetIndex /
-- SetRaidTargetIconTexture (Puppeteer, pfUI), UnitClassification (OctoMeter), UnitIsPartyLeader (AutoInvite / AutoMarkerOW),
-- IsShiftKeyDown / IsControlKeyDown / IsAltKeyDown (1.12), CastSpellByName(sort, unite) (Puppeteer, SuperWoW), PlaySoundFile (DebuffAlert),
-- AceLibrary("HealComm-1.0"):getHeal(nom), AceLibrary("Banzai-1.0"):GetUnitAggroByUnitId(unite) (Puppeteer). Tout est DONNEE DE TEST.
ALLOW("GRP")

GRP_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "PALADIN", "ROGUE", "HUNTER", "SHAMAN", "DRUID", "WARLOCK" }

function GRP_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  rawset(_G, "GRP", { mods = {}, spells = {}, casts = {}, sounds = 0, lastSound = nil, heals = {}, aggro = {}, lastTarget = nil, drops = 0, resurrecting = {}, ptheals = {}, ptres = {} })
  G("BOOKTYPE_SPELL", "spell")
  G("GetSpellName", function(i, book)
    local s = GRP.spells[i]
    if not s then return nil end
    return s[1], s[2]
  end)
  G("UnitIsUnit", function(a, b)
    local x, y = W.units[a], W.units[b]
    if not x or not y then return nil end
    return (x == y or (x.guid ~= nil and x.guid == y.guid)) and 1 or nil
  end)
  G("GetSpellTexture", function(i, book) local s = GRP.spells[i]; return s and s[3] or nil end)
  -- buffs du joueur : W.units.player.buffs[k] = { texture, applications, secondes restantes }
  G("GetPlayerBuff", function(i, filt) local b = W.units.player.buffs; if b and b[i + 1] then return i end return -1 end)
  G("GetPlayerBuffTexture", function(i) return W.units.player.buffs[i + 1][1] end)
  G("GetPlayerBuffTimeLeft", function(i) return W.units.player.buffs[i + 1][3] or 0 end)
  G("CursorHasItem", function() return W.cursorItem and 1 or nil end)
  G("UnitIsVisible", function(u) local x = W.units[u]; return (x and not x.hidden) and 1 or nil end)
  G("UnitBuff", function(u, i) local x = W.units[u]; local a = x and x.buffs and x.buffs[i]; if not a then return nil end return a[1], a[2] end)
  G("UnitDebuff", function(u, i) local x = W.units[u]; local a = x and x.debuffs and x.debuffs[i]; if not a then return nil end return a[1], a[2], a[3] end)
  G("GetRaidRosterInfo", function(i)
    local x = W.units["raid" .. i]
    if not x or i > W.raidMembers then return nil end
    return x.name, x.rank or 0, x.sub or 1, x.level, x.class, x.class, "Zone", (not x.offline) and 1 or nil, x.dead and 1 or nil
  end)
  G("UnitIsPartyLeader", function(u) local x = W.units[u]; return (x and x.leader) and 1 or nil end)
  G("UnitClassification", function(u) local x = W.units[u]; return x and x.classification or "normal" end)
  G("GetRaidTargetIndex", function(u) local x = W.units[u]; return x and x.mark or nil end)
  G("SetRaidTargetIconTexture", function(tex, idx) tex.markIdx = idx end)
  G("PlaySoundFile", function(p) GRP.sounds = GRP.sounds + 1; GRP.lastSound = p end)
  G("IsShiftKeyDown", function() return GRP.mods.shift and 1 or nil end)
  G("IsControlKeyDown", function() return GRP.mods.ctrl and 1 or nil end)
  G("IsAltKeyDown", function() return GRP.mods.alt and 1 or nil end)
  G("CastSpellByName", function(spell, unit)
    ACT("Cast " .. spell .. " " .. tostring(unit))
    table.insert(GRP.casts, { spell, unit, W.units.target and W.units.target.name or nil })
  end)
  G("TargetUnit", function(u) ACT("TargetUnit " .. u); GRP.lastTarget = W.units.target; W.units.target = W.units[u] end)
  G("TargetLastTarget", function() ACT("TargetLastTarget"); W.units.target = GRP.lastTarget end)
  G("ClearTarget", function() ACT("ClearTarget"); GRP.lastTarget = W.units.target; W.units.target = nil end)
  G("SpellStopTargeting", function() W.spellTargeting = false end)
  if not rawget(_G, "GameTooltip") then CreateFrame("GameTooltip", "GameTooltip", UIParent) end
  local gt = rawget(_G, "GameTooltip")
  gt.lines = {}
  gt.SetOwner = function(self, o, a) self.owner = o; self.lines = {} end
  gt.SetUnit = function(self, u) self.unit = u end
  gt.AddLine = function(self, t) table.insert(self.lines, t) end
end

-- Une unite de test. o : name, class, hp, hpMax, mana, manaMax, ptype, dist, sub, rank, offline, dead, hidden, leader, mark, buffs, debuffs.
function GRP_UNIT(token, o)
  o = o or {}
  local n = o.n or 1
  local u = { name = o.name or ("Unit" .. token), hp = o.hp or 4000, hpMax = o.hpMax or 4000, mana = o.mana or 2000, manaMax = o.manaMax or 2000,
    ptype = o.ptype or 0, level = 60, isPlayer = true, class = o.class or "WARRIOR", friend = true, canAttack = false,
    guid = o.guid or ("0xG" .. token), dist = o.dist or 10, sight = true, buffs = o.buffs or {}, debuffs = o.debuffs or {},
    sub = o.sub or 1, rank = o.rank or 0, offline = o.offline, dead = o.dead, hidden = o.hidden, leader = o.leader, mark = o.mark }
  W.units[token] = u
  return u
end

function GRP_CLEAR()
  for i = 1, 40 do W.units["raid" .. i] = nil end
  for i = 1, 4 do W.units["party" .. i] = nil; W.units["partypet" .. i] = nil end
  W.units.pet = nil
  W.raidMembers, W.partyMembers = 0, 0
end

-- GRP_PARTY(n [, specs]) : n membres de groupe (party1..n), specs[i] = options de GRP_UNIT.
function GRP_PARTY(n, specs)
  specs = specs or {}
  for i = 1, n do
    local o = specs[i] or {}
    o.name = o.name or ("Ami" .. i)
    o.class = o.class or GRP_CLASSES[SUI_MOD(i, 9) + 1]
    GRP_UNIT("party" .. i, o)
  end
  W.partyMembers = n
end

function SUI_MOD(a, m) return a - math.floor(a / m) * m end

-- GRP_RAID(n [, specs]) : un raid de n joueurs ; raid1 est le joueur lui-meme (meme table que "player" : meme GUID).
function GRP_RAID(n, specs)
  specs = specs or {}
  for i = 1, n do
    local o = specs[i] or {}
    o.name = o.name or ("Raider" .. i)
    o.class = o.class or GRP_CLASSES[SUI_MOD(i, 9) + 1]
    o.sub = o.sub or (math.floor((i - 1) / 5) + 1)
    if i == 1 then
      local p = W.units.player
      p.name, p.class, p.sub, p.rank = "Shikiwa", "PALADIN", 1, o.rank or 2
      W.units.raid1 = p
    else
      GRP_UNIT("raid" .. i, o)
    end
  end
  W.raidMembers = n
end

-- Liste des sorts connus : GRP_SPELLS({ { "Flash of Light", "Rank 1" }, ... })
function GRP_SPELLS(list) GRP.spells = list end

-- GRP_ACE(heal, banzai) : installe AceLibrary avec HealComm-1.0 et / ou Banzai-1.0 simules.
function GRP_ACE(heal, banzai)
  local libs = {}
  if heal then
    libs["HealComm-1.0"] = { getHeal = function(self, name) return GRP.heals[name] or 0 end,
      UnitisResurrecting = function(self, name) return GRP.resurrecting[name] end }
  end
  if banzai then libs["Banzai-1.0"] = { GetUnitAggroByUnitId = function(self, unit) return GRP.aggro[unit] end } end
  local al = { HasInstance = function(self, name) return libs[name] ~= nil end }
  setmetatable(al, { __call = function(self, name) return libs[name] end })
  rawset(_G, "AceLibrary", al)
end
function GRP_NOACE() rawset(_G, "AceLibrary", nil) end

-- GRP_PT(on) : simule PTHealPredict (Puppeteer) : getHeal(guid) -> somme, IsBeingResurrected(guid).
function GRP_PT(on)
  if on then
    rawset(_G, "PTHealPredict", { getHeal = function(guid) return GRP.ptheals[guid] or 0, 0 end,
      IsBeingResurrected = function(guid) return GRP.ptres[guid] end })
  else
    rawset(_G, "PTHealPredict", nil)
  end
end

-- Nombre de minuteries vivantes portant ce nom.
function GRP_TASKS(name)
  local n = 0
  for i = 1, table.getn(ShikiUI.tasks) do
    if ShikiUI.tasks[i].name == name and not ShikiUI.tasks[i].dead then n = n + 1 end
  end
  return n
end
