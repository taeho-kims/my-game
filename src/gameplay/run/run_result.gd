class_name RunResult
extends RefCounted
## The outcome of one finished run: a plain data object built once by RunController and handed
## out through its `run_finished` signal. Gold application (story 005) and the phase-2 handlers
## (shop, equipment, cards, codex) consume this object; none of them are known here.
##
## Implements design/game-brief.md (extension design principle) via
## production/epics/slime-nodaji/story-004-run-timer-burst.md.
## Values ported from slime-nodaji.html (finishRun) plus the new final-harvest bonus.

## Map the run was played on (one map in phase 1, kept as a field for later phases).
var map_id: String = ""
## Gold from the chest alone: round(collected * chest multiplier).
var base_gold: int = 0
## Gold from the final harvest: the accumulated float bonus, rounded.
var harvest_bonus: int = 0
## Tier index of the chest at the moment it opened (0 = wooden).
var chest_tier: int = 0
## Display name of that tier.
var chest_name: String = ""
## Final multiplier of that tier (base multiplier + chest level bonus).
var multiplier: float = 1.0
## Value the chest held when it opened (before the multiplier).
var collected: float = 0.0
## Slimes killed during the run.
var kills: int = 0
## True when the run's boss was defeated (no boss in the first release, always false for now).
var boss_defeated: bool = false
## Loot that rained from the chest: Array of {"kind": String, "count": int}, ordered gem,
## silver, copper; kinds that did not rain are omitted.
var drops: Array = []


## Gold earned by the run: base gold + harvest bonus.
func total_gold() -> int:
	return base_gold + harvest_bonus
