local addonName, PCT = ...

--------------------------------------------------------------------------------
-- ConfigUI
--
-- One page: what the addon is, how to move it, and the two buttons that cannot
-- live in Edit Mode because you want them while you are playing. Everything
-- that is a setting is in the Edit Mode schema next door, so the two surfaces
-- cannot disagree about what a change should do.
--------------------------------------------------------------------------------

local ConfigUI = {}
PCT.ConfigUI = ConfigUI

local PeaversCommons = _G.PeaversCommons
if not PeaversCommons then
    print("|cffff0000Error:|r PeaversCommons not found.")
    return
end

local ConfigUIUtils = PeaversCommons.ConfigUIUtils

function ConfigUI:BuildInfoPage(parentFrame)
    ConfigUIUtils.BuildInfoPageWithEditMode(parentFrame, "Combat Time", {
        "A stopwatch for fights. It starts the moment you enter combat - raid, " ..
            "dungeon, delve, open world, anywhere - and when the fight ends the " ..
            "time drops into a log underneath, so you can see at a glance which " ..
            "pulls are getting faster and which boss took two minutes longer " ..
            "than it should have.",

        { command = "/pct", desc = "open the settings" },
        { command = "/pct unlock", desc = "show the frame so it can be dragged" },
        { command = "/pct lock", desc = "finish positioning" },
        { command = "/pct clear", desc = "empty the log" },
        { command = "/pct reset", desc = "restore every setting to its default" },

        {
            button = {
                text = "Unlock To Drag",
                onClick = function()
                    if PCT.Core then PCT.Core:SetUnlocked(true) end
                end,
            },
        },
        {
            button = {
                text = "Lock In Place",
                onClick = function()
                    if PCT.Core then PCT.Core:SetUnlocked(false) end
                end,
            },
        },
        {
            button = {
                text = "Clear The Log",
                onClick = function()
                    if PCT.Core then PCT.Core:ClearLog() end
                end,
            },
        },

        { header = "What counts as one fight" },
        "Everything between entering combat and leaving it. A chain pull that " ..
            "never drops combat is one number; a pull that breaks because " ..
            "something lost aggro becomes two, and seeing it split is itself " ..
            "worth knowing. Fights shorter than the floor in the settings are " ..
            "still timed on the clock, they just do not take a row in the log.",

        { header = "Labels" },
        "Each logged fight is labelled with where it happened: the boss's name " ..
            "when the client announces an encounter, the dungeon and keystone " ..
            "level in a timed run, and the sub-zone out in the world. Once two " ..
            "fights share a label the quickest of them is coloured, which is " ..
            "the whole point of keeping a log.",

        { header = "Built for performance" },
        "The frame handler is attached when a fight starts and removed when it " ..
            "ends, so out of combat this addon is not cheap - it is doing " ..
            "nothing at all. While a fight is running it asks whether the tenth " ..
            "has turned over and returns without touching anything if it has " ..
            "not, which is about one in fourteen frames at 144fps. Time is read " ..
            "from the game clock rather than accumulated frame deltas, so a " ..
            "stutter cannot make the clock drift. Every one of those numbers is " ..
            "re-measured on each push and published in the README.",
    }, {
        title = "the combat clock",
        select = "the combat clock",
        reset = function()
            PCT.Config:Reset()
            if PCT.ApplySetting then PCT.ApplySetting() end
            if PeaversCommons.EditModePanel then
                PeaversCommons.EditModePanel:Refresh()
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- Page registration
--------------------------------------------------------------------------------

function ConfigUI:GetPages()
    return {
        { key = "info", label = "Information", builder = function(f) self:BuildInfoPage(f) end },
    }
end

-- Ask PeaversConfig to throw its cached pages away and build them again. Needed
-- after a reset, where the controls on screen are bound to a config table that
-- no longer exists. Deferred by a frame so the click handler that triggered it
-- has returned before its own page is torn down.
function ConfigUI:Rebuild()
    local PeaversConfig = _G.PeaversConfig
    local contentArea = PeaversConfig and PeaversConfig.ContentArea
    if not contentArea or not contentArea.InvalidateCache then return end

    C_Timer.After(0, function()
        contentArea:InvalidateCache(addonName)
        if contentArea.ShowAddon then
            contentArea:ShowAddon(addonName)
        end
    end)
end

function ConfigUI:OpenOptions()
    if _G.PeaversConfig and _G.PeaversConfig.MainFrame then
        _G.PeaversConfig.MainFrame:Show()
        _G.PeaversConfig.MainFrame:SelectAddon("PeaversCombatTime")
        return
    end

    if Settings and Settings.OpenToCategory then
        if PCT.directSettingsCategoryID then
            if pcall(Settings.OpenToCategory, PCT.directSettingsCategoryID) then return end
        end
        if PCT.directCategoryID then
            if pcall(Settings.OpenToCategory, PCT.directCategoryID) then return end
        end
    end

    if SettingsPanel then
        SettingsPanel:Open()
    end
end

function ConfigUI:BuildIntoFrame(parentFrame)
    self:BuildInfoPage(parentFrame)
    return parentFrame
end

function ConfigUI:Initialize()
end

return ConfigUI
