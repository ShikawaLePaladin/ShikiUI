-- mock_menu.lua : curseur simule pour les tests du menu (glissement de la barre de defilement). API 1.12 : GetCursorPosition() -> x, y (pixels
-- ecran) ; IsMouseButtonDown(bouton). Valeurs de test : MOUSE.x / MOUSE.y / MOUSE.down.
MOUSE = { x = 0, y = 0, down = false }
GetCursorPosition = function() return MOUSE.x, MOUSE.y end
IsMouseButtonDown = function(btn) return MOUSE.down end
