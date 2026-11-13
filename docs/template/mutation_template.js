// Mutations du module "template" (copiees sous tests\mutations\<nom>.js). Format : [fichier, motif, remplacement, libelle[, suite]].
// Le motif doit exister EXACTEMENT une fois dans le fichier (sinon "motif introuvable" = echec) ; chaque mutation doit faire echouer
// au moins une suite. Regle : une mutation par comportement important du module (pas par ligne).
module.exports = [
  ['Mod_Template.lua', 'M.count = SUI.Target.Visible(true)', 'M.count = SUI.Target.Visible(false) + 1', 'template : mauvais compte', 't_template.lua'],
  ['Mod_Template.lua', 'if M.on and C.Get("template.visible") then M.frame:Show() else M.frame:Hide() end', 'M.frame:Show()', 'template : reglage visible ignore', 't_template.lua'],
  ['Mod_Template.lua', 'M.frame:SetWidth(C.Get("template.width"))', 'M.frame:SetWidth(120)', 'template : largeur ignoree', 't_template.lua'],
  ['Mod_Template.lua', '\tSUI.Cancel(M.task)\n', '', 'template : minuterie non annulee a la desactivation', 't_template.lua'],
  ['Mod_Template.lua', 'SUI.Config.AddPreset("raid", "*", { ["template.width"] = 90 })', 'SUI.Config.AddPreset("raid", "*", { ["template.width"] = 120 })', 'template : preset Raid perdu', 't_template.lua'],
  ['Mod_Template.lua', 'cost = "light",', 'cost = "heavy",', 'template : cout declare modifie', 't_template.lua'],
];
