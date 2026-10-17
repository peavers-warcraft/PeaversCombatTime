local addonName, PCT = ...

--------------------------------------------------------------------------------
-- PeaversCombatTime Configuration
--
-- Account-wide: where a stopwatch sits on the screen belongs to the screen, not
-- to a character, so this uses the flat (non-profile) ConfigManager variant.
--
-- Appearance keys are stored flat on the config table rather than nested. That
-- is what lets PeaversCommons GlobalAppearance sync fontFace, fontSize, bgColor
-- and bgAlpha across every Peavers addon, and it means the config table can be
-- handed straight to Display:Layout as the appearance table.
--
-- The log itself is not here - see History.lua for why.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
local ConfigManager = PeaversCommons.ConfigManager

PCT.name = PCT.name or addonName

local PCT_DEFAULTS = {
    -- Appearance. bgColor, bgAlpha, fontFace and fontOutline all come from
    -- ConfigManager.CommonDefaults; only what differs is written out.
    fontSize = 11,
    clockFontSize = 20,
    borderColor = { r = 0, g = 0, b = 0 },
    borderAlpha = 1,
    showBorder = true,
    showBackground = true,
    frameStrata = "MEDIUM",

    -- Colours. The clock changes colour rather than disappearing when a fight
    -- ends, so a glance tells you whether the number is still moving.
    clockColor = { r = 1, g = 0.82, b = 0 },
    idleColor = { r = 0.55, g = 0.55, b = 0.58 },
    logColor = { r = 0.80, g = 0.80, b = 0.84 },
    bossColor = { r = 0.47, g = 0.74, b = 0.96 },
    bestColor = { r = 0.40, g = 0.85, b = 0.45 },

    -- Frame
    frameWidth = 160,
    framePoint = "CENTER",
    frameRelativePoint = "CENTER",
    frameX = 0,
    frameY = 180,
    rowSpacing = 2,

    -- The clock
    decimals = 1,
    showLabel = true,
    hideOutOfCombat = false,
    instancesOnly = false,

    -- The log
    showLog = true,
    maxEntries = 5,
    minDuration = 3,
    markBest = true,
}

local Config = ConfigManager:New(PCT, PCT_DEFAULTS, {
    savedVariablesName = "PeaversCombatTimeDB",
})
PCT.Config = Config

return Config
