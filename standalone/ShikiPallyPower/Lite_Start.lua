-- ShikiUI autonome : ShikiPallyPower (genere par tools/build_standalone.js, ne pas editer)
ShikiUI = ShikiUI or {}
-- ShikiUI complet deja charge (OptionalDeps) : cet addon ne fait rien
ShikiUI.liteSkip = (ShikiUI.VERSION ~= nil and ShikiUI.liteAddons == nil)
if not ShikiUI.liteSkip then
	ShikiUI.liteAddons = ShikiUI.liteAddons or {}
	ShikiUI.liteAddons["ShikiPallyPower"] = true
end
