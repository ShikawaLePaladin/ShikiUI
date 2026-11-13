-- mock_tanktools : extension de simulation du module "tanktools" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : TNK_SETUP() (appele par t_tanktools.lua seulement) definit les chaines d'echec de sort (formats ANGLAIS
-- vanilla cites par Tankalyze : DONNEES DE TEST), SendChatMessage, PlaySoundFile, UIErrorsFrame, IsAddOnLoaded, GetSpellCooldown et un grimoire.
ALLOW("TNK")

function TNK_SETUP()
	local function G(k, v) rawset(_G, k, v) end
	rawset(_G, "TNK", { chat = {}, sounds = {}, err = {}, loaded = {}, cd = {} })
	G("SPELLRESISTSELFOTHER", "Your %s was resisted by %s.")
	G("SPELLMISSSELFOTHER", "Your %s missed %s.")
	G("SPELLIMMUNESELFOTHER", "Your %s failed. %s is immune.")
	G("SPELLEVADEDSELFOTHER", "Your %s was evaded by %s.")
	G("SPELLDODGEDSELFOTHER", "Your %s was dodged by %s.")
	G("SPELLPARRIEDSELFOTHER", "Your %s was parried by %s.")
	G("BOOKTYPE_SPELL", "spell")
	G("GetSpellName", function(i, book)
		local s = W.spells[i]
		if not s then return nil end
		return s.name, s.rank
	end)
	G("GetSpellTexture", function(i, book) local s = W.spells[i]; return s and s.tex or nil end)
	G("GetSpellCooldown", function(i, book)
		local c = TNK.cd[i]
		if not c then return 0, 0, 1 end
		return c[1], c[2], 1
	end)
	G("SendChatMessage", function(msg, chan) table.insert(TNK.chat, chan .. "|" .. msg) end)
	G("PlaySoundFile", function(p) table.insert(TNK.sounds, p) end)
	G("UIErrorsFrame", { AddMessage = function(self, t, r, g, b) table.insert(TNK.err, t) end })
	G("IsAddOnLoaded", function(n) return TNK.loaded[n] and 1 or nil end)
end

-- Joueur de la classe donnee avec son grimoire (les rangs superieurs viennent apres : le module doit prendre le dernier).
function TNK_CLASS(class)
	MKPLAYER()
	W.units.player.name = "Shikiwa"
	W.units.player.class = class
	W.units.player.hp = 9000
	W.units.player.hpMax = 10000
	if class == "WARRIOR" then
		W.spells = {
			{ name = "Heroic Strike", rank = "Rank 1", tex = "tex_hs" },
			{ name = "Taunt", rank = "", tex = "tex_taunt1" },
			{ name = "Shield Block", rank = "", tex = "tex_block" },
			{ name = "Shield Wall", rank = "", tex = "tex_wall" },
			{ name = "Last Stand", rank = "", tex = "tex_last" },
			{ name = "Challenging Shout", rank = "", tex = "tex_shout" },
			{ name = "Taunt", rank = "Rank 2", tex = "tex_taunt2" },
			{ name = "Mocking Blow", rank = "Rank 1", tex = "tex_mock" },
		}
	elseif class == "DRUID" then
		W.spells = { { name = "Growl", rank = "", tex = "tex_growl" }, { name = "Barkskin", rank = "", tex = "tex_bark" } }
	else
		W.spells = { { name = "Fireball", rank = "Rank 1", tex = "tex_fb" } }
	end
	W.partyMembers = 0
	W.raidMembers = 0
end
