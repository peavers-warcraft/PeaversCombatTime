local addonName, PCT = ...

--------------------------------------------------------------------------------
-- Clock
--
-- The stopwatch itself, and the only thing that knows how a duration is
-- written down. No frames, no events, no config - which is what lets the tests
-- and the performance harness load it on its own.
--
-- Two rules shape it.
--
-- The clock is the game clock. Elapsed time is always `now - startedAt` against
-- GetTime(), never an accumulation of frame deltas. A dropped frame, a loading
-- screen or a stutter cannot make a timer that is read this way drift, and a
-- combat timer that disagreed with the player's own stopwatch by a second over
-- a four-minute fight would be worse than useless.
--
-- And the display is driven by Tick, not by Format. A stopwatch showing tenths
-- changes ten times a second however fast the screen refreshes, so the frame
-- handler asks for the integer identity of what would be shown and only builds
-- a string - and only touches a font string - when that number has moved. At
-- 144fps that is the difference between 144 SetText calls a second and 10.
--------------------------------------------------------------------------------

local Clock = {}
PCT.Clock = Clock

--------------------------------------------------------------------------------
-- Formatting
--------------------------------------------------------------------------------

-- Deliberately truncated rather than rounded. A stopwatch reads 12.4 for the
-- whole tenth between 12.4 and 12.5; rounding would show 12.5 halfway through
-- it, so the number on screen would be ahead of the fight.
--
-- Always m:ss, even under a minute, so the string keeps its width as the fight
-- goes on and the log underneath stays in a column. Past an hour the tenth is
-- dropped: at that length it is noise, and h:mm:ss is what anybody reads.
---@param seconds number|nil
---@param decimals number|nil 1 for tenths, anything else for whole seconds
---@return string
function Clock.Format(seconds, decimals)
    if type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 then
        seconds = 0
    end

    if decimals == 1 and seconds < 3600 then
        -- Carried out in whole tenths so the minute boundary cannot be reached
        -- by a float that formats as "60.0".
        local tenths = math.floor(seconds * 10)
        local minutes = math.floor(tenths / 600)
        local rest = tenths - (minutes * 600)
        return string.format("%d:%02d.%d", minutes, math.floor(rest / 10), rest % 10)
    end

    local whole = math.floor(seconds)
    local hours = math.floor(whole / 3600)
    local minutes = math.floor((whole % 3600) / 60)

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, whole % 60)
    end
    return string.format("%d:%02d", minutes, whole % 60)
end

-- The integer identity of what Format would produce: the same number means the
-- same string, so the caller can skip the format and the SetText entirely.
---@param seconds number|nil
---@param decimals number|nil
---@return number
function Clock.Tick(seconds, decimals)
    if type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 then
        return 0
    end
    if decimals == 1 and seconds < 3600 then
        return math.floor(seconds * 10)
    end
    return math.floor(seconds)
end

--------------------------------------------------------------------------------
-- The stopwatch
--------------------------------------------------------------------------------

Clock.running = false
Clock.startedAt = nil
Clock.stoppedAt = nil

-- Starting an already-running clock is deliberately a no-op rather than a
-- restart. PLAYER_REGEN_DISABLED can arrive while the addon already believes it
-- is in combat - crossing a loading screen into a fight is the common way - and
-- restarting there would throw away the time already counted.
---@param now number GetTime()
function Clock:Start(now)
    if self.running then return false end

    self.running = true
    self.startedAt = now
    self.stoppedAt = nil
    return true
end

--- The elapsed time of the segment just finished, or nil if none was running.
---@param now number GetTime()
---@return number|nil
function Clock:Stop(now)
    if not self.running then return nil end

    self.running = false
    self.stoppedAt = now
    return self:Elapsed(now)
end

-- While running this is live; once stopped it freezes at the final duration, so
-- the display can keep showing the last fight without a separate field for it.
---@param now number GetTime()
---@return number
function Clock:Elapsed(now)
    if not self.startedAt then return 0 end

    local to = self.running and now or (self.stoppedAt or self.startedAt)
    local elapsed = to - self.startedAt
    if elapsed < 0 then return 0 end
    return elapsed
end

--- Throw the last segment away, so nothing is shown until the next fight.
function Clock:Reset()
    self.running = false
    self.startedAt = nil
    self.stoppedAt = nil
end

--- True once a segment has been timed in this session.
function Clock:HasSegment()
    return self.startedAt ~= nil
end

return Clock
