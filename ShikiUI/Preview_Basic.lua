-- ShikiUI Preview_Basic : apercus MINIMAUX du volet d'apercu du menu pour les modules courants : cadres d'unites (joueur / cible / cible de
-- la cible), barres d'action (boutons, raccourcis, recharges, portee, mana), plaques de nom (barre, niveau, menace, debuffs, incantation)
-- et discussion (onglets, heure, couleurs de classe, lien, fond), puis incantation (barres joueur / cible / sort interrompu), buffs et debuffs
-- (grilles, durees, cumuls, sens), infobulle (objet, unite, ancre), compteurs, menace, minimap (ronde / carree) et sacs. Meme principe que Preview_Raid.lua : rien n'est cree dans update ; les
-- couleurs viennent des jetons du style (T.c.*, T.Accent) et des couleurs de classe du jeu ; un clic sur un element saute a son reglage.
-- Les faux contenus (noms, valeurs) sont des DONNEES D'EXEMPLE fixes. NON VERIFIE EN JEU : voir NOTES en bas de ce fichier.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local M = SUI.Menu
local C = SUI.Config
local P = SUI.Preview

local getn, tinsert = table.getn, table.insert
local floor = math.floor

local function num(key, d)
	local v = C.Get(key)
	if type(v) ~= "number" then return d end
	return v
end

local function flag(key, d)
	local v = C.Get(key)
	if v == nil then return d end
	return v and true or false
end

local function classRGB(class)
	local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if col then return col.r, col.g, col.b end          -- couleur de classe (donnee de jeu)
	return T.c.dim[1], T.c.dim[2], T.c.dim[3]
end

local function txt(parent, size, tok, just)
	local fs = T.Text(parent, size, tok or T.c.text, just or "LEFT", true)
	return fs
end

-- Place un texte (coin haut gauche) et le montre ; retourne sa largeur.
local function putText(fs, parent, x, y, size, str)
	P.Font(fs, size)
	fs:SetText(str)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	fs:Show()
	return fs:GetStringWidth()
end

local function box(parent, layer)
	local t = P.NewTex(parent, layer)
	t:Hide()
	return t
end

-- ================================================================ cadres d'unites
local UNITS = {
	{ id = "player", name = "Shikiwa", lvl = "60", hpr = 0.72, class = "PALADIN", pt = 0, friend = true },
	{ id = "target", name = "Thorgrim", lvl = "61", hpr = 0.45, class = "WARRIOR", pt = 1, friend = false },
	{ id = "tot", name = "Elaria", lvl = "60", hpr = 0.9, class = "PRIEST", pt = 0, friend = true },
}

local function newUnit(parent)
	local c = CreateFrame("Frame", nil, parent)
	c.edge, c.bg = box(c, "BACKGROUND"), box(c, "BACKGROUND")
	c.hp, c.pw = box(c, "ARTWORK"), box(c, "ARTWORK")
	c.name = txt(c, 11, T.c.text, "LEFT")
	c.hpt = txt(c, 11, T.c.text, "RIGHT")
	c.rc = { frame = { 0, 0, 0, 0 }, hp = { 0, 0, 0, 0 }, hptext = { 0, 0, 0, 0 }, power = { 0, 0, 0, 0 }, edgeh = { 0, 0, 0, 0 } }
	return c
end

local function setrc(c, k, x, y, w, h)
	local r = c.rc[k]
	r[1], r[2], r[3], r[4] = x, y, w, h
end

local function hpStr(mode, hp, mx)
	if mode == "none" then return "" end
	local pct = floor(hp / mx * 100 + 0.5) .. "%"
	if mode == "value" then return tostring(hp) end
	if mode == "percent" then return pct end
	return hp .. " | " .. pct
end

local function paintUnit(c, u, w, h, ph, showPower, classColor, hptextMode, s, dim)
	c:SetWidth(w)
	c:SetHeight(h)
	P.Fill(c.edge, T.c.border, 1)
	P.Box(c.edge, c, 0, 0, w, h)
	P.Fill(c.bg, T.c.bg, 1)
	P.Box(c.bg, c, 1, 1, w - 2, h - 2)
	local pw = (showPower and ph > 0) and floor(ph * s + 0.5) or 0
	local hpH = h - 2 - (pw > 0 and pw + 1 or 0)
	if hpH < 1 then hpH = 1 end
	local r, g, b
	if classColor and u.friend then
		r, g, b = classRGB(u.class)
	elseif u.friend then
		r, g, b = T.c.good[1], T.c.good[2], T.c.good[3]
	else
		r, g, b = T.c.bad[1], T.c.bad[2], T.c.bad[3]
	end
	c.hp:SetVertexColor(r, g, b, 1)
	P.Box(c.hp, c, 1, 1, (w - 2) * u.hpr, hpH)
	if pw > 0 then
		P.Fill(c.pw, T.c.dim, 1)
		P.Box(c.pw, c, 1, h - 1 - pw, (w - 2) * 0.8, pw)
	else
		c.pw:Hide()
	end
	setrc(c, "frame", 0, 0, w, h)
	setrc(c, "edgeh", w - 6, 0, 6, h)
	setrc(c, "hp", 1, 1, w - 2, hpH)
	setrc(c, "power", 1, h - 1 - (pw > 0 and pw or 3), w - 2, pw > 0 and pw or 3)
	local fs = 11 * s
	if fs > 14 then fs = 14 end
	if hpH >= 9 and not dim then
		putText(c.name, c, 4, 1 + (hpH - fs) / 2, fs, u.name)
		c.name:SetWidth(floor(w * 0.55))
		local str = hpStr(hptextMode, floor(u.hpr * 4000), 4000)
		if str ~= "" then
			putText(c.hpt, c, w * 0.45, 1 + (hpH - fs) / 2, fs, str)
			c.hpt:SetWidth(floor(w * 0.5))
			c.hpt:Show()
		else
			c.hpt:Hide()
		end
		setrc(c, "hptext", w * 0.45, 1, w * 0.5, hpH)
	else
		c.name:Hide()
		c.hpt:Hide()
		setrc(c, "hptext", w * 0.45, 1, w * 0.5, hpH)
	end
	c:Show()
end

local UZ = { "frame", "hp", "hptext", "power", "edgeh" }

local function unitsBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { cells = {}, zones = {} }
	root.st = st
	for i = 1, 3 do
		st.cells[i] = newUnit(root)
		st.zones[i] = {}
		for j = 1, getn(UZ) do st.zones[i][j] = P.Zone(root, UZ[j]) end
	end
	st.tot = P.Zone(root, "tot")
	st.hint = txt(root, 10, T.c.dim, "LEFT")
	return root
end

local function unitsUpdate(root, w, h, key, value)
	local st = root.st
	local uw, uh, ph = num("units.width", 180), num("units.height", 28), num("units.powerheight", 4)
	local sp = flag("units.showpower", true)
	local cc = flag("units.classcolor", true)
	local mode = C.Get("units.hptext") or "percent"
	local s = (w - 8) / uw
	if s > 1.6 then s = 1.6 end
	local y = 6
	for i = 1, 3 do
		local c = st.cells[i]
		local u = UNITS[i]
		local on = (i == 1) or (i == 2) or flag("units.tot.enabled", true)
		if i == 1 then on = flag("units.player.enabled", true) elseif i == 2 then on = flag("units.target.enabled", true) end
		local cw, chh = floor(uw * s), floor(uh * s)
		if i == 3 then cw, chh = floor(cw * 0.6), floor(chh * 0.8) end
		paintUnit(c, u, cw, chh, ph, sp, cc, mode, i == 3 and s * 0.7 or s, i == 3)
		P.Place(c, root, 4, y, cw, chh)
		if not on then c:SetAlpha(0.35) else c:SetAlpha(1) end
		for j = 1, getn(UZ) do
			local rc = c.rc[UZ[j]]
			P.PlaceZone(st.zones[i][j], root, 4 + rc[1], y + rc[2], rc[3], rc[4])
			if i == 3 then st.zones[i][j]:Hide() end
		end
		if i == 3 then
			P.PlaceZone(st.tot, root, 4, y, cw, chh)
		end
		y = y + chh + 10
	end
	st.hint:ClearAllPoints()
	st.hint:SetPoint("TOPLEFT", root, "TOPLEFT", 4, -(y + 4))
	st.hint:SetWidth(w - 8)
	st.hint:SetHeight(40)
	st.hint:SetText(L("mod.preview.units.hint"))
	st.hint:Show()
end

local UKEY = { frame = "units.width", hp = "units.classcolor", hptext = "units.hptext", edgeh = "units.height", tot = "units.tot.enabled" }
local function unitsClick(zone)
	if zone == "power" then
		if flag("units.showpower", true) then return "units.powerheight" end
		return "units.showpower"
	end
	return UKEY[zone]
end

P.Register("units", { watch = { "units." }, build = unitsBuild, update = unitsUpdate, click = unitsClick })

-- ================================================================ barres d'action
local NBTN = 12
local BKEYS = { "size", "keybinds", "cooldowns", "counts", "range", "mana", "macrotext", "size", "size", "size", "size", "empty" }
local KEYTXT = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }

local function barsBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { b = {}, z = {} }
	root.st = st
	st.gap = P.Zone(root, "gap", 1)
	for i = 1, NBTN do
		local b = CreateFrame("Frame", nil, root)
		b:SetFrameLevel(P.Lv(1))
		b.edge, b.bg, b.ic = box(b, "BACKGROUND"), box(b, "BACKGROUND"), box(b, "ARTWORK")
		b.tint, b.cd = box(b, "OVERLAY"), box(b, "OVERLAY")
		b.key = txt(b, 9, T.c.text, "RIGHT")
		b.cnt = txt(b, 9, T.c.text, "RIGHT")
		b.mac = txt(b, 8, T.c.dim, "LEFT")
		b.cdt = txt(b, 14, T.c.warn, "CENTER")
		st.b[i] = b
		st.z[i] = P.Zone(root, "b" .. i)
	end
	st.hint = txt(root, 10, T.c.dim, "LEFT")
	return root
end

local function barsUpdate(root, w, h, key, value)
	local st = root.st
	local size = num("actionbars.size", 36)
	local spc = num("actionbars.spacing", 3)
	local per = num("actionbars.main.perrow", 12)
	local n = num("actionbars.main.buttons", 12)
	if n > NBTN then n = NBTN end
	if per < 1 then per = 1 end
	-- echelle FIXE (barre de 12 boutons par defaut tenant dans la zone) : changer la taille ou l'espacement se voit ; si la ligne deborde,
	-- l'apercu la replie (comme la zone le permet) au lieu de reduire les boutons.
	local s = (w - 8) / (12 * 36 + 11 * 3)
	if s > 1 then s = 1 end
	local bs, bsp = floor(size * s + 0.5), floor(spc * s + 0.5)
	local fit = floor((w - 8 + bsp) / (bs + bsp))
	if fit < 1 then fit = 1 end
	if per > fit then per = fit end
	local showKeys, showCnt, showCd, showRange, showMana = flag("actionbars.keybinds", true), flag("actionbars.counts", true),
		flag("actionbars.cooldowns", true), flag("actionbars.range", true), flag("actionbars.mana", true)
	local showMac, showEmpty = flag("actionbars.macrotext", false), flag("actionbars.empty", true)
	local shade = C.Get("actionbars.cdshade")
	if type(shade) ~= "number" then shade = 0.6 elseif shade > 1 then shade = shade / 100 end
	local rows = floor((n - 1) / per) + 1
	local fs = 9 * s
	if fs < 7 then fs = 7 end
	local ar, ag, ab = T.Accent()
	for i = 1, NBTN do
		local b = st.b[i]
		local z = st.z[i]
		if i <= n then
			local row = floor((i - 1) / per)
			local col = (i - 1) - row * per
			local x, y = 4 + col * (bs + bsp), 6 + row * (bs + bsp)
			b:SetWidth(bs)
			b:SetHeight(bs)
			P.Place(b, root, x, y, bs, bs)
			P.Fill(b.edge, T.c.border, 1)
			P.Box(b.edge, b, 0, 0, bs, bs)
			P.Fill(b.bg, T.c.inset, 1)
			P.Box(b.bg, b, 1, 1, bs - 2, bs - 2)
			local empty = (i == NBTN)
			if empty and not showEmpty then
				b:SetAlpha(0.15)
			else
				b:SetAlpha(1)
			end
			if empty then
				b.ic:Hide()
			else
				b.ic:SetVertexColor(ar, ag, ab, 0.55)
				P.Box(b.ic, b, 3, 3, bs - 6, bs - 6)
			end
			b.tint:Hide()
			if showRange and i == 5 then
				P.Fill(b.tint, T.c.bad, 0.45)
				P.Box(b.tint, b, 1, 1, bs - 2, bs - 2)
			elseif showMana and i == 6 then
				P.Fill(b.tint, T.c.dim, 0.55)
				P.Box(b.tint, b, 1, 1, bs - 2, bs - 2)
			end
			if showCd and i == 3 then
				P.Fill(b.cd, T.c.bg, shade)
				P.Box(b.cd, b, 1, 1, bs - 2, bs - 2)
				P.Font(b.cdt, 13 * s)
				b.cdt:SetText("8")
				b.cdt:ClearAllPoints()
				b.cdt:SetPoint("CENTER", b, "CENTER", 0, 0)
				b.cdt:SetWidth(bs)
				b.cdt:Show()
			else
				b.cd:Hide()
				b.cdt:Hide()
			end
			if showKeys then
				P.Font(b.key, fs)
				b.key:SetText(KEYTXT[i])
				b.key:ClearAllPoints()
				b.key:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
				b.key:SetWidth(bs - 4)
				b.key:Show()
			else
				b.key:Hide()
			end
			if showCnt and i == 4 then
				P.Font(b.cnt, fs)
				b.cnt:SetText("20")
				b.cnt:ClearAllPoints()
				b.cnt:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
				b.cnt:SetWidth(bs - 4)
				b.cnt:Show()
			else
				b.cnt:Hide()
			end
			if showMac and i == 7 then
				P.Font(b.mac, fs)
				b.mac:SetText("Heal")
				b.mac:ClearAllPoints()
				b.mac:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 2)
				b.mac:SetWidth(bs - 4)
				b.mac:Show()
			else
				b.mac:Hide()
			end
			P.PlaceZone(z, root, x, y, bs, bs)
			b:Show()
		else
			b:Hide()
			z:Hide()
		end
	end
	local gw, gh = per * (bs + bsp), rows * (bs + bsp)
	P.PlaceZone(st.gap, root, 4, 6, gw, gh)
	st.hint:ClearAllPoints()
	st.hint:SetPoint("TOPLEFT", root, "TOPLEFT", 4, -(gh + 16))
	st.hint:SetWidth(w - 8)
	st.hint:SetHeight(50)
	st.hint:SetText(L("mod.preview.bars.hint"))
	st.hint:Show()
end

local function barsClick(zone)
	if zone == "gap" then return "actionbars.spacing" end
	local _, _, n = string.find(zone, "^b(%d+)$")
	if n then return "actionbars." .. BKEYS[tonumber(n)] end
	return nil
end

P.Register("actionbars", { watch = { "actionbars." }, build = barsBuild, update = barsUpdate, click = barsClick })

-- ================================================================ plaques de nom
local function newPlate(parent)
	local c = CreateFrame("Frame", nil, parent)
	c.glow = box(c, "BACKGROUND")
	c.edge, c.bg, c.hp = box(c, "BACKGROUND"), box(c, "BACKGROUND"), box(c, "ARTWORK")
	c.mk = c:CreateTexture(nil, "OVERLAY")
	c.mk:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	c.mk:SetTexCoord(0.75, 1, 0.25, 0.5)
	c.name, c.hpt, c.thr = txt(c, 10, T.c.text, "LEFT"), txt(c, 9, T.c.text, "RIGHT"), txt(c, 9, T.c.warn, "LEFT")
	c.de, c.di = {}, {}
	for k = 1, 6 do
		c.de[k], c.di[k] = box(c, "ARTWORK"), box(c, "OVERLAY")
	end
	c.cb, c.cf, c.ci = box(c, "BACKGROUND"), box(c, "ARTWORK"), box(c, "ARTWORK")
	c.cn = txt(c, 8, T.c.text, "LEFT")
	c.rc = { name = { 0, 0, 0, 0 }, bar = { 0, 0, 0, 0 }, hptext = { 0, 0, 0, 0 }, deb = { 0, 0, 0, 0 }, cast = { 0, 0, 0, 0 },
		mark = { 0, 0, 0, 0 }, thr = { 0, 0, 0, 0 } }
	return c
end

-- Dessine une plaque (w x h logiques, s echelle). opts : target (surbrillance), threat (nil | "warn" | "bad").
local function paintPlate(c, o, w, h, s, targetScale)
	local isTarget, thr = o.target, o.threat
	local sc = s * ((isTarget and o.glowOn) and targetScale or 1)
	local bw, bh = floor(w * sc), floor(h * sc)
	if bh < 3 then bh = 3 end
	local fs = 10 * sc
	if fs < 7 then fs = 7 end
	local msz = floor(o.msz * sc)
	local top = (o.showMark and msz or 0) + (o.showName and floor(fs + 3) or 0)
	local dz = o.showDeb and floor(o.dsz * sc) or 0
	local ch = o.showCast and floor(o.castH * sc) or 0
	local total = top + bh + (dz > 0 and dz + 3 or 0) + (ch > 0 and ch + 3 or 0)
	c:SetWidth(bw + 2)
	c:SetHeight(total + 2)
	local y = 1
	if o.showMark then
		c.mk:ClearAllPoints()
		c.mk:SetPoint("TOP", c, "TOP", 0, -y)
		c.mk:SetWidth(msz)
		c.mk:SetHeight(msz)
		c.mk:Show()
		c.rc.mark[1], c.rc.mark[2], c.rc.mark[3], c.rc.mark[4] = (bw - msz) / 2, y, msz, msz
		y = y + msz
	else
		c.mk:Hide()
		c.rc.mark[1], c.rc.mark[2], c.rc.mark[3], c.rc.mark[4] = (bw - 16) / 2, 0, 16, 16
	end
	if o.showName then
		local lab = (o.showLevel and "61 " or "") .. o.nm
		local tw = putText(c.name, c, 2, y, fs, lab)
		c.name:SetWidth(bw)
		c.rc.name[1], c.rc.name[2], c.rc.name[3], c.rc.name[4] = 2, y, tw, fs + 2
		y = y + floor(fs + 3)
	else
		c.name:Hide()
		c.rc.name[1], c.rc.name[2], c.rc.name[3], c.rc.name[4] = 2, y, 30, 10
	end
	-- surbrillance de cible / menace (liseret autour de la barre)
	local er, eg, eb = T.c.border[1], T.c.border[2], T.c.border[3]
	if thr == "bad" then
		er, eg, eb = T.c.bad[1], T.c.bad[2], T.c.bad[3]
	elseif thr == "warn" then
		er, eg, eb = T.c.warn[1], T.c.warn[2], T.c.warn[3]
	elseif isTarget and o.glowOn then
		er, eg, eb = T.Accent()
	end
	c.edge:SetVertexColor(er, eg, eb, 1)
	P.Box(c.edge, c, 0, y - 1, bw + 2, bh + 2)
	P.Fill(c.bg, T.c.bg, 1)
	P.Box(c.bg, c, 1, y, bw, bh)
	local r, g, b = T.c.bad[1], T.c.bad[2], T.c.bad[3]
	if o.classColor then r, g, b = classRGB("MAGE") end
	c.hp:SetVertexColor(r, g, b, 1)
	P.Box(c.hp, c, 1, y, bw * o.hpr, bh)
	c.rc.bar[1], c.rc.bar[2], c.rc.bar[3], c.rc.bar[4] = 1, y, bw, bh
	if o.showHp and bh >= 8 then
		local tw = putText(c.hpt, c, 1 + bw - 60, y + (bh - fs) / 2 - 1, fs * 0.9, floor(o.hpr * 100) .. "%")
		c.hpt:SetWidth(58)
		c.rc.hptext[1], c.rc.hptext[2], c.rc.hptext[3], c.rc.hptext[4] = bw - 30, y, 30, bh
	else
		c.hpt:Hide()
		c.rc.hptext[1], c.rc.hptext[2], c.rc.hptext[3], c.rc.hptext[4] = bw - 30, y, 30, bh
	end
	if thr and o.showThr then
		putText(c.thr, c, 3, y + (bh - fs) / 2 - 1, fs * 0.9, o.thrText)
		c.thr:SetWidth(40)
		c.rc.thr[1], c.rc.thr[2], c.rc.thr[3], c.rc.thr[4] = 1, y, 34, bh
	else
		c.thr:Hide()
		c.rc.thr[1], c.rc.thr[2], c.rc.thr[3], c.rc.thr[4] = 1, y, 34, bh
	end
	y = y + bh + 3
	-- debuffs
	for k = 1, 6 do
		if o.showDeb and k <= o.debMax and dz > 0 then
			P.Fill(c.de[k], k == 1 and T.c.bad or T.c.border, 1)
			P.Box(c.de[k], c, 1 + (k - 1) * (dz + 2), y, dz, dz)
			P.Fill(c.di[k], T.c.inset, 1)
			P.Box(c.di[k], c, 2 + (k - 1) * (dz + 2), y + 1, dz - 2, dz - 2)
		else
			c.de[k]:Hide()
			c.di[k]:Hide()
		end
	end
	c.rc.deb[1], c.rc.deb[2], c.rc.deb[3], c.rc.deb[4] = 1, y, (dz > 0 and o.debMax * (dz + 2) or 16), (dz > 0 and dz or 14)
	if dz > 0 then y = y + dz + 3 end
	-- incantation
	if ch > 0 then
		local ix = 0
		if o.showIcon then
			P.Fill(c.ci, T.c.dim, 1)
			P.Box(c.ci, c, 1, y, ch, ch)
			ix = ch + 1
		else
			c.ci:Hide()
		end
		P.Fill(c.cb, T.c.inset, 1)
		P.Box(c.cb, c, 1 + ix, y, bw - ix, ch)
		P.Fill(c.cf, T.c.warn, 1)
		P.Box(c.cf, c, 1 + ix, y, (bw - ix) * 0.6, ch)
		if o.showCastName and ch >= 8 then
			putText(c.cn, c, 3 + ix, y, 8 * sc, L("mod.preview.plates.cast"))
			c.cn:SetWidth(bw - ix)
		else
			c.cn:Hide()
		end
		c.rc.cast[1], c.rc.cast[2], c.rc.cast[3], c.rc.cast[4] = 1, y, bw, ch
	else
		c.cb:Hide()
		c.cf:Hide()
		c.ci:Hide()
		c.cn:Hide()
		c.rc.cast[1], c.rc.cast[2], c.rc.cast[3], c.rc.cast[4] = 1, y, bw, 6
	end
	c:Show()
end

local PZ = { "name", "bar", "hptext", "deb", "cast", "mark", "thr" }

local function platesBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { cells = {}, zones = {}, o = { {}, {}, {} } }
	root.st = st
	for i = 1, 3 do
		st.cells[i] = newPlate(root)
		st.zones[i] = {}
		for j = 1, getn(PZ) do st.zones[i][j] = P.Zone(root, PZ[j] .. i) end
	end
	st.hint = txt(root, 10, T.c.dim, "LEFT")
	return root
end

local function platesUpdate(root, w, h, key, value)
	local st = root.st
	local pw = num("nameplates.width", 110)
	local s = (w - 24) / pw
	if s > 2.2 then s = 2.2 end
	local ts = num("nameplates.targetscale", 1.2)
	local y = 4
	for i = 1, 3 do
		local o = st.o[i]
		o.target = (i == 2)
		o.glowOn = flag("nameplates.targetglow", true)
		o.threat = (i == 3) and (flag("nameplates.threat", true) and "warn" or nil) or nil
		if i == 1 then o.threat = nil end
		o.thrText = (i == 3) and ((num("nameplates.threatwarn", 80)) .. "%") or ""
		o.showThr = flag("nameplates.threatpct", true)
		o.msz = num("nameplates.markersize", 20) * 0.6
		o.showMark = flag("nameplates.markers", true) and (i == 1)
		o.nm = (i == 1) and "Gnoll" or ((i == 2) and "Kobold" or "Ogre")
		o.showName = flag("nameplates.name", true)
		o.showLevel = flag("nameplates.level", true)
		o.showHp = flag("nameplates.hptext", true)
		o.classColor = flag("nameplates.classcolor", false)
		o.hpr = (i == 1) and 0.8 or ((i == 2) and 0.55 or 0.3)
		o.showDeb = flag("nameplates.debuffs", true)
		o.debMax = floor(num("nameplates.debuffmax", 4))
		if o.debMax > 6 then o.debMax = 6 end
		o.dsz = num("nameplates.debuffsize", 14) * 0.7
		o.showCast = flag("nameplates.castbar", true) and (i ~= 3)
		o.castH = num("nameplates.castheight", 8)
		o.showIcon = flag("nameplates.casticon", true)
		o.showCastName = flag("nameplates.castname", true)
		local c = st.cells[i]
		paintPlate(c, o, pw, num("nameplates.height", 10), s, ts)
		local x = floor((w - c:GetWidth()) / 2)
		P.Place(c, root, x, y, c:GetWidth(), c:GetHeight())
		for j = 1, getn(PZ) do
			local rc = c.rc[PZ[j]]
			P.PlaceZone(st.zones[i][j], root, x + rc[1], y + rc[2], rc[3], rc[4])
		end
		y = y + c:GetHeight() + 12
	end
	st.hint:ClearAllPoints()
	st.hint:SetPoint("TOPLEFT", root, "TOPLEFT", 4, -(y + 2))
	st.hint:SetWidth(w - 8)
	st.hint:SetHeight(40)
	st.hint:SetText(L("mod.preview.plates.hint"))
	st.hint:Show()
end

local PKEY = { name = "nameplates.name", bar = "nameplates.height", hptext = "nameplates.hptext", deb = "nameplates.debuffs",
	cast = "nameplates.castbar", mark = "nameplates.markers", thr = "nameplates.threat" }
local function platesClick(zone)
	local _, _, base, n = string.find(zone, "^(%a+)(%d)$")
	if not base then return nil end
	if n == "2" and base == "bar" then return "nameplates.targetscale" end
	if n == "2" and base == "name" then return "nameplates.targetglow" end
	if base == "bar" then return "nameplates.width" end
	return PKEY[base]
end

P.Register("nameplates", { watch = { "nameplates." }, build = platesBuild, update = platesUpdate, click = platesClick })

-- ================================================================ discussion
local NLINE = 6
local CHAT = {      -- ch : suffixe de la cle du nom du canal ; chs : forme courte ; say : cle du texte d'exemple
	{ ch = "general", chs = "1", who = "Elaria", cl = "PRIEST", say = "mod.preview.chat.s1" },
	{ ch = "party", chs = "G", who = "Thorgrim", cl = "WARRIOR", say = "mod.preview.chat.s2" },
	{ ch = "guild", chs = "Gu", who = "Mirelle", cl = "MAGE", say = "mod.preview.chat.s3" },
	{ ch = "raid", chs = "R", who = "Zulkar", cl = "ROGUE", say = "mod.preview.chat.s4" },
	{ ch = "party", chs = "G", who = "Sylvie", cl = "DRUID", say = "mod.preview.chat.s5" },
	{ ch = "general", chs = "1", who = "Brannok", cl = "WARRIOR", say = "mod.preview.chat.s6" },
}
local STAMP = { hm = "12:34", hms = "12:34:56", hm12 = "12:34 PM" }

local function chatBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { lines = {}, zones = {} }
	root.st = st
	root.win = CreateFrame("Frame", nil, root)
	root.win:SetFrameLevel(P.Lv(1))
	st.edge, st.bg = box(root.win, "BACKGROUND"), box(root.win, "BACKGROUND")
	st.tab1, st.tab2 = box(root.win, "ARTWORK"), box(root.win, "ARTWORK")
	st.tt1, st.tt2 = txt(root.win, 9, T.c.text, "LEFT"), txt(root.win, 9, T.c.dim, "LEFT")
	for i = 1, NLINE do
		local ln = { stamp = txt(root.win, 10, T.c.dim, "LEFT"), ch = txt(root.win, 10, T.c.warn, "LEFT"),
			who = txt(root.win, 10, T.c.text, "LEFT"), say = txt(root.win, 10, T.c.text, "LEFT") }
		st.lines[i] = ln
	end
	local ids = { "tabs", "stamp", "channel", "name", "url", "win" }
	for i = 1, getn(ids) do st.zones[ids[i]] = P.Zone(root, ids[i], ids[i] == "win" and 1 or 3) end
	st.hint = txt(root, 10, T.c.dim, "LEFT")
	return root
end

local function chatUpdate(root, w, h, key, value)
	local st = root.st
	local ww, wh = w - 8, NLINE * 16 + 30
	P.Place(root.win, root, 4, 4, ww, wh)
	local bg = flag("chat.background", false)
	P.Fill(st.edge, T.c.border, 1)
	P.Box(st.edge, root.win, 0, 0, ww, wh)
	P.Fill(st.bg, T.c.bg, bg and num("chat.bgalpha", 0.6) or 0.25)
	P.Box(st.bg, root.win, 1, 1, ww - 2, wh - 2)
	local fsz = num("chat.fontsize", 0)
	if fsz < 8 then fsz = 11 end
	local lh = fsz + 5
	local tabs = flag("chat.tabs", true)
	local top = 2
	if tabs then
		P.Fill(st.tab1, T.c.panel, 1)
		P.Box(st.tab1, root.win, 2, 2, 70, 16)
		P.Fill(st.tab2, T.c.inset, 1)
		P.Box(st.tab2, root.win, 74, 2, 70, 16)
		putText(st.tt1, root.win, 8, 5, 9, L("mod.preview.chat.tab1"))
		putText(st.tt2, root.win, 80, 5, 9, L("mod.preview.chat.tab2"))
		P.PlaceZone(st.zones.tabs, root, 6, 6, 140, 16)
		top = 22
	else
		st.tab1:Hide()
		st.tab2:Hide()
		st.tt1:Hide()
		st.tt2:Hide()
		P.PlaceZone(st.zones.tabs, root, 6, 6, 40, 12)
	end
	local stamp = flag("chat.stamp", true)
	local ccol = flag("chat.classcolor", true)
	local short = flag("chat.shortchan", false)
	local url = flag("chat.url", true)
	local fmt = C.Get("chat.stampfmt") or "hm"
	local ar, ag, ab = T.Accent()
	local nl = floor((wh - top - 4) / lh)
	if nl > NLINE then nl = NLINE end
	for i = 1, NLINE do
		local ln = st.lines[i]
		local d = CHAT[i]
		if i <= nl then
			local y = top + (i - 1) * lh
			local x = 6
			if stamp then
				x = x + putText(ln.stamp, root.win, x, y, fsz, "[" .. (STAMP[fmt] or STAMP.hm) .. "]") + 4
			else
				ln.stamp:Hide()
			end
			local cx = x
			x = x + putText(ln.ch, root.win, x, y, fsz, "[" .. (short and d.chs or L("mod.preview.chat.c." .. d.ch)) .. "]") + 4
			local nx = x
			if ccol then
				local r, g, b = classRGB(d.cl)
				ln.who:SetTextColor(r, g, b, 1)
			else
				ln.who:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1)
			end
			local nw = putText(ln.who, root.win, x, y, fsz, d.who .. ":")
			x = x + nw + 4
			putText(ln.say, root.win, x, y, fsz, L(d.say))
			if url and i == 3 then
				ln.say:SetTextColor(ar, ag, ab, 1)
				P.PlaceZone(st.zones.url, root, 4 + x, 4 + y, ln.say:GetStringWidth(), fsz + 2)
			else
				ln.say:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1)
				if i == 3 then P.PlaceZone(st.zones.url, root, 4 + x, 4 + y, ln.say:GetStringWidth(), fsz + 2) end
			end
			if i == 1 then
				if stamp then P.PlaceZone(st.zones.stamp, root, 4 + 6, 4 + y, cx - 10, fsz + 2) else P.PlaceZone(st.zones.stamp, root, 4 + 6, 4 + y, 20, fsz + 2) end
				P.PlaceZone(st.zones.channel, root, 4 + cx, 4 + y, nx - cx - 4, fsz + 2)
			end
			if i == 2 then P.PlaceZone(st.zones.name, root, 4 + nx, 4 + y, nw, fsz + 2) end
		else
			ln.stamp:Hide()
			ln.ch:Hide()
			ln.who:Hide()
			ln.say:Hide()
		end
	end
	P.PlaceZone(st.zones.win, root, 4, 4, ww, wh)
	st.hint:ClearAllPoints()
	st.hint:SetPoint("TOPLEFT", root, "TOPLEFT", 4, -(wh + 12))
	st.hint:SetWidth(w - 8)
	st.hint:SetHeight(40)
	st.hint:SetText(L("mod.preview.chat.hint"))
	st.hint:Show()
end

local CKEY = { tabs = "chat.tabs", stamp = "chat.stamp", channel = "chat.shortchan", name = "chat.classcolor", url = "chat.url",
	win = "chat.background" }
P.Register("chat", { watch = { "chat." }, build = chatBuild, update = chatUpdate, click = function(zone) return CKEY[zone] end })


-- ================================================================ aides communes (castbar, auras, tooltip, meter, threat, minimap, bags)
-- Principe : chaque element dessine suit son vrai reglage ; un element coupe reste montre en fantome (opacite reduite) pour qu'on puisse le
-- rallumer d'un clic ; st.on[...] garde l'etat pour les tests. Les zones se placent TOUJOURS (meme element coupe).
local function newPanel(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetFrameLevel(P.Lv(1))
	f.edge, f.bg = box(f, "BACKGROUND"), box(f, "BACKGROUND")
	return f
end

-- Cadre w x h : liseret (jeton edgeTok) puis fond (jeton bgTok, opacite bgA).
local function paintPanel(f, w, h, bgTok, bgA, edgeTok)
	f:SetWidth(w)
	f:SetHeight(h)
	P.Fill(f.edge, edgeTok or T.c.border, 1)
	P.Box(f.edge, f, 0, 0, w, h)
	P.Fill(f.bg, bgTok or T.c.bg, bgA or 1)
	P.Box(f.bg, f, 1, 1, w - 2, h - 2)
end

local function tcol(fs, tok, a)
	fs:SetTextColor(tok[1], tok[2], tok[3], a or tok[4] or 1)
end

-- Cree les zones d'un apercu (ids dans l'ordre : la derniere creee est au-dessus).
local function zoneSet(root, st, ids)
	st.z = {}
	for i = 1, getn(ids) do st.z[ids[i]] = P.Zone(root, ids[i]) end
end

local function zp(st, root, id, x, y, w, h)
	P.PlaceZone(st.z[id], root, x, y, w, h)
end

local function zh(st, id)
	st.z[id]:Hide()
end

local function hintAt(st, root, y, w, key)
	st.hint:ClearAllPoints()
	st.hint:SetPoint("TOPLEFT", root, "TOPLEFT", 4, -(y + 4))
	st.hint:SetWidth(w - 8)
	st.hint:SetHeight(46)
	st.hint:SetText(L(key))
	st.hint:Show()
end

-- Zone nommee "<base><n>" (n = un chiffre) -> (base, n).
local function splitZone(zone)
	local _, _, base, n = string.find(zone, "^(%a+)(%d*)$")
	return base, tonumber(n)
end

local function fixed(v, dec)
	return string.format("%." .. dec .. "f", v)
end

local function short(n, on)
	if on and n >= 1000 then return (floor(n / 100) / 10) .. "k" end
	return tostring(n)
end

-- Couleur de qualite d'objet : donnee du JEU si elle existe, sinon jeton du style.
local QTOK = { "dim", "text", "good", "accent", "warn" }
local function qualityRGB(q)
	local tab = getglobal("ITEM_QUALITY_COLORS")
	local col = tab and tab[q]
	if col and col.r then return col.r, col.g, col.b end
	if QTOK[q + 1] == "accent" then return T.Accent() end
	local tok = T.c[QTOK[q + 1] or "text"]
	return tok[1], tok[2], tok[3]
end

-- ================================================================ incantation
local CBZ = { "cap", "bar", "dir", "icon", "spark", "name", "timer", "lag", "height" }

local function castBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { bars = {}, caps = {}, on = {} }
	root.st = st
	local ids = {}
	for i = 1, 3 do
		local b = newPanel(root)
		b.ic, b.fill, b.lag, b.spark = box(b, "ARTWORK"), box(b, "ARTWORK"), box(b, "OVERLAY"), box(b, "OVERLAY")
		b.nm, b.tm = txt(b, 10, T.c.text, "LEFT"), txt(b, 10, T.c.text, "RIGHT")
		st.bars[i] = b
		st.caps[i] = txt(root, 9, T.c.dim, "LEFT")
		for j = 1, getn(CBZ) do tinsert(ids, CBZ[j] .. i) end
	end
	zoneSet(root, st, ids)
	st.hint = txt(root, 10, T.c.dim, "LEFT")
	return root
end

local function castUpdate(root, w, h, key, value)
	local st = root.st
	local wP, wO, bh0 = num("castbar.width", 220), num("castbar.owidth", 180), num("castbar.height", 16)
	local mx = wP > wO and wP or wO
	if mx < 260 then mx = 260 end      -- echelle commune : un changement de largeur se voit tant que la barre tient dans la zone
	local s = (w - 16 - bh0) / mx
	if s > 1.5 then s = 1.5 end
	if s < 0.3 then s = 0.3 end
	local icon, showName, showTimer = flag("castbar.icon", true), flag("castbar.name", true), flag("castbar.timer", true)
	local lag, spark = flag("castbar.lag", true), flag("castbar.spark", true)
	local dec = floor(num("castbar.decimals", 1))
	if dec < 0 then dec = 0 elseif dec > 2 then dec = 2 end
	local dir = C.Get("castbar.channeldir") or "drain"
	local alpha = num("castbar.alpha", 1)
	local failtext, cls = flag("castbar.failtext", true), flag("castbar.classcolor", false)
	local thin = (C.Get("castbar.shape") == "thin")
	local en = { flag("castbar.player", true), flag("castbar.target", true), flag("castbar.focus", true) }
	local bh = floor(bh0 * s + 0.5)
	if bh < 6 then bh = 6 end
	local fs = bh * 0.62
	if fs > 12 then fs = 12 end
	local tb = thin and floor(bh * 0.4) or (bh - 2)
	if tb < 2 then tb = 2 end
	local y = 4
	for i = 1, 3 do
		local b = st.bars[i]
		local bw = floor((i == 1 and wP or wO) * s + 0.5)
		local ix = icon and (bh + 1) or 0
		local prog = (i == 1) and 0.62 or ((i == 2) and 0.4 or 1)
		local pf = prog
		if i == 2 and dir == "drain" then pf = 1 - prog end
		st.on[i] = en[i]
		b.p, b.bw = pf, bw
		b:SetAlpha(en[i] and alpha or alpha * 0.35)
		putText(st.caps[i], root, 4, y, 9, L("mod.preview.castbar.cap." .. i))
		tcol(st.caps[i], T.c.dim, en[i] and 1 or 0.45)
		st.caps[i]:SetWidth(120)
		local by = y + 12
		P.Place(b, root, 4, by, ix + bw, bh)
		P.Fill(b.edge, T.c.border, 1)
		P.Box(b.edge, b, ix, 0, bw, bh)
		P.Fill(b.bg, T.c.inset, 1)
		P.Box(b.bg, b, ix + 1, 1, bw - 2, bh - 2)
		if icon then
			b.ic:SetVertexColor(T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
			P.Box(b.ic, b, 0, 0, bh, bh)
		else
			b.ic:Hide()
		end
		local r, g, bl
		if i == 3 then
			r, g, bl = T.c.bad[1], T.c.bad[2], T.c.bad[3]
		elseif i == 2 then
			r, g, bl = T.c.good[1], T.c.good[2], T.c.good[3]
		elseif cls then
			r, g, bl = classRGB("PALADIN")
		else
			r, g, bl = T.Accent()
		end
		b.fill:SetVertexColor(r, g, bl, 1)
		local fy = 1 + floor((bh - 2 - tb) / 2)
		P.Box(b.fill, b, ix + 1, fy, (bw - 2) * pf, tb)
		local lw = (bw - 2) * 0.12
		if lag and i == 1 then
			P.Fill(b.lag, T.c.bad, 0.5)
			P.Box(b.lag, b, ix + bw - 1 - lw, 1, lw, bh - 2)
		else
			b.lag:Hide()
		end
		if spark and i ~= 3 then
			P.Fill(b.spark, T.c.text, 0.9)
			P.Box(b.spark, b, ix + 1 + (bw - 2) * pf - 1, 0, 3, bh)
		else
			b.spark:Hide()
		end
		local label
		if i == 3 then label = failtext and L("mod.preview.castbar.fail") or "" else label = L("mod.preview.castbar.sp." .. i) end
		if showName and label ~= "" and bh >= 8 then
			putText(b.nm, b, ix + 3, (bh - fs) / 2, fs, label)
			b.nm:SetWidth(bw * 0.6)
		else
			b.nm:Hide()
		end
		if showTimer and i ~= 3 and bh >= 8 then
			putText(b.tm, b, ix + bw - 3 - 50, (bh - fs) / 2, fs, fixed(i == 1 and 1.2 or 3.4, dec))
			b.tm:SetWidth(50)
		else
			b.tm:Hide()
		end
		-- zones
		local bx = 4 + ix
		zp(st, root, "cap" .. i, 4, y, 100, 11)
		zp(st, root, "bar" .. i, bx, by, bw, bh)
		if i == 1 then
			zp(st, root, "dir1", bx + 1, by + 1, (bw - 2) * 0.25, bh - 2)
		elseif i == 2 then
			zp(st, root, "dir2", bx + 1, by + 1, (bw - 2) * pf, bh - 2)
		else
			zh(st, "dir3")
		end
		zp(st, root, "icon" .. i, 4, by, icon and bh or 12, bh)
		if i ~= 3 then zp(st, root, "spark" .. i, bx + 1 + (bw - 2) * pf - 3, by, 6, bh) else zh(st, "spark3") end
		zp(st, root, "name" .. i, bx + 3, by, bw * 0.45, bh)
		if i ~= 3 then zp(st, root, "timer" .. i, bx + bw - 3 - bw * 0.2, by, bw * 0.2, bh) else zh(st, "timer3") end
		if i == 1 then
			zp(st, root, "lag1", bx + bw - 1 - lw, by, lw, bh)
			zp(st, root, "height1", bx, by + bh - 3, bw, 6)
		else
			zh(st, "lag" .. i)
			zh(st, "height" .. i)
		end
		y = by + bh + 10
	end
	hintAt(st, root, y, w, "mod.preview.castbar.hint")
end

local CBK = { cap = { "castbar.player", "castbar.target", "castbar.focus" }, bar = { "castbar.width", "castbar.owidth", "castbar.fade" },
	dir = { "castbar.classcolor", "castbar.channeldir" }, name = { "castbar.name", "castbar.name", "castbar.failtext" },
	icon = "castbar.icon", spark = "castbar.spark", lag = "castbar.lag", height = "castbar.height" }
local function castClick(zone)
	local base, n = splitZone(zone)
	if base == "timer" then return (n == 2) and "castbar.decimals" or "castbar.timer" end
	local k = CBK[base]
	if type(k) == "table" then return k[n] end
	return k
end

P.Register("castbar", { watch = { "castbar." }, build = castBuild, update = castUpdate, click = castClick })

-- ================================================================ buffs et debuffs
local NPOOL = 34
local ABUF = { 3600, 1920, 720, 252, 58, 9, 7, 5, 4, 3, 2, 1 }
local ADEB = { 45, 12, 8, 6 }
local AZ = { "gbuff1", "gdeb1", "gbuff2", "gdeb2", "cap1", "cap2", "cap3", "cap4", "cap5", "cap6", "size", "timer", "stack", "warn", "weapon", "grow" }

local function durTxt(sec)
	if sec >= 3600 then return floor(sec / 3600) .. "h" end
	if sec >= 120 then return floor(sec / 60) .. "m" end
	return tostring(sec)
end

local function aurasBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { pool = {}, caps = {}, on = {}, rect = {}, used = 0, root = root }
	root.st = st
	for i = 1, NPOOL do
		local c = CreateFrame("Frame", nil, root)
		c:SetFrameLevel(P.Lv(1))
		c.edge, c.bg, c.ic = box(c, "BACKGROUND"), box(c, "BACKGROUND"), box(c, "ARTWORK")
		c.tm = txt(c, 9, T.c.dim, "CENTER")
		c.sk = txt(c, 9, T.c.text, "RIGHT")
		st.pool[i] = c
	end
	for i = 1, 6 do st.caps[i] = txt(root, 10, T.c.text, "LEFT") end
	st.arrow = txt(root, 10, T.c.dim, "RIGHT")
	zoneSet(root, st, AZ)
	st.hint = txt(root, 10, T.c.dim, "LEFT")
	return root
end

local function paintIcon(c, kind, cs, tH, sec, stack, fs, o)
	c:SetWidth(cs)
	c:SetHeight(cs + tH)
	local ed = T.c.border
	if kind == "deb" then ed = T.c.bad elseif kind == "weapon" then ed = T.c.warn end
	P.Fill(c.edge, ed, 1)
	P.Box(c.edge, c, 0, 0, cs, cs)
	P.Fill(c.bg, T.c.inset, 1)
	P.Box(c.bg, c, 1, 1, cs - 2, cs - 2)
	if kind == "deb" then
		P.Fill(c.ic, T.c.bad, 0.4)
	else
		local ar, ag, ab = T.Accent()
		c.ic:SetVertexColor(ar, ag, ab, 0.55)
	end
	P.Box(c.ic, c, 2, 2, cs - 4, cs - 4)
	if o.timer then
		putText(c.tm, c, 0, cs + 1, fs, durTxt(sec))
		c.tm:SetWidth(cs)
		if o.warn > 0 and sec <= o.warn and kind ~= "weapon" then tcol(c.tm, T.c.warn) else tcol(c.tm, T.c.dim) end
	else
		c.tm:Hide()
	end
	if o.stacks and stack and stack > 1 then
		putText(c.sk, c, 1, cs - fs - 1, fs, tostring(stack))
		c.sk:SetWidth(cs - 3)
	else
		c.sk:Hide()
	end
	c:Show()
end

-- Place g.n icones (reserve a partir de st.used) en grille ; retourne x, largeur, hauteur du groupe et la liste des rectangles.
local function auraGroup(st, g, o)
	local s = g.s
	local cs = floor(g.size * s + 0.5)
	if cs < 8 then cs = 8 end
	local sp = floor(g.spc * s + 0.5)
	local tH = o.timer and floor(9 * s + 2) or 0
	local fit = floor((g.avail + sp) / (cs + sp))
	if fit < 1 then fit = 1 end
	local per = g.per
	if per > fit then per = fit end
	if per < 1 then per = 1 end
	local fs = 9 * s
	if fs < 7 then fs = 7 end
	local rowH = cs + tH + sp
	local rects = {}
	local n = g.n
	if st.used + n > NPOOL then n = NPOOL - st.used end
	for k = 1, n do
		local row = floor((k - 1) / per)
		local col = (k - 1) - row * per
		local x
		if g.toRight then x = g.x0 + col * (cs + sp) else x = g.x0 + g.avail - (col + 1) * cs - col * sp end
		local y = g.y0 + row * rowH
		local c = st.pool[st.used + k]
		local kind, sec, stack = g.kind, 0, nil
		if g.kind == "buff" then
			local bi = k - (g.weapon and 1 or 0)
			if g.weapon and k == 1 then
				kind, sec = "weapon", 1800
			else
				sec = ABUF[bi] or 1
				if bi == 3 then stack = 3 end
			end
		else
			sec = ADEB[k] or 1
			if k == 2 then stack = 5 end
		end
		paintIcon(c, kind, cs, tH, sec, stack, fs, o)
		P.Place(c, st.root, x, y, cs, cs + tH)
		c:SetAlpha(g.alpha)
		rects[k] = { x, y, cs, cs + tH }
	end
	st.used = st.used + n
	local cols = n < per and n or per
	local rows = floor((n - 1) / per) + 1
	if n < 1 then cols, rows = 1, 1 end
	local gw = cols * (cs + sp) - sp
	local gx = g.toRight and g.x0 or (g.x0 + g.avail - gw)
	return gx, gw, rows * rowH - sp, rects
end

local function capAt(st, root, i, y, str, on, x)
	local fs = st.caps[i]
	putText(fs, root, x or 4, y, 10, str)
	fs:SetWidth(100)
	tcol(fs, i == 1 and T.c.text or T.c.dim, on and 1 or 0.4)
	zp(st, root, "cap" .. i, x or 4, y, 90, 12)
end

local function aurasUpdate(root, w, h, key, value)
	local st = root.st
	local size, spc, tsize = num("auras.size", 28), num("auras.spacing", 3), num("auras.tsize", 22)
	local per, tper = floor(num("auras.perrow", 8)), floor(num("auras.tperrow", 8))
	local toRight = (C.Get("auras.grow") == "right")
	local o = { timer = flag("auras.timer", true), stacks = flag("auras.stacks", true), warn = num("auras.warn", 10) }
	local alpha = num("auras.alpha", 1)
	local nb = floor(num("auras.maxbuffs", 32))
	if nb > 12 then nb = 12 end
	if nb < 1 then nb = 1 end
	local weapon = flag("auras.weapon", true)
	local avail = w - 8 - 12
	local s = avail / (8 * 43)      -- echelle fixe (8 icones de 40 px) : changer la taille se voit ; la ligne se replie si elle deborde
	if s > 1 then s = 1 end
	if s < 0.4 then s = 0.4 end
	st.used = 0
	st.on.player, st.on.target = flag("auras.player", true), flag("auras.target", true)
	st.on.buffs, st.on.debuffs = flag("auras.buffs", true), flag("auras.debuffs", true)
	st.on.tbuffs, st.on.tdebuffs = flag("auras.targetbuffs", true), flag("auras.targetdebuffs", true)
	st.on.weapon, st.on.timer, st.on.stacks = weapon, o.timer, o.stacks
	st.on.right = toRight
	local y = 4
	local pa = st.on.player and alpha or alpha * 0.35
	local ta = st.on.target and alpha or alpha * 0.35
	capAt(st, root, 1, y, L("mod.preview.auras.player"), st.on.player)
	y = y + 14
	-- buffs du joueur
	capAt(st, root, 2, y, L("mod.preview.auras.buffs"), st.on.buffs, 10)
	st.arrow:ClearAllPoints()
	st.arrow:SetPoint("TOPLEFT", root, "TOPLEFT", 4 + avail - 40, -y)
	st.arrow:SetWidth(40)
	st.arrow:SetText(toRight and "-->" or "<--")
	st.arrow:Show()
	zp(st, root, "grow", 4 + avail - 40, y, 40, 12)
	y = y + 14
	local bx, bw, bhh, brects
	if st.on.buffs then
		bx, bw, bhh, brects = auraGroup(st, { kind = "buff", n = nb + (weapon and 1 or 0), x0 = 4, y0 = y, avail = avail, size = size, spc = spc,
			per = per, toRight = toRight, s = s, alpha = pa, weapon = weapon }, o)
		zp(st, root, "gbuff1", bx, y, bw, bhh)
		local off = weapon and 1 or 0
		local r1, r2, r3, r6 = brects[1 + off], brects[2 + off], brects[3 + off], brects[6 + off]
		if r1 then zp(st, root, "size", r1[1], r1[2], r1[3], r1[3]) else zh(st, "size") end
		if r2 then zp(st, root, "timer", r2[1], r2[2], r2[3], r2[4]) else zh(st, "timer") end
		if r3 then zp(st, root, "stack", r3[1], r3[2], r3[3], r3[3]) else zh(st, "stack") end
		if r6 then zp(st, root, "warn", r6[1], r6[2], r6[3], r6[4]) else zh(st, "warn") end
		if weapon and brects[1] then zp(st, root, "weapon", brects[1][1], brects[1][2], brects[1][3], brects[1][3]) else zh(st, "weapon") end
		y = y + bhh + 6
	else
		zh(st, "gbuff1")
		zh(st, "size")
		zh(st, "timer")
		zh(st, "stack")
		zh(st, "warn")
		zh(st, "weapon")
	end
	-- debuffs du joueur
	capAt(st, root, 3, y, L("mod.preview.auras.debuffs"), st.on.debuffs, 10)
	y = y + 14
	if st.on.debuffs then
		local dx, dw, dh = auraGroup(st, { kind = "deb", n = 3, x0 = 4, y0 = y, avail = avail, size = size, spc = spc, per = per, toRight = toRight,
			s = s, alpha = pa }, o)
		zp(st, root, "gdeb1", dx, y, dw, dh)
		y = y + dh + 8
	else
		zh(st, "gdeb1")
	end
	-- cible
	capAt(st, root, 4, y, L("mod.preview.auras.target"), st.on.target)
	y = y + 14
	capAt(st, root, 5, y, L("mod.preview.auras.buffs"), st.on.tbuffs, 10)
	y = y + 14
	if st.on.tbuffs then
		local tx, tw, th = auraGroup(st, { kind = "buff", n = 8, x0 = 4, y0 = y, avail = avail, size = tsize, spc = spc, per = tper,
			toRight = toRight, s = s, alpha = ta }, o)
		zp(st, root, "gbuff2", tx, y, tw, th)
		y = y + th + 6
	else
		zh(st, "gbuff2")
	end
	capAt(st, root, 6, y, L("mod.preview.auras.debuffs"), st.on.tdebuffs, 10)
	y = y + 14
	if st.on.tdebuffs then
		local tx, tw, th = auraGroup(st, { kind = "deb", n = 4, x0 = 4, y0 = y, avail = avail, size = tsize, spc = spc, per = tper,
			toRight = toRight, s = s, alpha = ta }, o)
		zp(st, root, "gdeb2", tx, y, tw, th)
		y = y + th + 6
	else
		zh(st, "gdeb2")
	end
	for i = st.used + 1, NPOOL do st.pool[i]:Hide() end
	hintAt(st, root, y, w, "mod.preview.auras.hint")
end

local AK = { gbuff1 = "auras.perrow", gdeb1 = "auras.spacing", gbuff2 = "auras.tsize", gdeb2 = "auras.tperrow", cap1 = "auras.player",
	cap2 = "auras.buffs", cap3 = "auras.debuffs", cap4 = "auras.target", cap5 = "auras.targetbuffs", cap6 = "auras.targetdebuffs",
	size = "auras.size", timer = "auras.timer", stack = "auras.stacks", warn = "auras.warn", weapon = "auras.weapon", grow = "auras.grow" }
P.Register("auras", { watch = { "auras." }, build = aurasBuild, update = aurasUpdate, click = function(zone) return AK[zone] end })

-- ================================================================ infobulle
local TZ = { "istyle", "uscale", "anchor", "ibord", "ilvl", "iid", "ucls", "utgt", "uhpb", "uhpv", "uid" }

local function tipBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { on = {} }
	root.st = st
	st.item = newPanel(root)
	st.item.l = {}
	for i = 1, 6 do st.item.l[i] = txt(st.item, 10, T.c.text, "LEFT") end
	st.unit = newPanel(root)
	st.unit.l = {}
	for i = 1, 4 do st.unit.l[i] = txt(st.unit, 10, T.c.text, "LEFT") end
	st.unit.hb, st.unit.hf = box(st.unit, "ARTWORK"), box(st.unit, "ARTWORK")
	st.unit.hv = txt(st.unit, 9, T.c.text, "CENTER")
	st.scr = newPanel(root)
	st.scr.tip, st.scr.tipb, st.scr.cur = box(st.scr, "OVERLAY"), box(st.scr, "ARTWORK"), box(st.scr, "OVERLAY")
	st.scr.lab = txt(st.scr, 9, T.c.dim, "LEFT")
	zoneSet(root, st, TZ)
	st.hint = txt(root, 10, T.c.dim, "LEFT")
	return root
end

-- Fond et liseret d'une bulle selon le style : habillee ShikiUI (panneau + liseret) ou aspect d'origine (liseret sourd, fond leger).
local function tipFrame(f, w, h, styled, er, eg, eb)
	f:SetWidth(w)
	f:SetHeight(h)
	if styled then
		P.Fill(f.bg, T.c.panel, 1)
		f.edge:SetVertexColor(er, eg, eb, 1)
	else
		P.Fill(f.bg, T.c.bg, 0.85)
		P.Fill(f.edge, T.c.dim, 1)
	end
	P.Box(f.edge, f, 0, 0, w, h)
	P.Box(f.bg, f, 1, 1, w - 2, h - 2)
end

local function tipUpdate(root, w, h, key, value)
	local st = root.st
	local ts = num("tooltip.scale", 1)
	local styled, bcol, ccol = flag("tooltip.style", true), flag("tooltip.bordercolor", true), flag("tooltip.classcolor", true)
	local showTgt, hpv, hpb = flag("tooltip.target", true), flag("tooltip.hpvalue", true), flag("tooltip.hpbar", true)
	local uid, ilvl, iid = flag("tooltip.unitid", false), flag("tooltip.itemlevel", true), flag("tooltip.itemid", false)
	local cursor = (C.Get("tooltip.anchor") == "cursor")
	st.on.style, st.on.bordercolor, st.on.classcolor, st.on.target = styled, bcol, ccol, showTgt
	st.on.hpvalue, st.on.hpbar, st.on.unitid, st.on.itemlevel, st.on.itemid = hpv, hpb, uid, ilvl, iid
	st.on.cursor = cursor
	local lh = floor(13 * ts + 0.5)
	local fs = 10 * ts
	local iw = floor(150 * ts + 0.5)
	if iw > w - 8 then iw = w - 8 end
	-- objet : 6 lignes fixes (une ligne coupee reste en fantome)
	local it = st.item
	local qr, qg, qb = qualityRGB(4)
	local ih = 6 * lh + 8
	tipFrame(it, iw, ih, styled, bcol and qr or T.c.border[1], bcol and qg or T.c.border[2], bcol and qb or T.c.border[3])
	P.Place(it, root, 4, 4, iw, ih)
	local lines = { L("mod.preview.tooltip.item"), L("mod.preview.tooltip.type"), L("mod.preview.tooltip.stat"),
		L("mod.preview.tooltip.ilvl", 66), L("mod.preview.tooltip.iid", 12345), L("mod.preview.tooltip.req") }
	local ily, iidy
	for i = 1, 6 do
		local fsx = it.l[i]
		local ly = 4 + (i - 1) * lh
		putText(fsx, it, 5, ly + (lh - fs) / 2 - 1, fs, lines[i])
		fsx:SetWidth(iw - 10)
		if i == 1 then
			fsx:SetTextColor(qr, qg, qb, 1)
		elseif i == 3 then
			tcol(fsx, T.c.good, 1)
		elseif i == 4 then
			tcol(fsx, T.c.text, ilvl and 1 or 0.3)
			ily = ly
		elseif i == 5 then
			tcol(fsx, T.c.dim, iid and 1 or 0.3)
			iidy = ly
		else
			tcol(fsx, T.c.dim, 1)
		end
	end
	-- unite
	local uy = 4 + ih + 10
	local uh = 4 * lh + 8 + (hpb and 10 or 0)
	local uw = floor(150 * ts + 0.5)
	if uw > w - 8 then uw = w - 8 end
	local un = st.unit
	local cr, cg, cb = classRGB("PALADIN")
	tipFrame(un, uw, uh, styled, bcol and cr or T.c.border[1], bcol and cg or T.c.border[2], bcol and cb or T.c.border[3])
	P.Place(un, root, 4, uy, uw, uh)
	local y = 4
	putText(un.l[1], un, 5, y + (lh - fs) / 2 - 1, fs, L("mod.preview.tooltip.uname"))
	if ccol then un.l[1]:SetTextColor(cr, cg, cb, 1) else tcol(un.l[1], T.c.text, 1) end
	un.l[1]:SetWidth(uw - 10)
	local nameY = y
	y = y + lh
	putText(un.l[2], un, 5, y + (lh - fs) / 2 - 1, fs, L("mod.preview.tooltip.ulvl"))
	tcol(un.l[2], T.c.dim, 1)
	un.l[2]:SetWidth(uw - 10)
	y = y + lh
	putText(un.l[3], un, 5, y + (lh - fs) / 2 - 1, fs, L("mod.preview.tooltip.utgt"))
	tcol(un.l[3], T.c.warn, showTgt and 1 or 0.3)
	un.l[3]:SetWidth(uw - 10)
	local tgtY = y
	y = y + lh
	putText(un.l[4], un, 5, y + (lh - fs) / 2 - 1, fs, L("mod.preview.tooltip.uid"))
	tcol(un.l[4], T.c.dim, uid and 1 or 0.3)
	un.l[4]:SetWidth(uw - 10)
	local idY = y
	y = y + lh + 2
	local bh = 10
	P.Fill(un.hb, T.c.inset, hpb and 1 or 0.3)
	P.Box(un.hb, un, 4, y, uw - 8, bh)
	P.Fill(un.hf, T.c.good, hpb and 1 or 0.3)
	P.Box(un.hf, un, 4, y, (uw - 8) * 0.72, bh)
	putText(un.hv, un, 4, y, 9, L("mod.preview.tooltip.uhp"))
	un.hv:SetWidth(uw - 8)
	tcol(un.hv, T.c.text, hpv and 1 or 0.25)
	local hpY = y
	-- mini ecran : emplacement de la bulle
	local sy = uy + uh + 10
	local sw, sh = w - 8, 64
	local sc = st.scr
	paintPanel(sc, sw, sh, T.c.inset, 1)
	P.Place(sc, root, 4, sy, sw, sh)
	local cx, cy = floor(sw * 0.38), floor(sh * 0.3)
	local tw, th = 38, 20
	local tx, ty = sw - tw - 6, sh - th - 6
	if cursor then tx, ty = cx + 8, cy + 8 end
	P.Fill(sc.tipb, T.c.border, 1)
	P.Box(sc.tipb, sc, tx - 1, ty - 1, tw + 2, th + 2)
	P.Fill(sc.tip, T.c.panel, 1)
	P.Box(sc.tip, sc, tx, ty, tw, th)
	local ar, ag, ab = T.Accent()
	sc.cur:SetVertexColor(ar, ag, ab, 1)
	P.Box(sc.cur, sc, cx - 2, cy - 2, 5, 5)
	putText(sc.lab, sc, 4, 3, 9, L(cursor and "mod.preview.tooltip.cursor" or "mod.preview.tooltip.default"))
	sc.lab:SetWidth(sw - 8)
	-- zones (ordre de creation = dessus)
	zp(st, root, "istyle", 4, 4, iw, ih)
	zp(st, root, "uscale", 4, uy, uw, uh)
	zp(st, root, "anchor", 4, sy, sw, sh)
	zp(st, root, "ibord", 4, 4, 6, ih)
	zp(st, root, "ilvl", 4 + 6, 4 + ily, iw - 12, lh)
	zp(st, root, "iid", 4 + 6, 4 + iidy, iw - 12, lh)
	zp(st, root, "ucls", 4 + 6, uy + nameY, uw - 12, lh)
	zp(st, root, "utgt", 4 + 6, uy + tgtY, uw - 12, lh)
	zp(st, root, "uhpb", 4, uy + hpY, uw - 8, bh)
	zp(st, root, "uhpv", 4 + floor(uw * 0.3), uy + hpY, floor(uw * 0.4), bh)
	zp(st, root, "uid", 4 + 6, uy + idY, uw - 12, lh)
	hintAt(st, root, sy + sh + 4, w, "mod.preview.tooltip.hint")
end

local TK = { istyle = "tooltip.style", uscale = "tooltip.scale", anchor = "tooltip.anchor", ibord = "tooltip.bordercolor", ilvl = "tooltip.itemlevel",
	iid = "tooltip.itemid", ucls = "tooltip.classcolor", utgt = "tooltip.target", uhpb = "tooltip.hpbar", uhpv = "tooltip.hpvalue", uid = "tooltip.unitid" }
P.Register("tooltip", { watch = { "tooltip." }, build = tipBuild, update = tipUpdate, click = function(zone) return TK[zone] end })

-- ================================================================ fenetres de liste (compteurs, menace) : modele commun
local function newWin(parent, nrow)
	local f = newPanel(parent)
	f.head = box(f, "ARTWORK")
	f.title = txt(f, 10, T.c.text, "LEFT")
	f.sub = txt(f, 9, T.c.dim, "RIGHT")
	f.tag = txt(f, 9, T.c.warn, "LEFT")
	f.r = {}
	for i = 1, nrow do
		f.r[i] = { bar = box(f, "ARTWORK"), nm = txt(f, 10, T.c.text, "LEFT"), vl = txt(f, 10, T.c.text, "RIGHT") }
	end
	return f
end

-- Dessine la fenetre f (largeur w) : o = { fs, rowh, spc, n, alpha, title, sub, rows = { { name, r, g, b, frac, val } } }.
-- Retourne sa hauteur et celle de l'entete.
local function paintWin(f, w, o)
	local hh = o.rowh + 2
	local total = hh + o.n * (o.rowh + o.spc) + 3
	paintPanel(f, w, total, T.c.bg, o.alpha)
	P.Fill(f.head, T.c.panel, 1)
	P.Box(f.head, f, 1, 1, w - 2, hh - 1)
	local fs = o.fs
	putText(f.title, f, 5, 1 + (hh - 1 - fs) / 2, fs, o.title)
	f.title:SetWidth(w * 0.6)
	if o.sub and o.sub ~= "" then
		putText(f.sub, f, w - 5 - w * 0.4, 1 + (hh - 1 - fs) / 2, fs * 0.9, o.sub)
		f.sub:SetWidth(w * 0.4)
	else
		f.sub:Hide()
	end
	for i = 1, getn(f.r) do
		local r = f.r[i]
		local d = o.rows[i]
		if i <= o.n and d then
			local y = hh + 1 + (i - 1) * (o.rowh + o.spc)
			r.bar:SetVertexColor(d.r, d.g, d.b, 0.85)
			P.Box(r.bar, f, 1, y, (w - 2) * d.frac, o.rowh)
			putText(r.nm, f, 4, y + (o.rowh - fs) / 2, fs, d.name)
			r.nm:SetWidth(w * 0.5)
			putText(r.vl, f, w - 4 - w * 0.45, y + (o.rowh - fs) / 2, fs, d.val)
			r.vl:SetWidth(w * 0.45)
		else
			r.bar:Hide()
			r.nm:Hide()
			r.vl:Hide()
		end
	end
	f:Show()
	return total, hh
end

-- Donnees d'exemple : joueurs de classes differentes, valeurs decroissantes.
local WHO = {
	{ "Thorgrim", "WARRIOR", 18420 }, { "Zulkar", "ROGUE", 16100 }, { "Mirelle", "MAGE", 15200 }, { "Shikiwa", "PALADIN", 12050 },
	{ "Sylvie", "DRUID", 9800 }, { "Elaria", "PRIEST", 8400 }, { "Brannok", "HUNTER", 7600 }, { "Vexa", "WARLOCK", 6300 },
}

-- ================================================================ compteurs
local MAXW = 4
local MZ = { "win", "title", "wins", "bar1", "name2", "cls", "val", "pct", "rowh", "font" }

local function meterBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { wins = {}, on = {} }
	root.st = st
	for i = 1, MAXW do st.wins[i] = newWin(root, 8) end
	zoneSet(root, st, MZ)
	st.hint = txt(root, 10, T.c.dim, "LEFT")
	return root
end

local function meterRows(o)
	local rows = {}
	local total = 0
	for i = 1, getn(WHO) do total = total + WHO[i][3] end
	local ar, ag, ab = T.Accent()
	for i = 1, getn(WHO) do
		local d = WHO[i]
		local r, g, b = ar, ag, ab
		if o.cls then r, g, b = classRGB(d[2]) end
		local val = short(d[3], o.short)
		if o.pct then val = val .. " (" .. floor(d[3] / total * 100 + 0.5) .. "%)" end
		rows[i] = { name = (o.rank and (i .. ". ") or "") .. d[1], r = r, g = g, b = b, frac = d[3] / WHO[1][3], val = val }
	end
	return rows
end

local function meterUpdate(root, w, h, key, value)
	local st = root.st
	local width, rowh, fsz = num("meter.width", 240), num("meter.rowh", 16), num("meter.fontsize", 11)
	local spc, alpha, hh = num("meter.spacing", 1), num("meter.alpha", 0.9), num("meter.height", 0)
	local n = floor(num("meter.rows", 10))
	if n > 8 then n = 8 end
	if n < 1 then n = 1 end
	if hh > 0 then
		local fit = floor((hh - (rowh + 2) - 3) / (rowh + spc))
		if fit < 1 then fit = 1 end
		if n > fit then n = fit end
	end
	local nwin = floor(num("meter.windows", 1))
	if nwin > MAXW then nwin = MAXW elseif nwin < 1 then nwin = 1 end
	local o = { cls = flag("meter.classcolor", true), rank = flag("meter.showrank", true), pct = flag("meter.showpct", true),
		short = flag("meter.shortnum", true) }
	st.on.cls, st.on.rank, st.on.pct, st.on.short = o.cls, o.rank, o.pct, o.short
	st.nwin, st.n = nwin, n
	local s = (w - 8) / (width > 300 and width or 300)
	if s > 1.3 then s = 1.3 end
	local pw = floor(width * s)
	local rs = floor(rowh * s + 0.5)
	if rs < 9 then rs = 9 end
	local fs = fsz * s
	if fs < 7 then fs = 7 end
	if fs > rs - 1 then fs = rs - 1 end
	local rows = meterRows(o)
	local view1, seg1 = C.Get("meter.view1") or "damage", C.Get("meter.seg1") or "current"
	local y = 4
	local th1, hh1
	for i = 1, MAXW do
		local f = st.wins[i]
		if i <= nwin then
			local po = { fs = fs, rowh = rs, spc = floor(spc * s + 0.5), n = n, alpha = alpha, rows = rows }
			local vw = C.Get("meter.view" .. i) or ((i == 2) and "heal" or ((i == 3) and "taken" or "interrupts"))
			local sg = C.Get("meter.seg" .. i) or "current"
			if i == 1 then vw, sg = view1, seg1 end
			po.title = L("choice.meter.view." .. vw) .. " - " .. L("choice.meter.seg." .. sg)
			local ww = pw
			if i == 1 then
				po.sub = L("mod.preview.meter.wins", nwin)
			else
				po.n = 2
				po.rowh = floor(rs * 0.75)
				po.fs = fs * 0.85
				ww = floor(pw * 0.8)
				po.sub = ""
			end
			local total, head = paintWin(f, ww, po)
			P.Place(f, root, 4, y, ww, total)
			if i == 1 then th1, hh1 = total, head end
			y = y + total + 6
		else
			f:Hide()
		end
	end
	-- zones sur la fenetre 1
	local sp1 = floor(spc * s + 0.5)
	local function rowY(i) return 4 + hh1 + 1 + (i - 1) * (rs + sp1) end
	zp(st, root, "win", 4, 4, pw, th1)
	zp(st, root, "title", 4, 4, floor(pw * 0.55), hh1)
	zp(st, root, "wins", 4 + floor(pw * 0.6), 4, floor(pw * 0.4), hh1)
	zp(st, root, "bar1", 4 + 1, rowY(1), floor(pw * 0.3), rs)
	if n >= 2 then zp(st, root, "name2", 4 + 1, rowY(2), floor(pw * 0.35), rs) else zh(st, "name2") end
	if n >= 3 then zp(st, root, "cls", 4 + floor(pw * 0.4), rowY(3), floor(pw * 0.15), rs) else zh(st, "cls") end
	if n >= 4 then zp(st, root, "val", 4 + floor(pw * 0.6), rowY(4), floor(pw * 0.38), rs) else zh(st, "val") end
	if n >= 5 then zp(st, root, "pct", 4 + floor(pw * 0.6), rowY(5), floor(pw * 0.38), rs) else zh(st, "pct") end
	if n >= 6 then zp(st, root, "rowh", 4 + floor(pw * 0.4), rowY(6), floor(pw * 0.15), rs) else zh(st, "rowh") end
	if n >= 7 then zp(st, root, "font", 4 + floor(pw * 0.1), rowY(7), floor(pw * 0.2), rs) else zh(st, "font") end
	hintAt(st, root, y, w, "mod.preview.meter.hint")
end

local MK = { win = "meter.width", title = "meter.view1", wins = "meter.windows", bar1 = "meter.rowh", name2 = "meter.showrank", cls = "meter.classcolor",
	val = "meter.shortnum", pct = "meter.showpct", rowh = "meter.spacing", font = "meter.fontsize" }
P.Register("meter", { watch = { "meter." }, build = meterBuild, update = meterUpdate, click = function(zone) return MK[zone] end })

-- ================================================================ menace
local TH = {       -- pourcentage de menace, menace brute, menace par seconde
	{ 100, 9400, 410 }, { 92, 8650, 380 }, { 78, 7330, 300 }, { 55, 5170, 210 }, { 40, 3760, 150 }, { 22, 2070, 90 },
}
local MOBS = { "Gnoll", "Kobold", "Ogre", "Murloc", "Defias", "Harpie" }
local HZ = { "win", "title", "sub", "row1", "row2", "tag", "row4", "row5" }

local function threatBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { on = {} }
	root.st = st
	st.win = newWin(root, 8)
	zoneSet(root, st, HZ)
	st.hint = txt(root, 10, T.c.dim, "LEFT")
	return root
end

local function threatUpdate(root, w, h, key, value)
	local st = root.st
	local width, rowh, fsz = num("threat.width", 220), num("threat.rowh", 16), num("threat.fontsize", 11)
	local spc, alpha, hh = num("threat.spacing", 1), num("threat.alpha", 0.9), num("threat.height", 0)
	local n = floor(num("threat.rows", 10))
	if n > 6 then n = 6 end
	if n < 1 then n = 1 end
	if hh > 0 then
		local fit = floor((hh - (rowh + 2) - 3) / (rowh + spc))
		if fit < 1 then fit = 1 end
		if n > fit then n = fit end
	end
	local warn = num("threat.warn", 85)
	local view = C.Get("threat.view") or "players"
	local cls, shortn, tps = flag("threat.classcolor", true), flag("threat.shortnum", true), flag("threat.showtps", true)
	local mark, taunt, est, agro = flag("threat.markholder", true), flag("threat.taunt", true), flag("threat.estimate", true), flag("threat.showagro", true)
	st.on.cls, st.on.short, st.on.tps, st.on.mark, st.on.taunt, st.on.est, st.on.agro = cls, shortn, tps, mark, taunt, est, agro
	st.view, st.n = view, n
	local s = (w - 8) / (width > 300 and width or 300)
	if s > 1.3 then s = 1.3 end
	local pw = floor(width * s)
	local rs = floor(rowh * s + 0.5)
	if rs < 9 then rs = 9 end
	local fs = fsz * s
	if fs < 7 then fs = 7 end
	if fs > rs - 1 then fs = rs - 1 end
	local ar, ag, ab = T.Accent()
	local rows = {}
	for i = 1, getn(TH) do
		local d, t = WHO[i], TH[i]
		local r, g, b = ar, ag, ab
		if cls and view == "players" then r, g, b = classRGB(d[2]) end
		local hot = (i > 1) and (t[1] >= warn)
		if hot then r, g, b = T.c.bad[1], T.c.bad[2], T.c.bad[3] end
		local nm = (view == "players") and d[1] or MOBS[i]
		if mark and i == 1 and view == "players" then nm = "[" .. L("mod.preview.threat.tank") .. "] " .. nm end
		local val = t[1] .. "%  " .. (est and "~" or "") .. short(t[2], shortn)
		if tps then val = val .. " " .. short(t[3], shortn) .. "/s" end
		rows[i] = { name = nm, r = r, g = g, b = b, frac = t[1] / 100, val = val }
	end
	local po = { fs = fs, rowh = rs, spc = floor(spc * s + 0.5), n = n, alpha = alpha, rows = rows, title = L("choice.threat.view." .. view) }
	if agro then po.sub = L("mod.preview.threat.agro", (view == "players") and WHO[1][1] or MOBS[1]) end
	local f = st.win
	local total, head = paintWin(f, pw, po)
	P.Place(f, root, 4, 4, pw, total)
	local sp1 = floor(spc * s + 0.5)
	local function rowY(i) return 4 + head + 1 + (i - 1) * (rs + sp1) end
	-- marque de provocation sur la 3e ligne (si elle existe)
	if taunt and n >= 3 and view == "players" then
		putText(f.tag, f, floor(pw * 0.42), head + 1 + 2 * (rs + sp1) + (rs - fs) / 2, fs * 0.9, L("mod.preview.threat.taunt"))
		f.tag:SetWidth(floor(pw * 0.3))
	else
		f.tag:Hide()
	end
	zp(st, root, "win", 4, 4, pw, total)
	zp(st, root, "title", 4, 4, floor(pw * 0.45), head)
	zp(st, root, "sub", 4 + floor(pw * 0.55), 4, floor(pw * 0.45), head)
	zp(st, root, "row1", 4 + 1, rowY(1), floor(pw * 0.45), rs)
	if n >= 2 then zp(st, root, "row2", 4 + 1, rowY(2), floor(pw * 0.4), rs) else zh(st, "row2") end
	if n >= 3 then zp(st, root, "tag", 4 + floor(pw * 0.42), rowY(3), floor(pw * 0.3), rs) else zh(st, "tag") end
	if n >= 4 then zp(st, root, "row4", 4 + floor(pw * 0.55), rowY(4), floor(pw * 0.43), rs) else zh(st, "row4") end
	if n >= 5 then zp(st, root, "row5", 4 + 1, rowY(5), floor(pw * 0.4), rs) else zh(st, "row5") end
	hintAt(st, root, total + 8, w, "mod.preview.threat.hint")
end

local HK = { win = "threat.width", title = "threat.view", sub = "threat.showagro", row1 = "threat.markholder", row2 = "threat.warn", tag = "threat.taunt",
	row4 = "threat.showtps", row5 = "threat.classcolor" }
P.Register("threat", { watch = { "threat." }, build = threatBuild, update = threatUpdate, click = function(zone) return HK[zone] end })

-- ================================================================ minimap
-- Rond ou carre dessine par bandes horizontales de textures unies (aucune ressource du jeu) : la bande du haut est plus etroite en rond.
local NSTRIP = 28
local MZN = { "disc", "size", "edge", "coords", "zone", "clock", "launcher", "toggle" }
local TOGGLE = { topleft = { 0, 0 }, topright = { 1, 0 }, bottomleft = { 0, 1 }, bottomright = { 1, 1 } }

local function mapBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { fill = {}, ring = {}, on = {} }
	root.st = st
	local d = CreateFrame("Frame", nil, root)
	d:SetFrameLevel(P.Lv(1))
	st.disc = d
	for i = 1, NSTRIP + 2 do st.ring[i] = box(d, "BACKGROUND") end
	for i = 1, NSTRIP do st.fill[i] = box(d, "BORDER") end
	st.land1, st.land2, st.me = box(d, "ARTWORK"), box(d, "ARTWORK"), box(d, "OVERLAY")
	st.zone, st.coords, st.clock = txt(d, 10, T.c.text, "CENTER"), txt(d, 10, T.c.text, "CENTER"), txt(d, 10, T.c.text, "CENTER")
	st.lb, st.lt = box(d, "OVERLAY"), txt(d, 9, T.c.text, "CENTER")
	st.tb, st.tt = box(d, "OVERLAY"), txt(d, 9, T.c.text, "CENTER")
	st.grip = box(d, "OVERLAY")
	st.cap = txt(root, 10, T.c.dim, "CENTER")
	zoneSet(root, st, MZN)
	st.hint = txt(root, 10, T.c.dim, "LEFT")
	return root
end

local function mapUpdate(root, w, h, key, value)
	local st = root.st
	local round = (C.Get("minimap.shape") ~= "square")
	local size = num("minimap.size", 140)
	local maxD = w - 40
	if h - 90 < maxD then maxD = h - 90 end
	if maxD < 60 then maxD = 60 end
	local sc = maxD / 240
	local d = floor(size * sc)
	if d < 40 then d = 40 end
	local R = d / 2
	local edge = flag("minimap.edge", true)
	st.on.round, st.on.edge, st.d = round, edge, d
	local dx = floor((w - d) / 2)
	local dy = 14
	local disc = st.disc
	P.Place(disc, root, dx, dy, d, d)
	disc:SetAlpha(num("minimap.alpha", 1))
	local rh = d / NSTRIP
	for i = 1, NSTRIP do
		local yc = (i - 0.5) * rh - R
		local hw = R
		if round then
			local q = R * R - yc * yc
			hw = (q > 0) and math.sqrt(q) or 0
		end
		P.Fill(st.fill[i], T.c.inset, 1)
		P.Box(st.fill[i], disc, R - hw, (i - 1) * rh, hw * 2, rh + 0.6)
	end
	local R2 = R + 2
	for i = 1, NSTRIP + 2 do
		local yy = (i - 2) * rh
		local yc = yy + rh / 2 - R
		local hw = R2
		if round then
			local q = R2 * R2 - yc * yc
			hw = (q > 0) and math.sqrt(q) or 0
		elseif yc < -R2 or yc > R2 then
			hw = 0
		end
		if edge and hw > 0 then
			P.Fill(st.ring[i], T.c.border, 1)
			P.Box(st.ring[i], disc, R - hw, yy, hw * 2, rh + 0.6)
		else
			st.ring[i]:Hide()
		end
	end
	-- relief d'exemple et position du joueur
	P.Fill(st.land1, T.c.good, 0.25)
	P.Box(st.land1, disc, R * 0.4, R * 0.9, R * 0.6, R * 0.35)
	local ar, ag, ab = T.Accent()
	st.land2:SetVertexColor(ar, ag, ab, 0.2)
	P.Box(st.land2, disc, R * 0.9, R * 0.3, R * 0.5, R * 0.4)
	st.me:SetVertexColor(ar, ag, ab, 1)
	P.Box(st.me, disc, R - 2, R - 2, 5, 5)
	-- zone, coordonnees, heure
	local fs = 10 * sc * 1.4
	if fs < 8 then fs = 8 elseif fs > 12 then fs = 12 end
	local zoneOn, coordOn = flag("minimap.zone", true), flag("minimap.coords", true)
	local clock = C.Get("minimap.clock") or "off"
	st.on.zone, st.on.coords, st.on.clock = zoneOn, coordOn, clock
	local zy = R * 0.2
	putText(st.zone, disc, 0, zy, fs, L("mod.preview.minimap.zone"))
	st.zone:SetWidth(d)
	if not zoneOn then st.zone:Hide() end
	local cy = d - fs - R * 0.2
	local dec = floor(num("minimap.dec", 1))
	if dec < 0 then dec = 0 elseif dec > 2 then dec = 2 end
	putText(st.coords, disc, 0, cy, fs, fixed(45.23, dec) .. ", " .. fixed(63.11, dec))
	st.coords:SetWidth(d)
	if not coordOn then st.coords:Hide() end
	local ky = zy + fs + 2
	putText(st.clock, disc, 0, ky, fs, (clock == "server") and L("mod.preview.minimap.server") or "12:34")
	st.clock:SetWidth(d)
	if clock == "off" then st.clock:Hide() end
	-- lanceur (sur le bord, a l'angle choisi) et bouton du tiroir
	local launch = flag("minimap.launcher", true)
	local ls = num("minimap.launchsize", 22) * sc * 1.2
	if ls < 10 then ls = 10 end
	local ang = math.rad(num("minimap.launchangle", 165))
	local lx, ly = R + math.cos(ang) * R - ls / 2, R - math.sin(ang) * R - ls / 2
	st.on.launcher = launch
	if launch then
		P.Fill(st.lb, T.c.panel, 1)
		P.Box(st.lb, disc, lx, ly, ls, ls)
		putText(st.lt, disc, lx, ly + (ls - 9) / 2, 9, "S")
		st.lt:SetWidth(ls)
	else
		st.lb:Hide()
		st.lt:Hide()
	end
	local tpos = C.Get("minimap.togglepos") or "topleft"
	local ts = num("minimap.togglesize", 16) * sc * 1.2
	if ts < 10 then ts = 10 end
	local tp = TOGGLE[tpos] or TOGGLE.topleft
	local tx, ty = tp[1] * (d - ts) + num("minimap.togglex", 0) * sc, tp[2] * (d - ts) - num("minimap.toggley", 0) * sc
	local tgl = flag("minimap.buttons", true) and tpos ~= "hide"
	st.on.toggle = tgl
	if tgl then
		P.Fill(st.tb, T.c.panel, 1)
		P.Box(st.tb, disc, tx, ty, ts, ts)
		putText(st.tt, disc, tx, ty + (ts - 9) / 2, 9, ">")
		st.tt:SetWidth(ts)
	else
		st.tb:Hide()
		st.tt:Hide()
	end
	-- poignee de taille (coin bas droit)
	P.Fill(st.grip, T.c.dim, 0.8)
	P.Box(st.grip, disc, d - 5, d - 5, 7, 7)
	st.cap:ClearAllPoints()
	st.cap:SetPoint("TOPLEFT", root, "TOPLEFT", 4, -(dy + d + 8))
	st.cap:SetWidth(w - 8)
	st.cap:SetText(L("mod.preview.minimap.cap", L(round and "mod.preview.minimap.round" or "mod.preview.minimap.square"), size))
	st.cap:Show()
	-- zones
	zp(st, root, "disc", dx, dy, d, d)
	zp(st, root, "size", dx + d - 6, dy + d - 6, 12, 12)
	zp(st, root, "edge", dx - 4, dy + R - 10, 8, 20)
	zp(st, root, "coords", dx + R * 0.3, dy + cy, d * 0.7, fs + 2)
	zp(st, root, "zone", dx + R * 0.3, dy + zy, d * 0.7, fs + 2)
	zp(st, root, "clock", dx + R * 0.5, dy + ky, d * 0.5, fs + 2)
	zp(st, root, "launcher", dx + lx, dy + ly, ls, ls)
	zp(st, root, "toggle", dx + tx, dy + ty, ts, ts)
	hintAt(st, root, dy + d + 26, w, "mod.preview.minimap.hint")
end

local MMK = { disc = "minimap.shape", size = "minimap.size", edge = "minimap.edge", coords = "minimap.coords", zone = "minimap.zone",
	clock = "minimap.clock", launcher = "minimap.launcher", toggle = "minimap.buttons" }
P.Register("minimap", { watch = { "minimap." }, build = mapBuild, update = mapUpdate, click = function(zone) return MMK[zone] end })

-- ================================================================ sacs
local NSLOT = 40
local BQ = { 4, 3, 3, 2, 2, 2, 1, 1, 1, 1, 0, 0, 2, 3, 1, 1, 2, 1, 0, 1, 2, 1, 1, 3, 1, 1 }   -- qualite des objets d'exemple (0 = gris)
local BCNT = { [5] = 20, [9] = 5, [10] = 200, [15] = 12, [17] = 3, [22] = 40 }
local BCATN = { 8, 8, 6, 4 }
local BZ = { "grid", "cell1", "qual", "border", "count", "junk", "sort", "search", "filters", "value", "keyring", "cats" }

local function bagsBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	local st = { cells = {}, on = {}, heads = {}, tabs = {} }
	root.st = st
	local win = newPanel(root)
	st.win = win
	win.title = txt(win, 10, T.c.text, "LEFT")
	win.sortt = txt(win, 9, T.c.dim, "CENTER")
	win.sb, win.st = box(win, "ARTWORK"), txt(win, 9, T.c.dim, "LEFT")
	for i = 1, 4 do
		st.tabs[i] = { b = box(win, "ARTWORK"), t = txt(win, 8, T.c.text, "CENTER") }
		st.heads[i] = txt(win, 9, T.c.dim, "LEFT")
	end
	for i = 1, NSLOT do
		local c = CreateFrame("Frame", nil, win)
		c:SetFrameLevel(P.Lv(2))
		c.edge, c.bg, c.ic = box(c, "BACKGROUND"), box(c, "BACKGROUND"), box(c, "ARTWORK")
		c.cn = txt(c, 9, T.c.text, "RIGHT")
		st.cells[i] = c
	end
	win.slots, win.money = txt(win, 9, T.c.dim, "LEFT"), txt(win, 9, T.c.warn, "RIGHT")
	win.kb, win.kt = box(win, "ARTWORK"), txt(win, 8, T.c.text, "CENTER")
	zoneSet(root, st, BZ)
	st.hint = txt(root, 10, T.c.dim, "LEFT")
	return root
end

-- Ordre d'affichage des objets d'exemple selon le tri choisi et "junk en dernier" (insertion stable).
local function bagOrder(sort, junklast)
	local key, ord = {}, {}
	for i = 1, getn(BQ) do
		local q = BQ[i]
		local k = i
		if sort == "quality" then k = (4 - q) * 100 + i end
		if junklast and q == 0 then k = k + 1000 end
		key[i] = k
		local j = i - 1
		while j >= 1 and key[ord[j]] > k do
			ord[j + 1] = ord[j]
			j = j - 1
		end
		ord[j + 1] = i
	end
	return ord
end

local function bagsUpdate(root, w, h, key, value)
	local st = root.st
	local cols, size, spc = floor(num("bags.columns", 10)), num("bags.size", 32), num("bags.spacing", 2)
	local limit = num("bags.borderlimit", 2)
	local useQ, cnt, junkl = flag("bags.quality", true), flag("bags.counts", true), flag("bags.junklast", true)
	local sort = C.Get("bags.sort") or "quality"
	local val, srch, filt, ring = flag("bags.value", true), flag("bags.search", true), flag("bags.filters", true), flag("bags.keyring", false)
	local catOpt = P.FindOption("bags.categories") ~= nil
	local cats = catOpt and flag("bags.categories", false)
	st.on.quality, st.on.counts, st.on.junklast, st.on.value, st.on.search, st.on.filters = useQ, cnt, junkl, val, srch, filt
	st.on.keyring, st.on.cats, st.sort = ring, cats, sort
	local ord = bagOrder(sort, junkl)
	st.ord = ord
	if cols < 4 then cols = 4 end
	local avail = w - 8 - 8
	local s = avail / (10 * 46)      -- echelle fixe (10 colonnes de 44 px) : taille et colonnes se voient
	if s > 1 then s = 1 end
	local cs = floor(size * s + 0.5)
	if cs < 8 then cs = 8 end
	local sp = floor(spc * s + 0.5)
	local fit = floor((avail + sp) / (cs + sp))
	if fit < 1 then fit = 1 end
	if cols > fit then cols = fit end
	st.cols = cols
	local gw = cols * (cs + sp) - sp
	local ww = gw + 8
	if ww < 150 then ww = 150 end
	local win = st.win
	-- entete : titre, tri, recherche
	local y = 4
	putText(win.title, win, 5, y + 2, 10, L("msg.bags.title.bag"))
	win.title:SetWidth(60)
	putText(win.sortt, win, 50, y + 3, 9, L("mod.preview.sort", L("choice.bags.sort." .. sort)))
	win.sortt:SetWidth(ww * 0.4)
	local sbw = floor(ww * 0.3)
	P.Fill(win.sb, T.c.inset, srch and 1 or 0.3)
	P.Box(win.sb, win, ww - sbw - 4, y, sbw, 14)
	putText(win.st, win, ww - sbw, y + 2, 9, L("mod.preview.bags.search"))
	win.st:SetWidth(sbw - 6)
	tcol(win.st, T.c.dim, srch and 1 or 0.3)
	local hy = y
	y = y + 18
	-- filtres
	local fy = y
	for i = 1, 4 do
		local tb = st.tabs[i]
		P.Fill(tb.b, i == 1 and T.c.panel or T.c.inset, filt and 1 or 0.3)
		P.Box(tb.b, win, 4 + (i - 1) * 38, y, 36, 12)
		putText(tb.t, win, 4 + (i - 1) * 38, y + 2, 8, L("mod.preview.bags.f." .. i))
		tb.t:SetWidth(36)
		tcol(tb.t, T.c.text, filt and 1 or 0.3)
	end
	y = y + 16
	-- grille (ou sections par categorie)
	local gy0 = y
	local n = 0
	local nslots = 32
	local rowsTot = 0
	for i = 1, NSLOT do st.cells[i]:Hide() end
	local function place(idx, x, yy, filled)
		local c = st.cells[idx]
		local itm = ord[filled]
		local q = itm and BQ[itm] or nil
		c:SetWidth(cs)
		c:SetHeight(cs)
		local er, eg, eb = T.c.border[1], T.c.border[2], T.c.border[3]
		if q and useQ and q >= limit then er, eg, eb = qualityRGB(q) end
		c.edge:SetVertexColor(er, eg, eb, 1)
		P.Box(c.edge, c, 0, 0, cs, cs)
		P.Fill(c.bg, T.c.inset, 1)
		P.Box(c.bg, c, 1, 1, cs - 2, cs - 2)
		if q then
			if q == 0 then
				P.Fill(c.ic, T.c.dim, 0.5)
			else
				local ar, ag, ab = T.Accent()
				c.ic:SetVertexColor(ar, ag, ab, 0.55)
			end
			P.Box(c.ic, c, 2, 2, cs - 4, cs - 4)
		else
			c.ic:Hide()
		end
		if q and cnt and BCNT[itm] and cs >= 14 then
			putText(c.cn, c, 1, cs - 11, 9, tostring(BCNT[itm]))
			c.cn:SetWidth(cs - 3)
		else
			c.cn:Hide()
		end
		P.Place(c, win, x, yy, cs, cs)
		c:Show()
		c.item, c.px, c.py = itm, x, yy
	end
	local firstQ, firstB, firstC, firstJ
	if cats then
		local idx = 0
		local filled = 0
		for g = 1, 4 do
			putText(st.heads[g], win, 4, y, 9, L("mod.preview.bags.c." .. g))
			st.heads[g]:SetWidth(120)
			y = y + 12
			local gn = BCATN[g]
			for k = 1, gn do
				local row = floor((k - 1) / cols)
				local col = (k - 1) - row * cols
				idx = idx + 1
				filled = filled + 1
				place(idx, 4 + col * (cs + sp), y + row * (cs + sp), filled)
			end
			y = y + (floor((gn - 1) / cols) + 1) * (cs + sp) + 2
		end
		n = idx
	else
		for g = 1, 4 do st.heads[g]:Hide() end
		for i = 1, nslots do
			local row = floor((i - 1) / cols)
			local col = (i - 1) - row * cols
			place(i, 4 + col * (cs + sp), y + row * (cs + sp), i)
		end
		n = nslots
		y = y + (floor((nslots - 1) / cols) + 1) * (cs + sp)
	end
	local gh = y - gy0
	-- pied : emplacements, valeur, cles
	y = y + 2
	putText(win.slots, win, 5, y + 1, 9, "26 / 32")
	win.slots:SetWidth(60)
	putText(win.money, win, ww - 4 - 90, y + 1, 9, L("mod.preview.bags.money"))
	win.money:SetWidth(90)
	if not val then win.money:Hide() end
	P.Fill(win.kb, T.c.panel, ring and 1 or 0.3)
	P.Box(win.kb, win, floor(ww / 2) - 20, y, 40, 12)
	putText(win.kt, win, floor(ww / 2) - 20, y + 2, 8, L("mod.preview.bags.keys"))
	win.kt:SetWidth(40)
	tcol(win.kt, T.c.text, ring and 1 or 0.3)
	y = y + 16
	paintPanel(win, ww, y, T.c.bg, 1)
	P.Place(win, root, 4, 4, ww, y)
	-- zones (coordonnees de la racine = fenetre + 4)
	zp(st, root, "grid", 8, 4 + gy0, gw, gh)
	local function cellAt(num2)
		for i = 1, n do
			if st.cells[i].item == num2 then return st.cells[i] end
		end
		return nil
	end
	-- 1re cellule = taille ; 1er objet de qualite 4 = qualite ; 1er de qualite = limite ; objet empile = compteur ; gris = junk
	local function cz(id, itm)
		local c = cellAt(itm)
		if c then
			zp(st, root, id, 4 + c.px, 4 + c.py, cs, cs)
		else
			zh(st, id)
		end
	end
	cz("cell1", ord[1])
	cz("qual", 1)
	cz("border", 4)
	cz("count", 5)
	cz("junk", 11)
	zp(st, root, "sort", 4 + 50, 4 + hy + 1, floor(ww * 0.4), 13)
	zp(st, root, "search", 4 + ww - sbw - 4, 4 + hy, sbw, 14)
	zp(st, root, "filters", 4 + 4, 4 + fy, 4 * 38 - 2, 12)
	zp(st, root, "value", 4 + ww - 94, 4 + y - 15, 90, 12)
	zp(st, root, "keyring", 4 + floor(ww / 2) - 20, 4 + y - 16, 40, 12)
	if catOpt then zp(st, root, "cats", 8, 4 + gy0, 120, 12) else zh(st, "cats") end
	hintAt(st, root, y + 8, w, "mod.preview.bags.hint")
end

local BK = { grid = "bags.columns", cell1 = "bags.size", qual = "bags.quality", border = "bags.borderlimit", count = "bags.counts", junk = "bags.junklast",
	sort = "bags.sort", search = "bags.search", filters = "bags.filters", value = "bags.value", keyring = "bags.keyring", cats = "bags.categories" }
local function bagsClick(zone)
	if zone == "cats" and not P.FindOption("bags.categories") then return nil end      -- option livree par le module des sacs
	return BK[zone]
end
P.Register("bags", { watch = { "bags." }, build = bagsBuild, update = bagsUpdate, click = bagsClick })

-- NOTES (apercus des modules) - NON VERIFIE EN JEU : (a) le minimap rond est dessine par bandes de textures unies (aucune ressource du jeu) ;
-- (b) les reglages d'aspect <module>.shape (castbar) et bags.categories ne sont lus que s'ils existent (livres par d'autres perimetres) ;
-- (c) les couleurs de qualite d'objet viennent de ITEM_QUALITY_COLORS (getglobal) avec repli sur les jetons du style ; (d) un element coupe
-- reste dessine en grise (opacite reduite) ou garde sa zone cliquable, pour pouvoir le rallumer d'un clic.
-- NOTES - NON VERIFIE EN JEU (1.12) : (1) GetStringWidth juste apres SetText (positionnement des segments de la discussion) ; (2) la
-- taille reduite de police ; (3) les vraies cles d'options des barres d'action (actionbars.main.buttons / perrow, cdshade) lues en repli
-- sur des valeurs d'exemple si elles manquent. Contenus d'exemple fixes : noms, textes, valeurs.

-- ================================================================ ECRAN : mini-carte de la disposition reelle
-- Dessine l'ecran entier et la position REELLE de chaque cadre enregistre (Layout.Rect) : joueur/cible, groupe,
-- raid, ennemis epingles, compteur, menace, marques, alarmes de boss, benedictions, minimap. Un clic sur un
-- cadre saute a sa categorie de reglages. Se redessine quand une disposition ou une position change.
local SCREEN_FRAMES = {
	{ key = "unit.player", label = "perso", cat = "units" },
	{ key = "unit.target", label = "cible", cat = "units" },
	{ key = "unit.targettarget", label = "c2", cat = "units" },
	{ key = "group", label = "groupe", cat = "group" },
	{ key = "group.enemies", label = "ennemis", cat = "group" },
	{ key = "raid", label = "raid", cat = "raid" },
	{ key = "meter.win1", label = "compteur", cat = "meter" },
	{ key = "threat.win", label = "menace", cat = "threat" },
	{ key = "marks.bar", label = "marques", cat = "marks" },
	{ key = "bossmods.win", label = "alarmes", cat = "bossmods" },
	{ key = "pp.win", label = "benes", cat = "pallypower" },
	{ key = "minimap", label = "minimap", cat = "minimap" },
	{ key = "chat.main", label = "chat", cat = "chat" },
	-- modules ajoutes aux presets (tout est maintenant place par les mises en page)
	{ key = "bags.window", label = "sacs", cat = "bags" },
	{ key = "bags.bank", label = "banque", cat = "bags" },
	{ key = "finder.win", label = "chercheur", cat = "finder" },
	{ key = "tracker.win", label = "suivi", cat = "tracker" },
	{ key = "esport.win", label = "pvp", cat = "esport" },
	{ key = "totems.bar", label = "totems", cat = "totems" },
	{ key = "tanktools.bar", label = "tank", cat = "tanktools" },
	{ key = "powerauras.banner", label = "auras", cat = "powerauras" },
	{ key = "messages.win", label = "messages", cat = "messages" },
	{ key = "items", label = "bijoux", cat = "items" },
	{ key = "hud", label = "hud", cat = "raid" },
	{ key = "bossmods.msg", label = "annonce", cat = "bossmods" },
}

local function screenBuild(parent, w, h)
	local root = CreateFrame("Frame", nil, parent)
	root.st = { boxes = {} }
	root.bg = root:CreateTexture(nil, "BACKGROUND")
	root.bg:SetTexture(T.tex.white)
	root.bg:SetAllPoints(root)
	root.bg:SetVertexColor(T.c.bg[1], T.c.bg[2], T.c.bg[3], 0.5)
	for i = 1, getn(SCREEN_FRAMES) do
		local d = SCREEN_FRAMES[i]
		local box = CreateFrame("Frame", nil, root)
		box:SetBackdrop({ bgFile = T.tex.white, edgeFile = nil, tile = false })
		box.label = txt(box, 9, T.c.text, "CENTER", true)
		box.label:SetAllPoints(box)
		box.label:SetText(d.label)
		box.cat = d.cat
		box.key = d.key
		root.st.boxes[i] = box
		local z = P.Zone(root, "f" .. i, 4)
		z:SetAllPoints(box)
	end
	return root
end

local function screenUpdate(root, w, h)
	local st = root.st
	local ar, ag, ab = T.Accent()
	for i = 1, getn(SCREEN_FRAMES) do
		local d = SCREEN_FRAMES[i]
		local box = st.boxes[i]
		local r = Layout and Layout.Rect and Layout.Rect(d.key)
		if r then
			local bl, bb = r[1] / w, r[2] / h          -- UIParent -> fraction (l, b en unites UIParent)
			local bw = (r[3] or 80) / w
			local bh = (r[4] or 20) / h
			box:ClearAllPoints()
			box:SetPoint("TOPLEFT", root, "TOPLEFT", floor(bl * w) + 2, -floor((1 - bb - bh) * h) - 2)
			box:SetWidth(mmax(14, floor(bw * w) - 4))
			box:SetHeight(mmax(8, floor(bh * h) - 4))
			box:SetBackdropColor(ar, ag, ab, 0.35)
			box.label:Show()
			box:Show()
		else
			box:Hide()
		end
	end
end

local function screenClick(zone)
	local _, _, n = string.find(zone, "^f(%d+)$")
	local i = tonumber(n)
	if i and SCREEN_FRAMES[i] then return "cat:" .. SCREEN_FRAMES[i].cat end
	return nil
end

P.Register("screen", { title = "mod.preview.screen.title", watch = { "layout.", "units.", "group.", "raid.", "meter.", "threat.", "marks.", "bossmods.", "chat.", "bags.", "messages.", "powerauras.", "tracker.", "finder.", "items.", "totems.", "tanktools.", "esport." },
	build = screenBuild, update = screenUpdate, click = screenClick })

