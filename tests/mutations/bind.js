// Mutations du mode raccourcis (Bind.lua). Format : [fichier, motif, remplacement, libelle[, suite]]. Motif present EXACTEMENT une fois.
const S = 't_bind.lua';
const F = 'Bind.lua';
module.exports = [
  [F, 'if IsAltKeyDown() then p = p .. "ALT-" end', '', 'bind : prefixe ALT', S],
  [F, 'if IsControlKeyDown() then p = p .. "CTRL-" end', 'if IsControlKeyDown() then p = p .. "SHIFT-" end', 'bind : prefixe CTRL', S],
  [F, 'if IsShiftKeyDown() then p = p .. "SHIFT-" end', '', 'bind : prefixe SHIFT', S],
  [F, 'if not k or M.MODKEYS[k] then return end', 'if not k then return end', 'bind : une touche de modification seule est ignoree', S],
  [F, 'if k1 and k2 then setKey(ops, k1, nil) end', '', 'bind : au plus deux touches par commande', S],
  [F, 'elseif changed then\n\t\tSaveBindings(GetCurrentBindingSet())', 'else\n\t\tSaveBindings(GetCurrentBindingSet())', 'bind : SaveBindings seulement s\'il y a eu des changements', S],
  [F, 'while M.n > 0 do M.Undo() end', '', 'bind : tout abandonner annule les changements', S],
  [F, 'if existing then\n\t\tM.AskConflict(key, existing, cmd)\n\t\treturn false\n\tend', '', 'bind : un conflit pose une question', S],
  [F, 'if existing == cmd then', 'if false then', 'bind : meme touche sur la meme commande', S],
  [F, 'for i = getn(M.ops), M.n + 1, -1 do table.remove(M.ops, i) end', '', 'bind : une nouvelle action vide le retablissement', S],
  [F, 'if curAction(key) ~= cmd then', 'if false then', 'bind : touche refusee par le client', S],
  [F, 'if SUI.InCombat() then\n\t\tSUI.Print(L("msg.combat.locked"))\n\t\treturn false\n\tend\n\tif SUI.Mover', 'if SUI.Mover', 'bind : interdit en combat', S],
  [F, 'SUI.On("PLAYER_REGEN_DISABLED", M.OnCombat)', '', 'bind : sortie automatique au debut du combat', S],
  [F, 'if SUI.Mover and SUI.Mover.active then SUI.Mover.Exit(true) end', '', 'bind : ferme le mode deplacement', S],
  [F, 'M.poll = SUI.Every(0.1, M.Poll, "bind.poll")', '', 'bind : le survol est suivi par une minuterie', S],
  [F, 'SUI.Cancel(M.poll)', '', 'bind : la minuterie s\'arrete a la sortie', S],
  [F, 'if M.cmd then M.ClearCmd(M.cmd) else M.Exit(true) end', 'M.Exit(true)', 'bind : Echap efface le raccourci du bouton survole', S],
  [F, 'if b == "RightButton" then\n\t\tif M.cmd then M.ClearCmd(M.cmd) end', 'if false then\n\t\tif M.cmd then M.ClearCmd(M.cmd) end', 'bind : clic droit efface', S],
  [F, 'elseif M.MOUSEKEYS[b] then', 'elseif false then', 'bind : boutons de souris', S],
  [F, 'MultiBarBottomLeftButton = "MULTIACTIONBAR1BUTTON"', 'MultiBarBottomLeftButton = "MULTIACTIONBAR2BUTTON"', 'bind : barre du bas gauche du jeu', S],
  [F, 'if M.reopenMenu then\n\t\tM.reopenMenu = false\n\t\tmn.Show()', 'if false then\n\t\tM.reopenMenu = false\n\t\tmn.Show()', 'bind : le menu se rouvre a la sortie', S],
  [F, 'if what == "replace" then', 'if what == "keep" then', 'bind : Remplacer pose la touche', S],
  ['Mod_Actionbars.lua', 'if f.bar and f.cmd and f.kind then return f.cmd end', 'return nil', 'actionbars : resolveur de raccourcis', 't_actionbars.lua'],
];
