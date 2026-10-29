class_name RunEvents
extends RefCounted
## The four run events (golden slime, slime rain, treasure goblin, boss pudding): the pure rules -
## which events a run has and when (decided once at run start), spawn chances, hp and coin counts.
## No nodes; the spawning is done by SlimeField and run_scene.gd.
##
## Implements design/game-brief.md (MVP 7) via production/epics/slime-nodaji/story-007-run-events.md.
## Values ported from slime-nodaji.html (newRun, spawnSlime, update, hurt, kill); spatial values halved.
## What a run gets comes from PlayerStats (the one place that turns node levels into stats), so a level
## is never turned into a chance by a second formula.

## Event ids returned by `poll`.
const RAIN: String = "rain"
const GOBLIN: String = "goblin"
const BOSS: String = "boss"

## Chance that a spawning normal slime is golden (the base chance without the golden node).
var golden_chance: float = 0.0
## Event start times in seconds from run start; -1 when the event does not happen this run.
var rain_at: float = -1.0
var goblin_at: float = -1.0
var boss_at: float = -1.0


## Loads and validates assets/data/run_events.json; returns an empty Dictionary (after push_error) when
## the file is missing or invalid. Sections: rich_coin_kind_chance {gem, silver}, fall.gravity, golden,
## rain, goblin, boss, banner (see the file; spatial values are px at the 640x360 base, times in seconds).
static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("RunEvents: data file not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RunEvents: data file is not a valid JSON object: %s" % path)
		return {}
	var data: Dictionary = parsed
	var schema: Dictionary = {
		"rich_coin_kind_chance": ["gem", "silver"],
		"fall": ["gravity"],
		"golden": ["base_hp", "radius", "color", "kill_coins"],
		"rain": ["window_start", "window_end_margin", "count", "height_min", "height_max"],
		"goblin": ["window_start", "window_end_ratio", "base_hp", "radius", "life", "hit_drop_chance",
			"hit_drop_coins", "kill_coins", "spawn_margin_x", "exit_margin", "flee_speed_x", "flee_speed_y",
			"flee_response", "exit_speed_boost", "wander_speed_y_factor", "colors"],
		"boss": ["time_ratio", "base_hp", "radius", "drop_height", "kill_coins", "hop_speed", "landing_shake",
			"hp_bar_width", "hp_bar_lift", "color", "crown_color", "crown_rects"],
		"banner": ["duration", "pop_time", "pop_scale", "fade_start", "font_size", "outline_size", "top_ratio",
			"color", "outline_color", "text"],
		"force": ["golden_chance", "times"],
	}
	for section: String in schema:
		if not data.has(section) or typeof(data[section]) != TYPE_DICTIONARY:
			push_error("RunEvents: invalid data file %s: missing or non-object section '%s'" % [path, section])
			return {}
		for key: String in schema[section]:
			if not (data[section] as Dictionary).has(key):
				push_error("RunEvents: invalid data file %s: missing key '%s.%s'" % [path, section, key])
				return {}
	if float(data["banner"]["duration"]) <= 0.0:
		push_error("RunEvents: banner.duration must be > 0")
		return {}
	return data


## Hp of an event slime ("golden", "goblin" or "boss"): base hp * run scale (the slime field's 1.07^runs).
static func hp(config: Dictionary, slime_config: Dictionary, kind: String, runs: int) -> float:
	return float(config[kind]["base_hp"]) * SlimeField.run_scale(slime_config, runs)


## Coins dropped when an event slime is killed.
static func kill_coins(config: Dictionary, kind: String) -> int:
	return int(config[kind]["kill_coins"])


## True when a uniform roll in [0, 1) makes a hit goblin drop a coin.
static func goblin_hit_drops(config: Dictionary, roll: float) -> bool:
	return roll < float(config["goblin"]["hit_drop_chance"])


## True once a goblin lived its `life` seconds and starts leaving the field.
static func goblin_expired(config: Dictionary, age: float) -> bool:
	return age >= float(config["goblin"]["life"])


## Decides the events of a run (call once at run start). `stats` is PlayerStats.compute (golden and rain
## chances, goblin and boss flags), `duration` the run length in seconds and `rng` the injected generator.
## The golden chance is the stats value as is: like the prototype, golden slimes appear (at the base
## chance) even without the golden node; rain, goblin and boss need their node.
func start(config: Dictionary, stats: Dictionary, duration: float, rng: RandomNumberGenerator) -> void:
	golden_chance = float(stats["golden"])
	rain_at = -1.0
	goblin_at = -1.0
	boss_at = -1.0
	var rain: Dictionary = config["rain"]
	var rain_chance: float = stats["rain"]
	if rain_chance > 0.0 and rng.randf() < rain_chance:
		var from: float = rain["window_start"]
		rain_at = rng.randf_range(from, maxf(from, duration - float(rain["window_end_margin"])))
	if bool(stats["goblin"]):
		var goblin: Dictionary = config["goblin"]
		var from: float = goblin["window_start"]
		goblin_at = rng.randf_range(from, maxf(from, duration * float(goblin["window_end_ratio"])))
	if bool(stats["boss"]):
		boss_at = duration * float(config["boss"]["time_ratio"])


## Dev: schedules all four events at the config's "force" times and sets the forced golden chance.
func force_all(config: Dictionary) -> void:
	var force: Dictionary = config["force"]
	golden_chance = force["golden_chance"]
	rain_at = force["times"]["rain"]
	goblin_at = force["times"]["goblin"]
	boss_at = force["times"]["boss"]


## Event ids that became due at `elapsed` seconds into the run; each fires once.
func poll(elapsed: float) -> Array[String]:
	var due: Array[String] = []
	if rain_at >= 0.0 and elapsed >= rain_at:
		rain_at = -1.0
		due.append(RAIN)
	if goblin_at >= 0.0 and elapsed >= goblin_at:
		goblin_at = -1.0
		due.append(GOBLIN)
	if boss_at >= 0.0 and elapsed >= boss_at:
		boss_at = -1.0
		due.append(BOSS)
	return due
