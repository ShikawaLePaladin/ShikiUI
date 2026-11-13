// Mutations du gestionnaire d'addons (Addons.lua), du bouton du menu Echap (GameMenu.lua) et des boutons du menu. Format : [fichier, motif, remplacement, libelle[, suite]].
const S = 't_addons.lua';
const F = 'Addons.lua';
const G = 'GameMenu.lua';
module.exports = [
  [F, 'A.CRITICAL = { "nampower", "perfboost", "superwow", "unitxp" }', 'A.CRITICAL = { "perfboost", "superwow", "unitxp" }', 'addons : nampower est critique', S],
  [F, 'if low == "shikiui" then return true end', '', 'addons : ShikiUI est critique', S],
  [F, 'if cur and A.IsCritical(name) then', 'if false then', 'addons : coupure critique en deux clics', S],
  [F, 'now - a.at <= A.CONFIRM', 'now - a.at <= 600', 'addons : delai du 2e clic', S],
  [F, 'if A.base[name] == nil then A.base[name] = e.on end', 'A.base[name] = e.on', 'addons : etat de depart conserve', S],
  [F, 'if f == "mine" and not A.IsMine(e.name) then return false end', '', 'addons : filtre Mes Shiki*', S],
  [F, 'if f == "off" and e.on then return false end', '', 'addons : filtre Inactifs', S],
  [F, 'string.find(string.lower(e.title), q, 1, true)', 'false', 'addons : recherche sur le titre', S],
  [F, 'if SUI.InCombat() then\n\t\tSUI.Print(L("msg.addons.combat"))', 'if false then\n\t\tSUI.Print(L("msg.addons.combat"))', 'addons : pas de rechargement en combat', S],
  [F, 'if string.lower(e.name) == "shikiui" then want = true end', '', 'addons : un ensemble ne coupe jamais ShikiUI', S],
  [F, 'if want ~= e.on then tinsert(res', 'if true then tinsert(res', 'addons : seulement les differences', S],
  ['Mode.lua', 'if SUI.Addons then SUI.Addons.OnMode(mode) end', '', 'addons : rappel a l\'entree en Raid', S],
  [F, 's = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")', '', 'addons : codes de couleur retires', S],
  [F, 'elseif e.on and not e.loadable then', 'elseif false then', 'addons : addon non chargeable', S],
  [F, 'if A.MemAvailable() then pcall(getglobal("UpdateAddOnMemoryUsage")) end', '', 'addons : memoire rafraichie', S],
  [G, 'if e.text == macros then return e.b, "macros" end', '', 'menu Echap : modele Macros', S],
  [G, 'if not low or e.top < low.top then low = e end', 'low = e', 'menu Echap : repli sous le dernier bouton du bloc', S],
  [G, 'if G.button then return true end', '', 'menu Echap : pas de doublon', S],
  [G, 'if string.find(rp, "BOTTOM") then shift = 0', 'if false then shift = 0', 'menu Echap : bouton pose sur le bas de la fenetre', S],
  [G, 'b:SetWidth(model:GetWidth())', '', 'menu Echap : meme largeur que le modele', S],
  [G, 'pcall(CreateFrame, "Button", G.NAME, frame, G.TEMPLATES[i])', 'pcall(CreateFrame, "Button", G.NAME, frame, G.TEMPLATES[1])', 'menu Echap : repli de modele de bouton', S],
  [G, 'if SUI.Menu then SUI.Menu.Show() end', '', 'menu Echap : le bouton ouvre ShikiUI', S],
  ['Menu.lua', 'f.moveBtn = lift(f, T.Button(f, "", 92, 22, function() if SUI.Mover then SUI.Mover.Toggle() end end))', 'f.moveBtn = lift(f, T.Button(f, "", 92, 22, function() end))', 'menu : bouton Deplacer', S],
  ['Menu.lua', 'f.bindBtn = lift(f, T.Button(f, "", 84, 22, function() if SUI.Bind then SUI.Bind.Toggle() end end))', 'f.bindBtn = lift(f, T.Button(f, "", 84, 22, function() end))', 'menu : bouton Raccourcis', S],
  ['Menu.lua', 'if fam.id == "tools" then\n\t\t\ttinsert(nav, { kind = "page", id = "addons" })', 'if fam.id == "zzz" then\n\t\t\ttinsert(nav, { kind = "page", id = "addons" })', 'menu : page Addons dans la famille Outils', S],
  ['Menu_Pages.lua', 'M.ActionCard(L("mod.mover.title"), L("mod.menu.card.move.desc"), function() SUI.Mover.Toggle() end, SUI.Mover.active)', 'M.ActionCard(L("mod.mover.title"), L("mod.menu.card.move.desc"), function() end, SUI.Mover.active)', 'menu : carte Deplacer l\'interface de l\'accueil', S],
];
