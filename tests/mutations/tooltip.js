// Mutations du module "tooltip". Format : [fichier, motif, remplacement, libelle, suite].
const F = 'Mod_Tooltip.lua', S = 't_tooltip.lua';
module.exports = [
  [F, 'if r and cfg.classcolor then', 'if false then', 'tooltip : couleur de nom ignoree', S],
  [F, 'if r and cfg.bordercolor then M.SetBorder(r, g, b) else M.SetBorder(nil) end', 'M.SetBorder(nil)', 'tooltip : bordure coloree des unites', S],
  [F, 'if cfg.target then\n\t\tlocal tu = M.tgt[unit]', 'if false then\n\t\tlocal tu = M.tgt[unit]', 'tooltip : cible de la cible ignoree', S],
  [F, 'if cfg.unitid and not UnitIsPlayer(unit) then', 'if cfg.unitid then', 'tooltip : ID affiche pour les joueurs', S],
  [F, 'if cfg.itemlevel and not M.HasLevelLine() then', 'if cfg.itemlevel then', 'tooltip : niveau d\'objet en double', S],
  [F, 'if cfg.itemid then GameTooltip:AddLine', 'if false then GameTooltip:AddLine', 'tooltip : ID d\'objet ignore', S],
  [F, 'if ok and type(v) == "number" and v > 0 then return v end', '', 'tooltip : niveau Nampower ignore', S],
  [F, 'local _, _, _, lv = GetItemInfo(link)', 'local _, _, lv = GetItemInfo(link)', 'tooltip : mauvais retour de niveau d\'objet', S],
  [F, 'if s and strfind(s, "^Item Level") then return true end', 'if false then return true end', 'tooltip : ligne de niveau deja presente', S],
  [F, 'if M.cfg.hpvalue and u and GameTooltip:IsShown() and UnitExists(u) then', 'if u and GameTooltip:IsShown() and UnitExists(u) then', 'tooltip : texte de vie ignore', S],
  [F, 'bar:SetAlpha(M.cfg.hpbar and 1 or 0)', 'bar:SetAlpha(1)', 'tooltip : barre de vie ignoree', S],
  [F, 'if unit and M.world and cfg.combathide and SUI.InCombat() then', 'if unit and cfg.combathide and SUI.InCombat() then', 'tooltip : masquage en combat hors du monde', S],
  [F, 'if unit and M.world and cfg.combathide and SUI.InCombat() then', 'if unit and M.world and SUI.InCombat() then', 'tooltip : option masquer en combat ignoree', S],
  [F, 'if M.on and M.cfg.anchor == "cursor" then', 'if false then', 'tooltip : ancrage au curseur ignore', S],
  [F, 'if M.on then M.world = (parent == UIParent) end', 'if M.on then M.world = true end', 'tooltip : infobulle de l\'interface prise pour le monde', S],
  [F, 'GameTooltip:SetScale(cfg.scale)', 'GameTooltip:SetScale(1)', 'tooltip : echelle ignoree', S],
  [F, '["tooltip.combathide"] = true, ["tooltip.hpvalue"] = false', '["tooltip.combathide"] = false, ["tooltip.hpvalue"] = true', 'tooltip : preset Raid perdu', S],
  [F, 'cost = "light",', 'cost = "heavy",', 'tooltip : cout declare modifie', S],
];
