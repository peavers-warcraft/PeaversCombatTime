local addonName, PCT = ...

--------------------------------------------------------------------------------
-- Edit Mode
--
-- One frame, one schema, so the settings are where the frame is rather than in
-- a window layered over the top of it.
--
-- The clock is a plain unprotected frame that already knows how to drag itself
-- when unlocked, so there is no mover to register in its place - the frame goes
-- in, and its own drag handlers come off while Edit Mode owns it. And because
-- it hides itself when the options say to, it is shown unconditionally while
-- Edit Mode is open: a hidden frame takes its own Edit Mode handle down with it,
-- which would leave nothing to select.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons

local EditMode = {}
PCT.EditMode = EditMode

--------------------------------------------------------------------------------
-- Applying a change
--------------------------------------------------------------------------------

function PCT.ApplySetting()
    if PCT.Core and PCT.Core.ApplyConfig then
        PCT.Core:ApplyConfig()
    end
end

--------------------------------------------------------------------------------
-- Schema
--------------------------------------------------------------------------------

EditMode.SECTIONS = {
    { key = "clock", label = "Clock" },
    { key = "log", label = "Log" },
    { key = "frame", label = "Frame" },
    { key = "appearance", label = "Appearance" },
    { key = "colors", label = "Colours" },
}

local function WhenLogHidden(cfg) return cfg.showLog == false end

EditMode.ENTRIES = {
    ----------------------------------------------------------------- clock ---
    {
        key = "decimals", label = "Precision", kind = "dropdown", section = "clock",
        default = 1,
        desc = "Tenths is what a stopwatch shows. Whole seconds redraws the "
            .. "clock ten times less often, which is already next to nothing.",
        values = {
            { value = 1, label = "Tenths (0:12.4)" },
            { value = 0, label = "Whole seconds (0:12)" },
        },
    },
    {
        key = "clockFontSize", label = "Clock Size", kind = "slider", section = "clock",
        min = 10, max = 48, step = 1, unit = "pt", default = 20,
    },
    {
        key = "showLabel", label = "Show Where You Are", kind = "checkbox",
        section = "clock", default = true,
        desc = "The dungeon, boss or sub-zone the fight is happening in, beside "
            .. "the clock.",
    },
    {
        key = "hideOutOfCombat", label = "Only Show In Combat", kind = "checkbox",
        section = "clock", default = false,
        desc = "Hides the whole thing, log included, until the next pull.",
    },
    {
        key = "instancesOnly", label = "Only Show In Instances", kind = "checkbox",
        section = "clock", default = false,
        desc = "Dungeons, raids, delves and scenarios. Open-world fights are "
            .. "still timed; the clock just is not on screen for them.",
    },

    ------------------------------------------------------------------- log ---
    {
        key = "showLog", label = "Show The Log", kind = "checkbox", section = "log",
        default = true, revealsOthers = true,
    },
    {
        key = "maxEntries", label = "Fights To Keep On Screen", kind = "slider",
        section = "log", min = 1, max = 15, step = 1, default = 5,
        hidden = WhenLogHidden,
    },
    {
        key = "minDuration", label = "Ignore Fights Under (Seconds)", kind = "slider",
        section = "log", min = 0, max = 30, step = 1, default = 3,
        desc = "Short fights are still timed and still shown on the clock - they "
            .. "just do not take a row in the log. Stops a critter on the way "
            .. "past pushing a real pull off the bottom.",
    },
    {
        key = "markBest", label = "Highlight The Best Time", kind = "checkbox",
        section = "log", default = true, hidden = WhenLogHidden,
        desc = "Colours the quickest of the logged fights that share a label, "
            .. "once there is more than one of them to compare.",
    },

    ----------------------------------------------------------------- frame ---
    { key = "frameWidth", label = "Width", section = "frame", min = 100, max = 400 },
    { key = "rowSpacing", label = "Row Spacing", kind = "slider", section = "frame",
      min = 0, max = 10, step = 1, unit = "px", default = 2 },
    {
        key = "framePoint", label = "Anchor", kind = "dropdown", section = "frame",
        fallback = "TOP",
        desc = "Which corner the clock is pinned by. The log grows downwards, so "
            .. "a top anchor keeps the clock itself still as fights are added.",
        values = {
            { value = "TOP", label = "Top" },
            { value = "CENTER", label = "Centre" },
            { value = "BOTTOM", label = "Bottom" },
            { value = "TOPLEFT", label = "Top left" },
            { value = "TOPRIGHT", label = "Top right" },
            { value = "BOTTOMLEFT", label = "Bottom left" },
            { value = "BOTTOMRIGHT", label = "Bottom right" },
        },
    },
    { key = "frameX", label = "X Offset", kind = "number", section = "frame", default = 0 },
    { key = "frameY", label = "Y Offset", kind = "number", section = "frame", default = -260 },
    {
        key = "frameStrata", label = "Layer", kind = "dropdown", section = "frame",
        fallback = "MEDIUM",
        desc = "Which layer it sits on, if something else is covering it.",
        values = {
            { value = "LOW", label = "Low" },
            { value = "MEDIUM", label = "Medium" },
            { value = "HIGH", label = "High" },
            { value = "DIALOG", label = "Dialog" },
        },
    },

    ------------------------------------------------------------ appearance ---
    { key = "fontFace", section = "appearance", height = 300 },
    { key = "fontSize", label = "Log Size", section = "appearance" },
    { key = "fontOutline", section = "appearance" },
    {
        key = "showBackground", label = "Show The Background", kind = "checkbox",
        section = "appearance", default = true, revealsOthers = true,
    },
    { key = "bgColor", section = "appearance",
      hidden = function(cfg) return cfg.showBackground == false end },
    { key = "bgAlpha", section = "appearance",
      hidden = function(cfg) return cfg.showBackground == false end },
    {
        key = "showBorder", label = "Show The Border", kind = "checkbox",
        section = "appearance", default = true, revealsOthers = true,
    },
    {
        key = "borderColor", label = "Border Colour", kind = "color",
        section = "appearance", default = { r = 0, g = 0, b = 0 },
        hidden = function(cfg) return cfg.showBorder == false end,
    },
    {
        key = "borderAlpha", label = "Border Opacity", kind = "slider",
        section = "appearance", min = 0, max = 1, step = 0.05, unit = "percent",
        default = 1, hidden = function(cfg) return cfg.showBorder == false end,
    },

    ---------------------------------------------------------------- colors ---
    {
        key = "clockColor", label = "Running", kind = "color", section = "colors",
        default = { r = 1, g = 0.82, b = 0 },
    },
    {
        key = "idleColor", label = "Stopped", kind = "color", section = "colors",
        default = { r = 0.55, g = 0.55, b = 0.58 },
        desc = "The clock changes colour rather than clearing when a fight ends, "
            .. "so a glance tells you whether the number is still moving.",
    },
    {
        key = "logColor", label = "Logged Fight", kind = "color", section = "colors",
        default = { r = 0.80, g = 0.80, b = 0.84 },
    },
    {
        key = "bossColor", label = "Boss Encounter", kind = "color", section = "colors",
        default = { r = 0.47, g = 0.74, b = 0.96 },
    },
    {
        key = "bestColor", label = "Best Time", kind = "color", section = "colors",
        default = { r = 0.40, g = 0.85, b = 0.45 },
        hidden = function(cfg) return cfg.markBest == false end,
    },
}

function EditMode:BuildSchema()
    if self.schema then return self.schema end

    self.schema = PeaversCommons.SettingsSchema:New({
        config = PCT.Config,
        sections = self.SECTIONS,
        entries = self.ENTRIES,
        apply = function() PCT.ApplySetting() end,
    })

    return self.schema
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

-- Edit Mode reports an anchor point and an offset, which is what this addon
-- already stores - including the relative point, which it keeps separately
-- because StopMovingOrSizing is free to leave a frame anchored by a different
-- corner than it started on.
local function SavePosition(frame, point, x, y)
    local config = PCT.Config
    local _, _, relativePoint = frame:GetPoint()

    config.framePoint = point
    config.frameRelativePoint = relativePoint or point
    config.frameX = x
    config.frameY = y
    config:Save()
end

function EditMode:Register()
    if not PeaversCommons.EditMode or not PeaversCommons.EditMode.available then
        return false
    end
    if not (PCT.Core and PCT.Core.display) then return false end
    if self.registered then return true end

    local config = PCT.Config

    PeaversCommons.EditMode:Register({
        frame = PCT.Core.display.frame,
        name = "Peavers Combat Time",
        schema = self:BuildSchema(),
        default = {
            point = config.framePoint or "TOP",
            x = config.frameX or 0,
            y = config.frameY or -260,
        },
        onPositionChanged = SavePosition,

        onEnter = function(frame)
            -- The frame drags itself when unlocked, and Edit Mode drags it
            -- through its own overlay; both at once means two systems answering
            -- one drag.
            frame:RegisterForDrag()
            frame:SetScript("OnDragStart", nil)
            frame:SetScript("OnDragStop", nil)
            frame:Show()
        end,
        onExit = function()
            PCT.ApplySetting()
        end,
    })

    self.registered = true
    return true
end

return EditMode
