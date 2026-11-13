// Mutations du contrat des modules : SUI.AddStrings, SUI.RegisterCommand, SUI.RegisterModule, categories reservees.
module.exports = [
  ['Locale.lua', 'type(v) ~= "string" or dest[k] ~= nil then', 'type(v) ~= "string" then', 'contrat : AddStrings ecrase une cle existante', 't_modules.lua'],
  ['Locale.lua', 'SUI.missingL[k] = nil', '', 'contrat : AddStrings n\'efface pas la cle manquante signalee', 't_modules.lua'],
  ['Locale.lua', 'if type(dest) ~= "table" or type(tbl) ~= "table" then return 0, 0 end', '', 'contrat : AddStrings accepte une langue inconnue', 't_modules.lua'],
  ['Locale.lua', 'if type(k) == "string" then SUI.localeSkipped[code .. ":" .. k] = true end', '', 'contrat : cle ignoree non signalee', 't_modules.lua'],
  ['Core.lua', 'if SUI.reservedCommands[name] or SUI.commands[name] then return false, "taken" end', '', 'contrat : commande reservee ou en double acceptee', 't_modules.lua'],
  ['Core.lua', 'if type(name) ~= "string" or not string.find(name, "^[a-z][a-z0-9]*$") or type(fn) ~= "function" then return false, "bad" end', '', 'contrat : commande invalide acceptee', 't_modules.lua'],
  ['Core.lua', 'if SUI.reservedModules[name] and not def.core then', 'if false then', 'contrat : nom de module reserve accepte', 't_modules.lua'],
  ['Core.lua', 'if not SUI.COSTS[def.cost] then', 'if false then', 'contrat : cout de module non controle', 't_modules.lua'],
  ['Core.lua', 'if SUI.modules[name] then\n\t\tSUI.Report("module", "module deja enregistre : " .. name)\n\t\treturn false', 'if false then\n\t\tSUI.Report("module", "module deja enregistre : " .. name)\n\t\treturn false', 'contrat : module enregistre deux fois', 't_modules.lua'],
  ['Core.lua', 'if type(name) ~= "string" or not string.find(name, "^[a-z][a-z0-9]*$") or type(def) ~= "table" then\n\t\tSUI.Report("module", "nom de module invalide', 'if false then\n\t\tSUI.Report("module", "nom de module invalide', 'contrat : nom de module invalide accepte', 't_modules.lua'],
  ['Core.lua', 'hdr = true, style = true, layout = true }', 'hdr = true }', 'contrat : noms style et layout non reserves', 't_modules.lua'],
  ['Core.lua', 'if SUI.Style then SUI.Style.LoadUser() end', '', 'demarrage : styles de l\'utilisateur non recharges', 't_boot.lua'],
  ['Core.lua', 'if SUI.Style then SUI.Style.Boot() end', '', 'demarrage : style non applique au login', 't_boot.lua'],
  ['Core.lua', 'if SUI.Mode then SUI.Mode.Boot() end', '', 'demarrage : mode non relu au login', 't_boot.lua'],
  ['Cmd.lua', 'elseif SUI.commands[cmd] then', 'elseif false then', 'contrat : commandes enregistrees non appelees', 't_modules.lua'],
];
