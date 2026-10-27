class_name SlimeField
extends Node2D
## Owns the normal slimes and dropped coins of one run: spawn timer, population cap,
## kill handling and coin drops.
##
## Implements design/game-brief.md (MVP 2) via production/epics/slime-nodaji/story-001-slime-field.md.
## Values ported from slime-nodaji.html (newRun, stats, spawnSlime, kill, dropCoins, update).
## Randomness, config and run progress are injected through `setup` (no singletons).

## Emitted after a slime died and was removed from the field.
signal slime_killed(slime: Slime)
## Emitted for every coin created by a kill.
signal coin_dropped(coin: Coin)

## Live slimes on the field.
var slimes: Array[Slime] = []
## Live coins on the field.
var coins: Array[Coin] = []

var _config: Dictionary = {}
var _rng: RandomNumberGenerator
var _bounds: Rect2
var _runs: int = 0
var _density_level: int = 0
var _coin_level: int = 0
var _spawn_timer: float = 0.0


## Loads and validates the slime field data file; returns an empty Dictionary (after
## push_error) when the file is missing or invalid.
##
## Schema (all numbers; see assets/data/slime_field.json):
## - reference_fps: frame rate that per-frame damping factors were tuned at.
## - run_scale_base: per-run growth base (hp and coin value scale = base^runs).
## - field: top (px), bottom_margin (px above the viewport bottom).
## - spawn: interval (s), base_max, max_per_density_level, start_count, margin_x/top/bottom (px spawn insets).
## - slime: base_hp, radius range, colors (hex), hop timing (s) and speed (px/s) ranges, hop_y_ratio,
##   hop_duration (s), glide_damping (per frame), flash_time (s), hop/wobble visuals, hp_bar_width (px).
## - drop: coins_base, extra_coin_chance (0..1).
## - coin: kind_chance {gem, silver} (copper is the remainder), base_value, value_bonus_per_coin_level,
##   colors {kind: [main, edge]}, life/blink_time (s), blink_frequency (rad/s), scatter/pop speeds (px/s),
##   scatter_y_ratio, start_height, gravity, bounce_restitution, bounce_min_speed, drag (per frame),
##   margin_x, bottom_slack (px), spin_rate (rad/s).
static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("SlimeField: data file not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SlimeField: data file is not a valid JSON object: %s" % path)
		return {}
	var data: Dictionary = parsed
	var problem: String = _find_problem(data)
	if not problem.is_empty():
		push_error("SlimeField: invalid data file %s: %s" % [path, problem])
		return {}
	return data


## Maximum number of normal slimes alive at once: base + per_level * density level.
static func max_slimes(config: Dictionary, density_level: int) -> int:
	var spawn: Dictionary = config["spawn"]
	return int(spawn["base_max"]) + int(spawn["max_per_density_level"]) * density_level


## Per-run growth factor: run_scale_base ^ runs.
static func run_scale(config: Dictionary, runs: int) -> float:
	return pow(float(config["run_scale_base"]), runs)


## Normal slime hp: base_hp * run scale.
static func slime_hp(config: Dictionary, runs: int) -> float:
	var slime: Dictionary = config["slime"]
	return float(slime["base_hp"]) * run_scale(config, runs)


## Coin value: base value * run scale * (1 + bonus per level * coin level).
static func coin_value(config: Dictionary, kind: String, runs: int, coin_level: int) -> float:
	var coin: Dictionary = config["coin"]
	var base: Dictionary = coin["base_value"]
	var multiplier: float = 1.0 + float(coin["value_bonus_per_coin_level"]) * coin_level
	return float(base[kind]) * run_scale(config, runs) * multiplier


## Maps a uniform roll in [0, 1) to a coin kind: gem, then silver, then copper.
static func roll_coin_kind(config: Dictionary, roll: float) -> String:
	var chance: Dictionary = config["coin"]["kind_chance"]
	var gem: float = chance["gem"]
	var silver: float = chance["silver"]
	if roll < gem:
		return "gem"
	if roll < gem + silver:
		return "silver"
	return "copper"


## Prepares the field for a run and spawns the starting slimes.
## `field_size` is the viewport size; `runs` is the number of completed runs.
func setup(config: Dictionary, rng: RandomNumberGenerator, field_size: Vector2, runs: int,
		density_level: int, coin_level: int) -> void:
	_config = config
	_rng = rng
	_runs = runs
	_density_level = density_level
	_coin_level = coin_level
	var field: Dictionary = config["field"]
	var top: float = field["top"]
	var bottom: float = field_size.y - float(field["bottom_margin"])
	_bounds = Rect2(0.0, top, field_size.x, bottom - top)
	y_sort_enabled = true
	_spawn_timer = 0.0
	var spawn: Dictionary = config["spawn"]
	for i in int(spawn["start_count"]):
		_spawn_slime()


## Advances the spawn timer: one slime per interval while below the population cap.
func tick(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and slimes.size() < max_slimes(_config, _density_level):
		_spawn_slime()
		var spawn: Dictionary = _config["spawn"]
		_spawn_timer = spawn["interval"]


func _process(delta: float) -> void:
	tick(delta)


func _spawn_slime() -> void:
	var spawn: Dictionary = _config["spawn"]
	var slime_cfg: Dictionary = _config["slime"]
	var margin_x: float = spawn["margin_x"]
	var pos := Vector2(
		_rng.randf_range(margin_x, _bounds.end.x - margin_x),
		_rng.randf_range(_bounds.position.y + float(spawn["margin_top"]), _bounds.end.y - float(spawn["margin_bottom"])))
	var radius: float = _rng.randf_range(slime_cfg["radius_min"], slime_cfg["radius_max"])
	var colors: Array = slime_cfg["colors"]
	var color := Color.html(colors[_rng.randi_range(0, colors.size() - 1)])
	var slime := Slime.new()
	add_child(slime)
	slime.setup(_config, _rng, _bounds, pos, slime_hp(_config, _runs), radius, color)
	slime.died.connect(_on_slime_died)
	slimes.append(slime)


func _on_slime_died(slime: Slime) -> void:
	slimes.erase(slime)
	var drop: Dictionary = _config["drop"]
	var count: int = int(drop["coins_base"])
	if _rng.randf() < float(drop["extra_coin_chance"]):
		count += 1
	for i in count:
		_drop_coin(slime.position)
	slime_killed.emit(slime)
	slime.queue_free()


func _drop_coin(origin: Vector2) -> void:
	var cfg: Dictionary = _config["coin"]
	var kind: String = roll_coin_kind(_config, _rng.randf())
	var angle: float = _rng.randf_range(0.0, TAU)
	var speed: float = _rng.randf_range(cfg["scatter_speed_min"], cfg["scatter_speed_max"])
	var velocity := Vector2(cos(angle), sin(angle) * float(cfg["scatter_y_ratio"])) * speed
	var pop_speed: float = _rng.randf_range(cfg["pop_speed_min"], cfg["pop_speed_max"])
	var coin := Coin.new()
	add_child(coin)
	coin.setup(_config, kind, coin_value(_config, kind, _runs, _coin_level), _bounds, origin, velocity, pop_speed)
	coin.expired.connect(_on_coin_expired)
	coins.append(coin)
	coin_dropped.emit(coin)


func _on_coin_expired(coin: Coin) -> void:
	coins.erase(coin)
	coin.queue_free()


## Returns a description of the first schema problem, or "" when the data is valid.
static func _find_problem(data: Dictionary) -> String:
	var schema: Dictionary = {
		"reference_fps": TYPE_FLOAT,
		"run_scale_base": TYPE_FLOAT,
		"field": {"top": TYPE_FLOAT, "bottom_margin": TYPE_FLOAT},
		"spawn": {"interval": TYPE_FLOAT, "base_max": TYPE_FLOAT, "max_per_density_level": TYPE_FLOAT,
			"start_count": TYPE_FLOAT, "margin_x": TYPE_FLOAT, "margin_top": TYPE_FLOAT, "margin_bottom": TYPE_FLOAT},
		"slime": {"base_hp": TYPE_FLOAT, "radius_min": TYPE_FLOAT, "radius_max": TYPE_FLOAT, "colors": TYPE_ARRAY,
			"first_hop_min": TYPE_FLOAT, "first_hop_max": TYPE_FLOAT, "hop_interval_min": TYPE_FLOAT,
			"hop_interval_max": TYPE_FLOAT, "hop_speed_min": TYPE_FLOAT, "hop_speed_max": TYPE_FLOAT,
			"hop_y_ratio": TYPE_FLOAT, "hop_duration": TYPE_FLOAT, "glide_damping": TYPE_FLOAT,
			"flash_time": TYPE_FLOAT, "age_phase_max": TYPE_FLOAT, "hop_stretch_x": TYPE_FLOAT,
			"hop_stretch_y": TYPE_FLOAT, "hop_lift": TYPE_FLOAT, "wobble_amplitude": TYPE_FLOAT,
			"wobble_speed": TYPE_FLOAT, "hp_bar_width": TYPE_FLOAT},
		"drop": {"coins_base": TYPE_FLOAT, "extra_coin_chance": TYPE_FLOAT},
		"coin": {"kind_chance": TYPE_DICTIONARY, "base_value": TYPE_DICTIONARY,
			"value_bonus_per_coin_level": TYPE_FLOAT, "colors": TYPE_DICTIONARY, "life": TYPE_FLOAT,
			"blink_time": TYPE_FLOAT, "blink_frequency": TYPE_FLOAT, "scatter_speed_min": TYPE_FLOAT,
			"scatter_speed_max": TYPE_FLOAT, "scatter_y_ratio": TYPE_FLOAT, "start_height": TYPE_FLOAT,
			"pop_speed_min": TYPE_FLOAT, "pop_speed_max": TYPE_FLOAT, "gravity": TYPE_FLOAT,
			"bounce_restitution": TYPE_FLOAT, "bounce_min_speed": TYPE_FLOAT, "drag": TYPE_FLOAT,
			"margin_x": TYPE_FLOAT, "bottom_slack": TYPE_FLOAT, "spin_rate": TYPE_FLOAT},
	}
	for key: String in schema:
		if not data.has(key):
			return "missing key '%s'" % key
		var expected: Variant = schema[key]
		if expected is Dictionary:
			if typeof(data[key]) != TYPE_DICTIONARY:
				return "'%s' must be an object" % key
			var section: Dictionary = data[key]
			for sub_key: String in expected:
				if not section.has(sub_key):
					return "missing key '%s.%s'" % [key, sub_key]
				if typeof(section[sub_key]) != expected[sub_key]:
					return "'%s.%s' has the wrong type" % [key, sub_key]
		elif typeof(data[key]) != expected:
			return "'%s' has the wrong type" % key
	var colors: Array = data["slime"]["colors"]
	if colors.is_empty():
		return "'slime.colors' must not be empty"
	for kind: String in ["copper", "silver", "gem"]:
		if not data["coin"]["base_value"].has(kind) or not data["coin"]["colors"].has(kind):
			return "coin kind '%s' missing from coin.base_value or coin.colors" % kind
	for kind: String in ["gem", "silver"]:
		if not data["coin"]["kind_chance"].has(kind):
			return "coin.kind_chance.%s missing" % kind
	return ""
