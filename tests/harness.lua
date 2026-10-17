--------------------------------------------------------------------------------
-- The offline harness.
--
-- Clock.lua and History.lua touch no client API at all, which is deliberate:
-- the two things in this addon that can be wrong without anybody being able to
-- see it are how a duration is written down and what order the log is in. Both
-- load standalone, so both are driven here directly.
--
-- Run with the system lua (tests/run.sh). Two things differ from WoW's 5.1:
-- loop control variables are const in 5.4+, and `unpack` is `table.unpack`.
-- Neither may appear in addon code - it would work in game and break here,
-- which is where the checking happens.
--------------------------------------------------------------------------------

local harness = {}

---This file is `<PeaversCombatTime>/tests/harness.lua`, whatever the checkout is
---called and wherever a worktree puts it, so the addon root is two levels up.
---@return string
local function root()
	local here = debug.getinfo(1, "S").source:sub(2)
	local testsDir = here:match("^(.*)[/\\][^/\\]+$") or "."
	return testsDir .. "/.."
end

harness.root = root

--- Load one addon file against a fresh namespace table.
---@param path string relative to the addon root, e.g. "src/Core/Clock.lua"
---@param namespace table|nil
function harness.load(path, namespace)
	namespace = namespace or {}
	local chunk = assert(loadfile(root() .. "/" .. path))
	return chunk("PeaversCombatTime", namespace), namespace
end

--------------------------------------------------------------------------------
-- Assertions
--------------------------------------------------------------------------------

local failures = 0
local checks = 0

function harness.equal(actual, expected, what)
	checks = checks + 1
	if actual ~= expected then
		failures = failures + 1
		print(string.format("  FAIL %s\n       expected %s, got %s",
			what, tostring(expected), tostring(actual)))
	end
end

function harness.near(actual, expected, tolerance, what)
	checks = checks + 1
	if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
		failures = failures + 1
		print(string.format("  FAIL %s\n       expected %s +/- %s, got %s",
			what, tostring(expected), tostring(tolerance), tostring(actual)))
	end
end

function harness.truthy(actual, what)
	checks = checks + 1
	if not actual then
		failures = failures + 1
		print(string.format("  FAIL %s\n       expected a truthy value, got %s",
			what, tostring(actual)))
	end
end

--- Print the tally and exit non-zero if anything failed.
function harness.finish()
	print(string.format("  %d checks, %d failures", checks, failures))
	if failures > 0 then os.exit(1) end
end

return harness
