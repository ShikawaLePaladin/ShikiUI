-- mock_totems : extension de simulation du module "totems" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : TOT_SETUP() (appele par t_totems.lua seulement) cree le grimoire du chaman, CastSpellByName, GameTooltip.
-- Noms d'API : GetSpellName / GetSpellTexture / BOOKTYPE_SPELL (1.12), CastSpellByName, SpellInfo (SuperWoW). Valeurs = DONNEES DE TEST.
ALLOW("TOT")

function TOT_SETUP(class)
  local function G(k, v) rawset(_G, k, v) end
  TOT = { cast = {}, tip = {} }
  W.units.player = W.units.player or { name = "Moi", guid = "0xPLAYER" }
  W.units.player.class = class or "SHAMAN"
  W.units.player.guid = "0xPLAYER"
  W.spells = {
    { name = "Lightning Bolt", rank = "Rank 1", tex = "Interface\\Icons\\Spell_Nature_Lightning" },
    { name = "Searing Totem", rank = "Rank 1", tex = "Interface\\Icons\\Spell_Fire_SearingTotem" },
    { name = "Searing Totem", rank = "Rank 2", tex = "Interface\\Icons\\Spell_Fire_SearingTotem" },
    { name = "Magma Totem", rank = "Rank 1", tex = "Interface\\Icons\\Spell_Fire_SelfDestruct" },
    { name = "Mana Spring Totem", rank = "Rank 1", tex = "Interface\\Icons\\Spell_Nature_ManaRegenTotem" },
    { name = "Healing Stream Totem", rank = "Rank 1", tex = "Interface\\Icons\\INV_Spear_04" },
    { name = "Tranquil Air Totem", rank = "Rank 1", tex = "Interface\\Icons\\Spell_Nature_Brilliance" },
    { name = "Windfury Totem", rank = "Rank 1", tex = "Interface\\Icons\\Spell_Nature_Windfury" },
    { name = "Stoneskin Totem", rank = "Rank 1", tex = "Interface\\Icons\\Spell_Nature_StoneSkinTotem" },
    { name = "Tremor Totem", rank = "Rank 1", tex = "Interface\\Icons\\Spell_Nature_TremorTotem" },
    { name = "Totemic Recall", rank = "", tex = "Interface\\Icons\\Spell_Shaman_TotemRecall" },
  }
  G("BOOKTYPE_SPELL", "spell")
  G("GetSpellName", function(i, book)
    local s = W.spells[i]
    if not s then return nil end
    return s.name, s.rank
  end)
  G("GetSpellTexture", function(i, book) local s = W.spells[i]; return s and s.tex or nil end)
  G("CastSpellByName", function(n) table.insert(TOT.cast, n) end)
  if not rawget(_G, "GameTooltip") then
    local gt = CreateFrame("GameTooltip", "GameTooltip", UIParent)
    gt.SetOwner = function(self, o, a) self.owner = o end
  end
  local gt = rawget(_G, "GameTooltip")
  gt.AddLine = function(self, t) table.insert(TOT.tip, t) end
  gt.Show = function(self) self.shown = true end
  gt.Hide = function(self) self.shown = false end
  -- SuperWoW : SpellInfo(sortId) -> nom (donnees de test)
  TOT.info = { [3599] = "Searing Totem", [8190] = "Magma Totem", [5675] = "Mana Spring Totem", [25908] = "Totemic Recall", [133] = "Fireball" }
end

function TOT_SPELLINFO()
  rawset(_G, "SpellInfo", function(id) return TOT.info[id] end)
end
