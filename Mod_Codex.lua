-- ShikiUI Codex : guide des donjons (butin par boss) et recherche d'objets / de quetes, dans UNE fenetre.
-- Aucune donnee propre : le butin vient d'Atlas-CFM (AtlasCFM.InstanceData, charge a la demande avec Atlas-CFM_Core), les noms et les quetes
-- de pfQuest (pfDB, deja en memoire). Fenetre construite a la premiere ouverture seulement ; fermee, elle ne coute rien (pas d'OnUpdate,
-- pas d'evenement ecoute sauf le debut de combat). L'index de recherche est prepare par petits paquets a l'ouverture de la recherche et libere
-- a la fermeture. Commande : /sui codex [texte].
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert, tsort = table.getn, table.insert, table.sort
local slower, sfind, sformat, ssub, slen = string.lower, string.find, string.format, string.sub, string.len
local floor = math.floor

local M = {}
SUI.Codex = M

M.on = false
M.NROWS = 18                 -- lignes visibles par colonne
M.RH = 18                    -- pas entre deux lignes
M.W, M.H = 650, 420
M.CHUNK = 4                  -- instances indexees par tour de minuterie
M.tab = "inst"
M.sel = { inst = nil, boss = nil }
M.off = { inst = 0, boss = 0, loot = 0, res = 0 }
M.insts = nil                -- liste triee des donjons (construite a la demande)
M.bosses, M.loots, M.res = {}, {}, {}
M.bcache = {}                -- boss visibles par donjon (vide a chaque ouverture)
M.ix = nil                   -- index de recherche : listes paralleles id / nom en minuscules / donjon / boss

-- ---------------------------------------------------------------- acces aux donnees (Atlas-CFM, pfQuest)
local function glob(name)
	return getglobal(name)
end

-- Donnees de butin pretes ? Charge Atlas-CFM_Core s'il le faut (chargement a la demande, une seule fois).
function M.AtlasReady()
	local a = glob("AtlasCFM")
	if a and a.InstanceData then return true end
	local la = glob("LoadAddOn")
	if la then pcall(la, "Atlas-CFM_Core") end
	a = glob("AtlasCFM")
	return (a and a.InstanceData) and true or false
end

function M.PfReady()
	local db = glob("pfDB")
	return (db and type(db["quests"]) == "table" and type(db["items"]) == "table") and true or false
end

-- Entree visible sur ce serveur ? (meme filtre qu'Atlas-CFM, donc memes listes)
local function visible(entry)
	local a = glob("AtlasCFM")
	if a and a.Server and a.Server.IsVisible then
		local ok, v = pcall(a.Server.IsVisible, entry)
		if ok then return v and true or false end
	end
	return true
end

-- Table pfDB[kind] dans la langue du client, sinon en anglais.
local function pfTable(kind)
	local db = glob("pfDB")
	local k = db and db[kind]
	if type(k) ~= "table" then return nil end
	local lc = GetLocale and GetLocale() or "enUS"
	if type(k[lc]) == "table" then return k[lc] end
	return k["enUS"]
end

-- Niveau d'un donjon : nombre (raids : 60) ou table { min, max } (donjons : { 19, 32 }). Retourne (min, max).
local function levelRange(v)
	if type(v) == "table" then
		local lo = tonumber(v[1]) or 0
		return lo, tonumber(v[2]) or lo
	end
	local n = tonumber(v) or 0
	return n, n
end

-- Table de butin d'un boss. Atlas-CFM convertit ses listes "loot" en "items" au chargement puis efface "loot" ; une valeur texte est
-- une cle de AtlasCFMLoot_Data. Retourne la table de butin ou nil.
local function lootTable(b)
	local v = b.items
	if v == nil then v = b.loot end
	if type(v) == "string" then
		local pages = glob("AtlasCFMLoot_Data")
		v = type(pages) == "table" and pages[v] or nil
	end
	if type(v) == "table" and getn(v) > 0 then return v end
	return nil
end

-- Liste des donjons : { key, name, lvl, hi, acr, max }, triee par niveau puis par nom. Seuls ceux qui ont du butin sont listes
-- (Atlas-CFM garde aussi des cartes d'information, des entrees et des champs de bataille sans butin).
function M.Instances()
	if M.insts then return M.insts end
	local list = {}
	local a = glob("AtlasCFM")
	local data = a and a.InstanceData
	if type(data) == "table" then
		local min = C.Get("codex.minlevel") or 0
		for key, d in pairs(data) do
			if type(d) == "table" and type(d.Bosses) == "table" and visible(d) then
				local lo, hi = levelRange(d.Level)
				if hi >= min and getn(M.Bosses(key)) > 0 then
					tinsert(list, { key = key, name = tostring(d.Name or key), lvl = lo, hi = hi, acr = d.Acronym, max = d.MaxPlayers })
				end
			end
		end
	end
	tsort(list, function(x, y)
		if x.lvl ~= y.lvl then return x.lvl < y.lvl end
		return x.name < y.name
	end)
	M.insts = list
	return list
end

function M.InstData(key)
	local a = glob("AtlasCFM")
	return a and a.InstanceData and a.InstanceData[key]
end

-- Boss visibles d'un donjon : { name, loot (table de butin), rate }.
function M.Bosses(key)
	if M.bcache[key] then return M.bcache[key] end
	local out = {}
	M.bcache[key] = out
	local d = M.InstData(key)
	if type(d) ~= "table" or type(d.Bosses) ~= "table" then return out end
	for i = 1, getn(d.Bosses) do
		local b = d.Bosses[i]
		if type(b) == "table" and visible(b) then
			local lt = lootTable(b)
			if lt then
				tinsert(out, { name = tostring(b.name or b.id or i), loot = lt, rate = b.defaults and b.defaults.dropRate })
			end
		end
	end
	return out
end

-- Butin visible d'un boss : { id, rate } (rate : nombre, ou texte comme ".2-10").
function M.Loot(boss)
	local out = {}
	if not boss then return out end
	for i = 1, getn(boss.loot) do
		local e = boss.loot[i]
		if type(e) == "table" and type(e.id) == "number" and visible(e) then
			local r = e.dropRate
			if r == nil then r = boss.rate end
			if type(r) ~= "number" and type(r) ~= "string" then r = nil end
			tinsert(out, { id = e.id, rate = r })
		end
	end
	return out
end

-- Taux affiche : entier tel quel, fraction avec ses decimales (0.25), texte tel quel (.2-10).
function M.RateText(r)
	if type(r) == "number" then
		if r == floor(r) then return floor(r) .. "%" end
		return sformat("%g", floor(r * 100 + 0.5) / 100) .. "%"
	end
	if type(r) == "string" then return r .. "%" end
	return ""
end

-- Niveau affiche : "60" ou "19-32".
function M.LevelText(it)
	if it.hi and it.hi ~= it.lvl then return it.lvl .. "-" .. it.hi end
	return tostring(it.lvl)
end

function M.ItemName(id)
	local n = GetItemInfo and GetItemInfo(id)
	if n then return n end
	local t = pfTable("items")
	if t and t[id] then return t[id] end
	return "#" .. id
end

function M.ItemQuality(id)
	if not GetItemInfo then return nil end
	local _, _, q = GetItemInfo(id)
	return q
end

function M.ItemIcon(id)
	if not GetItemInfo then return nil end
	local _, _, _, _, _, _, _, _, tex = GetItemInfo(id)
	return tex
end

-- ---------------------------------------------------------------- recherche
-- Index (objets des donjons) construit par paquets, pour ne jamais bloquer l'image.
function M.StartIndex()
	if M.ix and M.ix.done then return end
	if M.ixTask then return end
	if not M.AtlasReady() then
		M.ix = { id = {}, name = {}, inst = {}, boss = {}, n = 0, done = true }
		return
	end
	M.ix = { id = {}, name = {}, inst = {}, boss = {}, n = 0, done = false, at = 0 }
	M.ixTask = SUI.Every(0.03, M.IndexStep, "codex.index")
end

function M.IndexStep()
	local ix = M.ix
	local insts = M.Instances()
	if not ix or ix.done then
		SUI.Cancel(M.ixTask)
		M.ixTask = nil
		return
	end
	local last = ix.at + M.CHUNK
	while ix.at < last and ix.at < getn(insts) do
		ix.at = ix.at + 1
		local bl = M.Bosses(insts[ix.at].key)
		for b = 1, getn(bl) do
			local lt = M.Loot(bl[b])
			for k = 1, getn(lt) do
				ix.n = ix.n + 1
				ix.id[ix.n] = lt[k].id
				ix.name[ix.n] = slower(M.ItemName(lt[k].id))
				ix.inst[ix.n] = ix.at
				ix.boss[ix.n] = b
			end
		end
	end
	if ix.at >= getn(insts) then
		ix.done = true
		SUI.Cancel(M.ixTask)
		M.ixTask = nil
		if M.pending then M.DoSearch(M.pending) end
	end
	if M.win and M.tab == "search" then M.PaintStatus() end
end

function M.ReleaseIndex()
	if M.ixTask then SUI.Cancel(M.ixTask) end
	M.ixTask = nil
	M.ix = nil
	M.pending = nil
end

function M.MaxResults()
	return C.Get("codex.maxresults") or 40
end

-- Resultats pour un texte : objets des donjons d'abord, puis quetes (pfQuest).
function M.DoSearch(text)
	local res = {}
	M.res = res
	M.pending = nil
	text = slower(text or "")
	if slen(text) < 2 then
		M.off.res = 0
		if M.win then M.Paint() end
		return res
	end
	local cap = M.MaxResults()
	local ix = M.ix
	M.more = false
	if ix then
		local seen = {}
		for i = 1, ix.n do
			if sfind(ix.name[i], text, 1, true) then
				local key = ix.id[i] .. ":" .. ix.inst[i] .. ":" .. ix.boss[i]
				if not seen[key] then
					if getn(res) >= cap then
						M.more = true
						break
					end
					seen[key] = true
					tinsert(res, { kind = "item", id = ix.id[i], inst = ix.inst[i], boss = ix.boss[i] })
				end
			end
		end
	end
	local qt = pfTable("quests")
	local qd = glob("pfDB") and glob("pfDB")["quests"] and glob("pfDB")["quests"]["data"]
	if qt then
		local hits = {}
		for id, q in pairs(qt) do
			local title = type(q) == "table" and q["T"]
			if title and sfind(slower(title), text, 1, true) then tinsert(hits, id) end
		end
		tsort(hits, function(x, y)
			local tx, ty = slower(qt[x]["T"]), slower(qt[y]["T"])
			if tx ~= ty then return tx < ty end
			return x < y
		end)
		if getn(hits) > cap then M.more = true end
		for k = 1, getn(hits) do
			if k > cap then break end
			local id = hits[k]
			local d = qd and qd[id]
			tinsert(res, { kind = "quest", id = id, title = qt[id]["T"], lvl = d and d["lvl"], min = d and d["min"] })
		end
	end
	M.off.res = 0
	if M.win then M.Paint() end
	return res
end

function M.Search(text)
	if not M.ix or not M.ix.done then
		M.pending = text
		M.StartIndex()
		if M.ix and M.ix.done then M.DoSearch(text) end
		return
	end
	M.DoSearch(text)
end

-- Debut de la quete : nom du PNJ / objet / objet de depart.
function M.QuestStart(id)
	local db = glob("pfDB")
	local d = db and db["quests"] and db["quests"]["data"] and db["quests"]["data"][id]
	local st = d and d["start"]
	if type(st) ~= "table" then return L("msg.codex.unknown") end
	local kinds = { { "U", "units" }, { "O", "objects" }, { "I", "items" } }
	for i = 1, getn(kinds) do
		local list = st[kinds[i][1]]
		if type(list) == "table" and list[1] then
			local t = pfTable(kinds[i][2])
			local n = t and t[list[1]]
			if n then return tostring(n) end
		end
	end
	return L("msg.codex.unknown")
end

function M.QuestInfo(r)
	SUI.Print(L("msg.codex.questinfo", r.title, tostring(r.lvl or "?"), tostring(r.min or "?"), M.QuestStart(r.id)))
end

-- ---------------------------------------------------------------- navigation
local function clamp(col, count)
	local max = count - M.NROWS
	if max < 0 then max = 0 end
	if M.off[col] > max then M.off[col] = max end
	if M.off[col] < 0 then M.off[col] = 0 end
end

function M.SelectInst(i)
	local insts = M.Instances()
	local it = insts[i]
	M.sel.inst = i
	M.sel.boss = nil
	M.off.boss, M.off.loot = 0, 0
	M.bosses = it and M.Bosses(it.key) or {}
	if M.bosses[1] then M.SelectBoss(1) else M.loots = {} end
end

function M.SelectBoss(i)
	M.sel.boss = i
	M.sel.item = nil
	M.off.loot = 0
	M.loots = M.Loot(M.bosses[i])
end

-- Aller a un objet trouve : onglet Donjons, donjon et boss choisis, listes defilees pour montrer la selection.
function M.GoTo(inst, boss, item)
	M.tab = "inst"
	M.SelectInst(inst)
	if boss then M.SelectBoss(boss) end
	if item then
		M.sel.item = item
		for k = 1, getn(M.loots) do
			if M.loots[k].id == item then
				M.off.loot = k - 1
				break
			end
		end
		clamp("loot", getn(M.loots))
	end
	M.off.inst = inst - 1
	clamp("inst", getn(M.Instances()))
	M.off.boss = (boss or 1) - 1
	clamp("boss", getn(M.bosses))
	if M.win then M.Paint() end
end

function M.Wheel(col, delta)
	local count = 0
	if col == "inst" then count = getn(M.Instances())
	elseif col == "boss" then count = getn(M.bosses)
	elseif col == "loot" then count = getn(M.loots)
	else count = getn(M.res) end
	M.off[col] = M.off[col] - delta * 3
	clamp(col, count)
	M.Paint()
end

function M.LinkItem(id)
	if not GetItemInfo then return end
	local _, link = GetItemInfo(id)
	if not link then return end
	local ck, dress, sk = glob("IsControlKeyDown"), glob("DressUpItemLink"), glob("IsShiftKeyDown")
	if ck and ck() and dress then
		dress(link)
	elseif sk and sk() then
		local eb = glob("ChatFrameEditBox")
		if eb and eb:IsVisible() then eb:Insert(link) end
	end
end

-- ---------------------------------------------------------------- fenetre
function M.RowEnter(b)
	local r, g, bl = T.Accent()
	b:SetBackdropBorderColor(r, g, bl, 1)
	local id = b.itemId
	if id and GameTooltip then
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		if GetItemInfo and GetItemInfo(id) then
			GameTooltip:SetHyperlink("item:" .. id .. ":0:0:0")
		else
			GameTooltip:SetText(M.ItemName(id))
		end
		GameTooltip:Show()
	end
end

function M.QualityColor(b, id)
	local q = id and M.ItemQuality(id)
	local gq = glob("GetItemQualityColor")
	if q and gq then
		local r, g, bl = gq(q)
		b.label:SetTextColor(r, g, bl, 1)
	else
		b.label:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1)
	end
end

function M.RowLeave(b)
	T.SetSelected(b, b.selected)
	if b.itemId then M.QualityColor(b, b.itemId) end
	if GameTooltip then GameTooltip:Hide() end
end

function M.RowClick(b)
	local col, i = b.col, b.idx + M.off[b.col]
	if col == "inst" then
		M.SelectInst(i)
	elseif col == "boss" then
		M.SelectBoss(i)
	elseif col == "loot" then
		if M.loots[i] then M.LinkItem(M.loots[i].id) end
	else
		local r = M.res[i]
		if not r then return end
		if r.kind == "item" then
			M.GoTo(r.inst, r.boss, r.id)
		else
			M.QuestInfo(r)
		end
	end
	M.Paint()
end

function M.MakeRows(parent, col, x, y, w, withIcon, withRate)
	local rows = {}
	for i = 1, M.NROWS do
		local b = T.Button(parent, "", w, M.RH - 1, M.RowClick)
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - (i - 1) * M.RH)
		b.col, b.idx = col, i
		local lx = 4
		if withIcon then
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetWidth(M.RH - 3)
			b.icon:SetHeight(M.RH - 3)
			b.icon:SetPoint("LEFT", b, "LEFT", 2, 0)
			lx = M.RH + 1
		end
		b.label:ClearAllPoints()
		b.label:SetPoint("LEFT", b, "LEFT", lx, 0)
		b.label:SetWidth(w - lx - (withRate and 50 or 4))
		b.label:SetHeight(12)
		b.label:SetJustifyH("LEFT")
		if withRate then
			b.rate = T.Text(b, 10, T.c.dim, "RIGHT")
			b.rate:SetPoint("RIGHT", b, "RIGHT", -4, 0)
			b.rate:SetWidth(46)
		end
		b:EnableMouseWheel(true)
		b:SetScript("OnMouseWheel", function() M.Wheel(this.col, arg1) end)
		b:SetScript("OnEnter", function() M.RowEnter(this) end)
		b:SetScript("OnLeave", function() M.RowLeave(this) end)
		b:Hide()
		rows[i] = b
	end
	return rows
end

local function setRow(b, text, selected, itemId, rate)
	if not text then
		b:Hide()
		b.itemId = nil
		return
	end
	T.SetButtonText(b, text)
	T.SetSelected(b, selected)
	b.itemId = itemId
	if b.rate then b.rate:SetText(M.RateText(rate)) end
	if b.icon then
		if itemId then
			b.icon:SetTexture(M.ItemIcon(itemId) or "Interface\\Icons\\INV_Misc_QuestionMark")
			b.icon:Show()
		else
			b.icon:Hide()
		end
	end
	b:Show()
end

function M.PaintStatus()
	local w = M.win
	if not w then return end
	local txt = ""
	if M.tab == "inst" then
		if not M.AtlasReadyCached then txt = L("msg.codex.noatlas") else txt = L("msg.codex.hint") end
	else
		local ix = M.ix
		if ix and not ix.done then
			txt = L("msg.codex.indexing", ix.at or 0, getn(M.Instances()))
		elseif getn(M.res) > 0 then
			txt = L("msg.codex.results", getn(M.res))
			if M.more then txt = txt .. " " .. L("msg.codex.more") end
		elseif w.edit:GetText() ~= "" and slen(w.edit:GetText()) >= 2 then
			txt = L("msg.codex.noresult")
		else
			txt = L("msg.codex.search.hint")
		end
		if not M.PfReady() then txt = txt .. " " .. L("msg.codex.nopf") end
	end
	w.status:SetText(txt)
end

function M.Paint()
	local w = M.win
	if not w then return end
	local inst = M.tab == "inst"
	for i = 1, M.NROWS do
		w.rInst[i]:Hide() w.rBoss[i]:Hide() w.rLoot[i]:Hide() w.rRes[i]:Hide()
	end
	if inst then
		w.cInst:Show() w.cBoss:Show() w.cLoot:Show() w.edit:Hide() w.cRes:Hide()
		local insts = M.Instances()
		clamp("inst", getn(insts))
		clamp("boss", getn(M.bosses))
		clamp("loot", getn(M.loots))
		for i = 1, M.NROWS do
			local k = i + M.off.inst
			local it = insts[k]
			setRow(w.rInst[i], it and (it.name .. "  (" .. sformat(L("msg.codex.level"), M.LevelText(it)) .. ")") or nil, M.sel.inst == k)
			local bk = i + M.off.boss
			local bs = M.bosses[bk]
			setRow(w.rBoss[i], bs and bs.name or nil, M.sel.boss == bk)
			local lk = i + M.off.loot
			local lt = M.loots[lk]
			setRow(w.rLoot[i], lt and M.ItemName(lt.id) or nil, lt and lt.id == M.sel.item, lt and lt.id, lt and lt.rate)
			if lt then M.QualityColor(w.rLoot[i], lt.id) end
		end
	else
		w.cInst:Hide() w.cBoss:Hide() w.cLoot:Hide() w.edit:Show() w.cRes:Show()
		clamp("res", getn(M.res))
		local insts = M.Instances()
		for i = 1, M.NROWS do
			local r = M.res[i + M.off.res]
			if r then
				local txt
				if r.kind == "item" then
					local it = insts[r.inst]
					local bs = it and M.Bosses(it.key)[r.boss]
					txt = M.ItemName(r.id) .. "   -   " .. (bs and bs.name or "?") .. " (" .. (it and it.name or "?") .. ")"
				else
					txt = "[" .. L("msg.codex.quest") .. "] " .. r.title .. "  (" .. sformat(L("msg.codex.level"), tostring(r.lvl or "?")) .. ")"
				end
				setRow(w.rRes[i], txt, false, r.kind == "item" and r.id or nil)
				if r.kind == "item" then M.QualityColor(w.rRes[i], r.id) else w.rRes[i].label:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1) end
			else
				setRow(w.rRes[i], nil)
			end
		end
	end
	T.SetSelected(w.tabInst, inst)
	T.SetSelected(w.tabSearch, not inst)
	M.PaintStatus()
end

function M.SetTab(tab)
	M.tab = tab
	if tab == "search" then M.StartIndex() end
	M.Paint()
end

function M.OnSearchText()
	local e = this
	if M.searchTask then SUI.Cancel(M.searchTask) end
	local text = e:GetText()
	M.searchTask = SUI.After(0.35, function() M.Search(text) end, "codex.search")
end

function M.Build()
	if M.win then return end
	local f = CreateFrame("Frame", "ShikiUI_Codex", UIParent)
	f:SetWidth(M.W)
	f:SetHeight(M.H)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	T.Backdrop(f, T.c.panel, T.c.border)
	local w = { f = f }
	M.win = w

	w.title = T.Text(f, 14, T.c.text, "LEFT", true)
	w.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
	w.title:SetText(L("mod.codex.title"))
	w.close = T.Button(f, "x", 20, 20, function() M.Close() end)
	w.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
	w.tabInst = T.Button(f, L("msg.codex.tab.inst"), 90, 22, function() M.SetTab("inst") end)
	w.tabInst:SetPoint("TOPLEFT", f, "TOPLEFT", 90, -8)
	w.tabSearch = T.Button(f, L("msg.codex.tab.search"), 90, 22, function() M.SetTab("search") end)
	w.tabSearch:SetPoint("LEFT", w.tabInst, "RIGHT", 6, 0)

	local top = -66
	w.cInst = CreateFrame("Frame", nil, f)
	w.cInst:SetAllPoints(f)
	w.cBoss = CreateFrame("Frame", nil, f)
	w.cBoss:SetAllPoints(f)
	w.cLoot = CreateFrame("Frame", nil, f)
	w.cLoot:SetAllPoints(f)
	w.cRes = CreateFrame("Frame", nil, f)
	w.cRes:SetAllPoints(f)
	local h1 = T.Text(w.cInst, 11, T.c.dim, "LEFT")
	h1:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -44)
	h1:SetText(L("msg.codex.col.inst"))
	local h2 = T.Text(w.cBoss, 11, T.c.dim, "LEFT")
	h2:SetPoint("TOPLEFT", f, "TOPLEFT", 218, -44)
	h2:SetText(L("msg.codex.col.boss"))
	local h3 = T.Text(w.cLoot, 11, T.c.dim, "LEFT")
	h3:SetPoint("TOPLEFT", f, "TOPLEFT", 398, -44)
	h3:SetText(L("msg.codex.col.loot"))
	w.rInst = M.MakeRows(w.cInst, "inst", 12, top, 200, false, false)
	w.rBoss = M.MakeRows(w.cBoss, "boss", 218, top, 174, false, false)
	w.rLoot = M.MakeRows(w.cLoot, "loot", 398, top, 240, true, true)
	w.rRes = M.MakeRows(w.cRes, "res", 12, top, 626, true, false)

	w.edit = T.Edit(f, 300, 22)
	w.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -38)
	w.edit:SetScript("OnTextChanged", M.OnSearchText)
	w.edit:SetScript("OnEnterPressed", function() this:ClearFocus() M.Search(this:GetText()) end)
	w.edit:Hide()
	w.status = T.Text(f, 10, T.c.dim, "LEFT")
	w.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 8)
	w.status:SetWidth(M.W - 24)
	w.status:SetHeight(12)

	f:SetScript("OnHide", function() M.ReleaseIndex() end)
	f:Hide()
	SUI.Mover.Register("codex.win", f, { label = L("mod.codex.title"), point = "CENTER", x = 0, y = 0, scale = true })
	local sp = glob("UISpecialFrames")
	if type(sp) == "table" then tinsert(sp, "ShikiUI_Codex") end
end

-- ---------------------------------------------------------------- ouverture, fermeture
function M.Open(text)
	if not M.on then SUI.Print(L("msg.codex.off")) return end
	if SUI.InCombat() then SUI.Print(L("msg.codex.combat")) return end
	if not M.win then M.Build() end
	M.AtlasReadyCached = M.AtlasReady()
	M.insts = nil
	M.bcache = {}
	local insts = M.Instances()
	if not M.sel.inst or not insts[M.sel.inst] then
		if insts[1] then M.SelectInst(1) end
	end
	if text and text ~= "" then
		M.tab = "search"
		M.StartIndex()
		M.win.edit:SetText(text)
		M.Search(text)
	end
	M.win.f:Show()
	M.Paint()
end

function M.Close()
	if M.win then M.win.f:Hide() end
end

function M.Toggle(text)
	if M.win and M.win.f:IsShown() and (not text or text == "") then
		M.Close()
	else
		M.Open(text)
	end
end

function M.OnCombat()
	if M.win and M.win.f:IsShown() and C.Get("codex.closecombat") then M.Close() end
end

function M.OnKey(key, value)
	if key == "codex.minlevel" then
		M.insts = nil
		M.ReleaseIndex()
		M.sel.inst, M.sel.boss, M.sel.item = nil, nil, nil
		M.bosses, M.loots, M.res = {}, {}, {}
		M.off.res, M.more = 0, false
		if M.win and M.win.f:IsShown() then M.Open() end
	end
end

function M.Enable()
	M.on = true
	SUI.On("PLAYER_REGEN_DISABLED", M.OnCombat)
	if not M.watching then
		M.watching = true
		C.Watch("codex.", M.OnKey)
	end
end

function M.Disable()
	M.on = false
	SUI.Off("PLAYER_REGEN_DISABLED", M.OnCombat)
	if M.searchTask then SUI.Cancel(M.searchTask) M.searchTask = nil end
	M.ReleaseIndex()
	M.Close()
end

SUI.RegisterCategory("codex", 79)

SUI.RegisterModule("codex", {
	default = false,
	cost = "light",
	options = {
		{ key = "codex.closecombat", type = "bool", cat = "codex", label = "opt.codex.closecombat", tip = "tip.codex.closecombat",
			default = true, simple = true, order = 10 },
		{ key = "codex.maxresults", type = "number", cat = "codex", label = "opt.codex.maxresults", tip = "tip.codex.maxresults",
			min = 20, max = 200, step = 10, default = 40, order = 20 },
		{ key = "codex.minlevel", type = "number", cat = "codex", label = "opt.codex.minlevel", tip = "tip.codex.minlevel",
			min = 0, max = 60, step = 5, default = 0, order = 30 },
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("codex", function(rest)
	if not C.Get("modules.codex") then C.Set("modules.codex", true) end
	M.Toggle(rest)
end, "help.codex")
