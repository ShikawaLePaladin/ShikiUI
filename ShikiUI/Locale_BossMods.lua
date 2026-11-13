-- Locale_BossMods : textes du module "bossmods" (francais sans accents, anglais). Une entree par ligne : ["cle"] = "texte".
-- Memes cles et memes %s / %d dans les deux langues.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["cat.bossmods"] = "Alarmes de raid",
	["opt.modules.bossmods"] = "Alarmes de raid (BossMods)",
	["tip.modules.bossmods"] = "Barres de compte a rebours et annonces pour les evenements des boss (Submerge de Ragnaros, Deep Breath d'Onyxia, Web Spray de Maexxna...). Visez le boss : les barres s'allument et les annonces partent au canal choisi. Commande : /sui bossmods.",
	["mod.bossmods.title"] = "Alarmes de raid",
	["opt.bossmods.lead"] = "Pre-annonce (s)",
	["tip.bossmods.lead"] = "Secondes avant l'evenement : la barre s'allume et l'annonce part a ce moment (10 = 10 s avant).",
	["opt.bossmods.channel"] = "Canal des annonces",
	["tip.bossmods.channel"] = "Ou envoyer les annonces : chez vous seulement, en Raid Warning (raid seul) ou en groupe.",
	["choice.bossmods.channel.self"] = "Chez vous",
	["choice.bossmods.channel.raid"] = "Raid Warning",
	["choice.bossmods.channel.party"] = "Groupe",
	["opt.bossmods.sound"] = "Son des annonces",
	["tip.bossmods.sound"] = "Joue un son d'avertissement avec chaque annonce.",
	["msg.bossmods.soon"] = "%s dans %d s",
	["help.bossmods"] = "/sui bossmods [open|close] - alarmes de raid (barres + annonces)",
})

SUI.AddStrings("en", {
	["cat.bossmods"] = "Raid alarms",
	["opt.modules.bossmods"] = "Raid alarms (BossMods)",
	["tip.modules.bossmods"] = "Countdown bars and announcements for boss events (Ragnaros Submerge, Onyxia Deep Breath, Maexxna Web Spray...). Target the boss: bars light up and announcements go to the chosen channel. Command: /sui bossmods.",
	["mod.bossmods.title"] = "Raid alarms",
	["opt.bossmods.lead"] = "Lead announce (s)",
	["tip.bossmods.lead"] = "Seconds before the event: the bar lights up and the announcement fires then (10 = 10 s before).",
	["opt.bossmods.channel"] = "Announcement channel",
	["tip.bossmods.channel"] = "Where announcements go: to you only, in Raid Warning (raid only) or to the party.",
	["choice.bossmods.channel.self"] = "To you",
	["choice.bossmods.channel.raid"] = "Raid Warning",
	["choice.bossmods.channel.party"] = "Party",
	["opt.bossmods.sound"] = "Announcement sound",
	["tip.bossmods.sound"] = "Plays a warning sound with each announcement.",
	["msg.bossmods.soon"] = "%s in %d s",
	["help.bossmods"] = "/sui bossmods [open|close] - raid alarms (bars + announcements)",
})
