-- ShikiUI Menu_Preview : moteur du VOLET D'APERCU 2D du menu (a droite des reglages, ou sous eux sur un ecran etroit).
-- Un module enregistre son apercu avec SUI.Preview.Register(idCategorie, def) :
--   def.build(parent, w, h)            -> cadre racine (cree UNE fois, hors combat) ; parent = zone de l'apercu, w x h = sa taille
--   def.update(racine, w, h, cle, val) -> redessine ; cle == nil : tout ; jamais de creation de cadre ici (appele aussi en combat)
--   def.click(zone)                    -> cle d'option (ou "cat:<categorie>") a atteindre quand on clique la zone nommee
--   def.watch  = { "prefixe.", ... }   -> prefixes de reglages qui redessinent (par defaut "<idCategorie>.") ; def.title = cle de traduction
-- Les zones cliquables se creent dans build avec SUI.Preview.Zone(parent, nomDeZone) ; le clic appelle def.click puis M.GoHit (page du
-- reglage, mode Tout si besoin, surbrillance, defilement : M.FocusKey). L'apercu ne touche JAMAIS aux vrais cadres du jeu : tout est dessine
-- avec des textures / cadres propres, aux couleurs du style (T.c.*, T.Accent) et aux donnees du jeu (couleurs de classe, de debuff).
-- Cadres du volet : niveaux calcules sur M.lvl (apres M.SyncLevel), donc au-dessus du fond de la fenetre et sous la liste deroulante ; ils
-- suivent M.SetRaised (mode deplacement) car ce sont des descendants de la fenetre. Rien n'est cree en combat (P.Ensure refuse).
-- NON VERIFIE EN JEU : voir NOTES en bas de ce fichier.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local M = SUI.Menu
local C = SUI.Config

local getn, tinsert = table.getn, table.insert
local floor = math.floor
local sfind, ssub = string.find, string.sub

local P = {}
SUI.Preview = P
M.Preview = P

P.reg = {}          -- idCategorie -> def
P.order = {}        -- ordre d'enregistrement
P.cur = nil         -- def affichee
P.curId = nil
P.focus = nil       -- categorie du menu quand l'apercu affiche est un repli (mise en page) : permet de surligner son module
P.pane = nil
P.lastKey = nil     -- derniere cle atteinte par un clic (tests, diagnostic)

-- Reglages qui redessinent TOUT apercu (style, accent, langue, echelle, mode, role, mise en page, positions, interrupteurs de modules).
local GLOBAL_EXACT = { ["mode"] = true, ["role"] = true, ["layout"] = true, ["pos"] = true, ["ui.accent"] = true, ["ui.locale"] = true,
	["ui.scale"] = true }
local GLOBAL_PREFIX = { "style.", "modules." }

-- ---------------------------------------------------------------- enregistrement
function P.Register(catId, def)
	if type(catId) ~= "string" or catId == "" or type(def) ~= "table" or type(def.build) ~= "function" then return false end
	local old = P.reg[catId]
	if old and old.root then old.root:Hide() end
	def.id = catId
	def.root = nil
	def.failed = nil
	if not old then tinsert(P.order, catId) end
	P.reg[catId] = def
	return true
end

-- ---------------------------------------------------------------- aides de dessin (jetons du style, jamais de couleur en dur)
function P.NewTex(parent, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(T.tex.white)
	return t
end

-- Couleur d'un jeton { r, g, b, a } ; a : opacite imposee (facultative).
function P.Fill(t, col, a)
	t:SetVertexColor(col[1], col[2], col[3], a or col[4] or 1)
end

-- Place la texture t dans parent (x, y depuis le coin haut gauche, w x h) ; cachee si trop petite.
function P.Box(t, parent, x, y, w, h)
	if w < 0.5 or h < 0.5 then
		t:Hide()
		return
	end
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	t:SetWidth(w)
	t:SetHeight(h)
	t:Show()
end

-- Taille de police du style, a l'echelle voulue (le texte de l'apercu est reduit comme le dessin).
function P.Font(fs, size)
	if size < 6 then size = 6 end
	pcall(fs.SetFont, fs, T.font, size * (T.fontScale or 1), T.outline)
end

-- Place le cadre f dans parent (coin haut gauche) a la taille w x h.
function P.Place(f, parent, x, y, w, h)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	f:SetWidth(w)
	f:SetHeight(h)
end

-- ---------------------------------------------------------------- zones cliquables
function P.FindOption(key)
	for i = 1, getn(SUI.options) do
		local o = SUI.options[i]
		if o.key == key and o.type ~= "header" then return o end
	end
	return nil
end

-- Saute a l'option (ou "cat:<categorie>") : page, mode Tout si l'option est avancee, surbrillance et defilement.
function P.Goto(key)
	if type(key) ~= "string" or key == "" then return false end
	P.lastKey = key
	local _, _, cat = sfind(key, "^cat:(.+)$")
	if cat then
		if M.CatExists(cat) then
			M.Open("cat", cat)
			return true
		end
		return false
	end
	local o = P.FindOption(key)
	if not o then return false end
	M.GoHit(o)
	return true
end

local function zoneKey(z)
	local def = z.pdef
	if not def or type(def.click) ~= "function" then return nil end
	local ok, key = pcall(def.click, z.pz)
	if ok then return key end
	SUI.Report("preview click", key)
	return nil
end

local function zoneClick()
	local key = zoneKey(this)
	if key then P.Goto(key) end
end

local function zoneEnter()
	local z = this
	local r, g, b = T.Accent()
	z.hl:SetVertexColor(r, g, b, 0.28)
	z.hl:Show()
	local key = zoneKey(z)
	local o = key and P.FindOption(key)
	if o then
		M.TipShow(z, L(o.label), M.Short(M.Tx(o.tip), 120), L("mod.preview.zone"))
	elseif key then
		local _, _, cat = sfind(key, "^cat:(.+)$")
		if cat then M.TipShow(z, M.CatLabel(cat), L("mod.preview.zone")) end
	end
end

local function zoneLeave()
	this.hl:Hide()
	M.TipHide()
end

-- Zone cliquable (a creer dans def.build, hors combat) : cadre transparent au-dessus de ses freres, surligne au survol.
-- Niveaux ABSOLUS : P.base = niveau du cadre racine de l apercu en cours de construction ; P.Lv(rel) = P.base + rel (deterministe, sans parcours).
P.base = 0
function P.Lv(rel) return P.base + (rel or 0) end

function P.Zone(parent, id, rel)
	local z = CreateFrame("Button", nil, parent)
	z:SetFrameLevel(P.Lv(rel or 3))
	z.pz = id
	z.pdef = P.building
	z:RegisterForClicks("LeftButtonUp")
	z:EnableMouse(true)
	z.hl = z:CreateTexture(nil, "OVERLAY")
	z.hl:SetTexture(T.tex.white)
	z.hl:SetAllPoints(z)
	z.hl:Hide()
	z:SetScript("OnClick", zoneClick)
	z:SetScript("OnEnter", zoneEnter)
	z:SetScript("OnLeave", zoneLeave)
	return z
end

-- Place une zone sur le rectangle (x, y, w, h) de parent ; taille minimale 6 px pour rester cliquable.
function P.PlaceZone(z, parent, x, y, w, h)
	if w < 6 then
		x = x - (6 - w) / 2
		w = 6
	end
	if h < 6 then
		y = y - (6 - h) / 2
		h = 6
	end
	P.Place(z, parent, x, y, w, h)
	z:Show()
end

-- ---------------------------------------------------------------- volet
function P.Dims()
	local G = M.G
	if M.pvMode == "below" then return G.W - G.CX - G.PAD, G.BH - 6 end
	return G.PW, G.NAVH
end

function P.BodySize()
	local w, h = P.Dims()
	return w - 12, h - 26 - 20
end

-- Recale le volet sur le niveau reel du contenu (voir M.SyncLevel : le client change le niveau du cadre defilant apres sa creation).
function P.SyncLevel()
	M.SyncLevel()
	local pv = P.pane
	if not pv or not M.lvl or not M.child then return end
	local want = M.lvl
	local cur = pv:GetFrameLevel()
	if cur ~= want then M.Restack(pv, M.child:GetFrameStrata(), want - cur, {}) end
end

function M.BuildPreview(f)
	if P.pane then return P.pane end
	M.SyncLevel()
	local pv = CreateFrame("Frame", nil, f)
	P.pane = pv
	pv:SetFrameStrata(f:GetFrameStrata())
	pv:SetFrameLevel(M.lvl)
	T.Backdrop(pv, T.c.panel, T.c.border)
	pv:EnableMouse(true)
	pv.title = T.Text(pv, 12, T.c.text, "LEFT")
	pv.title:SetPoint("TOPLEFT", pv, "TOPLEFT", 8, -7)
	pv.title:SetHeight(14)
	pv.bScreen = T.Button(pv, L("mod.preview.screen.toggle"), 64, 14, function()
		-- bascule : apercu de l'ecran <-> apercu de la categorie courante
		if P.curId == "screen" then
			P.Show(P.Pick())
		else
			P.Show("screen")
		end
	end)
	pv.bScreen:SetPoint("TOPRIGHT", pv, "TOPRIGHT", -8, -24)
	pv.bScreen:Hide()   -- montre par P.Show quand un autre apercu est actif
	pv.status = T.Text(pv, 10, T.c.warn, "RIGHT")
	pv.status:SetPoint("TOPRIGHT", pv, "TOPRIGHT", -8, -8)
	pv.status:SetHeight(12)
	pv.body = CreateFrame("Frame", nil, pv)
	pv.body:SetPoint("TOPLEFT", pv, "TOPLEFT", 6, -24)
	pv.body:SetFrameLevel(M.lvl + 1)
	pv.msg = T.Text(pv, 11, T.c.dim, "CENTER")
	pv.msg:SetPoint("CENTER", pv, "CENTER", 0, 0)
	pv.msg:SetWidth(220)
	pv.msg:SetHeight(60)
	pv.msg:Hide()
	pv.hint = T.Text(pv, 10, T.c.dim, "LEFT")
	pv.hint:SetPoint("BOTTOMLEFT", pv, "BOTTOMLEFT", 8, 6)
	pv.hint:SetHeight(12)
	pv:Hide()
	C.Watch("", P.OnKey)
	T.OnAccent(P.OnRestyle)
	M.PreviewLayout()
	if M.PreviewWanted() then P.EnsureAll() end
	return pv
end

-- Place le volet selon M.pvMode et redimensionne les apercus deja construits.
function M.PreviewLayout()
	local pv = P.pane
	local f = M.frame
	if not pv or not f then return end
	local G = M.G
	local w, h = P.Dims()
	pv:ClearAllPoints()
	if M.pvMode == "below" then
		pv:SetPoint("TOPLEFT", f, "TOPLEFT", G.CX, -(G.NAVTOP + G.NAVH + 2))
	else
		pv:SetPoint("TOPLEFT", f, "TOPLEFT", G.W + G.PX, -G.NAVTOP)
	end
	pv:SetWidth(w)
	pv:SetHeight(h)
	local bw, bh = P.BodySize()
	pv.body:SetWidth(bw)
	pv.body:SetHeight(bh)
	pv.title:SetWidth(w - 150)
	pv.status:SetWidth(150)
	pv.hint:SetWidth(w - 16)
	for i = 1, getn(P.order) do
		local d = P.reg[P.order[i]]
		if d.root then
			d.root:SetWidth(bw)
			d.root:SetHeight(bh)
		end
	end
	if M.pvMode == "off" then
		pv:Hide()
	elseif f:IsShown() then
		M.SyncPreview()
	end
end

-- Construit (hors combat) l'apercu d'une def. Retourne vrai si sa racine existe.
function P.Ensure(def)
	if not def then return false end
	if def.root then return true end
	if def.failed or SUI.InCombat() then return false end
	local pv = P.pane
	if not pv then return false end
	P.SyncLevel()
	local bw, bh = P.BodySize()
	P.building = def
	P.base = pv.body:GetFrameLevel() + 1
	local ok, root = pcall(def.build, pv.body, bw, bh)
	P.building = nil
	if not ok or type(root) ~= "table" then
		def.failed = true
		SUI.Report("preview " .. tostring(def.id), ok and "build sans cadre racine" or root)
		return false
	end
	P.Place(root, pv.body, 0, 0, bw, bh)
	root:SetFrameLevel(P.Lv(0))
	root:Hide()
	def.root = root
	return true
end

-- Instance INDEPENDANTE d'un apercu (hors du volet du menu) : pour l'assistant d'installation ou un autre panneau. Construite hors combat
-- seulement ; interactive = false rend les zones insensibles a la souris. Retourne { root, def, Update(cle) } ou nil.
function P.Instance(catId, parent, w, h, interactive)
	local def = P.reg[catId]
	if not def or not parent or SUI.InCombat() then return nil end
	P.building = def
	P.base = parent:GetFrameLevel() + 1
	local ok, root = pcall(def.build, parent, w, h)
	P.building = nil
	if not ok or type(root) ~= "table" then
		SUI.Report("preview " .. tostring(catId), ok and "build sans cadre racine" or root)
		return nil
	end
	P.Place(root, parent, 0, 0, w, h)
	root:SetFrameLevel(P.Lv(0))
	if not interactive then
		local function mute(fr)
			if fr.pz and fr.pdef then fr:EnableMouse(false) end
			local kids = { fr:GetChildren() }
			for i = 1, getn(kids) do
				if kids[i] ~= fr then mute(kids[i]) end
			end
		end
		mute(root)
	end
	local inst = { root = root, def = def, w = w, h = h }
	inst.Update = function(key, value)
		if type(def.update) ~= "function" then return end
		local ok2, err = pcall(def.update, root, w, h, key, value)
		if not ok2 then SUI.Report("preview " .. tostring(catId), err) end
	end
	inst.Update(nil, nil)
	return inst
end

function P.EnsureAll()
	for i = 1, getn(P.order) do P.Ensure(P.reg[P.order[i]]) end
end

-- ---------------------------------------------------------------- choix et mise a jour
function P.Fallback()
	if P.reg.layout then return "layout" end
	return P.order[1]
end

-- Apercu a montrer : celui de la categorie ouverte, sinon la mise en page (vue d'ensemble) ; pendant une recherche, le dernier affiche.
function P.Pick()
	if M.search ~= "" and P.curId then return P.curId end
	if M.page == "cat" and P.reg[M.cat] then return M.cat end
	return P.Fallback()
end

function P.UpdateStatus(def)
	local pv = P.pane
	if not pv or not def then return end
	local m = SUI.modules[def.id]
	if m and not m.enabled then
		pv.status:SetText(L("mod.preview.off"))
	else
		pv.status:SetText("")
	end
end

function P.Update(def, key, value)
	if not def or not def.root or type(def.update) ~= "function" then return end
	local bw, bh = P.BodySize()
	local ok, err = pcall(def.update, def.root, bw, bh, key, value)
	if not ok then SUI.Report("preview " .. tostring(def.id), err) end
end

function P.Message(text)
	local pv = P.pane
	if text then
		pv.msg:SetText(text)
		pv.msg:Show()
	else
		pv.msg:Hide()
	end
end

function P.Show(id)
	local pv = P.pane
	local def = id and P.reg[id]
	P.cur, P.curId = def, id
	P.focus = (M.page == "cat" and id ~= M.cat) and M.cat or nil
	for i = 1, getn(P.order) do
		local d = P.reg[P.order[i]]
		if d ~= def and d.root and d.root:IsShown() then d.root:Hide() end
	end
	pv.hint:SetText(L("mod.preview.hint"))
	if not def then
		pv.title:SetText(L("mod.preview.title"))
		pv.status:SetText("")
		pv.bScreen:Hide()
		P.Message(L("mod.preview.none"))
		return
	end
	local name = def.title and M.Has(def.title) and L(def.title) or M.CatLabel(def.id)
	pv.title:SetText(L("mod.preview.for", name))
	if id ~= "screen" and P.reg.screen then
		pv.bScreen:Show()
	else
		pv.bScreen:Hide()
	end
	P.UpdateStatus(def)
	if not P.Ensure(def) then
		P.Message(def.failed and L("mod.preview.error") or L("mod.preview.combat"))
		return
	end
	P.Message(nil)
	if not def.root:IsShown() then def.root:Show() end
	P.Update(def, nil, nil)
end

-- Appele par M.Render : montre l'apercu qui correspond a la page.
function M.SyncPreview()
	local pv = P.pane
	if not pv then return end
	P.SyncLevel()
	if M.pvMode == "off" then
		if pv:IsShown() then pv:Hide() end
		return
	end
	if not pv:IsShown() then pv:Show() end
	P.Show(P.Pick())
end

function P.IsGlobal(key)
	if GLOBAL_EXACT[key] then return true end
	for i = 1, getn(GLOBAL_PREFIX) do
		local p = GLOBAL_PREFIX[i]
		if ssub(key, 1, string.len(p)) == p then return true end
	end
	return false
end

function P.Matches(def, key)
	local w = def.watch
	if type(w) ~= "table" then
		local p = def.id .. "."
		return ssub(key, 1, string.len(p)) == p
	end
	for i = 1, getn(w) do
		if ssub(key, 1, string.len(w[i])) == w[i] then return true end
	end
	return false
end

-- Un reglage a change : redessine l'apercu affiche s'il est concerne (sans rien reconstruire).
function P.OnKey(key, value)
	local f = M.frame
	if not f or not f:IsShown() or M.pvMode == "off" or not P.pane or not P.pane:IsShown() then return end
	local def = P.cur
	if not def or not def.root then return end
	if key == nil or P.IsGlobal(key) or P.Matches(def, key) then
		if key == nil or ssub(key, 1, 8) == "modules." then P.UpdateStatus(def) end
		P.Update(def, key, value)
	end
end

function P.OnRestyle()
	local f = M.frame
	if f and f:IsShown() and M.pvMode ~= "off" and P.cur and P.cur.root then P.Update(P.cur, nil, nil) end
end

-- NOTES - NON VERIFIE EN JEU (1.12) : (1) le niveau des cadres du volet (au-dessus du fond, sous la liste deroulante) apres le
-- relevement automatique de la fenetre "toplevel" ; (2) CreateFontString / SetFont avec une taille reduite (texte lisible a l'echelle
-- de l'apercu) ; (3) les textures "UI-RaidTargetingIcons" decoupees par SetTexCoord ; (4) la largeur de la fenetre elargie sur des
-- ecrans 4/3 (le plan M.PlanLayout bascule alors sous les reglages ou masque le volet).
