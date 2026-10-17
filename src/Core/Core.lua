local addonName, PCT = ...

--------------------------------------------------------------------------------
-- Core
--
-- Owns the display, and turns the client's combat events into segments.
--
-- A "segment" is one unbroken stretch of combat: everything between
-- PLAYER_REGEN_DISABLED and the PLAYER_REGEN_ENABLED that follows it. That is
-- deliberately the unit of measurement, because it is the unit players already
-- think in. A chain pull that never drops combat is one number; a pull that
-- breaks because somebody lost aggro is two, and seeing it split is itself the
-- useful information.
--
-- Three events and one zone query is the whole of it. There is no combat log
-- parsing here and there never should be: CLEU fires thousands of times a fight
-- and would cost more than everything else in this addon put together, to
-- answer a question the regen events already answer exactly.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons

local Clock = PCT.Clock
local History = PCT.History
local Display = PCT.Display

local Core = {}
PCT.Core = Core

Core.unlocked = false
Core.inInstance = false

--------------------------------------------------------------------------------
-- Where a fight is happening
--------------------------------------------------------------------------------

-- Resolved once when the segment starts rather than read per frame, and never
-- re-read mid-fight: a label that changed halfway through a pull would be
-- describing the wrong half of it.
--
-- Difficulty 8 is a timed dungeon - Mythic+ on retail, Challenge Mode on Mists -
-- where the keystone level is the single most useful thing about the label, so
-- it is appended when the client will tell us. Every other client simply has no
-- C_ChallengeMode and falls through to the instance name.
---@return string|nil label, boolean inInstance
local function Where()
    local name, instanceType, difficultyID = GetInstanceInfo()

    if instanceType and instanceType ~= "none" and name and name ~= "" then
        if difficultyID == 8 and C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
            local level = C_ChallengeMode.GetActiveKeystoneInfo()
            if type(level) == "number" and level > 0 then
                return name .. " +" .. level, true
            end
        end
        return name, true
    end

    -- Open world. The sub-zone is the more useful of the two - "Dornogal" tells
    -- you less than "The Great Vault" - and it is captured at the start, so it
    -- cannot change under the fight.
    local subZone = GetSubZoneText()
    if subZone and subZone ~= "" then return subZone, false end

    local zone = GetZoneText()
    if zone and zone ~= "" then return zone, false end

    return nil, false
end

function Core:RefreshZone()
    local _, inInstance = Where()
    self.inInstance = inInstance
    self:ApplyVisibility()
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

function Core:ShouldShow()
    if self.unlocked then return true end

    local config = PCT.Config
    if config.instancesOnly and not self.inInstance then return false end
    if config.hideOutOfCombat and not Clock.running then return false end

    return true
end

function Core:ApplyVisibility()
    self.display:SetVisible(self:ShouldShow())
end

--------------------------------------------------------------------------------
-- Segments
--------------------------------------------------------------------------------

function Core:StartCombat()
    if not Clock:Start(GetTime()) then return end

    local label, inInstance = Where()
    self.inInstance = inInstance

    -- An encounter can announce itself a moment before the pull registers as
    -- combat, so a boss name that arrived first takes precedence over the zone.
    if self.pendingBoss then
        self.segmentLabel = self.pendingBoss
        self.segmentIsBoss = true
    else
        self.segmentLabel = label
        self.segmentIsBoss = false
    end

    -- Time before label: the label is truncated to whatever room the clock
    -- leaves, so the clock has to be on screen for that to be measurable.
    self.display:SetTime(0)
    self.display:SetLabel(self.segmentLabel)
    self.display:StartTicking(self.elapsed)

    self:ApplyVisibility()
end

function Core:EndCombat()
    local duration = Clock:Stop(GetTime())
    if not duration then return end

    self.display:StopTicking(duration)

    local config = PCT.Config

    -- Below the floor the fight is not logged, but the clock still shows what it
    -- read. Tapping a critter on the way past should not push a real pull off
    -- the bottom of the log.
    if duration >= (config.minDuration or 0) then
        History:Push(duration, self.segmentLabel, self.segmentIsBoss)

        -- A full layout rather than just a redraw: the log is one row longer
        -- than it was, so the frame itself has to grow. Out of combat, once a
        -- pull, with no OnUpdate attached - it costs nothing worth saving.
        self.display:Layout(config, History:Get(config.maxEntries), self.unlocked)
    end

    self.pendingBoss = nil
    self.segmentLabel = nil
    self.segmentIsBoss = false

    self:ApplyVisibility()
end

-- ENCOUNTER_START can land either side of the pull registering as combat, so it
-- is handled both ways: relabel the running segment, or remember the name for
-- the segment about to start.
function Core:OnEncounterStart(_, encounterName)
    if type(encounterName) ~= "string" or encounterName == "" then return end

    self.pendingBoss = encounterName

    if Clock.running then
        self.segmentLabel = encounterName
        self.segmentIsBoss = true
        self.display:SetLabel(encounterName)
    end
end

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

--- Single entry point for "config changed, make the world match".
function Core:ApplyConfig()
    local config = PCT.Config

    self.display:Layout(config, History:Get(config.maxEntries), self.unlocked)

    -- Layout leaves the clock's text alone, so a precision change has to be
    -- repainted here. While a fight is running the next tick does it anyway.
    if not Clock.running then
        self.display:SetTime(Clock:HasSegment() and Clock:Elapsed(GetTime()) or 0)
    end

    self:ApplyVisibility()
end

function Core:SetUnlocked(unlocked)
    self.unlocked = unlocked and true or false
    self:ApplyConfig()
    return self.unlocked
end

function Core:ToggleUnlocked()
    return self:SetUnlocked(not self.unlocked)
end

function Core:ClearLog()
    History:Clear()
    Clock:Reset()
    self.display:SetTime(0)
    self:ApplyConfig()
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function Core:Initialize()
    self.display = Display.New()

    -- Held rather than built per pull: StartCombat runs on every pull of every
    -- dungeon, and this would otherwise allocate a closure each time.
    self.elapsed = function() return Clock:Elapsed(GetTime()) end

    local events = PeaversCommons.Events

    events:RegisterEvent("PLAYER_REGEN_DISABLED", function() self:StartCombat() end)
    events:RegisterEvent("PLAYER_REGEN_ENABLED", function() self:EndCombat() end)

    -- Boss names are a nicety, and the events carrying them do not exist on
    -- every client this addon runs on. Registering a name the client has never
    -- heard of is a hard Lua error, but the shared event frame already asks
    -- before it registers and remembers the answer, so an unknown name here is
    -- a quiet no - the clock simply falls back to the zone label.
    events:RegisterEvent("ENCOUNTER_START", function(_, ...) self:OnEncounterStart(...) end)
    events:RegisterEvent("ENCOUNTER_END", function() self.pendingBoss = nil end)

    events:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() self:RefreshZone() end)

    events:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        self:RefreshZone()
        self:ApplyConfig()

        -- Crossing a loading screen into a fight - a pull that started before
        -- the zone-in finished, or a /reload mid-pull - means the regen event
        -- has already been and gone. The clock would otherwise sit at zero for
        -- the rest of the fight.
        if InCombatLockdown() then
            self:StartCombat()
        end
    end)

    self:ApplyConfig()
end

return Core
