-- ShikiUI TooltipCompare : comparaison compacte avec l'objet equipe quand on survole un equipement en maintenant Maj (option
-- tooltip.compare ; tooltip.compareauto = sans Maj). Un petit cadre colle a l'infobulle liste SEULEMENT les differences (vert = gain,
-- rouge = perte) avec l'equivalence entre pourcentages et caracteristiques : par exemple +1% de critique vaut environ 20 d'agilite.
-- Les statistiques sont lues dans le texte des infobulles (anglais et francais), jamais dans une base de donnees : un texte inconnu
-- est simplement ignore. Cout : un OnUpdate enfant de GameTooltip (il ne tourne que pendant qu'une infobulle est visible) ; les
-- lectures sont mises en cache par lien. Appele par Mod_Tooltip (SUI.TooltipCompare.Show / Hide).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local C = SUI.Config

local K = {}
SUI.TooltipCompare = K

local getn, tinsert = table.getn, table.insert
local strfind, strlower, strsub = string.find, string.lower, string.sub
local floor = math.floor

-- ordre d'affichage des statistiques
K.ORDER = { "armor", "str", "agi", "sta", "int", "spi", "ap", "sp", "heal", "mp5", "crit", "hit", "scrit", "shit", "dodge", "parry", "block", "dps" }
K.PCT = { crit = true, hit = true, scrit = true, shit = true, dodge = true, parry = true, block = true }

-- caracteristiques pour 1% (approximation niveau 60, a titre indicatif)
K.AGI_PER_CRIT = { WARRIOR = 20, PALADIN = 20, DRUID = 20, SHAMAN = 20, ROGUE = 29, HUNTER = 53, MAGE = 20, WARLOCK = 20, PRIEST = 20 }
K.INT_PER_SCRIT = 59

-- emplacement(s) d'equipement par type d'objet
K.SLOTS = { INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 },
	INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
	INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 },
	INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 } }

local function num(s)
	if not s then return nil end
	s = string.gsub(s, ",", ".")
	return tonumber(s)
end

local PRIMARY = { { "^strength", "str" }, { "^force", "str" }, { "^agilit", "agi" }, { "^stamina", "sta" }, { "^endurance", "sta" },
	{ "^intellect", "int" }, { "^intelligence", "int" }, { "^spirit", "spi" }, { "^esprit", "spi" } }
local SCHOOLS = { "fire", "frost", "shadow", "holy", "nature", "arcane", "feu", "givre", "ombre", "sacr", "arcan" }

local function hasAny(s, list)
	local i
	for i = 1, getn(list) do
		if strfind(s, list[i], 1, true) then return true end
	end
	return false
end

-- Lit les lignes d'une infobulle (liste de textes) -> table de statistiques { str = n, crit = 1.0, ... }
function K.Parse(lines)
	local st = {}
	local i
	for i = 1, getn(lines) do
		local raw = lines[i]
		if type(raw) == "string" and raw ~= "" then
			local s = strlower(raw)
			local _, _, v, name = strfind(s, "^%+(%d+) (.+)$")
			local done = false
			if v then
				local p
				for p = 1, getn(PRIMARY) do
					if strfind(name, PRIMARY[p][1]) then
						st[PRIMARY[p][2]] = (st[PRIMARY[p][2]] or 0) + tonumber(v)
						done = true
						break
					end
				end
			end
			if not done then
				local _, _, a = strfind(s, "^(%d+) arm")
				if a then
					st.armor = tonumber(a)
					done = true
				end
			end
			if not done then
				local _, _, d = strfind(s, "%(([%d%.,]+) [^%)]*sec[^%)]*%)")
				if d and (strfind(s, "damage", 1, true) or strfind(s, "par seconde", 1, true)) then
					st.dps = num(d)
					done = true
				end
			end
			if not done and (strfind(s, "^equip") or strfind(s, "^\195\169quip") or strfind(s, "^\195\137quip")) and strfind(s, ":", 1, true) then
				-- ligne "Equip :" / "Equipe :" : on cherche le mot-cle puis le nombre
				local _, _, pct = strfind(s, "([%d%.,]+)%%")
				local _, _, n1 = strfind(s, "(%d+)")
				local spell = strfind(s, "spell", 1, true) or strfind(s, "sort", 1, true)
				if pct and (strfind(s, "critical", 1, true) or strfind(s, "critique", 1, true)) then
					st[spell and "scrit" or "crit"] = (st[spell and "scrit" or "crit"] or 0) + num(pct)
				elseif pct and (strfind(s, "to hit", 1, true) or strfind(s, "toucher", 1, true)) then
					st[spell and "shit" or "hit"] = (st[spell and "shit" or "hit"] or 0) + num(pct)
				elseif pct and (strfind(s, "dodge", 1, true) or strfind(s, "esquiv", 1, true)) then
					st.dodge = (st.dodge or 0) + num(pct)
				elseif pct and (strfind(s, "parry", 1, true) or strfind(s, "parade", 1, true)) then
					st.parry = (st.parry or 0) + num(pct)
				elseif pct and (strfind(s, "block", 1, true) or strfind(s, "bloqu", 1, true)) then
					st.block = (st.block or 0) + num(pct)
				elseif n1 and strfind(s, "5 sec", 1, true) and strfind(s, "mana", 1, true) then
					st.mp5 = (st.mp5 or 0) + tonumber(n1)
				elseif n1 and (strfind(s, "attack power", 1, true) or strfind(s, "puissance d", 1, true))
					and not strfind(s, "ranged", 1, true) and not strfind(s, "distance", 1, true)
					and not strfind(s, "fighting", 1, true) and not strfind(s, "contre", 1, true) then
					st.ap = (st.ap or 0) + tonumber(n1)
				elseif n1 and not hasAny(s, SCHOOLS) and (strfind(s, "healing", 1, true) or strfind(s, "soins", 1, true)) then
					st.heal = (st.heal or 0) + tonumber(n1)
					if strfind(s, "damage", 1, true) or strfind(s, "d.g.ts") then st.sp = (st.sp or 0) + tonumber(n1) end
				elseif n1 and not hasAny(s, SCHOOLS) and (strfind(s, "damage", 1, true) or strfind(s, "d.g.ts"))
					and (strfind(s, "spells", 1, true) or strfind(s, "sorts", 1, true)) then
					st.sp = (st.sp or 0) + tonumber(n1)
				end
			end
		end
	end
	return st
end

-- Differences nouvelle - equipee : liste ordonnee { cle, delta }
function K.Delta(new, old)
	local out = {}
	local i
	for i = 1, getn(K.ORDER) do
		local k = K.ORDER[i]
		local d = (new[k] or 0) - (old[k] or 0)
		if d > 0.049 or d < -0.049 then tinsert(out, { k, d }) end
	end
	return out
end

-- Equivalence indicative : texte entre parentheses ou nil
function K.Equiv(key, delta, class)
	local a = delta < 0 and -delta or delta
	local sign = delta < 0 and "-" or "+"
	if key == "crit" then
		return L("msg.tooltip.cmp.eq.agi", sign, floor(a * (K.AGI_PER_CRIT[class or ""] or 20) + 0.5))
	elseif key == "agi" then
		local per = K.AGI_PER_CRIT[class or ""] or 20
		return L("msg.tooltip.cmp.eq.crit", sign, floor(a / per * 10 + 0.5) / 10)
	elseif key == "scrit" then
		return L("msg.tooltip.cmp.eq.int", sign, floor(a * K.INT_PER_SCRIT + 0.5))
	elseif key == "int" then
		return L("msg.tooltip.cmp.eq.scrit", sign, floor(a / K.INT_PER_SCRIT * 10 + 0.5) / 10)
	end
	return nil
end

-- ---------------------------------------------------------------- lecture des infobulles
local cache = {}

function K.Scanner()
	if K.scan then return K.scan end
	if not CreateFrame then return nil end
	local ok, f = pcall(CreateFrame, "GameTooltip", "ShikiUI_CmpScan", UIParent, "GameTooltipTemplate")
	if not ok or not f then return nil end
	K.scan = f
	return f
end

local function readLines(tip)
	local out = {}
	local n = tip:NumLines() or 0
	local i
	for i = 1, n do
		local fs = getglobal("ShikiUI_CmpScanTextLeft" .. i)
		out[i] = fs and fs:GetText() or ""
	end
	return out
end

function K.StatsOfLink(link)
	if not link then return nil end
	if cache[link] then return cache[link] end
	local tip = K.Scanner()
	if not tip then return nil end
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	tip:ClearLines()
	tip:SetHyperlink(link)
	local st = K.Parse(readLines(tip))
	tip:Hide()
	cache[link] = st
	return st
end

function K.StatsOfSlot(slot)
	local tip = K.Scanner()
	if not tip then return nil end
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	tip:ClearLines()
	tip:SetInventoryItem("player", slot)
	local st = K.Parse(readLines(tip))
	tip:Hide()
	return st
end

-- Emplacement a comparer pour un type d'objet : le plus faible des deux pour les doubles (bagues, bijoux, armes a une main)
function K.PickSlot(equipLoc)
	local list = K.SLOTS[equipLoc or ""]
	if not list then return nil end
	if getn(list) == 1 then return list[1] end
	local best, bestLv
	local i
	for i = 1, getn(list) do
		local link = GetInventoryItemLink("player", list[i])
		if not link then return list[i] end
		local _, _, _, lv = GetItemInfo(link)
		lv = lv or 0
		if not bestLv or lv < bestLv then
			best, bestLv = list[i], lv
		end
	end
	return best
end

-- ---------------------------------------------------------------- cadre
local MAXROWS = 12

function K.Build()
	if K.frame then return K.frame end
	local f = T.Panel(UIParent, 190, 60)
	f:SetFrameStrata("TOOLTIP")
	f:Hide()
	f.title = T.Text(f, 11, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
	f.title:SetWidth(178)
	f.rows = {}
	local i
	for i = 1, MAXROWS do
		local r = T.Text(f, 11, T.c.text, "LEFT")
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -(22 + (i - 1) * 13))
		r:SetWidth(178)
		r:Hide()
		f.rows[i] = r
	end
	K.frame = f
	return f
end

local function setColor(fs, c)
	if fs.SetTextColor then fs:SetTextColor(c[1], c[2], c[3], 1) end
end

-- Montre la comparaison de l'objet du lien avec l'objet equipe
function K.Show(link)
	if not link or not K.on then return end
	local _, _, q, lv, _, _, _, _, equipLoc = GetItemInfo(link)
	local slot = K.PickSlot(equipLoc)
	if not slot then
		K.Hide()
		return
	end
	local cur = GetInventoryItemLink("player", slot)
	if not cur or cur == link then
		K.Hide()
		return
	end
	local key = link .. "|" .. cur
	if K.shownKey == key and K.frame and K.frame:IsShown() then return end
	local new = K.StatsOfLink(link)
	local old = K.StatsOfSlot(slot)
	if not new or not old then return end
	local f = K.Build()
	local cname, _, cq = GetItemInfo(cur)
	f.title:SetText(L("msg.tooltip.cmp.title", cname or "?"))
	local qc = getglobal("ITEM_QUALITY_COLORS")
	local col = qc and cq and qc[cq]
	if col then f.title:SetTextColor(col.r, col.g, col.b, 1) else setColor(f.title, T.c.text) end    -- style:ok couleur de qualite (donnee de jeu)
	local _, class = UnitClass("player")
	local d = K.Delta(new, old)
	local n = getn(d)
	if n > MAXROWS then n = MAXROWS end
	local i
	for i = 1, MAXROWS do f.rows[i]:Hide() end
	if n == 0 then
		f.rows[1]:SetText(L("msg.tooltip.cmp.same"))
		setColor(f.rows[1], T.c.dim)
		f.rows[1]:Show()
		n = 1
	else
		for i = 1, n do
			local k, v = d[i][1], d[i][2]
			local txt
			if K.PCT[k] then
				txt = (v > 0 and "+" or "") .. (floor(v * 10 + 0.5) / 10) .. "% " .. L("msg.tooltip.cmp.stat." .. k)
			else
				txt = (v > 0 and "+" or "") .. floor(v * 10 + 0.5) / 10 .. " " .. L("msg.tooltip.cmp.stat." .. k)
			end
			local eq = K.Equiv(k, v, class)
			if eq then txt = txt .. "  " .. eq end
			f.rows[i]:SetText(txt)
			setColor(f.rows[i], v > 0 and T.c.good or T.c.bad)
			f.rows[i]:Show()
		end
	end
	f:SetHeight(26 + n * 13)
	f:ClearAllPoints()
	local gt = GameTooltip
	local right = gt:GetRight() or 0
	if right + 195 > (GetScreenWidth() or 1024) / (UIParent:GetScale() or 1) then
		f:SetPoint("TOPRIGHT", gt, "TOPLEFT", -2, 0)
	else
		f:SetPoint("TOPLEFT", gt, "TOPRIGHT", 2, 0)
	end
	f:Show()
	K.shownKey = key
end

function K.Hide()
	K.shownKey = nil
	if K.frame then K.frame:Hide() end
end

-- Surveille Maj tant que l'infobulle d'un objet est visible (enfant de GameTooltip : ne tourne que si elle est affichee)
function K.Watch()
	if K.watch or not getglobal("GameTooltip") then return end
	local w = CreateFrame("Frame", "ShikiUI_TooltipCmpWatch", GameTooltip)
	w.t = 0
	w:SetScript("OnUpdate", function()
		this.t = this.t + (arg1 or 0)
		if this.t < 0.12 then return end
		this.t = 0
		local link = SUI.Tooltip and SUI.Tooltip.link
		if not K.on or not link then
			K.Hide()
			return
		end
		if IsShiftKeyDown() or K.auto then K.Show(link) else K.Hide() end
	end)
	w:SetScript("OnHide", K.Hide)
	K.watch = w
end

function K.Apply()
	K.on = C.Get("tooltip.compare") and true or false
	K.auto = C.Get("tooltip.compareauto") and true or false
	if K.on then K.Watch() else K.Hide() end
end
