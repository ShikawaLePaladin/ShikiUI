// Mutations du module "marks" (barre de ciblage des marques de raid). Format : [fichier, motif, remplacement, libelle, suite].
const F = 'Mod_Marks.lua', S = 't_marks.lua';
module.exports = [
  [F, 'cost = "light",', 'cost = "heavy",', 'marks : cout declare modifie', S],
  [F, '\t\t\tM.found[idx] = u', '', 'marks : detection jamais memorisee', S],
  [F, 'idx = GetRaidTargetIndex(u)', 'idx = nil', 'marks : marques du raid jamais lues', S],
  [F, '			TargetUnit(u)', '', 'marks : clic ne cible pas le mob marque', S],
  [F, '			SetRaidTarget("target", idx)', '', 'marks : pose de marqueur sans effet', S],
  [F, 'if M.task then\n\t\tSUI.Cancel(M.task)\n\t\tM.task = nil\n\tend', '', 'marks : minuterie non annulee a la fermeture', S],
  [F, 'idx >= 1 and idx <= MAXM', 'idx >= 1', 'marks : index de marque hors limite accepte', S],

  [F, 'M.nunits = buildUnits()\n\t\tM.ApplySize()', 'M.nunits = 0\n\t\tM.ApplySize()', 'marks : unites jamais balayees', S],
];
