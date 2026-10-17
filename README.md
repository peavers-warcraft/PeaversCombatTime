# PeaversCombatTime

[![Ultra Performance](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/peavers-warcraft/PeaversCombatTime/master/.github/badges/perf.json)](https://github.com/peavers-warcraft/PeaversCombatTime/actions/workflows/perf.yml)
[![AddonSentry](https://addonsentry.io/api/public/repos/peavers-warcraft/PeaversCombatTime/badge.svg)](https://addonsentry.io/dashboard/peavers-warcraft/PeaversCombatTime)

A stopwatch for fights. It starts the moment you enter combat — raid, dungeon, delve, open world, anywhere — and when the fight ends the time drops into a log underneath, so you can see which pulls are getting faster and which boss took two minutes longer than it should have.

**~53 KB. No bundled libraries. Nothing at all between fights, and about one font string update per tenth of a second while one is running.**

Part of the **Peavers Ultra Performance** family: addons that hold themselves to a published budget, measured on every push.

## Built for performance

A clock that updates while you are fighting is exactly the kind of addon that
quietly costs a frame rate, so this one is measured rather than assumed. The
table below is regenerated on every push by the
[Ultra Performance harness](https://github.com/peavers-code/peavers-warcraft-workflows/tree/master/perf-harness),
which loads this addon's real source into a Lua VM, drives its own `OnUpdate`
through a three-minute fight, and counts what it actually asked the client to
do. If any number goes outside `perf/budget.json`, the build fails.

<!-- perf:begin -->

> Measured on every push by the Ultra Performance harness. The build fails if any number here exceeds the budget in `perf/budget.json`.

| Check | Measured | Budget | |
|---|---:|---:|:--:|
| Packaged size | 53.8 KB | 100 KB | pass |
| Bundled libraries | 0 | 0 | pass |
| Widget calls per frame | 0.17 | 0.25 | pass |
| Widget calls per second while idle | 0 | 0 | pass |

Scenarios driven against the real addon source, outside the game:

| Scenario | Calls/frame | Notes |
|---|---:|---|
| 3 minute fight, tenths, 144fps | 0.07 | 25920 frames driven |
| 3 minute fight, tenths, 60fps | 0.17 | 10800 frames driven |
| 30 second pull, tenths, 144fps | 0.07 | 4320 frames driven |
| 3 minute fight, whole seconds, 144fps | 0.01 | 25920 frames driven |
| idle, between fights | 0.00 | no handler attached |

<sub>1,504 lines of Lua · 53.8 KB packaged · no bundled libraries</sub>

<!-- perf:end -->

How it gets there:

- **Between fights there is no handler to call.** The `OnUpdate` is attached when combat starts and removed when it ends, rather than left in place and made to return early. An `OnUpdate` that exists runs every frame forever, and this addon is idle almost all the time — so out of combat the cost is not small, it is nothing. That is measured above, not merely asserted.
- **The clock only redraws when it changes.** A font string re-measures its whole string on every `SetText`, changed or not. The handler asks the clock for the integer identity of what would be shown and returns without touching anything if the tenth has not turned over — about one frame in fourteen at 144fps.
- **The clock is the clock.** Elapsed time is always `GetTime()` minus the start, never accumulated frame deltas, so a stutter or a loading screen cannot make the timer drift out of step with the fight.
- **Three events, no combat log.** `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` and `ENCOUNTER_START` are the whole of it. Parsing the combat log would cost more than everything else here put together, to answer a question the regen events already answer exactly.
- **The label is resolved once per fight.** Which dungeon, boss or sub-zone you are in is read when the pull starts and then left alone — both because it is cheaper and because a label that changed halfway through a pull would be describing the wrong half of it.

## Features

<!-- peavers:features -->
- A combat stopwatch that starts and stops itself, anywhere in the game — raids, Mythic+, delves, scenarios, open world
- A log of the last few fights underneath the clock, newest first, so chain pulls and boss attempts can be compared at a glance
- Each fight is labelled with where it happened: the boss's name when the client announces an encounter, the dungeon and keystone level in a timed run, the sub-zone out in the world
- The quickest of any fights sharing a label is coloured, so a new best time is obvious without reading the numbers
- Boss encounters are coloured apart from trash, so a pull history reads as pulls rather than as a list
- A floor on what gets logged, so tapping a critter on the way past cannot push a real pull off the bottom
- Tenths or whole seconds, your choice — whole seconds redraws ten times less often, which is already next to nothing
- Optionally hidden outside combat, or outside instances, for people who only want it when it matters
- Survives a reload: the log is saved, and a `/reload` mid-pull picks the clock back up
- Positioned in Blizzard's Edit Mode, or dragged with `/pct unlock`
- Full appearance control, and optional sync with the shared Peavers global appearance profile
<!-- /peavers:features -->

## Usage

<!-- peavers:usage -->
Nothing to set up — enter combat and the clock starts. When the fight ends the time drops into the log underneath.

To move it, press **Unlock To Drag** on the settings page (or `/pct unlock`), drag it where you want it, then **Lock In Place**. On clients with Edit Mode you can also press Escape, choose Edit Mode, and select the combat clock; every setting is grouped into buttons beside the Edit Mode dialog.

A fight is everything between entering combat and leaving it. A chain pull that never drops combat is one number; a pull that breaks because something lost aggro becomes two, and seeing it split is itself worth knowing.

### Slash Commands

- `/pct` - Open settings
- `/pct unlock` - Show the clock so it can be dragged
- `/pct lock` - Finish positioning
- `/pct clear` - Empty the log
- `/pct reset` - Restore every setting to its default
<!-- /peavers:usage -->

## Installation

### Recommended: PeaversUpdater

Download and install [PeaversUpdater](https://github.com/peavers-warcraft/PeaversUpdater/releases/latest), the desktop updater for the whole Peavers collection. It installs PeaversCombatTime together with its required dependencies and delivers updates before they reach CurseForge.

### Alternative: CurseForge

1. Download from CurseForge
2. Ensure [PeaversCommons](https://www.curseforge.com/wow/addons/peaverscommons) is also installed
3. Ensure [PeaversConfig](https://www.curseforge.com/wow/addons/peaversconfig) is also installed
4. Enable the addon on the character selection screen

---

*Part of the [Peavers](https://peavers.io) addon collection · [Report an issue](https://github.com/peavers-warcraft/PeaversCombatTime/issues) · [Support development on Patreon](https://www.patreon.com/Peavers)*
