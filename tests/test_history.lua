--------------------------------------------------------------------------------
-- The log: what order it is in, what survives a reload, and which row counts as
-- the best.
--
-- Newest-first is the part worth pinning down. Getting it backwards is a
-- one-character mistake that looks entirely plausible in a dungeon, because the
-- row you just finished would simply appear at the bottom instead of the top.
--------------------------------------------------------------------------------

local here = debug.getinfo(1, "S").source:sub(2)
local testsDir = here:match("^(.*)[/\\][^/\\]+$") or "."
local h = dofile(testsDir .. "/harness.lua")

local History = h.load("src/Core/History.lua")

--------------------------------------------------------------------------------
print("Order and capacity")
--------------------------------------------------------------------------------

History:Load(nil)
h.equal(History:Count(), 0, "a first run starts empty")

History:Push(10, "First")
History:Push(20, "Second")
History:Push(30, "Third")

h.equal(History:Count(), 3, "three logged")
h.equal(History.entries[1].label, "Third", "newest first")
h.equal(History.entries[3].label, "First", "oldest last")

for index = 1, History.MAX + 5 do
    History:Push(index, "Filler")
end
h.equal(History:Count(), History.MAX, "capped at MAX")
h.equal(History.entries[1].duration, History.MAX + 5, "and the cap drops the oldest, not the newest")

--------------------------------------------------------------------------------
print("Get")
--------------------------------------------------------------------------------

History:Load(nil)
History:Push(1, "A")
History:Push(2, "B")
History:Push(3, "C")

h.equal(#History:Get(2), 2, "asking for fewer than there are")
h.equal(History:Get(2)[1].duration, 3, "and still newest first")
h.equal(#History:Get(10), 3, "asking for more than there are")
h.equal(#History:Get(nil), 3, "asking for all of them")

--------------------------------------------------------------------------------
print("Persistence")
--------------------------------------------------------------------------------

-- A log is not worth a migration path, so anything that is not a well-formed
-- entry is dropped rather than repaired.
local saved = {
    { duration = 42.5, label = "Kept", boss = true },
    { label = "No duration" },
    "not a table",
    { duration = "not a number" },
    { duration = 7 },
}

local adopted = History:Load(saved)
h.equal(History:Count(), 2, "only the well-formed entries survive")
h.equal(History.entries[1].label, "Kept", "order preserved from the save")
h.equal(History.entries[1].boss, true, "boss flag preserved")
h.equal(History.entries[2].label, nil, "a missing label stays missing")

-- The caller stores the returned table back as the SavedVariable, so every
-- later Push has to land in that same table or nothing is ever written out.
History:Push(1, "Later")
h.equal(adopted[1].label, "Later", "pushes land in the adopted table")

History:Clear()
h.equal(History:Count(), 0, "cleared")
h.equal(adopted, History.entries, "cleared in place, so the SavedVariable still points at it")

--------------------------------------------------------------------------------
print("Best time")
--------------------------------------------------------------------------------

History:Load(nil)
History:Push(60, "Boss")
h.equal(History:BestFor("Boss"), nil, "a single fight has nothing to have beaten")

History:Push(45, "Boss")
h.equal(History:BestFor("Boss"), 45, "the quicker of two")

History:Push(90, "Boss")
h.equal(History:BestFor("Boss"), 45, "a slower third does not take the crown")

History:Push(30, "Other")
h.equal(History:BestFor("Other"), nil, "labels do not pool together")
h.equal(History:BestFor(nil), nil, "an unlabelled fight has no best")
h.equal(History:BestFor("Nothing like it"), nil, "an unknown label")

h.finish()
