// Mutations du module "powerauras". Format : [fichier, motif, remplacement, libelle[, suite]]. Motif present EXACTEMENT une fois.
module.exports = [
  ['Mod_PowerAuras.lua', 'return a.when == "has" and a.cnt >= a.minst', 'return a.when == "has"', 'powerauras : piles minimum ignorees', 't_powerauras.lua'],
  ['Mod_PowerAuras.lua', 'a.frac = mmin(1, left / dur)', 'a.frac = 1', 'powerauras : fraction de recharge perdue', 't_powerauras.lua'],
  ['Mod_PowerAuras.lua', 'if now - M.lastSound < M.SOUND_GAP then return end', '', 'powerauras : delai entre sons ignore', 't_powerauras.lua'],
  ['Mod_PowerAuras.lua', 'local quiet = now < M.quietUntil', 'local quiet = false', 'powerauras : periode calme ignoree', 't_powerauras.lua'],
  ['Mod_PowerAuras.lua', 'a.clsok = (a.cls == "ANY" or a.cls == M.class)', 'a.clsok = true', 'powerauras : filtre de classe ignore', 't_powerauras.lua'],
  ['Mod_PowerAuras.lua', 'f:SetPoint("TOPRIGHT", z, "TOPRIGHT", -off, 0)', 'f:SetPoint("TOPRIGHT", z, "TOPRIGHT", off, 0)', 'powerauras : direction gauche inversee', 't_powerauras.lua'],
  ['Mod_PowerAuras.lua', 'if M.nal >= M.MAXA then return nil, "full" end\n\tlocal parts = M.Parts()', 'local parts = M.Parts()', 'powerauras : limite de 24 alertes', 't_powerauras.lua'],
  ['Mod_PowerAuras.lua', 'cost = "light",', 'cost = "heavy",', 'powerauras : cout declare modifie', 't_powerauras.lua'],
  ['Mod_PowerAuras.lua', '\t\t\tt.glowA = -1\n', '', 'powerauras : lueur fixe apres pulsation', 't_powerauras.lua'],
];
