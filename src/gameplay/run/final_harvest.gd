class_name FinalHarvest
extends RefCounted
## The final harvest: a short timer during which the cursor magnet may pick the landed loot up
## again. Every picked coin adds a bonus (coin value formula, NO chest tier multiplier) that is
## accumulated separately from the chest. Pure data, no node access.
##
## Implements design/game-brief.md (MVP 4) via production/epics/slime-nodaji/story-004-run-timer-burst.md.
## New feature, not in the prototype slime-nodaji.html; the bonus reuses SlimeField.coin_value
## (base value * 1.07 ^ runs * (1 + 0.3 * coin level)). Numbers come from assets/data/run.json (harvest).

## Seconds left of the harvest; 0 once it is over.
var time_left: float = 0.0
## Accumulated bonus (float, rounded only when the RunResult is built).
var bonus: float = 0.0
## Kind of every coin picked so far, in pick order.
var picked: Array[String] = []

var _slime_config: Dictionary
var _runs: int = 0
var _coin_level: int = 0


## `run_config` is the full run.json config, `slime_config` the slime_field config (coin values),
## `runs` the completed runs and `coin_level` the coin upgrade level.
func _init(run_config: Dictionary, slime_config: Dictionary, runs: int, coin_level: int) -> void:
	time_left = float(run_config["harvest"]["duration"])
	_slime_config = slime_config
	_runs = runs
	_coin_level = coin_level


## Bonus of one picked coin: SlimeField.coin_value (base * run scale * coin level multiplier).
static func bonus_for(slime_config: Dictionary, kind: String, runs: int, coin_level: int) -> float:
	return SlimeField.coin_value(slime_config, kind, runs, coin_level)


## Counts the timer down by `delta` seconds, never below 0.
func advance(delta: float) -> void:
	time_left = maxf(0.0, time_left - delta)


## True once the timer ran out.
func is_finished() -> bool:
	return time_left <= 0.0


## Records a picked coin of `kind` and returns the bonus it added.
func pick(kind: String) -> float:
	var amount: float = bonus_for(_slime_config, kind, _runs, _coin_level)
	bonus += amount
	picked.append(kind)
	return amount


## The accumulated bonus rounded to whole gold (half away from zero, like Math.round).
func rounded_bonus() -> int:
	return roundi(bonus)
