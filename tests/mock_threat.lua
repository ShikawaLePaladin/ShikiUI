-- mock_threat : extension de simulation du module "threat" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : THR_SETUP() (appele par t_threat.lua seulement) definit SendAddonMessage, PlaySoundFile, UIErrorsFrame,
-- SendChatMessage et IsAddOnLoaded. Les paquets ci-dessous imitent le format lu dans TWThreat (DONNEES DE TEST, jamais observees en jeu).
ALLOW("THR")

function THR_SETUP()
	local function G(k, v) rawset(_G, k, v) end
	rawset(_G, "THR", { sent = {}, chat = {}, sounds = {}, err = {}, loaded = {} })
	G("SendAddonMessage", function(prefix, msg, chan) table.insert(THR.sent, prefix .. "|" .. msg .. "|" .. chan) end)
	G("SendChatMessage", function(msg, chan) table.insert(THR.chat, chan .. "|" .. msg) end)
	G("PlaySoundFile", function(p) table.insert(THR.sounds, p) end)
	G("UIErrorsFrame", { AddMessage = function(self, t, r, g, b) table.insert(THR.err, t) end })
	G("IsAddOnLoaded", function(n) return THR.loaded[n] and 1 or nil end)
	RAID_CLASS_COLORS.WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }
	RAID_CLASS_COLORS.MAGE = { r = 0.41, g = 0.8, b = 0.94 }
	RAID_CLASS_COLORS.PALADIN = { r = 0.96, g = 0.55, b = 0.73 }
end

-- Le joueur (PALADIN, Shikiwa), Bob (WARRIOR) et Eve (MAGE) en groupe de 3.
function THR_GROUP()
	MKPLAYER()
	W.units.player.name = "Shikiwa"
	W.units.player.class = "PALADIN"
	W.units.party1 = { name = "Bob", class = "WARRIOR", hp = 4000, hpMax = 5000 }
	W.units.party2 = { name = "Eve", class = "MAGE", hp = 2000, hpMax = 3000 }
	W.partyMembers = 2
	W.raidMembers = 0
end

-- Paquet de menace : THR_PACKET({ {"Bob", 1, 10000, 100, 1}, ... })
function THR_PACKET(rows, tm)
	local t = {}
	for i = 1, table.getn(rows) do
		local r = rows[i]
		table.insert(t, r[1] .. ":" .. r[2] .. ":" .. r[3] .. ":" .. r[4] .. ":" .. r[5])
	end
	local s = "TWTv4=" .. table.concat(t, ";")
	if tm then s = s .. "#TMTv1=" .. tm end
	return s
end
