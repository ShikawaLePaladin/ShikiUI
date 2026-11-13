-- mock_castbar : extension de simulation du module "castbar" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : CB_SETUP() (appele par t_castbar.lua seulement) cree CastingBarFrame, le grimoire et les fonctions
-- du client. Noms d'API releves dans les addons installes : GetSpellName / GetSpellTexture / BOOKTYPE_SPELL (1.12), CastingBarFrame et ses
-- evenements SPELLCAST_* (FrameXML 1.12, voir SpellStatusV2 de BigWigs), SpellInfo (SuperWoW), GetNetStats. Valeurs = DONNEES DE TEST.
ALLOW("CB")

CB_EVENTS = { "SPELLCAST_START", "SPELLCAST_STOP", "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED", "SPELLCAST_DELAYED",
  "SPELLCAST_CHANNEL_START", "SPELLCAST_CHANNEL_UPDATE", "SPELLCAST_CHANNEL_STOP" }

function CB_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  CB = { shows = 0 }
  local cbf = CreateFrame("Frame", "CastingBarFrame", UIParent)
  for _, e in ipairs(CB_EVENTS) do cbf:RegisterEvent(e) end
  cbf:SetScript("OnShow", function() CB.shows = CB.shows + 1 end)
  W.spells = {
    { name = "Fireball", rank = "Rank 1", tex = "Interface\\Icons\\Spell_Fire_FlameBolt" },
    { name = "Fireball", rank = "Rank 2", tex = "Interface\\Icons\\Spell_Fire_FlameBolt" },
    { name = "Drain Life", rank = "Rank 1", tex = "Interface\\Icons\\Spell_Shadow_LifeDrain02" },
  }
  G("BOOKTYPE_SPELL", "spell")
  G("GetSpellName", function(i, book)
    local s = W.spells[i]
    if not s then return nil end
    return s.name, s.rank
  end)
  G("GetSpellTexture", function(i, book) local s = W.spells[i]; return s and s.tex or nil end)
  -- SuperWoW : SpellInfo(sortId) -> nom, rang, texture (donnees de test)
  CB.info = {
    [133] = { "Fireball", "Rank 1", "Interface\\Icons\\Spell_Fire_FlameBolt" },
    [689] = { "Drain Life", "Rank 1", "Interface\\Icons\\Spell_Shadow_LifeDrain02" },
  }
end

function CB_SPELLINFO()
  rawset(_G, "SpellInfo", function(id)
    local x = CB.info[id]
    if not x then return nil end
    return x[1], x[2], x[3]
  end)
end

-- FIREX(evenement, a1 ... a9) : comme Fire, mais pose aussi arg6..arg9 (evenements Nampower a plus de 5 arguments).
function FIREX(ev, a1, a2, a3, a4, a5, a6, a7, a8, a9)
  rawset(_G, "arg6", a6); rawset(_G, "arg7", a7); rawset(_G, "arg8", a8); rawset(_G, "arg9", a9)
  Fire(ev, a1, a2, a3, a4, a5)
  rawset(_G, "arg6", nil); rawset(_G, "arg7", nil); rawset(_G, "arg8", nil); rawset(_G, "arg9", nil)
end
