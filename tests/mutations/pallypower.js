// Mutations du module "pallypower". Format : [fichier, motif, remplacement, libelle, suite].
const F = 'Mod_PallyPower.lua', S = 't_pallypower.lua';
module.exports = [
  ['Mod_PallyPower.lua', 'cost = "medium",', 'cost = "light",', 'pallypower : cout declare modifie', S],
  ['Mod_PallyPower.lua', '\tif want == nil then want = not a[b] end\n\tif want then a[b] = true else a[b] = nil end', '\tif want == nil then want = not a[b] end\n\tif want then a[b] = true end', 'pallypower : retrait d attribution sans effet', S],
  ['Mod_PallyPower.lua', '\t\t\t\tif a[b] and not M.HasBuff(r.unit, M.SPELLS[b]) then', '\t\t\t\tif a[b] then', 'pallypower : bene reposee par-dessus', S],
  ['Mod_PallyPower.lua', '\tif C.Get("pallypower.greater") then return M.GREATERPFX .. base end', '', 'pallypower : reglage greater ignore', S],
  ['Mod_PallyPower.lua', 'M.task = SUI.Every(1.1, M.CastStep, "pp.cast", true)', 'M.task = SUI.Every(1.1, M.CastStep, "pp.cast", true)\n\tM.Stop()', 'pallypower : cycle qui ne demarre pas', S],
  ['Mod_PallyPower.lua', 'if j ~= EMPTY and UnitExists("target") and UnitCanAttack("player", "target") then CastSpellByName(j) end', '', 'pallypower : jugement jamais pose', S],
  ['Mod_PallyPower.lua', '\t\tif p and UnitExists(p.unit) and not UnitIsDead(p.unit) then', '\t\tif p and UnitExists(p.unit) then', 'pallypower : cible morte benie quand meme', S],
  ['Mod_PallyPower.lua', '\tcastOn(p.unit, p.name)', '', 'pallypower : aucune pose dans le cycle', S],
  ['Mod_PallyPower.lua', 'if not M.on then SUI.Print(L("msg.pallypower.off")) return end', 'if not M.on then return end', 'pallypower : coupure silencieuse', S],
  ['Mod_PallyPower.lua', '\tSUI.On("RAID_ROSTER_UPDATE", M.OnRoster)', '', 'pallypower : liste du raid jamais reprise', S],
  ['Mod_PallyPower.lua', '\tSUI.Off("RAID_ROSTER_UPDATE", M.OnRoster)', '', 'pallypower : raid ecoute apres coupure', S],
  ['Mod_PallyPower.lua', 'local name, _, _, _, _, file = gri(i)', 'local name, _, _, _, _, file = gri(i)\n\t\t\t\tfile = "PALADIN"', 'pallypower : classe du raid forcee', S],
  ['Mod_PallyPower.lua', 'if M.nrost >= M.ROWS then return end', '', 'pallypower : liste du raid sans plafond', S],
  ['Mod_PallyPower.lua', '		if M.roster[i].name == name then return end', '', 'pallypower : doublon dans la liste', S],
  ['Mod_PallyPower.lua', '\t\t\tfor k in pairs(a) do a[k] = nil end\n\t\t\tif attr then', '\t\t\tif attr then', 'pallypower : jeu de classe qui ajoute sans vider', S],
  ['Mod_PallyPower.lua', 'M.SetAll(b, not M.AllHave(b))', 'M.SetAll(b, true)', 'pallypower : bouton d en-tete qui ne retire jamais', S],
  ['Mod_PallyPower.lua', 'M.offset = mmax(0, mmin(maxoff, M.offset + d))', 'M.offset = M.offset + d', 'pallypower : defilement non borne', S],
  ['Mod_PallyPower.lua', '\tif M.task then SUI.Cancel(M.task) M.task = nil end\n\t-- le jugement part avant tout', '', 'pallypower : minuterie non annulee a la coupure', S],
];
