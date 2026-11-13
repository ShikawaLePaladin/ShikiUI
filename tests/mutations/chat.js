// Mutations du module "chat". Format : [fichier, motif, remplacement, libelle, suite].
const F = 'Mod_Chat.lua', S = 't_chat.lua';
module.exports = [
  [F, 'if cfg.stamp then', 'if false then', 'chat : horodatage ignore', S],
  [F, 'if isPlayer and cfg.classcolor then', 'if false then', 'chat : couleur de classe ignoree', S],
  [F, 'if cfg.url and M.HasUrl(text) then', 'if false then', 'chat : liens ignores', S],
  [F, 'now - M.dedupeTime[i] < cfg.dedupe', 'now - M.dedupeTime[i] > cfg.dedupe', 'chat : fenetre de doublons inversee', S],
  [F, 'if isChannel and cfg.quiet and SUI.InCombat() then', 'if isChannel and cfg.quiet then', 'chat : silence hors combat aussi', S],
  [F, 'if isChannel and cfg.nourl and M.HasUrl(text) then', 'if isChannel and M.HasUrl(text) then', 'chat : option sans liens dans les canaux ignoree', S],
  [F, 'if isChannel and cfg.shortchan then', 'if isChannel then', 'chat : canaux courts ignores', S],
  [F, 'or frame.suiSkip then return text end', 'then return text end', 'chat : journal de combat traite', S],
  [F, 'if n > limit then n = limit end', '', 'chat : limite de lignes ignoree', S],
  [F, 'return M.origItemRef(link, text, button)', 'return nil', 'chat : liens du jeu perdus', S],
  [F, 'if M.selected and frame ~= M.selected and cfg.unread then', 'if M.selected and cfg.unread then', 'chat : non lus comptes sur l\'onglet courant', S],
  [F, 'if M.selected and frame ~= M.selected and cfg.unread then', 'if M.selected and frame ~= M.selected then', 'chat : option non lus ignoree', S],
  [F, '\tif M.on then\n\t\tlocal ok, res = pcall(M.Process, self, text)', '\tif true then\n\t\tlocal ok, res = pcall(M.Process, self, text)', 'chat : module coupe mais lignes modifiees', S],
  [F, 'if arg1 > 0 then', 'if arg1 < 0 then', 'chat : sens de la molette inverse', S],
  [F, 'if M.on and cfg.tabs then\n\t\t\t\ttab:SetAlpha(0)', 'if cfg.tabs then\n\t\t\t\ttab:SetAlpha(0)', 'chat : onglets du jeu caches module coupe', S],
  [F, '\t\t\t\ttab:SetAlpha(1)\n', '', 'chat : onglets du jeu non restaures', S],
  [F, 'if p > HIST_MAX then p = 1 end', 'if p > HIST_MAX + 1 then p = 1 end', 'chat : anneau d\'historique', S],
  [F, '\tSUI.Cancel(M.task)\n\tM.task = nil\n\tSUI.Off("PLAYER_TARGET_CHANGED"', '\tM.task = nil\n\tSUI.Off("PLAYER_TARGET_CHANGED"', 'chat : minuterie non annulee', S],
  [F, '["chat.history"] = 100, ["chat.dedupe"] = 5, ["chat.quiet"] = true, ["chat.shortchan"] = true', '["chat.history"] = 200, ["chat.dedupe"] = 0, ["chat.quiet"] = false, ["chat.shortchan"] = false', 'chat : preset Raid perdu', S],
  [F, 'cost = "medium",', 'cost = "heavy",', 'chat : cout declare modifie', S],
];
