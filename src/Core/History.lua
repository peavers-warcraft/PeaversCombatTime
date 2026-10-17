local addonName, PCT = ...

--------------------------------------------------------------------------------
-- History
--
-- The log of finished fights. Newest first, capped, and persisted.
--
-- It lives in its own SavedVariable rather than inside the config table, for two
-- reasons. A settings reset should not throw away the log - those are different
-- things to want - and ConfigManager hands out the *same table* it holds as the
-- default on a first run, so a list that grows in place would quietly grow the
-- default it is supposed to be restorable to.
--
-- Plain Lua on purpose: no frames and no API calls, so the tests can drive it
-- directly. Whether a 40-second pull lands above or below a 41-second one is
-- exactly the kind of thing that is easy to get backwards and impossible to
-- notice in a dungeon.
--------------------------------------------------------------------------------

local History = {}
PCT.History = History

-- What is kept, as opposed to what is shown. The display asks for the newest
-- few; raising that slider should not have had to be done before the fight.
History.MAX = 25

History.entries = {}

--------------------------------------------------------------------------------
-- Persistence
--------------------------------------------------------------------------------

-- Adopt the SavedVariable table if it holds anything usable, and keep writing
-- through to it afterwards. Anything that is not a well-formed entry is dropped
-- rather than repaired: a log is not worth a migration path.
---@param saved table|nil the SavedVariable, which is nil on a first run
---@return table the table to store back as the SavedVariable
function History:Load(saved)
    self.entries = {}

    if type(saved) == "table" then
        for _, entry in ipairs(saved) do
            if type(entry) == "table" and type(entry.duration) == "number" then
                self.entries[#self.entries + 1] = {
                    duration = entry.duration,
                    label = type(entry.label) == "string" and entry.label or nil,
                    boss = entry.boss and true or nil,
                }
            end
        end
    end

    self:Trim()
    return self.entries
end

function History:Trim()
    for index = #self.entries, History.MAX + 1, -1 do
        self.entries[index] = nil
    end
end

--------------------------------------------------------------------------------
-- The log
--------------------------------------------------------------------------------

--- Record a finished fight. Returns the stored entry.
---@param duration number seconds
---@param label string|nil where it happened, or which boss it was
---@param boss boolean|nil true when `label` names an encounter
function History:Push(duration, label, boss)
    local entry = {
        duration = duration,
        label = label,
        boss = boss and true or nil,
    }

    table.insert(self.entries, 1, entry)
    self:Trim()

    return entry
end

--- The newest `count` entries, in the order they should be shown.
---@param count number|nil
---@return table
function History:Get(count)
    if not count or count >= #self.entries then
        return self.entries
    end

    local out = {}
    for index = 1, count do
        out[index] = self.entries[index]
    end
    return out
end

function History:Count()
    return #self.entries
end

-- Emptied in place rather than replaced, so the SavedVariable the caller is
-- holding stays the table that gets written out.
function History:Clear()
    for index = #self.entries, 1, -1 do
        self.entries[index] = nil
    end
end

--- The quickest of the logged fights that share a label, or nil if it stands alone.
--- Used to mark the row that beat the rest of its kind.
---@param label string|nil
---@return number|nil
function History:BestFor(label)
    if not label then return nil end

    local best, seen
    for _, entry in ipairs(self.entries) do
        if entry.label == label then
            seen = (seen or 0) + 1
            if not best or entry.duration < best then
                best = entry.duration
            end
        end
    end

    if not seen or seen < 2 then return nil end
    return best
end

return History
