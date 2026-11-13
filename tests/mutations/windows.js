// Mutations du module "windows". Format : [fichier, motif, remplacement, libelle[, suite]]. Motif present EXACTEMENT une fois.
const S = 't_windows.lua';
const F = 'Mod_Windows.lua';
module.exports = [
  [F, 'if key ~= "none" and not modDown(key) then return end', 'if key ~= "none" and not IsShiftKeyDown() then return end', 'windows : touche choisie ignoree (toujours Maj)', S],
  [F, 'if key ~= "none" and not modDown(key) then return end', 'if not modDown(key) then return end', 'windows : choix "aucune touche" ignore', S],
  [F, 'if button ~= "LeftButton" then return end', '', 'windows : tout bouton de souris deplace', S],
  [F, 'C.SetPos(d.pk, left * es / ps, bottom * es / ps)', 'C.SetPos(d.pk, left, bottom)', 'windows : echelle du cadre ignoree a l\'enregistrement', S],
  [F, 'f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * ps / es, b * ps / es)', 'f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)', 'windows : echelle du cadre ignoree a l\'application', S],
  [F, '\tif o then o(a) end\n\tif M.on then M.PlaceAll() end', '\tif o then o(a) end', 'windows : position non remise apres UpdateUIPanelPositions', S],
  [F, '\t\tsetglobal("UpdateUIPanelPositions", panelUpdate)\n', '', 'windows : UpdateUIPanelPositions jamais enveloppee', S],
  [F, '\t\tsetglobal("UpdateUIPanelPositions", M.origUpdate)\n', '', 'windows : fonction Blizzard non restituee a la desactivation', S],
  [F, '\tlocal o = this.suiWinOS\n\tif o then o() end\n\tM.Place(this)', '\tM.Place(this)', 'windows : ancien OnShow de la fenetre perdu', S],
  [F, 'return M.on and C.Get(d.opt) and true or false', 'return M.on and true or false', 'windows : case deplacable par fenetre ignoree', S],
  [F, '\t\t\telseif f.suiWinMoved then\n\t\t\t\tM.Restore(f)', '\t\t\telseif false then\n\t\t\t\tM.Restore(f)', 'windows : fenetre non rendue a Blizzard au decochage', S],
  [F, 'if value then\n\t\t\tC.Set("windows.resetall", false)', 'if value then', 'windows : case "reinitialiser tout" jamais decochee', S],
  [F, 'C.ClearPosAll(d.pk)', 'C.ClearPos(d.pk .. "x")', 'windows : reinitialisation sans effet', S],
  [F, 'if arg1 == "ShikiUI" then return end\n\tM.Scan()', 'if arg1 == "ShikiUI" then return end', 'windows : fenetres a chargement a la demande non accrochees', S],
  [F, 'return (d and d.protected and SUI.InCombat()) and true or false', 'return false', 'windows : cadre protege touche en combat', S],
  [F, 'if d.skip and d.skip() then return end\n\tlocal l, b = C.GetPos(d.pk)', 'local l, b = C.GetPos(d.pk)', 'windows : banque geree par Bags deplacee quand meme', S],
  [F, 'C.Watch("pos", M.OnKey)', '', 'windows : reinitialisation globale des positions non suivie', S],
  [F, 'cost = "light",', 'cost = "heavy",', 'windows : cout declare modifie', S],
];
