--[[
    Phyz's Quest bar
    Your whole quest log down the side of the screen, tracked or not, grouped by
    zone. The zone you're in jumps to the top and opens by itself; fly to the
    Barrens and the Barrens quests open, fly on to Ashenvale and those open instead.

    Data side: reads the quest log into groups. The panel lives in PhyzQuestBar_UI.lua.

    PhyzQuestBarDB = { settings = { autoZone, hideTracker, locked, scale }, pinned = { [zone]=true }, point = {...}, size = {w, h}, hidden }
]]

local ADDON = ...
local QSB = {}
PhyzQuestBar = QSB

local DEFAULTS = { autoZone = true, hideTracker = true, locked = false, scale = 1, showObjectives = true, opacity = 1, minimap = true,
                   autoShare = false, hideGrey = false, questItems = true }

local db
QSB.open = {}          -- zones opened by hand this visit (cleared when you change zone)
QSB.closed = {}        -- the current zone, closed by hand
local currentZone

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ddffPhyz's Quest bar|r: " .. tostring(msg))
end
QSB.Print = Print

local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

function QSB.DB() return db end

---------------------------------------------------------------------------
-- Reading the quest log
---------------------------------------------------------------------------
local function NumEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then return (C_QuestLog.GetNumQuestLogEntries()) end
    return (GetNumQuestLogEntries())
end

local function Entry(i)
    if C_QuestLog and C_QuestLog.GetInfo then
        local e = C_QuestLog.GetInfo(i)
        if not e then return nil end
        -- Modern clients (Forever included) leave isComplete out of GetInfo: ask
        -- the quest itself, as Questie and Shortest Path do. 1 = done, -1 = failed.
        local complete = e.isComplete
        if not e.isHeader and e.questID and e.questID > 0 then
            if C_QuestLog.IsFailed and C_QuestLog.IsFailed(e.questID) == true then
                complete = -1
            elseif C_QuestLog.IsComplete and C_QuestLog.IsComplete(e.questID) == true then
                complete = 1
            elseif C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(e.questID) == true then
                complete = 1
            end
        end
        return { title = e.title, level = e.level, isHeader = e.isHeader, isCollapsed = e.isCollapsed,
                 isComplete = complete, questID = e.questID, isHidden = e.isHidden, suggestedGroup = e.suggestedGroup,
                 index = i }
    end
    local title, level, _, isHeader, isCollapsed, isComplete, _, questID = GetQuestLogTitle(i)
    if not title then return nil end
    return { title = title, level = level, isHeader = isHeader, isCollapsed = isCollapsed,
             isComplete = isComplete, questID = questID, index = i }
end

-- Quests under a header that is collapsed in Blizzard's quest log are invisible
-- to addons, so open those headers (the sidebar does the collapsing now).
local function ExpandBlizzardHeaders()
    if InCombatLockdown and InCombatLockdown() then return false end
    local expanded = false
    for i = NumEntries(), 1, -1 do
        local e = Entry(i)
        if e and e.isHeader and e.isCollapsed then
            if ExpandQuestHeader then pcall(ExpandQuestHeader, i) end
            expanded = true
        end
    end
    return expanded
end

local function Objectives(e)
    local list = {}
    local objs = C_QuestLog and C_QuestLog.GetQuestObjectives and e.questID and C_QuestLog.GetQuestObjectives(e.questID)
    if objs then
        for _, o in ipairs(objs) do
            if o.text and o.text ~= "" and not IsSecret(o.text) then
                list[#list + 1] = { text = o.text, finished = o.finished }
            end
        end
    elseif GetNumQuestLeaderBoards then
        for j = 1, (GetNumQuestLeaderBoards(e.index) or 0) do
            local text, _, finished = GetQuestLogLeaderBoard(j, e.index)
            if text and text ~= "" then list[#list + 1] = { text = text, finished = finished } end
        end
    end
    return list
end

function QSB.IsTracked(questID, index)
    if C_QuestLog and C_QuestLog.GetQuestWatchType then return C_QuestLog.GetQuestWatchType(questID) ~= nil end
    if IsQuestWatched then return IsQuestWatched(index) and true or false end
    return false
end

-- "Dungeon", "Elite", "Raid"... or nil
function QSB.TagText(questID)
    if not questID or questID == 0 then return nil end
    if C_QuestLog and C_QuestLog.GetQuestTagInfo then
        local info = C_QuestLog.GetQuestTagInfo(questID)
        if info and info.tagName and info.tagName ~= "" and not IsSecret(info.tagName) then return info.tagName end
    end
    return nil
end

-- The quest's short objective text ("Scout the gazebo on Mystral Lake..."), cached
-- because reading it means briefly selecting the quest in Blizzard's log.
local detailCache = {}
function QSB.Details(q)
    if detailCache[q.questID] ~= nil then return detailCache[q.questID] or nil end
    local text
    if GetQuestLogQuestText then
        if C_QuestLog and C_QuestLog.SetSelectedQuest then
            local old = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
            C_QuestLog.SetSelectedQuest(q.questID)
            local _, objectives = GetQuestLogQuestText()
            text = objectives
            if old and old ~= 0 then C_QuestLog.SetSelectedQuest(old) end
        elseif SelectQuestLogEntry and GetQuestLogSelection then
            local old = GetQuestLogSelection()
            SelectQuestLogEntry(q.index)
            local _, objectives = GetQuestLogQuestText()
            text = objectives
            if old and old > 0 then SelectQuestLogEntry(old) end
        end
    end
    if text and (text == "" or IsSecret(text)) then text = nil end
    detailCache[q.questID] = text or false
    return text
end

-- Who to hand a finished quest to ("Return to Regthar Deathgate..."), when the
-- client offers it; otherwise nil and the objective summary is shown instead.
local turnInCache = {}
function QSB.TurnIn(q)
    if not q.complete or not GetQuestLogCompletionText then return nil end
    if turnInCache[q.questID] ~= nil then return turnInCache[q.questID] or nil end
    local ok, text
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        local old = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(q.questID)
        ok, text = pcall(GetQuestLogCompletionText, q.index)
        if old and old ~= 0 then C_QuestLog.SetSelectedQuest(old) end
    elseif SelectQuestLogEntry and GetQuestLogSelection then
        local old = GetQuestLogSelection()
        SelectQuestLogEntry(q.index)
        ok, text = pcall(GetQuestLogCompletionText, q.index)
        if old and old > 0 then SelectQuestLogEntry(old) end
    end
    if not ok or type(text) ~= "string" or text == "" or IsSecret(text) then text = nil end
    turnInCache[q.questID] = text or false
    return text
end

---------------------------------------------------------------------------
-- XP for handing a quest in
---------------------------------------------------------------------------
-- The reward depends on your level, so the cache is per level. None at max level
-- (or with XP turned off): the quest pays gold instead.
local xpCache, xpLevel = {}, nil

local function AtMaxLevel()
    if IsXPUserDisabled and IsXPUserDisabled() then return true end
    local me = UnitLevel and UnitLevel("player")
    local max = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
        or (GetMaxPlayerLevel and GetMaxPlayerLevel())
    return type(me) == "number" and type(max) == "number" and max > 0 and me >= max
end
QSB.AtMaxLevel = AtMaxLevel

local function ReadXP(q)
    if not GetQuestLogRewardXP then return nil end
    local ok, xp = pcall(GetQuestLogRewardXP, q.questID)
    if ok and type(xp) == "number" and not IsSecret(xp) and xp > 0 then return xp end
    -- older clients read the quest selected in the log
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        local old = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(q.questID)
        ok, xp = pcall(GetQuestLogRewardXP)
        if old and old ~= 0 then C_QuestLog.SetSelectedQuest(old) end
    elseif SelectQuestLogEntry and GetQuestLogSelection then
        local old = GetQuestLogSelection()
        SelectQuestLogEntry(q.index)
        ok, xp = pcall(GetQuestLogRewardXP)
        if old and old > 0 then SelectQuestLogEntry(old) end
    end
    if ok and type(xp) == "number" and not IsSecret(xp) and xp > 0 then return xp end
    return nil
end

-- XP you'll get for turning the quest in, or nil
function QSB.RewardXP(q)
    if not q or not q.questID or q.questID == 0 or AtMaxLevel() then return nil end
    local lvl = UnitLevel and UnitLevel("player")
    if lvl ~= xpLevel then wipe(xpCache); xpLevel = lvl end
    -- a number is kept; "none yet" is retried after 10s (quest data can still
    -- be loading right after login)
    local v = xpCache[q.questID]
    local now = GetTime and GetTime() or 0
    if type(v) == "number" then return v end
    if v and now - v.at < 10 then return nil end
    local xp = ReadXP(q)
    xpCache[q.questID] = xp or { at = now }
    return xp
end

function QSB.FormatXP(n)
    local s = (BreakUpLargeNumbers and BreakUpLargeNumbers(n)) or tostring(math.floor(n))
    return s .. " XP"
end

-- "about 35% of a level" against what this level needs
function QSB.LevelShare(xp)
    local need = UnitXPMax and UnitXPMax("player")
    if type(need) ~= "number" or need <= 0 or IsSecret(need) then return nil end
    return math.floor(xp / need * 100 + 0.5)
end

-- { {zone, quests = { {title, level, questID, index, complete, objectives, tracked} }, total, done }, ... }
function QSB.ReadLog()
    if ExpandBlizzardHeaders() then
        -- the log reshuffles after expanding; the QUEST_LOG_UPDATE that follows redraws us
    end
    local groups, group = {}, nil
    for i = 1, NumEntries() do
        local e = Entry(i)
        if e and not IsSecret(e.title) then
            if e.isHeader then
                group = { zone = e.title, quests = {}, done = 0 }
                groups[#groups + 1] = group
            elseif not e.isHidden and e.title then
                if not group then
                    group = { zone = "Other", quests = {}, done = 0 }
                    groups[#groups + 1] = group
                end
                local complete = e.isComplete == true or e.isComplete == 1
                group.quests[#group.quests + 1] = {
                    title = e.title, level = e.level, questID = e.questID, index = i, complete = complete,
                    failed = e.isComplete == -1, group = e.suggestedGroup,
                    objectives = Objectives(e), tracked = QSB.IsTracked(e.questID, i),
                    tag = QSB.TagText(e.questID),
                }
                if complete then group.done = group.done + 1 end
            end
        end
    end
    -- drop empty headers; ready-to-turn-in quests go to the top of their zone
    for i = #groups, 1, -1 do
        local qs = groups[i].quests
        if #qs == 0 then
            table.remove(groups, i)
        else
            for n, q in ipairs(qs) do q.order = n end
            table.sort(qs, function(x, y)
                if x.complete ~= y.complete then return x.complete end
                return x.order < y.order
            end)
        end
    end
    return groups
end

---------------------------------------------------------------------------
-- Which zone are we in, and which groups are open?
---------------------------------------------------------------------------
local function ZoneNames()
    local names = {}
    for _, f in ipairs({ GetRealZoneText, GetZoneText }) do
        local z = f and f()
        if z and z ~= "" and not IsSecret(z) then names[z] = true end
    end
    if C_Map and C_Map.GetBestMapForUnit then
        -- also the parent zone when standing in a sub-area that has its own map
        local id = C_Map.GetBestMapForUnit("player")
        local guard = 0
        while id and guard < 4 do
            local info = C_Map.GetMapInfo(id)
            if not info then break end
            if info.name and not IsSecret(info.name) then names[info.name] = true end
            if info.mapType and Enum and Enum.UIMapType and info.mapType <= Enum.UIMapType.Zone then break end
            id = info.parentMapID
            guard = guard + 1
        end
    end
    return names
end

function QSB.CurrentZone() return currentZone end

-- the quest-log header that matches where we are (headers are zone names)
function QSB.MatchZone(groups)
    local names = ZoneNames()
    for _, g in ipairs(groups) do
        if names[g.zone] then return g.zone end
    end
    return GetRealZoneText and GetRealZoneText() or nil
end

function QSB.IsOpen(zone)
    if db.pinned[zone] then return true end
    if zone == currentZone and db.settings.autoZone then return not QSB.closed[zone] end
    return QSB.open[zone] == true
end

function QSB.ToggleZone(zone)
    if zone == currentZone and db.settings.autoZone then
        QSB.closed[zone] = not QSB.closed[zone] or nil
        if db.pinned[zone] then db.pinned[zone] = nil; QSB.closed[zone] = true end
    elseif db.pinned[zone] then
        db.pinned[zone] = nil
        QSB.open[zone] = nil
    else
        QSB.open[zone] = not QSB.open[zone] or nil
    end
    QSB.Refresh()
end

function QSB.TogglePin(zone)
    if db.pinned[zone] then db.pinned[zone] = nil else db.pinned[zone] = true end
    QSB.Refresh()
end

-- A-Z by zone name (a leading "The " is ignored, so The Barrens sorts under B)
local function SortKey(zone)
    return (zone:gsub("^[Tt]he%s+", "")):lower()
end
QSB.SortKey = SortKey

function QSB.Ordered(groups)
    local out = {}
    for _, g in ipairs(groups) do out[#out + 1] = g end
    table.sort(out, function(a, b) return SortKey(a.zone) < SortKey(b.zone) end)
    return out
end

-- the group for where we are standing, or nil
function QSB.HereGroup(groups)
    for _, g in ipairs(groups) do if g.zone == currentZone then return g end end
end

-- per-quest show/hide of objectives (click the quest)
QSB.questFolded = {}
function QSB.ToggleQuest(q)
    QSB.questFolded[q.questID] = not QSB.questFolded[q.questID] or nil
    QSB.Refresh()
end

local function OnZoneChanged()
    local groups = QSB.ReadLog()
    local zone = QSB.MatchZone(groups)
    if zone ~= currentZone then
        currentZone = zone
        if db.settings.autoZone then
            wipe(QSB.open)   -- close what you opened by hand somewhere else; pinned zones stay
            wipe(QSB.closed)
        end
    end
    QSB.Refresh(groups)
end
QSB.OnZoneChanged = OnZoneChanged

---------------------------------------------------------------------------
-- The item a quest wants you to use
---------------------------------------------------------------------------
-- The game's own quest item first (GetQuestLogSpecialItemInfo). Many old quests
-- don't flag theirs, so then Questie's data: the item the quest gave you, if
-- it is in your bags and has a "Use:" effect.
-- { itemID, texture, charges, logIndex (when the game flagged it) } or nil
local sourceCache = {}

local function ItemCount(id)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) or 0 end
    if GetItemCount then return GetItemCount(id) or 0 end
    return 0
end

local function Usable(id)
    local spell = (C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(id)) or (GetItemSpell and GetItemSpell(id))
    return spell ~= nil
end

local function ItemIcon(id)
    return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))
        or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function SourceItems(questID)
    local v = sourceCache[questID]
    if v ~= nil then return v end
    v = {}
    local L = LibQuestieDB
    if type(L) == "table" and L.Quest and L.Quest.Get then
        local ok, id = pcall(L.Quest.Get, questID, "sourceItemId")
        if ok and type(id) == "number" and id > 0 then v[#v + 1] = id end
        local ok2, list = pcall(L.Quest.Get, questID, "requiredSourceItems")
        if ok2 and type(list) == "table" then
            for _, i in ipairs(list) do if type(i) == "number" and i > 0 then v[#v + 1] = i end end
        end
        sourceCache[questID] = v
    end
    return v -- not cached while Questie isn't there yet
end

function QSB.QuestItem(q)
    if not q or not q.questID or q.questID == 0 then return nil end
    if GetQuestLogSpecialItemInfo and q.index then
        local ok, link, texture, charges, showWhenComplete = pcall(GetQuestLogSpecialItemInfo, q.index)
        if ok and type(link) == "string" and not IsSecret(link) and (not q.complete or showWhenComplete) then
            local id = tonumber(link:match("item:(%d+)"))
            if id then return { itemID = id, texture = texture or ItemIcon(id), charges = charges, logIndex = q.index } end
        end
    end
    if q.complete then return nil end
    for _, id in ipairs(SourceItems(q.questID)) do
        if ItemCount(id) > 0 and Usable(id) then
            local n = ItemCount(id)
            return { itemID = id, texture = ItemIcon(id), charges = n > 1 and n or nil }
        end
    end
end

---------------------------------------------------------------------------
-- Where a finished quest is handed in
---------------------------------------------------------------------------
-- Questie's database (LibQuestieDB) names the turn-in NPC or object and where it
-- stands. Without it, the game's own quest marker for a finished quest is used.
-- { zone = "Orgrimmar", npc = "Thrall", map = uiMapID, x = 0..1, y = 0..1 } or nil
local placeCache = {}

local function MapName(uiMapID)
    if not uiMapID or not C_Map or not C_Map.GetMapInfo then return nil end
    local info = C_Map.GetMapInfo(uiMapID)
    local name = info and info.name
    if name and not IsSecret(name) and name ~= "" then return name end
end

-- QuestieDB ships the area -> map table as data ("return { ... }" strings), ready as
-- soon as it loads. Questie's own ZoneDB only answers once Questie has started up,
-- which can be well after we first draw.
local areaMap
local function SupportAreaMap()
    if areaMap ~= nil then return areaMap or nil end
    local L = LibQuestieDB
    local zone = type(L) == "table" and L.Support and L.Support.Get and L.Support.Get("ZoneDB")
    local private = zone and zone.private
    if not private then return nil end -- not loaded yet: try again later
    local out = {}
    for _, key in ipairs({ "areaIdToUiMapId", "areaIdToUiMapIdOverride" }) do
        local src = private[key]
        if type(src) == "string" then
            local fn = loadstring and loadstring(src)
            local ok, t = false, nil
            if fn then
                if setfenv then setfenv(fn, {}) end -- plain data: no globals
                ok, t = pcall(fn)
            end
            if ok and type(t) == "table" then for a, m in pairs(t) do out[a] = m end end
        elseif type(src) == "table" then
            for a, m in pairs(src) do out[a] = m end
        end
    end
    areaMap = next(out) and out or false
    return areaMap or nil
end

local function AreaToUiMap(areaID)
    if QuestieLoader and QuestieLoader.ImportModule then
        local ok, zoneDB = pcall(QuestieLoader.ImportModule, QuestieLoader, "ZoneDB")
        if ok and zoneDB and zoneDB.GetUiMapIdByAreaId then
            local ok2, map = pcall(zoneDB.GetUiMapIdByAreaId, zoneDB, areaID)
            if ok2 and type(map) == "number" and map > 0 then return map end
        end
    end
    local t = SupportAreaMap()
    local map = t and t[areaID]
    if type(map) == "number" and map > 0 then return map end
end

local function FromQuestie(questID)
    local L = LibQuestieDB
    if type(L) ~= "table" or not L.Quest or not L.Quest.Get then return nil end
    local ok, finishedBy = pcall(L.Quest.Get, questID, "finishedBy")
    if not ok or type(finishedBy) ~= "table" then return nil end
    for kind, entity in ipairs({ L.Npc, L.Object }) do
        local ids = finishedBy[kind]
        if entity and entity.Get and type(ids) == "table" then
            for _, id in ipairs(ids) do
                local _, name = pcall(entity.Get, id, "name")
                local _, areaID = pcall(entity.Get, id, "zoneID")
                local _, spawns = pcall(entity.Get, id, "spawns")
                if type(spawns) == "table" then
                    -- its main zone's spawn, else any spawn it has
                    local list, area = (type(areaID) == "number" and areaID > 0) and spawns[areaID] or nil, areaID
                    if type(list) ~= "table" or not list[1] then
                        for a, l in pairs(spawns) do if type(l) == "table" and l[1] then list, area = l, a; break end end
                    end
                    local spot = list and list[1]
                    local map = area and AreaToUiMap(area)
                    if spot and map then
                        return { zone = MapName(map), npc = type(name) == "string" and name or nil,
                                 map = map, x = spot[1] / 100, y = spot[2] / 100 }
                    end
                    if area and C_Map and C_Map.GetAreaInfo then
                        local zone = C_Map.GetAreaInfo(area)
                        if zone and zone ~= "" then
                            return { zone = zone, npc = type(name) == "string" and name or nil }
                        end
                    end
                end
            end
        end
    end
end

-- Only the game's waypoint to the hand-in. (The quest's own map can be where the
-- objective was, e.g. "Excavation Site: Wetlands" for a quest handed in in Mulgore,
-- so it is not used for turn-ins.)
local function FromClient(q)
    if not C_QuestLog or not C_QuestLog.GetNextWaypoint then return nil end
    local ok, map, x, y = pcall(C_QuestLog.GetNextWaypoint, q.questID)
    if ok and type(map) == "number" and type(x) == "number" and not IsSecret(x) then
        return { zone = MapName(map), map = map, x = x, y = y }
    end
end

function QSB.TurnInPlace(q)
    if not q or not q.questID or q.questID == 0 then return nil end
    -- Questie's answer is kept; the game's marker or "unknown" is asked again after
    -- 10s (Questie may still be loading, and the marker can move)
    local now = GetTime and GetTime() or 0
    local hit = placeCache[q.questID]
    if hit and (hit.final or now - hit.at < 10) then return hit.v end
    local v = FromQuestie(q.questID)
    local final = v ~= nil
    local c = FromClient(q)
    if v and not v.zone and c then v.zone = c.zone end
    if v and not v.map and c and c.map then v.map, v.x, v.y = c.map, c.x, c.y end
    v = v or c
    if v and not v.zone then v = nil end
    placeCache[q.questID] = { v = v, at = now, final = final and v ~= nil }
    return v
end

---------------------------------------------------------------------------
-- Distances: yards in the world, for nearest-first ordering
---------------------------------------------------------------------------
local function World(map, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) or not map or not x then return nil end
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if not ok or not cont or not pos then return nil end
    local wx, wy = pos:GetXY()
    return cont, wx, wy
end

local function PlayerWorld()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    if IsSecret(x) then return nil end
    return World(map, x, y)
end

local FAR = 1e9
local function Dist(c1, x1, y1, c2, x2, y2)
    if not c1 or not c2 then return FAR end
    if c1 ~= c2 then return FAR / 2 end -- another continent: last
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end

-- greedy nearest-next from where you stand
function QSB.NearestOrder(list)
    local pc, px, py = PlayerWorld()
    local left, out = {}, {}
    for _, q in ipairs(list) do
        local pl = QSB.TurnInPlace(q)
        local c, x, y
        if pl and pl.map then c, x, y = World(pl.map, pl.x, pl.y) end
        left[#left + 1] = { q = q, c = c, x = x, y = y }
    end
    while #left > 0 do
        local best, bestD = 1, nil
        for i, e in ipairs(left) do
            local d = Dist(pc, px, py, e.c, e.x, e.y)
            if not bestD or d < bestD then best, bestD = i, d end
        end
        local e = table.remove(left, best)
        out[#out + 1] = e.q
        if e.c then pc, px, py = e.c, e.x, e.y end
    end
    return out
end

---------------------------------------------------------------------------
-- Chain route: every hand-in at one place, nearest first
---------------------------------------------------------------------------
-- Shortest Path takes the whole list as one journey with a stop per NPC. Each
-- stop waits until you've handed that quest in; then the rest are re-planned
-- from where you are, so it is always nearest-next. Without Shortest Path the
-- game's arrow points at one hand-in after another.
local OWNER = "PhyzQuestBar"
local chain -- { zone, pending = {[questID] = true}, spf }

function QSB.ChainZone() return chain and chain.zone or nil end

local function SPFApi()
    local api = ShortestPathForever and ShortestPathForever.API
    if type(api) == "table" and api.NavigateRoute then return api end
end

function QSB.StopChain(quiet)
    if not chain then return false end
    local c = chain
    chain = nil
    local api = SPFApi()
    if c.spf and api and api.Cancel then pcall(api.Cancel, OWNER) end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID and c.current then
        local now = C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
        if not now or now == c.current then C_SuperTrack.SetSuperTrackedQuestID(0) end
    end
    if not quiet then Print("Stopped the turn-in route for " .. c.zone .. ".") end
    QSB.QueueRefresh()
    return true
end

local function StillReady()
    local list = {}
    for _, g in ipairs(QSB.ReadLog()) do
        for _, q in ipairs(g.quests) do
            if q.complete and chain.pending[q.questID] then list[#list + 1] = q end
        end
    end
    return list
end

local function AdvanceChain()
    if not chain then return end
    local list = StillReady()
    if #list == 0 then
        local zone = chain.zone
        QSB.StopChain(true)
        Print("All handed in at " .. zone .. "!")
        return
    end
    local ordered = QSB.NearestOrder(list)
    local api = SPFApi()
    if api then
        local stops = {}
        for _, q in ipairs(ordered) do
            local pl = QSB.TurnInPlace(q)
            if pl and pl.map and pl.x then
                stops[#stops + 1] = { map = pl.map, x = pl.x, y = pl.y, hold = true, questID = q.questID,
                    title = (pl.npc and (pl.npc .. ": ") or "") .. q.title }
            end
        end
        if #stops > 0 then
            local ok, started = pcall(api.NavigateRoute, OWNER, stops)
            if ok and started then
                chain.spf, chain.current = true, ordered[1].questID
                QSB.QueueRefresh()
                return
            end
        end
    end
    -- no Shortest Path (or it couldn't plan): the game's arrow, one at a time
    chain.spf = false
    chain.current = ordered[1].questID
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then C_SuperTrack.SetSuperTrackedQuestID(chain.current) end
    QSB.QueueRefresh()
end

-- Click once to start, again to stop.
function QSB.ChainTurnIns(zone, quests)
    if chain and chain.zone == zone then QSB.StopChain(); return "stopped" end
    if InCombatLockdown and InCombatLockdown() then
        Print("Routes can't be planned in combat. Try again once it's over.")
        return nil
    end
    if not quests or #quests == 0 then return nil end
    if chain then QSB.StopChain(true) end
    if QSB.StopRoute then QSB.StopRoute(true) end
    chain = { zone = zone, pending = {} }
    for _, q in ipairs(quests) do chain.pending[q.questID] = true end
    AdvanceChain()
    if not chain then return nil end
    local first = QSB.NearestOrder(StillReady())
    local names = {}
    for i, q in ipairs(first) do names[i] = q.title end
    Print("Turn-in route for " .. zone .. ", nearest first: " .. table.concat(names, ", ") .. "."
        .. (chain.spf and "" or (QSB.HasRouter() and "" or " (Install Shortest Path Forever for full routes.)")))
    return chain.spf and "route" or "arrow"
end

local function OnTurnedIn(questID)
    if not chain or not questID or not chain.pending[questID] then return end
    chain.pending[questID] = nil
    C_Timer.After(0.5, AdvanceChain) -- let the log update, then re-plan from here
end

---------------------------------------------------------------------------
-- Fastest route to a quest
---------------------------------------------------------------------------
-- With Shortest Path Forever installed, its "travel to my tracked quest" plans the
-- quickest journey: walking, flight paths, boats, zeppelins, lifts, the tram,
-- portals and teleports, to the objective area (or the turn-in NPC once the quest
-- is done). We make the quest the tracked one and start that journey.
-- Without it, the game's own quest arrow points the way (straight line only).
local SPF_BUTTON = "ShortestPathForeverTravelToTrackedQuestButton"

function QSB.HasRouter()
    local b = _G[SPF_BUTTON]
    return type(b) == "table" and b.Click ~= nil
end

local function SuperTrack(questID)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        C_SuperTrack.SetSuperTrackedQuestID(questID)
        return true
    end
    return false
end

local SPF_CLEAR = "ShortestPathForeverClearJourneyButton"
local routed -- { questID, title, addedWatch, spf }

local function SPFActive()
    local api = ShortestPathForever and ShortestPathForever.API
    if api and api.Active then
        local ok, active = pcall(api.Active)
        if ok then return active == true end
    end
    return true -- can't tell: trust what we started
end

-- Is this quest the one we're routing to right now?
function QSB.IsRouted(q)
    if not routed or not q or routed.questID ~= q.questID then return false end
    if routed.spf and not SPFActive() then
        routed = nil -- the journey ended on its own (you arrived, or cancelled it elsewhere)
        return false
    end
    return true
end

function QSB.StopRoute(quiet)
    if not routed then return false end
    local r = routed
    routed = nil
    if r.spf then
        local clear = _G[SPF_CLEAR]
        if type(clear) == "table" and clear.Click then clear:Click("LeftButton") end
    end
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.SetSuperTrackedQuestID
        and C_SuperTrack.GetSuperTrackedQuestID() == r.questID then
        C_SuperTrack.SetSuperTrackedQuestID(0)
    end
    -- we tracked it to route there, so untrack it again
    if r.addedWatch and QSB.IsTracked(r.questID) then
        if C_QuestLog and C_QuestLog.RemoveQuestWatch then C_QuestLog.RemoveQuestWatch(r.questID) end
    end
    if not quiet then Print("Stopped the route to " .. r.title .. ".") end
    QSB.QueueRefresh()
    return true
end

-- Click once to route there, click again to stop.
function QSB.RouteTo(q)
    if not q or not q.questID or q.questID == 0 then return nil end
    if QSB.IsRouted(q) then
        QSB.StopRoute()
        return "stopped"
    end
    if InCombatLockdown and InCombatLockdown() then
        Print("Routes can't be planned in combat. Try again once it's over.")
        return nil
    end
    if routed then QSB.StopRoute(true) end -- switching to another quest
    if QSB.StopChain then QSB.StopChain(true) end
    local addedWatch = not q.tracked
    if QSB.HasRouter() then
        SuperTrack(q.questID)
        if addedWatch then QSB.ToggleTrack(q) end -- so it shows in the tracker too
        _G[SPF_BUTTON]:Click("LeftButton")
        routed = { questID = q.questID, title = q.title, addedWatch = addedWatch, spf = true }
        QSB.QueueRefresh()
        return "route"
    end
    if SuperTrack(q.questID) then
        if addedWatch then QSB.ToggleTrack(q) end
        routed = { questID = q.questID, title = q.title, addedWatch = addedWatch, spf = false }
        Print("Following " .. q.title .. " with the game's quest arrow. Install Shortest Path Forever for full routes with flight paths, boats and portals.")
        QSB.QueueRefresh()
        return "arrow"
    end
    Print("No way to point you to that quest on this client. Shortest Path Forever adds full routes.")
    return nil
end

---------------------------------------------------------------------------
-- Actions on a quest
---------------------------------------------------------------------------
function QSB.IsActive(q)
    if db and db.settings.followPhyzLeveling then return db.guideQuestID == q.questID end
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        return C_SuperTrack.GetSuperTrackedQuestID() == q.questID
    end
    return db and db.activeQuestID == q.questID
end

function QSB.SyncLevelingQuest()
    if not db then return end
    local id
    local api = PhyzLevelingQuestBarAPI
    if db.settings.followPhyzLeveling and api and api.GetCurrentStepQuestIDs then
        local available = {}
        for index = 1, NumEntries() do
            local quest = Entry(index)
            if quest and not quest.isHeader and quest.questID then available[quest.questID] = true end
        end
        for _, questID in ipairs(api.GetCurrentStepQuestIDs()) do
            if available[questID] then id = questID; break end
        end
    end
    if db.guideQuestID ~= id then
        db.guideQuestID = id
        if db.settings.followPhyzLeveling and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
            C_SuperTrack.SetSuperTrackedQuestID(id or 0)
        end
        QSB.QueueRefresh()
    end
end

function QSB.ToggleActive(q)
    if db.settings.followPhyzLeveling then
        Print("Active quest follows Phyz Leveling. Turn this off in settings to select a quest manually.")
        return
    end
    local id = QSB.IsActive(q) and 0 or q.questID
    db.activeQuestID = id > 0 and id or nil
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        C_SuperTrack.SetSuperTrackedQuestID(id)
    end
    QSB.QueueRefresh()
end

function QSB.HasVoice(q)
    local v = VoiceOver
    if not (v and v.Player and v.QuestOverlayUI and v.QuestOverlayUI.QueuedLine and v.DataModules and v.Enums) then return false end
    if Spoken and Spoken.IsPartOn and not Spoken:IsPartOn("quests") then return false end
    return v.DataModules:PrepareSound({ event = v.Enums.SoundEvent.QuestAccept, questID = q.questID }) and true or false
end

function QSB.IsSpeaking(q)
    return QSB.HasVoice(q) and VoiceOver.QuestOverlayUI:QueuedLine(q.questID) ~= nil
end

function QSB.ToggleVoice(q)
    if not QSB.HasVoice(q) then return end
    local v = VoiceOver
    local queued = v.QuestOverlayUI:QueuedLine(q.questID)
    if queued then v.Player:Remove(queued) else
        local kind, id = v.DataModules:GetQuestLogQuestGiverTypeAndID(q.questID)
        v.Player:PlayNow({ event = v.Enums.SoundEvent.QuestAccept, questID = q.questID,
            name = id and v.DataModules:GetObjectName(kind, id) or "Unknown Name", title = q.title,
            unitGUID = id and v.Enums.GUID:CanHaveID(kind) and v.Utils:MakeGUID(kind, id) or nil,
            unitIsObjectOrItem = id ~= nil and not v.Enums.GUID:IsCreature(kind), origin = "Phyz's Quest bar" })
    end
    QSB.QueueRefresh()
end

function QSB.OpenQuest(q)
    if QuestLogFrame and SelectQuestLogEntry then
        SelectQuestLogEntry(q.index)
        if not QuestLogFrame:IsShown() then ShowUIPanel(QuestLogFrame) end
        if QuestLog_Update then QuestLog_Update() end
    elseif QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(q.questID)
    elseif ToggleQuestLog then
        ToggleQuestLog()
    end
end

function QSB.LinkQuest(q)
    local link = (C_QuestLog and C_QuestLog.GetQuestLink and C_QuestLog.GetQuestLink(q.questID))
        or (GetQuestLink and GetQuestLink(q.questID))
    if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
end

function QSB.ToggleTrack(q)
    if C_QuestLog and C_QuestLog.AddQuestWatch then
        if q.tracked then C_QuestLog.RemoveQuestWatch(q.questID) else C_QuestLog.AddQuestWatch(q.questID) end
    elseif AddQuestWatch then
        if q.tracked then RemoveQuestWatch(q.index) else AddQuestWatch(q.index) end
    end
    QSB.QueueRefresh()
end

---------------------------------------------------------------------------
-- Share every quest in the zone you're in with your party
---------------------------------------------------------------------------
-- The game shares the quest selected in the log, one at a time, so we walk the
-- zone's quests with a short gap between each. If a party member is busy (they
-- still have the last shared quest open), that quest goes to the back of the
-- queue and is tried again, up to SHARE_TRIES times.
local SHARE_GAP, SHARE_TRIES = 1.5, 3
local share -- { zone, queue = {q...}, tries = {[id]=n}, current, sent, oldSel }

function QSB.InGroup()
    if IsInGroup then return IsInGroup() and true or false end
    return (GetNumGroupMembers and GetNumGroupMembers() or 0) > 0
end

function QSB.Sharing() return share ~= nil end

local function Select(q)
    if C_QuestLog and C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(q.questID)
    elseif SelectQuestLogEntry then SelectQuestLogEntry(q.index) end
end

local function RestoreSelection(old)
    if not old or old == 0 then return end
    if C_QuestLog and C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(old)
    elseif SelectQuestLogEntry then SelectQuestLogEntry(old) end
end

local function Pushable(q)
    if C_QuestLog and C_QuestLog.IsPushableQuest then return C_QuestLog.IsPushableQuest(q.questID) and true or false end
    if GetQuestLogPushable then Select(q); return GetQuestLogPushable() and true or false end
    return true
end

---------------------------------------------------------------------------
-- Who in the party has a quest
---------------------------------------------------------------------------
local function PartyUnits()
    local units = {}
    if not QSB.InGroup() then return units end
    if IsInRaid and IsInRaid() then return units end -- markers are for 5-man parties
    local n = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or ((GetNumGroupMembers and GetNumGroupMembers() or 1) - 1)
    for i = 1, math.min(4, n or 0) do
        local u = "party" .. i
        if not UnitExists or UnitExists(u) then units[#units + 1] = u end
    end
    return units
end

local function UnitOnQuest(unit, q)
    local ok, on
    if C_QuestLog and C_QuestLog.IsUnitOnQuest then
        ok, on = pcall(C_QuestLog.IsUnitOnQuest, unit, q.questID)
    elseif IsUnitOnQuest then
        ok, on = pcall(IsUnitOnQuest, q.index, unit)
    else
        return nil
    end
    if not ok or IsSecret(on) then return nil end
    return on == true or on == 1
end

-- { have = {names}, missing = {names} } or nil when solo / the client can't tell
function QSB.PartyOn(q)
    local units = PartyUnits()
    if #units == 0 then return nil end
    local have, missing = {}, {}
    for _, u in ipairs(units) do
        local on = UnitOnQuest(u, q)
        if on == nil then return nil end
        local name = UnitName and UnitName(u)
        if not name or IsSecret(name) then name = u end
        if on then have[#have + 1] = name else missing[#missing + 1] = name end
    end
    return { have = have, missing = missing }
end

-- everyone in the party already has it: no point sharing
local function EveryoneHas(q)
    local p = QSB.PartyOn(q)
    return p ~= nil and #p.missing == 0
end

local function FinishShare(msg)
    if not share then return end
    local s = share
    share = nil
    RestoreSelection(s.oldSel)
    if not msg then
        if s.sent == 1 and s.single then
            msg = "Shared " .. s.single .. " with your party."
        else
            msg = "Shared " .. s.sent .. " quest" .. (s.sent == 1 and "" or "s") .. (s.zone and (" from " .. s.zone) or "") .. " with your party."
        end
    end
    Print(msg)
    QSB.Refresh()
end

local function ShareStep()
    if not share then return end
    if not QSB.InGroup() then return FinishShare("Stopped sharing: you're no longer in a group.") end
    local q = table.remove(share.queue, 1)
    if not q then return FinishShare() end
    share.current = q
    Select(q)
    QuestLogPushQuest()
    share.tries[q.questID] = (share.tries[q.questID] or 0) + 1
    if share.tries[q.questID] == 1 then share.sent = share.sent + 1 end
    C_Timer.After(SHARE_GAP, ShareStep)
end

local function SelectedNow()
    return (C_QuestLog and C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest())
        or (GetQuestLogSelection and GetQuestLogSelection())
end

local function PushableKeepSel(q)
    local oldSel = SelectedNow()
    local ok = Pushable(q)
    RestoreSelection(oldSel)
    return ok
end

-- Queue quests to share. Joins a share that is already running.
local function QueueShare(list, zone)
    if share then
        local queued = {}
        for _, q in ipairs(share.queue) do queued[q.questID] = true end
        if share.current then queued[share.current.questID] = true end
        for _, q in ipairs(list) do
            if not queued[q.questID] and not share.tries[q.questID] then share.queue[#share.queue + 1] = q end
        end
        share.single = nil
        return
    end
    share = { zone = zone, queue = list, tries = {}, sent = 0, oldSel = SelectedNow(),
              single = (#list == 1 and not zone) and list[1].title or nil }
    QSB.Refresh()
    ShareStep()
end

local function CanShare()
    if not QSB.InGroup() then Print("Join a party first, then share your quests."); return false end
    if not QuestLogPushQuest then Print("This client can't share quests."); return false end
    return true
end

function QSB.ShareZone()
    if share and share.zone then return Print("Already sharing quests, give it a moment.") end
    if not CanShare() then return end
    local g = QSB.HereGroup(QSB.ReadLog())
    if not g then return Print("You have no quests for " .. (currentZone or "this zone") .. ".") end
    local queue, skipped, everyone = {}, 0, 0
    for _, q in ipairs(g.quests) do
        if not PushableKeepSel(q) then skipped = skipped + 1
        elseif EveryoneHas(q) then everyone = everyone + 1
        else queue[#queue + 1] = q end
    end
    local notes = {}
    if skipped > 0 then notes[#notes + 1] = skipped .. " can't be shared" end
    if everyone > 0 then notes[#notes + 1] = everyone .. " the whole party already has" end
    local note = #notes > 0 and (" (" .. table.concat(notes, ", ") .. ")") or ""
    if #queue == 0 then
        return Print("Nothing to share from " .. g.zone .. note .. ".")
    end
    Print("Sharing " .. #queue .. " quest" .. (#queue == 1 and "" or "s") .. " from " .. g.zone .. note .. "...")
    QueueShare(queue, g.zone)
end

function QSB.ShareQuest(q)
    if not CanShare() then return end
    if not PushableKeepSel(q) then return Print(q.title .. " can't be shared.") end
    if EveryoneHas(q) then return Print("Everyone in your party already has " .. q.title .. ".") end
    QueueShare({ q }, nil)
end

function QSB.CanPush(q)
    if not QSB.InGroup() or not QuestLogPushQuest then return false end
    return PushableKeepSel(q)
end

-- Auto-share (setting, off by default): a quest you pick up while in a party is
-- shared straight away. Quests the whole party already has (for example one
-- a friend just shared with you) are not sent back.
local function FindQuest(questID)
    for _, g in ipairs(QSB.ReadLog()) do
        for _, q in ipairs(g.quests) do if q.questID == questID then return q end end
    end
end

local function OnQuestAccepted(a, b)
    if not db or not db.settings.autoShare or not QSB.InGroup() or not QuestLogPushQuest then return end
    local questID = b or a
    if type(questID) ~= "number" or questID == 0 then return end
    C_Timer.After(1, function()
        if not QSB.InGroup() then return end
        local q = FindQuest(questID)
        if q and PushableKeepSel(q) and not EveryoneHas(q) then QueueShare({ q }, nil) end
    end)
end

---------------------------------------------------------------------------
-- Abandon (asks first)
---------------------------------------------------------------------------
function QSB.AbandonNow(q)
    if C_QuestLog and C_QuestLog.SetSelectedQuest and C_QuestLog.SetAbandonQuest then
        C_QuestLog.SetSelectedQuest(q.questID)
        C_QuestLog.SetAbandonQuest()
        C_QuestLog.AbandonQuest()
    elseif SelectQuestLogEntry and SetAbandonQuest then
        SelectQuestLogEntry(q.index)
        SetAbandonQuest()
        AbandonQuest()
    end
    Print("Abandoned " .. q.title .. ".")
    QSB.QueueRefresh()
end

function QSB.Abandon(q)
    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs.PHYZQUESTBAR_ABANDON = StaticPopupDialogs.PHYZQUESTBAR_ABANDON or {
            text = "Abandon \"%s\"?", button1 = YES or "Yes", button2 = NO or "No",
            OnAccept = function(self, data) QSB.AbandonNow(data or self.data) end,
            timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
        }
        local dialog = StaticPopup_Show("PHYZQUESTBAR_ABANDON", q.title, nil, q)
        if dialog then dialog.data = q end
    else
        QSB.AbandonNow(q)
    end
end

-- "Name is busy." comes back as a system message: try that quest again later
local busyPattern
local function OnSystemMessage(msg)
    if not share or not share.current or type(msg) ~= "string" or IsSecret(msg) then return end
    if not busyPattern then
        local fmt = ERR_QUEST_PUSH_BUSY_S or "%s is busy."
        busyPattern = "^" .. fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", ".+") .. "$"
    end
    if msg:find(busyPattern) then
        local q = share.current
        if (share.tries[q.questID] or 0) < SHARE_TRIES then
            share.current = nil
            share.queue[#share.queue + 1] = q
        end
    end
end

---------------------------------------------------------------------------
-- Refresh plumbing
---------------------------------------------------------------------------
function QSB.Refresh(groups)
    if not QSB.UI then return end
    groups = groups or QSB.ReadLog()
    QSB.UI.Draw(QSB.Ordered(groups))
end

local queued = false
function QSB.QueueRefresh()
    if queued then return end
    queued = true
    C_Timer.After(0.2, function()
        queued = false
        QSB.Refresh()
    end)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function OnOff(v) return v and "|cff33ff66on|r" or "|cffff6666off|r" end

local function Slash(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local s = db.settings
    if cmd == "" or cmd == "toggle" then
        QSB.UI.ToggleShown()
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        QSB.UI.ToggleSettings()
    elseif cmd == "opacity" and tonumber(arg) then
        local v = tonumber(arg)
        if v > 1 then v = v / 100 end
        s.opacity = math.max(0.1, math.min(1, v))
        QSB.UI.ApplyOpacity()
        Print("Opacity " .. math.floor(s.opacity * 100 + 0.5) .. "%")
    elseif cmd == "minimap" then
        s.minimap = not s.minimap
        QSB.UI.ApplyMinimap()
        Print("Minimap button: " .. OnOff(s.minimap))
    elseif cmd == "turnin" or cmd == "done" then
        if not QSB.UI.IsShown() then QSB.UI.ToggleShown() end
        QSB.UI.SelectTab("turnin")
    elseif cmd == "share" then
        QSB.ShareZone()
    elseif cmd == "route" or cmd == "go" then
        -- the quest you're tracking at the top of this zone, else the first one here
        local g = QSB.HereGroup(QSB.ReadLog())
        local pick
        for _, q in ipairs(g and g.quests or {}) do
            if q.tracked then pick = q; break end
        end
        pick = pick or (g and g.quests[1])
        if pick then QSB.RouteTo(pick) else Print("No quests here to route to.") end
    elseif cmd == "autoshare" then
        s.autoShare = not s.autoShare
        Print("Auto-share new quests with your party: " .. OnOff(s.autoShare))
    elseif cmd == "grey" or cmd == "gray" then
        s.hideGrey = not s.hideGrey
        Print("Hide grey (low level) quests: " .. OnOff(s.hideGrey))
        QSB.Refresh()
    elseif cmd == "min" or cmd == "minimize" then
        QSB.UI.ToggleMinimized()
    elseif cmd == "auto" then
        s.autoZone = not s.autoZone
        Print("Open the zone you're in automatically: " .. OnOff(s.autoZone))
        QSB.Refresh()
    elseif cmd == "tracker" then
        s.hideTracker = not s.hideTracker
        Print("Hide Blizzard's quest tracker: " .. OnOff(s.hideTracker) .. (s.hideTracker and "" or " (a /reload brings it back fully)"))
        QSB.UI.ApplyTracker(true)
    elseif cmd == "lock" then
        s.locked = not s.locked
        Print("Panel locked: " .. OnOff(s.locked))
    elseif cmd == "objectives" then
        s.showObjectives = not s.showObjectives
        Print("Show objectives: " .. OnOff(s.showObjectives))
        QSB.Refresh()
    elseif cmd == "scale" and tonumber(arg) then
        s.scale = math.max(0.5, math.min(2, tonumber(arg)))
        QSB.UI.ApplyScale()
        Print("Scale " .. s.scale)
    elseif cmd == "reset" then
        wipe(db.pinned)
        QSB.UI.ResetPosition()
        Print("Back to the default size and position, and all zones unpinned.")
        QSB.Refresh()
    else
        Print("/pqb - show/hide the sidebar")
        Print("/pqb auto - open the zone you're in automatically (" .. OnOff(s.autoZone) .. ")")
        Print("/pqb tracker - hide Blizzard's quest tracker (" .. OnOff(s.hideTracker) .. ")")
        Print("/pqb objectives - show objective lines (" .. OnOff(s.showObjectives) .. ")")
        Print("/pqb settings - open the settings (or click the cog on the window)")
        Print("/pqb turnin - show the Turn in tab (every finished quest)")
        Print("/pqb share - share all your quests for this zone with your party")
        Print("/pqb route - fastest route to your tracked quest in this zone (or Ctrl-click any quest)")
        Print("/pqb autoshare - share quests you pick up with your party (" .. OnOff(s.autoShare) .. ")")
        Print("/pqb grey - hide grey (low level) quests (" .. OnOff(s.hideGrey) .. ")")
        Print("/pqb min - minimize/restore   /pqb minimap - minimap button on/off")
        Print("/pqb opacity 70 | lock | scale 0.8 | reset")
        Print("Click a zone to open/close it, Shift-click to pin it open. Click a quest to show/hide its objectives, Shift-click to link, right-click for more.")
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
QSB.frame = frame

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        PhyzQuestBarDB = PhyzQuestBarDB or {}
        db = PhyzQuestBarDB
        db.settings = db.settings or {}
        db.pinned = db.pinned or {}
        if db.settings.followPhyzLeveling == nil and PhyzLevelingQuestBarAPI then
            db.settings.followPhyzLeveling = true
        end
        db.guideQuestID = nil
        for k, v in pairs(DEFAULTS) do if db.settings[k] == nil then db.settings[k] = v end end
        if QSB.UI then QSB.UI.Init(db) end
        QSB.SyncLevelingQuest()
        QSB.levelingTicker = C_Timer.NewTicker(0.5, QSB.SyncLevelingQuest)
        if Spoken and Spoken.RegisterCallback then
            for _, callback in ipairs({ "VOICE_PACKS_LOADED", "PART_SWITCHED", "AUDIO_CHANGED" }) do
                Spoken:RegisterCallback(callback, function() QSB.QueueRefresh() end)
            end
        end
        for _, ev in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "UNIT_QUEST_LOG_CHANGED", "QUEST_ACCEPTED",
                              "QUEST_REMOVED", "QUEST_TURNED_IN", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED",
                              "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
                              "GROUP_ROSTER_UPDATE", "CHAT_MSG_SYSTEM", "PLAYER_LEVEL_UP",
                              "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "PLAYER_REGEN_DISABLED", "SUPER_TRACKING_CHANGED" }) do
            pcall(frame.RegisterEvent, frame, ev)
        end
        local spf = ShortestPathForever and ShortestPathForever.API
        if spf and spf.Subscribe then pcall(spf.Subscribe, function() QSB.QueueRefresh() end) end
        SLASH_PHYZQUESTBAR1 = "/pqb"
        SLASH_PHYZQUESTBAR2 = "/phyzquestbar"
        SlashCmdList.PHYZQUESTBAR = Slash
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS" then
        if db then OnZoneChanged() end
    elseif event == "CHAT_MSG_SYSTEM" then
        OnSystemMessage(...)
    elseif event == "QUEST_ACCEPTED" then
        OnQuestAccepted(...)
        QSB.QueueRefresh()
    elseif event == "BAG_UPDATE_COOLDOWN" then
        if QSB.UI and QSB.UI.UpdateItemCooldowns then QSB.UI.UpdateItemCooldowns() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- last moment before combat locks the item buttons: put them right
        if QSB.UI and QSB.UI.UpdateItemButtons then QSB.UI.UpdateItemButtons() end
    elseif event == "QUEST_TURNED_IN" then
        OnTurnedIn(...)
        QSB.QueueRefresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if db then QSB.UI.ApplyTracker(); QSB.QueueRefresh() end
    elseif db then
        QSB.QueueRefresh()
    end
end)
frame:RegisterEvent("PLAYER_LOGIN")

function PhyzQuestBar_Toggle() QSB.UI.ToggleShown() end
