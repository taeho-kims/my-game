class_name RunController
extends Node
## Owns one run's phase flow: RUNNING (timed play) -> BURST (the chest moves to the centre and
## opens, loot rains) -> HARVEST (final harvest: the magnet may pick the landed loot up again)
## -> RESULT (one RunResult is emitted). No UI node is referenced: the HUD, the result screen and
## the burst visuals read the getters and connect to the signals. `advance(delta)` drives the
## whole flow and needs no scene tree.
##
## Implements design/game-brief.md (MVP 4) via production/epics/slime-nodaji/story-004-run-timer-burst.md.
## Values ported from slime-nodaji.html (newRun, stats().time, beginBurst, updateBurst, finishRun,
## hud); spatial values halved for the 640x360 base. All numbers live in assets/data/run.json.
##
## Phase transition table (TRANSITIONS):
##   RUNNING -> BURST    the run time ran out
##   BURST   -> HARVEST  the chest is open and every loot coin touched the floor, or
##                       harvest.start_max_wait passed since opening
##   HARVEST -> RESULT   the harvest timer is 0 and no magnet coin is still flying
##   RESULT  -> (none)
##
## Deliberate deviation from the prototype: the prototype froze the chest total at beginBurst; here
## it is frozen at the OPEN moment (burst.open_time), so coins that were already flying to the chest
## when the time ran out still count. The wiring must not let the magnet absorb anything new once
## BURST starts (see `magnet_allowed`).
##
## Wiring contract for Part B: add every deposit to `collected`, count kills in `kills`, create one
## Coin per entry of `loot` when HARVEST starts (store the entry's "id" as meta "loot_id"), point the
## Magnet at the open chest with `Magnet.set_target(chest_position, func(coin): pick_loot(id))`, and
## pass `magnet.flying_count` as `pending_flights` to `start`.

## Emitted on every phase change, after the state of the new phase is ready.
signal phase_changed(phase: int)
## Emitted once when the chest opens (the burst screen shake and sound belong here).
signal chest_opened
## Emitted for a rain blip while loot rains (BURST only) with its pitch in Hz.
signal rain_blip(frequency: float)
## Emitted exactly once, when the phase becomes RESULT.
signal run_finished(result: RunResult)

enum Phase { RUNNING, BURST, HARVEST, RESULT }

## Allowed phase transitions.
const TRANSITIONS: Dictionary = {
	Phase.RUNNING: [Phase.BURST],
	Phase.BURST: [Phase.HARVEST],
	Phase.HARVEST: [Phase.RESULT],
	Phase.RESULT: [],
}

## Current phase.
var phase: Phase = Phase.RUNNING
## Value the chest holds; the wiring adds every deposit. Read when the chest opens.
var collected: float = 0.0
## Slimes killed this run; the wiring increments it.
var kills: int = 0
## Run length in seconds: base_time + time_per_level * time level.
var duration: float = 0.0
## Seconds since BURST started.
var burst_time: float = 0.0
## True from the chest opening on.
var opened: bool = false
## Base gold shown over the open chest, counting up to `base_gold`.
var shown_gold: float = 0.0
## Frozen at the open moment: base gold, chest tier and tier multiplier.
var base_gold: int = 0
var chest_tier: int = 0
var multiplier: float = 1.0
## Loot coins (see ChestBurst for the Dictionary keys): rains in BURST, frozen on the floor in
## HARVEST (picked ones are removed), empty again in RESULT.
var loot: Array[Dictionary] = []
## The finished run; null until RESULT.
var result: RunResult

var _config: Dictionary = {}
var _chest_config: Dictionary = {}
var _slime_config: Dictionary = {}
var _rng: RandomNumberGenerator
var _field_size: Vector2 = Vector2.ZERO
var _chest_start: Vector2 = Vector2.ZERO
var _runs: int = 0
var _chest_level: int = 0
var _coin_level: int = 0
var _elapsed: float = 0.0
var _since_open: float = 0.0
var _next_loot_id: int = 0
var _drops: Array = []
var _harvest: FinalHarvest
var _pending_flights: Callable


## Loads and validates the run data file; returns an empty Dictionary (after push_error) when
## the file is missing or invalid.
##
## Schema (all numbers unless noted; see assets/data/run.json):
## - run: map_id (String), base_time (s), time_per_level (s per time level), low_time_threshold (s; the
##   low-time warning shows while the remaining time is strictly below it).
## - burst: move_time (s the chest takes to reach the centre), open_time (s until it opens), scale_gain
##   (extra chest scale at the centre), dim_alpha_max (0..1), center_offset_y (px below the field centre),
##   shake_start (s; the chest shakes after it until opened), shake_amplitude (px), open_shake (px of
##   screen shake at opening), count_up_time (s of the gold count-up), count_up_min_rate (gold per second
##   added on top, keeps the count-up moving), open_sound {wave (String), frequency (Hz), duration (s), volume}.
## - rain: count_base / count_per_sqrt_total / count_max (loot count = min(max, floor(base + sqrt(total) * per))),
##   kind_chance {gem, silver} (0..1, copper is the remainder), gravity (px/s^2, shapes the loot's flight arc),
##   spin_rate (rad/s), spin_start_max (rad),
##   blip {wave (String), chance (0..1 per advance), frequency_min / frequency_max (Hz), duration (s), volume}.
## - ring: inner_radius (px), width (px; outer radius = inner + width), gem_band (0..1, share of the width at the
##   outer edge where gems land), spread_speed (px/s the loot flies out of the chest at). The loot lands on this
##   ring around the open chest, where the final harvest picks it up.
## - harvest: duration (s of the final harvest), start_max_wait (s after opening before it starts anyway).
static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("RunController: data file not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RunController: data file is not a valid JSON object: %s" % path)
		return {}
	var data: Dictionary = parsed
	var problem: String = _find_problem(data)
	if not problem.is_empty():
		push_error("RunController: invalid data file %s: %s" % [path, problem])
		return {}
	return data


## Run length in seconds: base_time + time_per_level * time level.
static func run_duration(config: Dictionary, time_level: int) -> float:
	var run: Dictionary = config["run"]
	return float(run["base_time"]) + float(run["time_per_level"]) * time_level


## True while `remaining` seconds is strictly below the low-time threshold (the HUD turns red).
static func is_low_time(config: Dictionary, remaining: float) -> bool:
	return remaining < float(config["run"]["low_time_threshold"])


## Starts a run in the RUNNING phase.
## `config` is run.json, `chest_config` chest_tiers.json, `slime_config` slime_field.json; `field_size`
## the viewport size; `chest_start` the chest's field position (where the burst move begins); `runs`
## the completed runs; `levels` a Dictionary with int entries "time", "chest", "coin".
## `pending_flights` is an optional Callable returning how many magnet coins are still flying (pass
## `magnet.flying_count`); the harvest only ends once it returns 0.
func start(config: Dictionary, chest_config: Dictionary, slime_config: Dictionary, rng: RandomNumberGenerator,
		field_size: Vector2, chest_start: Vector2, runs: int, levels: Dictionary,
		pending_flights: Callable = Callable()) -> void:
	_config = config
	_chest_config = chest_config
	_slime_config = slime_config
	_rng = rng
	_field_size = field_size
	_chest_start = chest_start
	_runs = runs
	_chest_level = levels["chest"]
	_coin_level = levels["coin"]
	_pending_flights = pending_flights
	duration = run_duration(config, levels["time"])


## Advances the run by `delta` seconds. Does nothing before `start` and after RESULT.
func advance(delta: float) -> void:
	if _config.is_empty():
		return
	match phase:
		Phase.RUNNING:
			_elapsed += delta
			if _elapsed >= duration:
				_enter(Phase.BURST)
		Phase.BURST:
			_advance_burst(delta)
		Phase.HARVEST:
			_harvest.advance(delta)
			if _harvest.is_finished() and _flying_count() == 0:
				_enter(Phase.RESULT)
		Phase.RESULT:
			pass


## Picks the loot coin with `id` up during the harvest: removes it and adds its bonus. Returns
## false (and does nothing) outside HARVEST or when the coin is not on the list, so a coin never
## pays twice.
func pick_loot(id: int) -> bool:
	if phase != Phase.HARVEST:
		return false
	for i: int in loot.size():
		if loot[i]["id"] == id:
			_harvest.pick(loot[i]["kind"])
			loot.remove_at(i)
			return true
	return false


## True while knights may still be dropped (RUNNING only: the drops stop when the time is up).
func hero_drop_allowed() -> bool:
	return phase == Phase.RUNNING


## True while the magnet may absorb new coins: RUNNING, and HARVEST until its timer ran out.
## Never during BURST or RESULT.
func magnet_allowed() -> bool:
	return phase == Phase.RUNNING or (phase == Phase.HARVEST and not _harvest.is_finished())


## Seconds of run time left; 0 once the time is up.
func remaining_time() -> float:
	return maxf(0.0, duration - _elapsed) if phase == Phase.RUNNING else 0.0


## Remaining time as a 0..1 fraction of the run length (the HUD time bar).
func time_ratio() -> float:
	return remaining_time() / duration if duration > 0.0 else 0.0


## True while the low-time warning shows (RUNNING and remaining below the threshold).
func is_time_low() -> bool:
	return phase == Phase.RUNNING and is_low_time(_config, remaining_time())


## Eased burst progress 0..1 (0 before BURST, 1 once the chest is in the centre).
func burst_progress() -> float:
	return ChestBurst.ease_out(_config, burst_time)


## Chest position during the burst (its start position before BURST).
func chest_position() -> Vector2:
	return ChestBurst.chest_position(_config, _chest_start, _field_size, burst_time)


## Chest scale during the burst (1 before BURST).
func chest_scale() -> float:
	return ChestBurst.chest_scale(_config, burst_time)


## Alpha of the dark overlay during the burst.
func dim_alpha() -> float:
	return ChestBurst.dim_alpha(_config, burst_time)


## True while the closed chest shakes; the view applies ChestBurst.shake_offset with its own roll.
func chest_shaking() -> bool:
	return phase == Phase.BURST and ChestBurst.is_shaking(_config, burst_time, opened)


## Seconds left of the final harvest (the full duration before it starts, 0 after).
func harvest_time_left() -> float:
	if phase == Phase.HARVEST:
		return _harvest.time_left
	return float(_config["harvest"]["duration"]) if phase < Phase.HARVEST else 0.0


## Bonus accumulated by the harvest so far (float; 0 before HARVEST).
func harvest_bonus() -> float:
	return _harvest.bonus if _harvest != null else 0.0


func _process(delta: float) -> void:
	advance(delta)


func _advance_burst(delta: float) -> void:
	burst_time += delta
	if not opened and ChestBurst.is_open_time(_config, burst_time):
		_open()
	if not opened:
		return
	_since_open += delta
	for coin: Dictionary in loot:
		ChestBurst.step_ring_loot(_config, coin, delta)
	shown_gold = ChestBurst.shown_gold_step(_config, shown_gold, base_gold, delta)
	if ChestBurst.blip_due(_config, _rng.randf()):
		rain_blip.emit(ChestBurst.blip_frequency(_config, _rng.randf()))
	if ChestBurst.all_landed(loot) or _since_open >= float(_config["harvest"]["start_max_wait"]):
		_enter(Phase.HARVEST)


## Opens the chest: freezes tier, multiplier and base gold from `collected`, launches the loot
## towards the ring around the chest (per coin the rng draws the kind roll, the angle, the radius
## roll, then the start spin) and emits `chest_opened`.
func _open() -> void:
	opened = true
	var run_scale: float = SlimeField.run_scale(_slime_config, _runs)
	chest_tier = ChestTiers.tier_of(_chest_config, collected, run_scale)
	multiplier = ChestTiers.multiplier(_chest_config, chest_tier, _chest_level)
	base_gold = ChestBurst.base_gold(_chest_config, collected, run_scale, _chest_level)
	for i: int in ChestBurst.drop_count(_config, base_gold):
		var kind: String = ChestBurst.roll_kind(_config, _rng.randf())
		var angle_roll: float = _rng.randf()
		var radius_roll: float = _rng.randf()
		var spin: float = _rng.randf_range(0.0, float(_config["rain"]["spin_start_max"]))
		loot.append(ChestBurst.make_ring_loot(_config, _field_size, _next_loot_id, kind, angle_roll, radius_roll, spin))
		_next_loot_id += 1
	_drops = ChestBurst.tally_drops(loot)
	chest_opened.emit()


func _enter(next: Phase) -> void:
	if not TRANSITIONS[phase].has(next):
		push_error("RunController: illegal phase transition %d -> %d" % [phase, next])
		return
	phase = next
	match next:
		Phase.HARVEST:
			for coin: Dictionary in loot:
				ChestBurst.settle_ring_loot(coin)
			_harvest = FinalHarvest.new(_config, _slime_config, _runs, _coin_level)
		Phase.RESULT:
			loot.clear()
			result = _build_result()
	phase_changed.emit(next)
	if next == Phase.RESULT:
		run_finished.emit(result)


func _build_result() -> RunResult:
	var built := RunResult.new()
	built.map_id = _config["run"]["map_id"]
	built.base_gold = base_gold
	built.harvest_bonus = _harvest.rounded_bonus()
	built.chest_tier = chest_tier
	built.chest_name = ChestTiers.tier_name(_chest_config, chest_tier)
	built.multiplier = multiplier
	built.collected = collected
	built.kills = kills
	built.drops = _drops
	return built


func _flying_count() -> int:
	return int(_pending_flights.call()) if _pending_flights.is_valid() else 0


## Returns a description of the first schema problem, or "" when the data is valid.
static func _find_problem(data: Dictionary) -> String:
	var num: int = TYPE_FLOAT
	var schema: Dictionary = {
		"run": {"map_id": TYPE_STRING, "base_time": num, "time_per_level": num, "low_time_threshold": num},
		"burst": {"move_time": num, "open_time": num, "scale_gain": num, "dim_alpha_max": num,
			"center_offset_y": num, "shake_start": num, "shake_amplitude": num, "open_shake": num,
			"count_up_time": num, "count_up_min_rate": num, "open_sound": TYPE_DICTIONARY},
		"rain": {"count_base": num, "count_per_sqrt_total": num, "count_max": num, "kind_chance": TYPE_DICTIONARY,
			"gravity": num, "spin_rate": num, "spin_start_max": num, "blip": TYPE_DICTIONARY},
		"ring": {"inner_radius": num, "width": num, "gem_band": num, "spread_speed": num},
		"harvest": {"duration": num, "start_max_wait": num},
	}
	for key: String in schema:
		if not data.has(key) or typeof(data[key]) != TYPE_DICTIONARY:
			return "missing or non-object section '%s'" % key
		var section: Dictionary = data[key]
		var expected: Dictionary = schema[key]
		for sub_key: String in expected:
			if not section.has(sub_key):
				return "missing key '%s.%s'" % [key, sub_key]
			if typeof(section[sub_key]) != expected[sub_key]:
				return "'%s.%s' has the wrong type" % [key, sub_key]
	var sound_schema: Dictionary = {"wave": TYPE_STRING, "frequency": num, "duration": num, "volume": num}
	var blip_schema: Dictionary = {"wave": TYPE_STRING, "chance": num, "frequency_min": num, "frequency_max": num,
		"duration": num, "volume": num}
	var nested: Array = [["burst", "open_sound", sound_schema], ["rain", "blip", blip_schema],
		["rain", "kind_chance", {"gem": num, "silver": num}]]
	for entry: Array in nested:
		var section: Dictionary = data[entry[0]][entry[1]]
		var expected: Dictionary = entry[2]
		for sub_key: String in expected:
			if not section.has(sub_key):
				return "missing key '%s.%s.%s'" % [entry[0], entry[1], sub_key]
			if typeof(section[sub_key]) != expected[sub_key]:
				return "'%s.%s.%s' has the wrong type" % [entry[0], entry[1], sub_key]
	if float(data["burst"]["move_time"]) <= 0.0 or float(data["burst"]["count_up_time"]) <= 0.0 \
			or float(data["harvest"]["duration"]) <= 0.0:
		return "burst.move_time, burst.count_up_time and harvest.duration must be > 0"
	if float(data["ring"]["inner_radius"]) <= 0.0 or float(data["ring"]["width"]) <= 0.0 \
			or float(data["ring"]["spread_speed"]) <= 0.0 or clampf(float(data["ring"]["gem_band"]), 0.0, 1.0) != float(data["ring"]["gem_band"]):
		return "ring.inner_radius, ring.width and ring.spread_speed must be > 0 and ring.gem_band within 0..1"
	if float(data["rain"]["kind_chance"]["gem"]) + float(data["rain"]["kind_chance"]["silver"]) > 1.0:
		return "rain.kind_chance.gem + silver must not exceed 1"
	if float(data["rain"]["blip"]["frequency_min"]) > float(data["rain"]["blip"]["frequency_max"]):
		return "rain.blip.frequency_min must not exceed frequency_max"
	return ""
