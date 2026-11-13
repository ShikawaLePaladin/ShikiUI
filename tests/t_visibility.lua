-- t_visibility : service de visibilite partage (Visibility.lua) : options, matrice combat x groupe x instance x cible, evenements,
-- fondu, modes alpha / show, cadre protege, specialisation, mode deplacement, aucune creation en combat, cout nul, coupure propre.
local SUI = ShikiUI
local C = SUI.Config
local V = SUI.Visibility

-- monde simule (les mocks des autres suites redefinissent ces globales : on impose les notres)
local VW = { raid = 0, party = 0, inst = nil }
setglobal("GetNumRaidMembers", function() return VW.raid end)
setglobal("GetNumPartyMembers", function() return VW.party end)
setglobal("IsInInstance", function() if VW.inst then return 1, VW.inst end return nil, "none" end)

BOOT()
SETTLE()
W.combat = false
W.units.target = nil

local function taskCount(name)
  local n = 0
  for i = 1, table.getn(SUI.tasks) do
    if SUI.tasks[i].name == name and not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end

SECTION("t_visibility : cout nul sans cadre")
EQ("aucun cadre enregistre", V.Count(), 0)
EQ("evenements non ecoutes", V.attached, nil)
local ev0 = SUI.evCount["PARTY_MEMBERS_CHANGED"]
local vis0 = taskCount("vis")
local c0 = CREATED
Fire("PARTY_MEMBERS_CHANGED")
Fire("PLAYER_REGEN_DISABLED")
Fire("PLAYER_REGEN_ENABLED")
Pump(0.2, 3)
EQ("aucune evaluation", V.evals, 0)
EQ("aucune minuterie de visibilite", taskCount("vis") + taskCount("visfade"), vis0)
EQ("aucune creation", CREATED, c0)

SECTION("t_visibility : options (descripteurs)")
local d = V.Options("meter")
EQ("deux descripteurs", table.getn(d), 2)
EQ("cle vis", d[1].key, "meter.vis")
EQ("cle fade", d[2].key, "meter.fade")
EQ("categorie deduite", d[1].cat, "meter")
EQ("type choice", d[1].type, "choice")
EQ("defaut toujours", d[1].default, "always")
EQ("liste partagee", d[1].choices, V.CHOICES)
EQ("fondu par defaut", d[2].default, V.DEFAULT_FADE)
local d2 = V.Options("tracker.win", { cat = "tracker", order = 500, default = "combat" })
EQ("categorie imposee", d2[1].cat, "tracker")
EQ("ordre", d2[2].order, 501)
EQ("defaut impose", d2[1].default, "combat")
local want = { "always", "combat", "ooc", "group", "raid", "instance", "pvp", "solo", "target", "spec:1", "spec:2", "spec:3", "never" }
EQ("nombre de choix", table.getn(V.CHOICES), table.getn(want))
for i = 1, table.getn(want) do
  EQ("choix " .. want[i], V.CHOICES[i], want[i])
  local txt = d[1].choiceText(d[1], want[i])
  T("texte FR du choix " .. want[i], type(txt) == "string" and txt ~= "" and not string.find(txt, "^choice%."))
end
T("libelle et infobulle traduits", SUI.L(d[1].label) ~= d[1].label and SUI.L(d[1].tip) ~= d[1].tip and SUI.L(d[2].label) ~= d[2].label)
SUI.SetLocale("en")
EQ("EN : toujours", d[1].choiceText(d[1], "always"), "Always")
SUI.SetLocale("fr")
-- enregistrement par un module : valeurs validees
for i = 1, 2 do SUI.RegisterOption(d[i]) end
EQ("defaut lu", C.Get("meter.vis"), "always")
local okSet = C.Set("meter.vis", "raid")
EQ("choix valide accepte", C.Get("meter.vis"), "raid")
C.Set("meter.vis", "nimporte")
EQ("choix inconnu refuse", C.Get("meter.vis"), "raid")
C.Set("meter.vis", "spec:2")
EQ("spec:2 accepte", C.Get("meter.vis"), "spec:2")
C.Set("meter.vis", "always")
C.Set("meter.fade", 9)
EQ("fondu borne", C.Get("meter.fade"), 2)
C.Set("meter.fade", V.DEFAULT_FADE)

SECTION("t_visibility : matrice combat x groupe x instance x cible x choix")
local f = CreateFrame("Frame")
local c1 = CREATED
EQ("Add accepte le cadre", V.Add(f, "mx"), true)
EQ("Add ne cree rien", CREATED, c1)
EQ("options declarees par Add", C.meta["mx.vis"] ~= nil and C.meta["mx.fade"] ~= nil, true)
EQ("un cadre", V.Count(), 1)
EQ("evenements ecoutes", V.attached, true)
C.Set("mx.fade", 0)
EQ("Add refuse un non-cadre", V.Add(nil, "mx"), false)
EQ("Add refuse un prefixe absent", V.Add(f, nil), false)

local function expect(choice, s)
  if choice == "always" then return true end
  if choice == "never" then return false end
  if choice == "combat" then return s.combat end
  if choice == "ooc" then return not s.combat end
  if choice == "group" then return s.grp ~= "solo" end
  if choice == "raid" then return s.grp == "raid" end
  if choice == "solo" then return s.grp == "solo" end
  if choice == "instance" then return s.inst == "party" or s.inst == "raid" end
  if choice == "pvp" then return s.inst == "pvp" or s.inst == "arena" end
  if choice == "target" then return s.target end
  return true      -- spec:n avec specialisation inconnue
end
local grp = { "solo", "party", "raid" }
local insts = { "none", "party", "raid", "pvp", "arena" }
local bad = 0
local total = 0
for ci = 1, 2 do
  for gi = 1, 3 do
    for ii = 1, 5 do
      for ti = 1, 2 do
        local s = { combat = (ci == 2), grp = grp[gi], inst = (insts[ii] ~= "none") and insts[ii] or nil, target = (ti == 2) }
        W.combat = s.combat
        VW.raid = (s.grp == "raid") and 5 or 0
        VW.party = (s.grp == "party") and 2 or 0
        VW.inst = s.inst
        if s.target then MKTARGET({ name = "X" }) else W.units.target = nil end
        for k = 1, table.getn(want) do
          C.Set("mx.vis", want[k])
          V.Refresh()
          total = total + 1
          local shown = (f:GetAlpha() > 0.99)
          local hidden = (f:GetAlpha() < 0.01)
          local e = expect(want[k], s)
          if not ((e and shown) or (not e and hidden)) or V.Allowed(f) ~= e then
            bad = bad + 1
            if bad < 6 then print("  matrice : " .. want[k] .. " combat=" .. tostring(s.combat) .. " grp=" .. s.grp .. " inst=" .. tostring(s.inst) .. " cible=" .. tostring(s.target) .. " alpha=" .. f:GetAlpha()) end
          end
        end
      end
    end
  end
end
EQ("matrice (" .. total .. " cas) sans ecart", bad, 0)
W.combat = false
VW.raid, VW.party, VW.inst = 0, 0, nil
W.units.target = nil
C.Set("mx.vis", "always")
V.Refresh()

SECTION("t_visibility : evenements")
C.Set("mx.vis", "group")
EQ("solo : masque", f:GetAlpha(), 0)
VW.party = 2
Fire("PARTY_MEMBERS_CHANGED")
EQ("evenement groupe : differe (rafale)", f:GetAlpha(), 0)
Pump(0.15)
EQ("groupe forme : visible", f:GetAlpha(), 1)
VW.party, VW.raid = 0, 3
Fire("RAID_ROSTER_UPDATE")
Fire("RAID_ROSTER_UPDATE")
Fire("PARTY_MEMBERS_CHANGED")
local e0 = V.evals
Pump(0.15)
EQ("une seule evaluation pour la rafale", V.evals, e0 + 1)
EQ("raid : visible", f:GetAlpha(), 1)
VW.raid = 0
Fire("RAID_ROSTER_UPDATE")
Pump(0.15)
EQ("groupe dissous : masque", f:GetAlpha(), 0)
C.Set("mx.vis", "instance")
EQ("hors instance : masque", f:GetAlpha(), 0)
VW.inst = "party"
Fire("ZONE_CHANGED_NEW_AREA")
Pump(0.15)
EQ("zone d'instance : visible", f:GetAlpha(), 1)
VW.inst = nil
Fire("PLAYER_ENTERING_WORLD")
Pump(0.15)
EQ("sortie d'instance : masque", f:GetAlpha(), 0)
-- combat : l'evenement impose l'etat meme si UnitAffectingCombat est en retard
C.Set("mx.vis", "combat")
EQ("hors combat : masque", f:GetAlpha(), 0)
Fire("PLAYER_REGEN_DISABLED")
EQ("entree en combat : immediat", f:GetAlpha(), 1)
Fire("PLAYER_REGEN_ENABLED")
EQ("sortie de combat : immediat", f:GetAlpha(), 0)
-- cible
C.Set("mx.vis", "target")
EQ("sans cible : masque", f:GetAlpha(), 0)
MKTARGET({ name = "Y" })
Fire("PLAYER_TARGET_CHANGED")
Pump(0.15)
EQ("cible : visible", f:GetAlpha(), 1)
W.units.target = nil
Fire("PLAYER_TARGET_CHANGED")
Pump(0.15)
EQ("cible perdue : masque", f:GetAlpha(), 0)
-- le changement de cible n'evalue rien quand aucun cadre n'a le choix "cible"
C.Set("mx.vis", "always")
local e1 = V.evals
Fire("PLAYER_TARGET_CHANGED")
Pump(0.15)
EQ("changement de cible ignore", V.evals, e1)

SECTION("t_visibility : specialisation")
local Sp = SUI.Specs
local keepCur = Sp.cur
C.Set("mx.vis", "spec:2")
Sp.cur = nil
V.Refresh()
EQ("spe inconnue : visible", f:GetAlpha(), 1)
Sp.cur = { n = 3, id = 2, total = 31, pts = { 0, 31, 0 }, names = { "A", "B", "C" } }
V.Refresh()
EQ("spe 2 active : visible", f:GetAlpha(), 1)
Sp.cur = { n = 3, id = 1, total = 31, pts = { 31, 0, 0 }, names = { "A", "B", "C" } }
Fire("CHARACTER_POINTS_CHANGED")
Pump(0.15)
EQ("spe 1 active : spe:2 masque", f:GetAlpha(), 0)
Sp.cur = { n = 3, id = 0, total = 5, pts = { 2, 2, 1 }, names = { "A", "B", "C" } }
V.Refresh()
EQ("hybride (id 0) : visible (inconnu)", f:GetAlpha(), 1)
CONTAINS("texte avec nom de spe", d[1].choiceText(d[1], "spec:2"), "B")
Sp.cur = keepCur

SECTION("t_visibility : fondu")
C.Set("mx.vis", "combat")
C.Set("mx.fade", 0.3)
W.combat = false
V.Refresh()
EQ("masque", f:GetAlpha(), 0)
Fire("PLAYER_REGEN_DISABLED")
EQ("fondu demarre : opacite encore basse", f:GetAlpha(), 0)
EQ("minuterie de fondu active", taskCount("visfade"), 1)
Pump(0.03, 4)
T("fondu en cours : entre 0 et 1", f:GetAlpha() > 0.1 and f:GetAlpha() < 0.95)
local mid = f:GetAlpha()
Pump(0.03, 3)
T("fondu monotone", f:GetAlpha() > mid)
Pump(0.03, 12)
EQ("fondu termine", f:GetAlpha(), 1)
Pump(0.03, 2)
EQ("minuterie arretee", taskCount("visfade"), 0)
-- retournement en plein fondu
Fire("PLAYER_REGEN_ENABLED")
Pump(0.03, 3)
local part = f:GetAlpha()
T("fondu sortant en cours", part < 1 and part > 0)
Fire("PLAYER_REGEN_DISABLED")
Pump(0.03, 3)
T("retournement : remonte", f:GetAlpha() > part)
Pump(0.03, 15)
EQ("fin : visible", f:GetAlpha(), 1)
Fire("PLAYER_REGEN_ENABLED")
Pump(0.03, 15)
EQ("fin : masque", f:GetAlpha(), 0)
EQ("plus de minuterie", taskCount("visfade"), 0)
C.Set("mx.fade", 0)

SECTION("t_visibility : opacite de base")
V.Remove(f)
local g = CreateFrame("Frame")
g:SetAlpha(0.6)
V.Add(g, "bs", { alpha = 0.6 })
C.Set("bs.fade", 0)
C.Set("bs.vis", "combat")
EQ("masque a 0", g:GetAlpha(), 0)
Fire("PLAYER_REGEN_DISABLED")
EQ("visible a l'opacite du module", g:GetAlpha(), 0.6)
V.SetBase(g, 0.4)
EQ("nouvelle opacite pleine", g:GetAlpha(), 0.4)
Fire("PLAYER_REGEN_ENABLED")
V.Remove(g)
EQ("retrait : opacite d'origine restauree", g:GetAlpha(), 0.4)

SECTION("t_visibility : mode show, rappel onChange, Allowed")
local h = CreateFrame("Frame")
local calls = {}
V.Add(h, "sh", { mode = "show", onChange = function(v, fr) table.insert(calls, v and "on" or "off") end })
C.Set("sh.fade", 0)
EQ("rappel initial", calls[1], "on")
EQ("visible au depart", h:IsShown(), true)
C.Set("sh.vis", "combat")
EQ("Hide reel hors combat", h:IsShown(), false)
EQ("rappel off", calls[2], "off")
EQ("Allowed faux", V.Allowed(h), false)
Fire("PLAYER_REGEN_DISABLED")
EQ("Show reel en combat (non protege)", h:IsShown(), true)
EQ("rappel on", calls[3], "on")
EQ("Allowed vrai", V.Allowed(h), true)
Fire("PLAYER_REGEN_DISABLED")
EQ("pas de rappel sans changement", table.getn(calls), 3)
EQ("Allowed d'un cadre inconnu", V.Allowed(CreateFrame("Frame")), true)
Fire("PLAYER_REGEN_ENABLED")
-- fondu avec Show/Hide differe a la fin du fondu
C.Set("sh.fade", 0.2)
Fire("PLAYER_REGEN_DISABLED")
Pump(0.03, 3)
T("en fondu : toujours affiche", h:IsShown())
Pump(0.03, 10)
EQ("apres le fondu : visible", h:GetAlpha(), 1)
Fire("PLAYER_REGEN_ENABLED")
Pump(0.03, 3)
EQ("sortant : encore affiche pendant le fondu", h:IsShown(), true)
Pump(0.03, 12)
EQ("fondu fini : cache", h:IsShown(), false)
V.Remove(h)

SECTION("t_visibility : cadre protege (jamais de Show/Hide en combat)")
local p = CreateFrame("Frame")
V.Add(p, "pr", { mode = "show", protected = true })
C.Set("pr.fade", 0)
C.Set("pr.vis", "ooc")
W.combat = false
V.Refresh()
EQ("hors combat : visible", p:IsShown(), true)
W.combat = true
local c2 = CREATED
Fire("PLAYER_REGEN_DISABLED")
EQ("combat : opacite 0", p:GetAlpha(), 0)
EQ("combat : Hide differe (toujours affiche)", p:IsShown(), true)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
EQ("opacite revenue", p:GetAlpha(), 1)
-- masque hors combat, puis combat : pas de Show en combat
C.Set("pr.vis", "combat")
EQ("hors combat avec choix combat : cache", p:IsShown(), false)
W.combat = true
Fire("PLAYER_REGEN_DISABLED")
EQ("combat : Show differe (reste cache)", p:IsShown(), false)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
Fire("PLAYER_REGEN_DISABLED")
Fire("PLAYER_REGEN_ENABLED")
EQ("etat final coherent", p:IsShown(), false)
V.Remove(p)

SECTION("t_visibility : module coupe, mode deplacement")
local m = CreateFrame("Frame")
SUI.modules.zzvis = { enabled = true }
V.Add(m, "md", { module = "zzvis" })
C.Set("md.fade", 0)
C.Set("md.vis", "never")
EQ("module actif : masque", m:GetAlpha(), 0)
SUI.modules.zzvis.enabled = false
V.Refresh()
EQ("module coupe : opacite d'origine, plus touche", m:GetAlpha(), 1)
C.Set("md.vis", "never")
EQ("module coupe : un reglage ne le masque pas", m:GetAlpha(), 1)
SUI.modules.zzvis.enabled = true
V.Refresh()
EQ("module reactive : masque", m:GetAlpha(), 0)
local keepMover = SUI.Mover.active
SUI.Mover.active = true
V.Refresh()
EQ("mode deplacement : toujours visible", m:GetAlpha(), 1)
SUI.Mover.active = keepMover
V.Refresh()
EQ("fin du deplacement : masque", m:GetAlpha(), 0)
V.Remove(m)
SUI.modules.zzvis = nil

SECTION("t_visibility : aucune creation en combat, aucune erreur")
local q = CreateFrame("Frame")
W.combat = true
local c3 = CREATED
V.Add(q, "cb", { mode = "show" })
C.Set("cb.vis", "group")
Fire("PARTY_MEMBERS_CHANGED")
Fire("RAID_ROSTER_UPDATE")
Fire("ZONE_CHANGED_NEW_AREA")
Fire("PLAYER_ENTERING_WORLD")
Fire("PLAYER_REGEN_DISABLED")
Fire("PLAYER_TARGET_CHANGED")
Pump(0.2, 5)
EQ("rien cree en combat", CREATED, c3)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
Pump(0.2, 3)
EQ("rien cree a la sortie de combat", CREATED, c3)
V.Remove(q)
EQ("aucune erreur", SUI.errCount, 0)

SECTION("t_visibility : coupure propre")
EQ("un seul cadre restant (mx deja retire, bs, sh, pr, md, cb retires)", V.Count(), 0)
EQ("evenements detaches", V.attached, false)
local ev2 = V.evals
local tasks0 = table.getn(SUI.tasks)
Fire("PARTY_MEMBERS_CHANGED")
Fire("PLAYER_REGEN_DISABLED")
C.Set("mx.vis", "never")
Pump(0.3, 3)
EQ("plus aucune evaluation", V.evals, ev2)
EQ("plus de minuterie de fondu", taskCount("visfade"), 0)
EQ("Remove d'un inconnu", V.Remove(f), false)
-- reinscription apres coupure : tout repart
local r = CreateFrame("Frame")
V.Add(r, "mx", {})
EQ("reinscription : evenements rebranches", V.attached, true)
EQ("reinscription : mx.vis = never applique", r:GetAlpha(), 0)
V.Remove(r)
EQ("re-coupure", V.attached, false)

SECTION("t_visibility : textes")
local missing = 0
for k, _ in pairs(SUI.missingL) do
  if string.find(k, "visibility") then missing = missing + 1 print("  cle manquante : " .. k) end
end
EQ("aucune cle de traduction manquante", missing, 0)
EQ("aucune cle ignoree", SUI.localeSkipped["fr:opt.visibility.vis"], nil)
EQ("erreurs finales", SUI.errCount, 0)

DONE()
