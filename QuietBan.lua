-- QuietBan.lua
-- Banned players: their chat is hidden, their group, guild and channel invites,
-- trades and duels are declined. Own list, no size limit, Blizzard ignore list untouched.
-- Quiet mode declines the same requests from everyone.
local addonName, NS = ...
local L = NS.L

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_RAID_WARNING",
}
local PREFIX = "|cff66ccffQuietBan|r: "

local db                    -- QuietBanDB: players
local canAccess = canaccessvalue or function(_) return true end
local ownKey
local frame = CreateFrame("Frame")

local function Print(text) print(PREFIX .. text) end

-- Lower case for UTF-8 text. The client has no such function: string.lower only folds ASCII.
-- ponytail: folds Latin-1 (À-Þ) and Cyrillic (Ѐ-Я) only, add a range when a name outside them fails to match.
local function Lower(text)
    text = text:lower()
    -- U+00C0-U+00DE except the multiplication sign U+00D7.
    text = text:gsub("\195([\128-\150\152-\158])", function(char)
        return "\195" .. string.char(char:byte() + 32)
    end)
    text = text:gsub("\208([\128-\175])", function(char)
        local byte = char:byte()
        if byte < 144 then return "\209" .. string.char(byte + 16) end   -- U+0400-U+040F
        if byte < 160 then return "\208" .. string.char(byte + 32) end   -- U+0410-U+041F
        return "\209" .. string.char(byte - 32)                          -- U+0420-U+042F
    end)
    return text
end

-- WoW Forever: a character has a first name and a surname ("Marcel Pagnol") and no realm
-- in its name.
local function HasSurnames()
    return RegionalUniqueNamesEnabled ~= nil and RegionalUniqueNamesEnabled() == true
end

-- Name as shown to the player, from the two returns of UnitNames.
local function JoinName(name, second)
    if type(second) ~= "string" or second == "" then return name end
    return name .. (HasSurnames() and " " or "-") .. second
end

-- Ban list key. nil when the client hides the value.
-- With surnames: "Marcel Pagnol" or "Marcel-Pagnol" -> "marcel-pagnol", whatever separator
-- the chat, a link or the player used. Otherwise: "Name" or "Name-Realm" -> "name-realm".
local function NormalizeName(name)
    if type(name) ~= "string" or not canAccess(name) then return nil end
    if HasSurnames() then
        name = name:match("^[%s-]*(.-)[%s-]*$"):gsub("[%s-]+", "-")
        if name == "" then return nil end
        return Lower(name)
    end
    name = name:gsub("%s", "")
    if name == "" then return nil end
    if not name:find("-", 1, true) then
        local realm = GetNormalizedRealmName()
        if not realm then return nil end
        name = name .. "-" .. realm
    end
    return Lower(name)
end

local function IsBanned(key)
    return key ~= nil and db.players[key] ~= nil
end

-- Quiet mode: requests of the chosen kinds are declined from everyone, banned or not.
local QUIET_KINDS = { "party", "guild", "channel", "trade", "duel" }

local function IsQuiet(kind)
    return db.quiet.enabled and db.quiet[kind]
end

-- Name and realm of a unit, or first name and surname on WoW Forever: Blizzard reads the
-- surname with UnitNameUnmodified, UnitFullName is not proven to return it.
local function UnitNames(unit)
    return (HasSurnames() and UnitNameUnmodified or UnitFullName)(unit)
end

local function UnitKey(unit)
    local name, realm = UnitNames(unit)
    if not canAccess(name) or not canAccess(realm) or not name then return nil end
    return NormalizeName(realm and realm ~= "" and (name .. "-" .. realm) or name)
end

--------------------------------------------------------------------------------
-- Chat filter, invites, trades, duels
--------------------------------------------------------------------------------
-- Called once per chat frame per message. Blizzard skips it when a value is secret.
-- Blizzard also runs filters on the player's own messages: never hide them.
local function ChatFilter(_, _, _, sender)
    local key = NormalizeName(sender)
    ownKey = ownKey or UnitKey("player")
    if not key or key == ownKey then return false end
    return IsBanned(key)
end

-- System lines ("X invites you", "you declined X's invitation", duel/trade notices)
-- that name a player we just blocked are hidden for a few seconds.
local SYSTEM_HIDE_SECONDS = 3
local recentlyBlocked = {}   -- short name in lower case -> GetTime() expiry

local function NoteBlocked(key)
    if not key then return end   -- quiet mode can decline a sender whose name is hidden
    recentlyBlocked[key:match("^[^-]+")] = GetTime() + SYSTEM_HIDE_SECONDS
end

local function SystemFilter(_, _, message)
    if type(message) ~= "string" or not canAccess(message) then return false end
    -- A line linking a banned player is hidden even if it arrives before the request event.
    for linkName in message:gmatch("|Hplayer:([^:|]+)") do
        if IsBanned(NormalizeName(linkName)) then return true end
    end
    if next(recentlyBlocked) == nil then return false end
    local text, now = Lower(message), GetTime()
    for name, expiry in pairs(recentlyBlocked) do
        if expiry < now then
            recentlyBlocked[name] = nil
        -- Whole word only: bytes 128-255 count as letters so "ana" does not match "anaïs".
        elseif text:find("%f[%a\128-\255]" .. name .. "%f[^%a\128-\255]") then
            return true
        end
    end
    return false
end

local function HidePopupLater(which)
    C_Timer.After(0, function() StaticPopup_Hide(which) end)
end

-- Requests that Blizzard_Game handles before any addon frame sees them: its handler plays
-- the sound and shows the popup first. QuietBan takes these events over at load, declines
-- a banned sender silently and hands anyone else back to Blizzard's handler.
-- nameIndex: payload position of the sender. popup: dialog closed when the takeover is unavailable.
-- kind: the quiet mode setting that declines this request from everyone.
local REQUESTS = {
    PARTY_INVITE_REQUEST = { handler = "HandlePartyInviteRequest", nameIndex = 1, popup = "PARTY_INVITE",
        kind = "party", decline = function() DeclineGroup() end },
    TRADE_REQUEST = { handler = "HandleTradeRequest", nameIndex = 1, popup = "TRADE",
        kind = "trade", decline = function() CancelTrade() end },   -- hiding the popup alone would leave the request open
    DUEL_REQUESTED = { handler = "HandleDuelRequested", nameIndex = 1, popup = "DUEL_REQUESTED",
        kind = "duel", decline = function() CancelDuel() end },
    DUEL_TO_THE_DEATH_REQUESTED = { handler = "HandleDuelToTheDeathRequested", nameIndex = 1,
        popup = "DUEL_TO_THE_DEATH_REQUESTED", kind = "duel", decline = function() CancelDuel() end },
    -- Taken over too, so a banned sender's popup never shows. Known cost: for anyone else
    -- the popup is shown from addon code, its OnAccept runs tainted and writes the chat
    -- frame's channel list. Under chat lockdown, channel lines of that chat frame can then
    -- raise errors and go missing until /reload.
    CHANNEL_INVITE_REQUEST = { handler = "HandleChannelInviteRequest", nameIndex = 2,
        popup = "CHAT_CHANNEL_INVITE", kind = "channel", decline = function(channel) DeclineChannelInvite(channel) end },
}
local ownedRequests = {}   -- event -> true when QuietBan routes it instead of Blizzard_Game

local function TakeOverRequestEvents()
    if not (GameEvent and GameEvent.UnregisterInternalEvent) then return end
    for event, request in pairs(REQUESTS) do
        if request.handler and GameEvent[request.handler] then
            GameEvent.UnregisterInternalEvent(event)
            ownedRequests[event] = true
        end
    end
end

local function OnRequest(event, ...)
    local request = REQUESTS[event]
    local key = NormalizeName((select(request.nameIndex, ...)))
    if not IsBanned(key) and not IsQuiet(request.kind) then
        -- Not banned: hand the request back to Blizzard (popup, sound, icon flash).
        if ownedRequests[event] then GameEvent[request.handler](nil, event, ...) end
        return
    end
    NoteBlocked(key)
    request.decline(...)
    if ownedRequests[event] then return end   -- nothing was shown
    C_Timer.After(0, function()
        StaticPopup_Hide(request.popup)
        if event == "PARTY_INVITE_REQUEST" and LFGInvitePopup and LFGInvitePopup:IsShown() then
            StaticPopupSpecial_Hide(LFGInvitePopup)
        end
    end)
end

-- Guild invites are not routed by Blizzard_Game on Forever: GuildInviteFrame listens itself,
-- if it is loaded. QuietBan takes its event over the same way.
local ownsGuildInvite = false

local function TakeOverGuildInvite()
    if not (GuildInviteFrame and GuildInviteFrame_OnEvent) then return end
    GuildInviteFrame:UnregisterEvent("GUILD_INVITE_REQUEST")
    ownsGuildInvite = true
end

local function OnGuildInvite(inviter, ...)
    local key = NormalizeName(inviter)
    if not IsBanned(key) and not IsQuiet("guild") then
        if ownsGuildInvite then
            GuildInviteFrame_OnEvent(GuildInviteFrame, "GUILD_INVITE_REQUEST", inviter, ...)
        end
        return
    end
    NoteBlocked(key)
    DeclineGuild()
    if not ownsGuildInvite then HidePopupLater("GUILD_INVITE") end
end

--------------------------------------------------------------------------------
-- Ban list window: an Unban button per row.
--------------------------------------------------------------------------------
local ROW_HEIGHT = 24
local playerWindow
local RefreshList

local function CreateListWindow(frameName, title)
    local window = CreateFrame("Frame", frameName, UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(280, 360)
    window:SetPoint("CENTER")
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)

    window.TitleText:SetText(title)

    window.search = CreateFrame("EditBox", nil, window, "SearchBoxTemplate")
    window.search:SetHeight(20)
    window.search:SetPoint("TOPLEFT", 16, -30)
    window.search:SetPoint("TOPRIGHT", -12, -30)
    -- HookScript: the template's own handler keeps its clear button and placeholder.
    window.search:HookScript("OnTextChanged", function() RefreshList() end)

    local scroll = CreateFrame("ScrollFrame", nil, window, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -56)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    window.content = CreateFrame("Frame", nil, scroll)
    window.content:SetSize(240, 1)
    scroll:SetScrollChild(window.content)

    window.empty = window.content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    window.empty:SetPoint("TOPLEFT", 4, -4)
    window.empty:SetText(L.NO_BAN)

    window.rows = {}
    window:Hide()
    tinsert(UISpecialFrames, frameName)   -- Escape closes it
    return window
end

-- entries: sorted { key, label, unban }. Rows are reused, never recreated.
local function FillWindow(window, entries)
    for i, entry in ipairs(entries) do
        local row = window.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, window.content)
            row:SetSize(240, ROW_HEIGHT)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.label:SetPoint("LEFT", 4, 0)
            row.label:SetPoint("RIGHT", -80, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetWordWrap(false)
            row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.button:SetSize(74, 20)
            row.button:SetPoint("RIGHT")
            row.button:SetText(L.UNBAN)
            window.rows[i] = row
        end
        row.label:SetText(entry.label)
        row.button:SetScript("OnClick", function() entry.unban(entry.key) end)
        row:Show()
    end
    for i = #entries + 1, #window.rows do window.rows[i]:Hide() end
    window.content:SetHeight(math.max(1, #entries * ROW_HEIGHT))
    window.empty:SetShown(#entries == 0)
end

local function UnbanPlayer(key)
    if not db.players[key] then return end
    db.players[key] = nil
    Print(L.UNBANNED_PLAYER:format(key))
    RefreshList()
end

-- Sorted by label, filtered by the search box.
function RefreshList()
    if not playerWindow or not playerWindow:IsShown() then return end
    local query = Lower(playerWindow.search:GetText() or "")
    local players = {}
    for key, value in pairs(db.players) do
        -- Older bans stored true instead of the name as typed: show the key then.
        local label = type(value) == "string" and value or key
        if query == "" or Lower(label):find(query, 1, true) then
            players[#players + 1] = { key = key, label = label, unban = UnbanPlayer }
        end
    end
    table.sort(players, function(a, b) return Lower(a.label) < Lower(b.label) end)
    FillWindow(playerWindow, players)
end

local function ShowList()
    -- Not in combat: the window could not be closed until it ends.
    if InCombatLockdown() then
        UIErrorsFrame:AddExternalErrorMessage(ERR_NOT_IN_COMBAT)
        return
    end
    playerWindow = playerWindow or CreateListWindow("QuietBanPlayersFrame", L.TITLE_BANS)
    playerWindow:Show()
    RefreshList()
end

-- Global on purpose: the minimap addon compartment calls the function named by ## AddonCompartmentFunc.
function QuietBan_OnAddonCompartmentClick()
    ShowList()
end

-- label: the name as typed or as shown in game, kept for the list window.
local function BanPlayer(key, label)
    db.players[key] = label or key
    Print(L.BANNED_PLAYER:format(key))
    RefreshList()
end

-- First session only: players on the Blizzard ignore list join the ban list. The list
-- can still be empty at ADDON_LOADED, so this runs again on each ignore list update;
-- PLAYER_LOGOUT closes the import even when the list was empty.
local function ImportIgnoreList()
    if db.ignoreImported or not (C_FriendList and C_FriendList.GetNumIgnores) then return end
    local count = C_FriendList.GetNumIgnores() or 0
    if count == 0 then return end
    local added = 0
    for i = 1, count do
        local name = C_FriendList.GetIgnoreName(i)
        local key = NormalizeName(name)
        if key and not db.players[key] then
            db.players[key] = name
            added = added + 1
        end
    end
    db.ignoreImported = true
    if added > 0 then
        Print(L.IGNORE_IMPORTED:format(added))
        RefreshList()
    end
end

--------------------------------------------------------------------------------
-- Right-click menu on a player: "Ban player", or "Unban" when already banned.
--------------------------------------------------------------------------------
local MENU_TAGS = { "PLAYER", "ENEMY_PLAYER", "TARGET", "FOCUS", "PARTY", "RAID_PLAYER", "RAID", "FRIEND", "CHAT_ROSTER" }

local function AddMenuEntries(_, rootDescription, contextData)
    local name, realm, unit = contextData.name, contextData.surname, contextData.unit
    if unit and not UnitIsPlayer(unit) then return end
    if type(name) ~= "string" or not canAccess(name) or not canAccess(realm) then return end
    -- surname: the realm, or the character's surname on WoW Forever.
    local label = JoinName(name, realm)
    -- Same key as the chat filter: UnitKey uses the normalized realm of the unit.
    local key = unit and UnitKey(unit) or NormalizeName(label)
    ownKey = ownKey or UnitKey("player")
    if not key or key == ownKey then return end
    if db.players[key] then
        rootDescription:CreateButton(L.UNBAN, function() UnbanPlayer(key) end)
    else
        rootDescription:CreateButton(L.MENU_BAN_PLAYER, function() BanPlayer(key, label) end)
    end
end

local function Help()
    Print(L.HELP_BAN)
    Print(L.HELP_UNBAN)
    Print(L.HELP_LIST)
    Print(L.HELP_QUIET)
    Print(L.HELP_QUIET_KIND)
end

-- "/qb quiet [on|off]" turns quiet mode on or off, "/qb quiet <kind>" adds or removes one kind.
local function OnQuiet(kind)
    if kind == "" or kind == "on" or kind == "off" then
        if kind == "" then db.quiet.enabled = not db.quiet.enabled else db.quiet.enabled = kind == "on" end
        if not db.quiet.enabled then return Print(L.QUIET_OFF) end
        local declined = {}
        for _, name in ipairs(QUIET_KINDS) do
            if db.quiet[name] then declined[#declined + 1] = L["QUIET_" .. name:upper()] end
        end
        return Print(L.QUIET_ON:format(#declined > 0 and table.concat(declined, ", ") or L.QUIET_NONE))
    end
    if kind == "enabled" or db.quiet[kind] == nil then return Print(L.HELP_QUIET_KIND) end
    db.quiet[kind] = not db.quiet[kind]
    Print((db.quiet[kind] and L.QUIET_KIND_ON or L.QUIET_KIND_OFF):format(L["QUIET_" .. kind:upper()]))
    if not db.quiet.enabled then Print(L.QUIET_OFF) end   -- the choice applies once the mode is on
end

local function OnSlash(input)
    local command, arg = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "ban" then
        local key = arg ~= "" and NormalizeName(arg)
            or (UnitExists("target") and UnitIsPlayer("target") and UnitKey("target"))
        if not key then return Print(L.NEED_NAME) end
        local label = arg
        if arg == "" then
            -- Read only here: UnitKey just proved the target's name and realm are readable.
            label = JoinName(UnitNames("target"))
        end
        BanPlayer(key, label)
    elseif command == "unban" then
        local key = NormalizeName(arg)
        if key and db.players[key] then
            UnbanPlayer(key)
        else
            Print(L.NOT_IN_LIST:format(arg))
        end
    elseif command == "list" then
        ShowList()
    elseif command == "quiet" then
        OnQuiet(arg:lower())
    else
        Help()
    end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then return end
        self:UnregisterEvent("ADDON_LOADED")
        QuietBanDB = QuietBanDB or {}
        db = QuietBanDB
        db.version = db.version or 1
        db.players = db.players or {}
        db.quiet = db.quiet or { enabled = false }
        for _, kind in ipairs(QUIET_KINDS) do
            if db.quiet[kind] == nil then db.quiet[kind] = true end
        end
        db.guilds, db.guildOf = nil, nil   -- guild bans were removed: drop their saved data
        if db.version < 2 then
            -- Keys saved before Lower() kept accented and Cyrillic capitals: fold them.
            -- With surnames, older keys glued "First Surname" and added a realm: rebuild
            -- them from the name kept as label.
            local folded = {}
            for key, label in pairs(db.players) do
                local newKey = HasSurnames() and NormalizeName(label) or Lower(key)
                if newKey ~= key then folded[key] = newKey end
            end
            for key, newKey in pairs(folded) do
                db.players[newKey] = db.players[newKey] or db.players[key]
                db.players[key] = nil
            end
            db.version = 2
        end

        local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
        for _, chatEvent in ipairs(CHAT_EVENTS) do addFilter(chatEvent, ChatFilter) end
        addFilter("CHAT_MSG_SYSTEM", SystemFilter)
        -- "X invites you to channel Y".
        -- Blizzard prints the invite line when notice is "INVITE" (ChatFrameOverrides.lua).
    addFilter("CHAT_MSG_CHANNEL_NOTICE_USER", function(_, _, notice, name)
        return IsBanned(NormalizeName(name)) or (notice == "INVITE" and IsQuiet("channel"))
    end)

        for _, name in ipairs({ "TRADE_SHOW", "GUILD_INVITE_REQUEST", "PLAYER_REGEN_DISABLED" }) do
            self:RegisterEvent(name)
        end
        for requestEvent in pairs(REQUESTS) do self:RegisterEvent(requestEvent) end
        TakeOverRequestEvents()
        TakeOverGuildInvite()

        if not db.ignoreImported then
            self:RegisterEvent("IGNORELIST_UPDATE")
            self:RegisterEvent("FRIENDLIST_UPDATE")
            self:RegisterEvent("PLAYER_LOGOUT")
            ImportIgnoreList()
        end

        if Menu and Menu.ModifyMenu then
            for _, which in ipairs(MENU_TAGS) do Menu.ModifyMenu("MENU_UNIT_" .. which, AddMenuEntries) end
        end

        SLASH_QUIETBAN1, SLASH_QUIETBAN2 = "/qb", "/quietban"
        SlashCmdList.QUIETBAN = OnSlash
    elseif REQUESTS[event] then
        OnRequest(event, ...)
    elseif event == "GUILD_INVITE_REQUEST" then
        OnGuildInvite(...)
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Closed before combat: in combat it could not be closed.
        if playerWindow then playerWindow:Hide() end
    elseif event == "TRADE_SHOW" then
        local key = UnitKey("npc")
        if IsBanned(key) then NoteBlocked(key); CancelTrade() end
    elseif event == "IGNORELIST_UPDATE" or event == "FRIENDLIST_UPDATE" then
        ImportIgnoreList()
        if db.ignoreImported then
            self:UnregisterEvent("IGNORELIST_UPDATE")
            self:UnregisterEvent("FRIENDLIST_UPDATE")
        end
    elseif event == "PLAYER_LOGOUT" then
        db.ignoreImported = true
    end
end)
