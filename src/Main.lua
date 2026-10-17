local addonName, PCT = ...

local PeaversCommons = _G.PeaversCommons
local Utils = PeaversCommons.Utils

PCT.name = addonName
PCT.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0.0"

PeaversCommons.SlashCommands:Register(addonName, "pct", {
    default = function()
        PCT.ConfigUI:OpenOptions()
    end,
    unlock = function()
        PCT.Core:SetUnlocked(true)
        Utils.Print(PCT, "Clock unlocked - drag it into place, then /pct lock.")
    end,
    lock = function()
        PCT.Core:SetUnlocked(false)
        Utils.Print(PCT, "Clock locked.")
    end,
    toggle = function()
        local unlocked = PCT.Core:ToggleUnlocked()
        Utils.Print(PCT, unlocked and "Clock unlocked." or "Clock locked.")
    end,
    clear = function()
        PCT.Core:ClearLog()
        Utils.Print(PCT, "Log cleared.")
    end,
    reset = function()
        PCT.Config:Reset()
        PCT.Core:ApplyConfig()
        if PCT.ConfigUI and PCT.ConfigUI.Rebuild then
            PCT.ConfigUI:Rebuild()
        end
        Utils.Print(PCT, "All settings restored to defaults. The log was left alone - /pct clear empties that.")
    end,
    help = function()
        Utils.Print(PCT, "Commands:")
        print("  /pct - Open settings")
        print("  /pct unlock - Show the clock so it can be dragged")
        print("  /pct lock - Finish positioning")
        print("  /pct clear - Empty the log")
        print("  /pct reset - Restore every setting to its default")
    end,
})

PeaversCommons.Events:Init(addonName, function()
    PCT.Config:Initialize()

    -- The log is adopted rather than copied: History keeps writing through to
    -- whatever table it was handed, so the global has to end up pointing at the
    -- same one or nothing would ever be saved.
    PeaversCombatTimeLog = PCT.History:Load(PeaversCombatTimeLog)

    PCT.Core:Initialize()

    -- After Core, because it registers the frame Core builds.
    if PCT.EditMode then
        PCT.EditMode:Register()
    end

    if PCT.ConfigUI and PCT.ConfigUI.Initialize then
        PCT.ConfigUI:Initialize()
    end

    if PCT.Patrons and PCT.Patrons.Initialize then
        PCT.Patrons:Initialize()
    end

    -- Use the centralized SettingsUI system from PeaversCommons
    C_Timer.After(0.5, function()
        PeaversCommons.SettingsUI:CreateRedirectPage(PCT, "PeaversCombatTime", "Peavers Combat Time")
    end)

    -- Register with the PeaversConfig registry
    if PeaversCommons.ConfigRegistry then
        PeaversCommons.ConfigRegistry:Register({
            name = "PeaversCombatTime",
            displayName = "Combat Time",
            description = "A stopwatch for fights, with a log of the last few",
            addonRef = PCT,
            config = PCT.Config,
            pages = PCT.ConfigUI:GetPages(),
            order = 4,
        })
    end
end, {
    suppressAnnouncement = true
})

_G.PeaversCombatTime = PCT
