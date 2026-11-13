// Mutations du module "actionbars" (copiees sous tests\mutations\<nom>.js). Format : [fichier, motif, remplacement, libelle[, suite]].
// Le motif doit exister EXACTEMENT une fois dans le fichier (sinon "motif introuvable" = echec) ; chaque mutation doit faire echouer
// au moins une suite. Regle : une mutation par comportement important du module (pas par ligne).
const S = 't_actionbars.lua';
const F = 'Mod_Actionbars.lua';
module.exports = [
  // raccourcis : branchement sur le service SUI.Bind
  [F, 'if f.bar and f.cmd and f.kind then return f.cmd end', 'if false then return f.cmd end', 'actionbars : les boutons des barres se declarent au service de raccourcis', S],
  [F, 'M.bind = on and true or false', 'M.bind = false', 'actionbars : le mode raccourcis rend les barres visibles', S],
  // emplacements et pages
  [F, 'bar2   = { kind = "action", base = 60,', 'bar2   = { kind = "action", base = 48,', 'actionbars : base de la barre 2 (bas gauche)', S],
  [F, 'bar3   = { kind = "action", base = 48,', 'bar3   = { kind = "action", base = 60,', 'actionbars : base de la barre 3 (bas droite)', S],
  [F, 'bar4   = { kind = "action", base = 24,', 'bar4   = { kind = "action", base = 36,', 'actionbars : base de la barre 4 (droite)', S],
  [F, 'bar5   = { kind = "action", base = 36,', 'bar5   = { kind = "action", base = 24,', 'actionbars : base de la barre 5 (gauche)', S],
  [F, 'return (NUM_ACTIONBAR_PAGES or 6) + off end', 'return off end', 'actionbars : page de la barre bonus (forme, camouflage)', S],
  [F, 'if cfg.autopage and page == 1 and GetBonusBarOffset then', 'if page == 1 and GetBonusBarOffset then', 'actionbars : option suivre les formes ignoree', S],
  [F, 'local base = (page - 1) * 12', 'local base = page * 12', 'actionbars : decalage de page', S],
  // recharges et etats
  [F, 'd > 0 and en ~= 0 and ((gcd', 'd > 0 and ((gcd', 'actionbars : recharge arretee (en = 0) affichee', S],
  [F, '(not gcd and d >= cfg.cdmin)', '(not gcd)', 'actionbars : recharge minimale ignoree', S],
  [F, 'return NO_TINT, c[2] * 0.45, c[3] * 0.45', 'return NO_TINT, NO_TINT, NO_TINT', 'actionbars : teinte hors de portee', S],
  [F, 'return r + (NO_TINT - r) * 0.35, g + (NO_TINT - g) * 0.35, bl + (NO_TINT - bl) * 0.35', 'return r, g, bl', 'actionbars : teinte ressource insuffisante', S],
  [F, '		if maxlv then pcall(hideBar, xp) else pcall(pin, xp, "BOTTOMLEFT", 0, 0, 5) end', '		pcall(pin, xp, "BOTTOMLEFT", 0, 0, 5)', 'actionbars : experience vide montree au niveau 60', S],
  // clics et raccourcis
  [F, 'if (cfg.altself and IsAltKeyDown()) or (cfg.rightself and mouse == "RightButton") then onself = 1 end', 'if (IsAltKeyDown()) or (cfg.rightself and mouse == "RightButton") then onself = 1 end', 'actionbars : option Alt sur soi ignoree', S],
  [F, 'if (cfg.altself and IsAltKeyDown()) or (cfg.rightself and mouse == "RightButton") then onself = 1 end', 'if (cfg.altself and IsAltKeyDown()) or (mouse == "RightButton") then onself = 1 end', 'actionbars : option clic droit sur soi ignoree', S],
  [F, 'UseAction(b.slot, 1, onself)', 'UseAction(b.slot, nil, onself)', 'actionbars : UseAction sans le drapeau de clic', S],
  [F, 'if cfg.lockdrag and not IsShiftKeyDown() then return end', 'if not IsShiftKeyDown() then return end', 'actionbars : option Maj pour deplacer ignoree', S],
  // visibilite
  [F, 'if not (M.combat or bar.hover or M.bind) then a = cfg.fade end', 'if not (bar.hover or M.bind) then a = cfg.fade end', 'actionbars : barre opaque en combat', S],
  [F, 'if not (bar.hover or M.bind) then a = cfg.fade end', 'if not (M.bind) then a = cfg.fade end', 'actionbars : barre opaque au survol', S],
  [F, 'cfg.fade = C.Get("actionbars.fade") / 100', 'cfg.fade = 0.5', 'actionbars : opacite estompee ignoree', S],
  // Blizzard, pfUI, cycle de vie
  [F, 'if f.Show then f.Show = noop end', '', 'actionbars : Show() de Blizzard non neutralise', S],
  [F, 'M.StyleXpBars()\n\tif SUI.Migrate and SUI.Migrate.Running and SUI.Migrate.Running("actionbar") then return end', 'M.StyleXpBars()', 'actionbars : barres de Blizzard masquees alors que pfUI les remplace', S],
  [F, 'if M.killed or not cfg.hideblizz then return end', 'if M.killed then return end', 'actionbars : option masquer Blizzard ignoree', S],
  [F, '\tSUI.Cancel(M.task)\n', '', 'actionbars : minuterie non annulee a la desactivation', S],
  [F, 'SUI.WhenSafe(M.Build)', 'M.Build()', 'actionbars : construction en combat', S],
  [F, 'SUI.Migrate.MAP.actionbars = { "actionbar" }', 'SUI.Migrate.MAP.actionbars = { "actionbars" }', 'actionbars : equivalent pfUI mal declare', S],
  [F, '["actionbars.tooltips"] = "safe",', '["actionbars.tooltips"] = "always",', 'actionbars : preset Raid (infobulles)', S],
  [F, '["actionbars.bar4.show"] = "hover", ["actionbars.bar5.show"] = "hover"', '["actionbars.bar4.show"] = "always", ["actionbars.bar5.show"] = "hover"', 'actionbars : preset Raid (barre 4)', S],
  [F, 'cost = "medium",', 'cost = "heavy",', 'actionbars : cout declare modifie', S],
  [F, 'default = false,', 'default = true,', 'actionbars : module actif par defaut', S],
];
