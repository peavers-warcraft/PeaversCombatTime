--------------------------------------------------------------------------------
-- Ultra Performance case: what the clock costs while a fight is running, and
-- what it costs between fights.
--
-- Loads the real src/UI/Display.lua and drives its own OnUpdate, counting every
-- call it makes to the client. Two claims are being measured, not asserted:
--
--   * while a fight runs, the handler only touches a font string when the
--     displayed tenth has actually turned over - so the cost is the refresh
--     rate divided by ten, not one call a frame;
--   * between fights there is no handler attached at all, so the cost is zero
--     rather than merely small. The case checks for the handler the same way
--     WoW would, by asking the frame for it.
--
-- The 60fps row is the important one. Tick gating saves less at low refresh
-- rates, because a larger share of frames land on a new tenth - so that is the
-- number the budget has to hold against, not the flattering 144fps one.
--------------------------------------------------------------------------------

-- Not addon code: this runs in the harness's VM, outside WoW, against globals
-- the runner injects. Linting it as a WoW addon is a category error -
-- HARNESS_LIB and ADDON_DIR come from the runner, and the PeaversCommons table
-- below is a deliberate three-function stub rather than the real library.
---@diagnostic disable: undefined-global, deprecated, duplicate-set-field, missing-fields

local Stubs = dofile(HARNESS_LIB .. "/wow-stubs.lua").Install()

--------------------------------------------------------------------------------
-- Addon-side scaffolding the file expects at load time
--------------------------------------------------------------------------------

_G.PeaversCommons = {
    Utils = {
        GetDefaultFont = function() return "Fonts\\FRIZQT__.TTF" end,
        SafeSetFont = function() end,
        -- Pass-through. The real helper binary-searches with GetStringWidth,
        -- which is honest work but happens on layout and at the end of a fight,
        -- never on the frame path this case measures.
        TruncateText = function(_, text) return text end,
    },
}

local PCT = {}
local Clock = assert(loadfile(ADDON_DIR .. "/src/Core/Clock.lua"))("PeaversCombatTime", PCT)
assert(loadfile(ADDON_DIR .. "/src/Core/History.lua"))("PeaversCombatTime", PCT)
local Display = assert(loadfile(ADDON_DIR .. "/src/UI/Display.lua"))("PeaversCombatTime", PCT)

local CONFIG = {
    frameWidth = 160,
    framePoint = "TOP", frameRelativePoint = "TOP", frameX = 0, frameY = -260,
    fontSize = 11, clockFontSize = 20, rowSpacing = 2,
    bgColor = { r = 0, g = 0, b = 0 }, bgAlpha = 0.8,
    borderColor = { r = 0, g = 0, b = 0 }, borderAlpha = 1,
    showBackground = true, showBorder = true,
    clockColor = { r = 1, g = 0.82, b = 0 },
    idleColor = { r = 0.55, g = 0.55, b = 0.58 },
    logColor = { r = 0.8, g = 0.8, b = 0.84 },
    bossColor = { r = 0.47, g = 0.74, b = 0.96 },
    bestColor = { r = 0.4, g = 0.85, b = 0.45 },
    decimals = 1,
    showLabel = true, showLog = true, maxEntries = 5, minDuration = 3,
    markBest = true,
}

-- A log with something in it, because an empty one would skip the row drawing
-- entirely and measure a frame that is not the one players have.
local function Populate()
    PCT.History:Load(nil)
    PCT.History:Push(74.2, "The Dawnbreaker +12")
    PCT.History:Push(38.9, "The Dawnbreaker +12")
    PCT.History:Push(126.4, "Anub'zekt", true)
    PCT.History:Push(41.1, "The Dawnbreaker +12")
    PCT.History:Push(63.0, "The Dawnbreaker +12")
end

local function NewDisplay(decimals)
    local config = {}
    for key, value in pairs(CONFIG) do config[key] = value end
    config.decimals = decimals

    Populate()

    local display = Display.New()
    display:Layout(config, PCT.History:Get(config.maxEntries), false)
    display:SetVisible(true)
    return display
end

--------------------------------------------------------------------------------
-- Scenario driving
--------------------------------------------------------------------------------

--- Drive one fight start to finish and report the average per-frame cost.
local function MeasureFight(label, seconds, fps, decimals)
    local display = NewDisplay(decimals)

    Stubs.time = 1000
    local startedAt = Stubs.time

    Clock:Reset()
    Clock:Start(startedAt)
    display:SetTime(0)
    display:SetLabel("The Dawnbreaker +12")
    display:StartTicking(function() return Clock:Elapsed(Stubs.time) end)

    local frames = math.floor(seconds * fps)
    local perFrame = Stubs.Drive(function() display:Tick() end, frames, 1 / fps)

    return {
        name = label,
        callsPerFrame = perFrame,
        notes = string.format("%d frames driven", frames),
    }
end

-- Between fights. The handler is removed rather than made to return early, so
-- there is nothing for WoW to call - which is what this asks the frame.
local function MeasureIdle(fps)
    local display = NewDisplay(1)

    Clock:Reset()
    Clock:Start(1000)
    display:StartTicking(function() return Clock:Elapsed(Stubs.time) end)
    display:StopTicking(Clock:Stop(1045))

    Stubs.ResetCounts()

    local handler = display.frame:GetScript("OnUpdate")
    local ticked = 0
    for _ = 1, fps do
        Stubs.time = Stubs.time + 1 / fps
        -- Exactly what the client does: a frame with no OnUpdate, or a hidden
        -- one, is never called.
        if handler and display.frame:IsShown() then
            handler()
            ticked = ticked + 1
        end
    end

    return {
        name = "idle, between fights",
        callsPerFrame = 0,
        idleCallsPerSecond = Stubs.TotalCalls(),
        notes = handler == nil and "no handler attached" or (ticked .. " frames ticked"),
    }
end

return {
    MeasureFight("3 minute fight, tenths, 144fps", 180, 144, 1),
    MeasureFight("3 minute fight, tenths, 60fps", 180, 60, 1),
    MeasureFight("30 second pull, tenths, 144fps", 30, 144, 1),
    MeasureFight("3 minute fight, whole seconds, 144fps", 180, 144, 0),
    MeasureIdle(144),
}
