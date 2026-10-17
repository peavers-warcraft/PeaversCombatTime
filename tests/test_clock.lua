--------------------------------------------------------------------------------
-- The clock: how a duration is written down, and the stopwatch itself.
--
-- The minute boundary is the case worth having a test for. Written with a
-- float format, 59.98 seconds renders as "0:60.0" - a time that does not exist -
-- which is why Format carries the arithmetic out in whole tenths instead.
--------------------------------------------------------------------------------

local here = debug.getinfo(1, "S").source:sub(2)
local testsDir = here:match("^(.*)[/\\][^/\\]+$") or "."
local h = dofile(testsDir .. "/harness.lua")

local Clock = h.load("src/Core/Clock.lua")

--------------------------------------------------------------------------------
print("Format, tenths")
--------------------------------------------------------------------------------

h.equal(Clock.Format(0, 1), "0:00.0", "zero")
h.equal(Clock.Format(0.9, 1), "0:00.9", "under a second")
h.equal(Clock.Format(12.44, 1), "0:12.4", "truncated, not rounded")
h.equal(Clock.Format(12.46, 1), "0:12.4", "still truncated past the halfway point")
h.equal(Clock.Format(59.98, 1), "0:59.9", "just short of a minute is not 0:60.0")
h.equal(Clock.Format(60, 1), "1:00.0", "the minute boundary")
h.equal(Clock.Format(125.5, 1), "2:05.5", "past two minutes")

--------------------------------------------------------------------------------
print("Format, whole seconds")
--------------------------------------------------------------------------------

h.equal(Clock.Format(0, 0), "0:00", "zero")
h.equal(Clock.Format(12.9, 0), "0:12", "truncated")
h.equal(Clock.Format(59.9, 0), "0:59", "just short of a minute")
h.equal(Clock.Format(60, 0), "1:00", "the minute boundary")

--------------------------------------------------------------------------------
print("Format, past an hour and bad input")
--------------------------------------------------------------------------------

-- The tenth is dropped past an hour whatever the precision setting says: at
-- that length it is noise, and h:mm:ss is what anybody reads.
h.equal(Clock.Format(3600, 1), "1:00:00", "an hour, asked for tenths")
h.equal(Clock.Format(3725, 1), "1:02:05", "an hour and change")
h.equal(Clock.Format(3599.5, 1), "59:59.5", "just short of an hour keeps the tenth")

h.equal(Clock.Format(nil, 1), "0:00.0", "nil")
h.equal(Clock.Format(-5, 1), "0:00.0", "negative")
h.equal(Clock.Format(0 / 0, 1), "0:00.0", "NaN")

--------------------------------------------------------------------------------
print("Tick gating")
--------------------------------------------------------------------------------

-- This is what keeps the per-frame cost down: the same number means the same
-- string, so the frame handler can skip both the format and the SetText.
h.equal(Clock.Tick(12.40, 1), Clock.Tick(12.49, 1), "within one tenth")
h.truthy(Clock.Tick(12.50, 1) ~= Clock.Tick(12.49, 1), "across a tenth")
h.equal(Clock.Tick(12.1, 0), Clock.Tick(12.9, 0), "within one second at whole precision")
h.truthy(Clock.Tick(13.0, 0) ~= Clock.Tick(12.9, 0), "across a second")
h.equal(Clock.Tick(nil, 1), 0, "nil")

--------------------------------------------------------------------------------
print("The stopwatch")
--------------------------------------------------------------------------------

Clock:Reset()
h.equal(Clock:HasSegment(), false, "nothing timed yet")
h.equal(Clock:Elapsed(1000), 0, "elapsed before any start")
h.equal(Clock:Stop(1000), nil, "stopping a clock that was never started")

h.equal(Clock:Start(1000), true, "first start")
h.equal(Clock.running, true, "running")
h.near(Clock:Elapsed(1012.5), 12.5, 0.0001, "live elapsed")

-- PLAYER_REGEN_DISABLED can arrive while the addon already believes it is in
-- combat - crossing a loading screen into a fight is the common way - and
-- restarting there would throw away the time already counted.
h.equal(Clock:Start(1010), false, "a second start is refused")
h.near(Clock:Elapsed(1012.5), 12.5, 0.0001, "and left the original start alone")

h.near(Clock:Stop(1020) or -1, 20, 0.0001, "stop returns the final duration")
h.equal(Clock.running, false, "stopped")
h.near(Clock:Elapsed(1099), 20, 0.0001, "elapsed freezes at the final duration")
h.equal(Clock:HasSegment(), true, "a segment was timed")

-- A clock whose start is somehow ahead of now reads zero rather than counting
-- backwards. GetTime is monotonic, so this is paranoia - but a negative
-- duration would be formatted, logged and compared against.
Clock:Reset()
Clock:Start(2000)
h.equal(Clock:Elapsed(1999), 0, "never negative")

h.finish()
