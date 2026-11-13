// Mutations du module "bulletin". Format : [fichier, motif, remplacement, libelle, suite].
const F = 'Mod_Bulletin.lua', S = 't_bulletin.lua';
module.exports = [
  [F, 'if not M.present then return end            -- DBB absent : rien d\'enregistre', '', 'bulletin : DBB absent enregistre quand meme', S],
  [F, 'if not M.Attach() then SUI.On("PLAYER_ENTERING_WORLD", M.Attach) end', 'SUI.On("PLAYER_ENTERING_WORLD", M.Attach)', 'bulletin : evenement jamais rendu', S],
  [F, '\tSUI.Off("PLAYER_ENTERING_WORLD", M.Attach)\n\tif gui:IsShown() then M.Skin() end', '\tif gui:IsShown() then M.Skin() end', 'bulletin : evenement garde apres la fenetre', S],
  [F, 'if M.oldShow then M.oldShow() end', '', 'bulletin : OnShow de DBB perdu', S],
  [F, 'if M.oldHide then M.oldHide() end', '', 'bulletin : OnHide de DBB perdu', S],
  [F, 'if freeShow then g:SetScript("OnShow", M.oldShow) end', '', 'bulletin : OnShow d\'origine non remis', S],
  [F, 'if freeHide then g:SetScript("OnHide", M.oldHide) end', '', 'bulletin : OnHide d\'origine non remis', S],
  [F, 'if not M.on or not C.Get("bulletin.skin") then return end', 'if not M.on then return end', 'bulletin : option d\'habillage ignoree', S],
  [F, 'pcall(d.CreateBackdrop, d, gui, nil, nil, 0.85)', '', 'bulletin : DBB ne retrouve pas ses couleurs', S],
  [F, 'if not C.Get("bulletin.rememberpos") then return end\n\tlocal gui = M.Gui()\n\tif not gui then return end', 'local gui = M.Gui()\n\tif not gui then return end', 'bulletin : memorisation sans l\'option', S],
  [F, 'if rel and rel ~= UIParent then return end', '', 'bulletin : ancre relative memorisee', S],
  [F, 'if not p or not ANCHORS[p] or not ANCHORS[rp] then return end', 'if not p then return end', 'bulletin : ancre inconnue acceptee', S],
  [F, 'floor(x + 0.5)', 'x', 'bulletin : position non arrondie', S],
  [F, 'if M.on and M.skinned then M.Skin() end', 'if false then M.Skin() end', 'bulletin : pas de repeinture a chaud', S],
];
