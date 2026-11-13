-- mock_chattabs : simulation des fonctions de fenetres de chat du client 1.12 pour le module "chattabs" (chargee automatiquement).
-- Noms d'API releves dans pfUI\modules\chat.lua et _LazyPig : FCF_Close, FCF_SetWindowName, FCF_SelectDockFrame, FCF_DockUpdate,
-- ChatFrame_AddMessageGroup, ChatFrame_RemoveAllMessageGroups, ChatFrame_AddChannel, ChatFrame_RemoveChannel, ChatFrame_RemoveAllChannels,
-- ChatFrame_ActivateCombatMessages, GetChannelList, ChatTypeGroup, frame.messageTypeList / frame.channelList.
-- Hypotheses NON VERIFIEES en jeu (donc simulees ici telles quelles) : FCF_OpenNewWindow(nom), ChatFrame_RemoveMessageGroup.
-- Rien n'est defini au chargement : CTW_SETUP() (appelee par t_chattabs seulement) pose le monde.
-- Aides : CTW_SETUP() CTW_LOG() CTW_LOGCLEAR() CTW_CHANNELS({ noms }) CTW_GROUPS(i) CTW_HASGROUP(i, g) CTW_CHANS(i).

CTW = { log = {} }

function CTW_LOG() return table.concat(CTW.log, "|") end
function CTW_LOGCLEAR() CTW.log = {} end
function CTW_GROUPS(i) return table.concat(getglobal("ChatFrame" .. i).messageTypeList, ",") end
function CTW_CHANS(i) return table.concat(getglobal("ChatFrame" .. i).channelList, ",") end
function CTW_HASGROUP(i, g)
  for _, v in ipairs(getglobal("ChatFrame" .. i).messageTypeList) do if v == g then return true end end
  return false
end
function CTW_CHANNELS(names)
  CTW.channels = names
end

-- CTW_FADE(i) : le client reaffiche l'onglet Blizzard i (fondu, nouvelle fenetre).
function CTW_FADE(i) local t = getglobal("ChatFrame" .. i .. "Tab"); t:SetAlpha(1); t:EnableMouse(true) end
function CTW_DOCK()
  local t = {}
  for _, f in ipairs(DOCKED_CHAT_FRAMES) do table.insert(t, f.id) end
  return table.concat(t, ",")
end

function CTW_SETUP(noDock)
  CHAT_SETUP()
  local G = function(k, v) rawset(_G, k, v) end
  CTW = { log = {}, channels = { "General - Elwynn", "Trade - City", "World" }, noOpen = false, noDock = noDock }
  local groups = { "SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "WHISPER", "PARTY", "RAID", "RAID_LEADER", "RAID_WARNING", "BATTLEGROUND",
    "BATTLEGROUND_LEADER", "LOOT", "MONEY", "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE", "SKILL", "SYSTEM", "CREATURE",
    "MONSTER_SAY", "MONSTER_YELL", "MONSTER_EMOTE", "MONSTER_WHISPER", "MONSTER_BOSS_EMOTE", "MONSTER_BOSS_WHISPER", "CHANNEL",
    "COMBAT_SELF_HITS", "COMBAT_SELF_MISSES", "COMBAT_MISC_INFO" }
  local tg = {}
  for _, g in ipairs(groups) do tg[g] = { "CHAT_MSG_" .. g } end      -- GUILD_OFFICER volontairement absent : doit etre ignore
  G("ChatTypeGroup", tg)
  G("GENERAL", "General")
  for i = 1, 7 do
    local f = getglobal("ChatFrame" .. i)
    f.messageTypeList = {}
    f.channelList = {}
  end
  getglobal("ChatFrame1").messageTypeList = { "SAY", "YELL", "WHISPER", "LOOT" }
  getglobal("ChatFrame1").channelList = { "General" }
  getglobal("ChatFrame2").messageTypeList = { "COMBAT_SELF_HITS", "COMBAT_SELF_MISSES" }
  G("GetChannelList", function()
    local t = {}
    for i, n in ipairs(CTW.channels) do t[2 * i - 1] = i; t[2 * i] = n end
    return unpack(t)
  end)
  local function has(l, v) for _, x in ipairs(l) do if x == v then return true end end return false end
  local function rm(l, v) for i = table.getn(l), 1, -1 do if l[i] == v then table.remove(l, i) end end end
  G("ChatFrame_AddMessageGroup", function(f, g)
    if tg[g] and not has(f.messageTypeList, g) then table.insert(f.messageTypeList, g) end
    table.insert(CTW.log, "add:" .. f.id .. ":" .. g)
  end)
  G("ChatFrame_RemoveMessageGroup", function(f, g) rm(f.messageTypeList, g); table.insert(CTW.log, "rm:" .. f.id .. ":" .. g) end)
  G("ChatFrame_RemoveAllMessageGroups", function(f) f.messageTypeList = {}; table.insert(CTW.log, "rmall:" .. f.id) end)
  G("ChatFrame_AddChannel", function(f, c) if not has(f.channelList, c) then table.insert(f.channelList, c) end; table.insert(CTW.log, "addch:" .. f.id .. ":" .. c) end)
  G("ChatFrame_RemoveChannel", function(f, c) rm(f.channelList, c); table.insert(CTW.log, "rmch:" .. f.id .. ":" .. c) end)
  G("ChatFrame_RemoveAllChannels", function(f) f.channelList = {}; table.insert(CTW.log, "rmallch:" .. f.id) end)
  G("ChatFrame_ActivateCombatMessages", function(f)
    for _, g in ipairs({ "COMBAT_SELF_HITS", "COMBAT_SELF_MISSES", "COMBAT_XP_GAIN" }) do
      if not has(f.messageTypeList, g) then table.insert(f.messageTypeList, g) end
    end
  end)
  G("FCF_SetWindowName", function(f, name) CHATW.names[f.id] = name; table.insert(CTW.log, "name:" .. f.id .. ":" .. name) end)
  G("DOCKED_CHAT_FRAMES", { getglobal("ChatFrame1"), getglobal("ChatFrame2"), getglobal("ChatFrame3") })
  for i = 1, 3 do getglobal("ChatFrame" .. i).isDocked = i end
  local function undock(f)
    for i = table.getn(DOCKED_CHAT_FRAMES), 1, -1 do if DOCKED_CHAT_FRAMES[i] == f then table.remove(DOCKED_CHAT_FRAMES, i) end end
    f.isDocked = nil
  end
  G("FCF_Close", function(f) CHATW.shown[f.id] = false; undock(f); table.insert(CTW.log, "close:" .. f.id) end)
  G("FCF_UnDockFrame", function(f) undock(f); table.insert(CTW.log, "undock:" .. f.id) end)
  G("FCF_SetLocked", function(f, v) f.locked = v and true or false; table.insert(CTW.log, "lock:" .. f.id .. ":" .. tostring(v)) end)
  G("FCF_SaveDock", function() table.insert(CTW.log, "savedock") end)
  if CTW.noDock then G("FCF_DockFrame", nil) end
  if not CTW.noDock then
    G("FCF_DockFrame", function(f)
      if f.isDocked then return end
      table.insert(DOCKED_CHAT_FRAMES, f)
      f.isDocked = table.getn(DOCKED_CHAT_FRAMES)
      table.insert(CTW.log, "dock:" .. f.id)
    end)
  end
  G("FCF_DockUpdate", function() end)
  G("FCF_OpenNewWindow", function(name)
    if CTW.noOpen then return end
    for i = 1, 7 do
      if not CHATW.shown[i] and i ~= 2 then
        CHATW.shown[i] = true
        CHATW.names[i] = name or ("Chat " .. i)
        local f = getglobal("ChatFrame" .. i)
        f.messageTypeList = { "SAY" }
        f.channelList = {}
        f.locked = true           -- le client verrouille la fenetre neuve (hypothese pessimiste)
        f.isDocked = nil          -- le client ouvre une fenetre FLOTTANTE (hypothese pessimiste)
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        table.insert(CTW.log, "open:" .. i)
        return
      end
    end
  end)
end
