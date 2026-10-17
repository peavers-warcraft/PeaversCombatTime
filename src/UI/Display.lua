local addonName, PCT = ...

--------------------------------------------------------------------------------
-- Display
--
-- The whole of what is on screen: one clock row, and under it a row per logged
-- fight. It knows nothing about combat - Core hands it a number to show and a
-- list to draw.
--
-- The one performance decision that matters lives here. The frame's OnUpdate is
-- *attached when a fight starts and removed when it ends*, rather than left in
-- place and made to return early. An OnUpdate that exists is called every
-- frame, forever, and this addon is idle almost all the time: out of combat
-- there is no handler to call, so the cost is not small, it is nothing. The
-- harness measures that rather than taking it on trust.
--
-- While a fight is running the handler asks the Clock for the integer identity
-- of what would be shown and returns without touching anything if it has not
-- moved. A FontString re-measures its string on every SetText, changed or not,
-- so at tenths precision that turns 144 calls a second into 10.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
local Utils = PeaversCommons.Utils

local Clock = PCT.Clock

local Display = {}
PCT.Display = Display
Display.__index = Display

local PAD = 6
local GAP = 4

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local function Color(color, fallback)
    if type(color) ~= "table" then return fallback.r, fallback.g, fallback.b end
    return color.r or fallback.r, color.g or fallback.g, color.b or fallback.b
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

function Display.New()
    local self = setmetatable({}, Display)

    local frame = CreateFrame("Frame", "PCTCombatTimeFrame", UIParent, "BackdropTemplate")
    frame:SetSize(160, 40)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -260)
    frame:SetBackdrop(BACKDROP)
    frame:SetClampedToScreen(true)
    frame:Hide()
    self.frame = frame

    local clockText = frame:CreateFontString(nil, "OVERLAY")
    clockText:SetJustifyH("LEFT")
    self.clockText = clockText

    local labelText = frame:CreateFontString(nil, "OVERLAY")
    labelText:SetJustifyH("RIGHT")
    self.labelText = labelText

    -- One per logged fight that is on show. Built on demand in Layout and kept,
    -- because the count only changes when the slider does.
    self.rows = {}

    -- Held rather than built per start, so attaching the handler does not also
    -- allocate a closure every pull.
    self.onUpdate = function() self:Tick() end

    self.decimals = 1
    self.running = false

    return self
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

function Display:Row(index)
    local row = self.rows[index]
    if row then return row end

    local time = self.frame:CreateFontString(nil, "OVERLAY")
    time:SetJustifyH("LEFT")

    local label = self.frame:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("RIGHT")

    row = { time = time, label = label }
    self.rows[index] = row
    return row
end

-- Deliberately not PeaversCommons.FrameLock. That helper leaves EnableMouse(true)
-- on a locked frame, which is right for a panel you want to keep clickable and
-- wrong for something parked over the middle of the screen: it would swallow
-- clicks meant for the world beneath it. The clock takes the mouse only while
-- it is being positioned.
function Display:SetDraggable(config, draggable)
    local frame = self.frame

    if not draggable then
        frame:SetMovable(false)
        frame:EnableMouse(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        return
    end

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()

        -- The relative point is stored alongside the anchor point rather than
        -- assumed equal to it: StopMovingOrSizing is free to leave the frame
        -- anchored by a different corner than it started on, and re-applying the
        -- offsets against the wrong corner is what makes a frame jump on reload.
        local point, _, relativePoint, x, y = f:GetPoint()
        config.framePoint = point
        config.frameRelativePoint = relativePoint
        config.frameX = x
        config.frameY = y
        config:Save()
    end)
end

--- Apply every appearance and position setting. Cheap enough to call on any
--- settings change, and it redraws the log itself so nothing is left stale.
---@param config table
---@param entries table|nil the log, newest first
---@param unlocked boolean|nil
function Display:Layout(config, entries, unlocked)
    local frame = self.frame
    local width = config.frameWidth or 160

    entries = entries or {}

    self.decimals = (config.decimals == 0) and 0 or 1
    self.config = config

    local fontFace = config.fontFace or Utils.GetDefaultFont()
    local outline = config.fontOutline
    if outline == "NONE" or outline == false then outline = nil end
    if outline == true then outline = "OUTLINE" end

    local clockSize = config.clockFontSize or 20
    local rowSize = config.fontSize or 11
    local rowSpacing = config.rowSpacing or 2

    Utils.SafeSetFont(self.clockText, fontFace, clockSize, outline)
    Utils.SafeSetFont(self.labelText, fontFace, math.max(8, rowSize), outline)

    -- Background and border are separable: a border with no fill is the lightest
    -- thing that still reads as one object on a busy screen.
    local bgR, bgG, bgB = Color(config.bgColor, { r = 0, g = 0, b = 0 })
    frame:SetBackdropColor(bgR, bgG, bgB,
        config.showBackground ~= false and (config.bgAlpha or 0.8) or 0)
    local brR, brG, brB = Color(config.borderColor, { r = 0, g = 0, b = 0 })
    frame:SetBackdropBorderColor(brR, brG, brB,
        config.showBorder ~= false and (config.borderAlpha or 1) or 0)

    frame:SetFrameStrata(config.frameStrata or "MEDIUM")

    local point = config.framePoint or "TOP"
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, config.frameRelativePoint or point,
        config.frameX or 0, config.frameY or -260)
    self:SetDraggable(config, unlocked and true or false)

    --------------------------------------------------------------------- clock
    local clockHeight = math.max(clockSize, rowSize) + 2
    self.clockText:ClearAllPoints()
    self.clockText:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)

    -- One anchor each, not two. A font string given both a left and a right
    -- edge takes its vertical position from the second anchor as well, so
    -- pinning the label to the clock and to the frame's edge at once leaves the
    -- two rules fighting and the row visibly off-centre. The text is truncated
    -- to the space the clock leaves instead, which is what stops them colliding.
    self.labelText:ClearAllPoints()
    self.labelText:SetPoint("RIGHT", frame, "TOPRIGHT", -PAD, -(PAD + clockHeight / 2))
    self.labelText:SetShown(config.showLabel ~= false)

    ----------------------------------------------------------------------- log
    -- Sized to the rows that actually have something in them, so an empty log
    -- is a one-line clock rather than a tall empty box waiting to be filled.
    local shown = 0
    if config.showLog ~= false then
        shown = math.min(config.maxEntries or 5, #entries)
    end

    local y = -(PAD + clockHeight)
    for index = 1, shown do
        local row = self:Row(index)
        y = y - rowSpacing

        Utils.SafeSetFont(row.time, fontFace, rowSize, outline)
        Utils.SafeSetFont(row.label, fontFace, rowSize, outline)

        row.time:ClearAllPoints()
        row.time:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)

        row.label:ClearAllPoints()
        row.label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, y)

        y = y - rowSize
    end

    -- y has walked down past the last row, so the frame is exactly as tall as
    -- what is in it. Rows beyond the current count are hidden by RenderLog.
    frame:SetSize(width, -y + PAD)

    self:RenderLog(entries)
    self:SetLabel(self.labelRaw)
    self:Repaint()
end

--------------------------------------------------------------------------------
-- The clock
--------------------------------------------------------------------------------

-- Both colours come from config rather than one being derived, because the
-- point of the idle colour is that a stopped clock is obviously stopped - and
-- how obvious that needs to be depends on the rest of somebody's UI.
function Display:Repaint()
    local config = self.config
    if not config then return end

    local color = self.running and config.clockColor or config.idleColor
    local r, g, b = Color(color, { r = 1, g = 0.82, b = 0 })
    self.clockText:SetTextColor(r, g, b)

    local lr, lg, lb = Color(config.logColor, { r = 0.8, g = 0.8, b = 0.84 })
    self.labelText:SetTextColor(lr, lg, lb)
end

-- The label is kept in full as well as drawn, because what fits depends on the
-- frame's width and on how wide the clock's own string is - both of which change
-- under it. Re-truncating from the original on every layout is the only way a
-- narrowed frame does not end up with a label running under the clock.
---@param text string|nil where this fight is happening
function Display:SetLabel(text)
    self.labelRaw = text

    if not self.config or self.config.showLabel == false then return end

    local available = (self.config.frameWidth or 160) - (PAD * 2) - GAP
        - (self.clockText:GetStringWidth() or 0)

    self.labelText:SetText(Utils.TruncateText(self.labelText, text or "", math.max(0, available)))
end

-- Paint the clock once, outside any tick. Used when a fight ends, and whenever
-- the frame is laid out while nothing is running.
---@param seconds number
function Display:SetTime(seconds)
    self.lastTick = Clock.Tick(seconds, self.decimals)
    self.clockText:SetText(Clock.Format(seconds, self.decimals))
end

function Display:Tick()
    local seconds = self.elapsed and self.elapsed() or 0

    -- The whole of the per-frame cost: an integer compare, and nothing at all
    -- unless the tenth has turned over.
    local tick = Clock.Tick(seconds, self.decimals)
    if tick == self.lastTick then return end

    self.lastTick = tick
    self.clockText:SetText(Clock.Format(seconds, self.decimals))
end

--- Begin ticking. `elapsed` is called once a frame and must return seconds.
---@param elapsed fun():number
function Display:StartTicking(elapsed)
    self.elapsed = elapsed
    self.running = true
    self.lastTick = nil

    self:Tick()
    self:Repaint()
    self.frame:SetScript("OnUpdate", self.onUpdate)
end

--- Stop ticking, leaving the final time on screen.
function Display:StopTicking(finalSeconds)
    self.frame:SetScript("OnUpdate", nil)
    self.running = false

    if finalSeconds then
        self:SetTime(finalSeconds)
    end
    self:Repaint()
end

--------------------------------------------------------------------------------
-- The log
--------------------------------------------------------------------------------

---@param entries table|nil newest first
function Display:RenderLog(entries)
    local config = self.config
    if not config then return end

    -- Normalised once rather than tested at each use. "No log yet" and "a log
    -- with nothing in it" draw the same thing, so they may as well be the same
    -- value by the time the row loop reads it.
    entries = entries or {}

    local shown = 0
    if config.showLog ~= false then
        shown = math.min(config.maxEntries or 5, #entries)
    end

    local logR, logG, logB = Color(config.logColor, { r = 0.8, g = 0.8, b = 0.84 })
    local bossR, bossG, bossB = Color(config.bossColor, { r = 0.47, g = 0.74, b = 0.96 })
    local bestR, bestG, bestB = Color(config.bestColor, { r = 0.4, g = 0.85, b = 0.45 })

    for index = 1, shown do
        local entry = entries[index]
        local row = self:Row(index)

        row.time:SetText(Clock.Format(entry.duration, self.decimals))

        -- A fight that beat every other logged fight of its kind is the whole
        -- reason for keeping a log, so it is the one thing that gets a colour of
        -- its own. Only ever marked when there is something to have beaten.
        local best = config.markBest ~= false and PCT.History:BestFor(entry.label)
        if best and entry.duration <= best then
            row.time:SetTextColor(bestR, bestG, bestB)
        elseif entry.boss then
            row.time:SetTextColor(bossR, bossG, bossB)
        else
            row.time:SetTextColor(logR, logG, logB)
        end

        local available = (config.frameWidth or 160) - (PAD * 2) - GAP
            - (row.time:GetStringWidth() or 0)
        row.label:SetText(Utils.TruncateText(row.label, entry.label or "",
            math.max(0, available)))
        row.label:SetTextColor(logR, logG, logB)

        row.time:Show()
        row.label:Show()
    end

    for index = shown + 1, #self.rows do
        self.rows[index].time:Hide()
        self.rows[index].label:Hide()
    end
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

---@param visible boolean
function Display:SetVisible(visible)
    self.frame:SetShown(visible and true or false)
end

function Display:IsVisible()
    return self.frame:IsShown()
end

return Display
