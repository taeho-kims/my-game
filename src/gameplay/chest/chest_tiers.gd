class_name ChestTiers
extends RefCounted
## Chest tier formulas and the chest_tiers data file loader. Pure static functions, no node or
## scene access, so every rule stays unit-testable.
##
## Implements design/game-brief.md (MVP 3) via production/epics/slime-nodaji/story-003-magnet-chest-tiers.md.
## Values ported from slime-nodaji.html (TIERS, tierOf, multOf, stats().chestBonus, beginBurst total).
## `run_scale` is the per-run growth factor (1.07 ^ runs), see SlimeField.run_scale.


## Loads and validates the chest data file; returns an empty Dictionary (after push_error)
## when the file is missing or invalid.
##
## Schema (all numbers unless noted; see assets/data/chest_tiers.json):
## - chest_bonus_per_level: multiplier added per chest level and tier number (0.1).
## - tiers: ascending array of {name (String), threshold (chest value before run scale),
##   multiplier (base multiplier), color (hex String)}.
## - chest: bottom_offset (px above the field bottom), bump_decay (1/s), bump_scale (extra scale
##   at full bump), bump_lift (px the chest rises at full bump).
## - magnet: base_radius / radius_per_level (px), fly_speed (flight progress per second),
##   control_x_range (px), control_rise_min / control_rise_max (px above the curve's anchor),
##   arrival_height (px above the chest position where a coin lands), flight_spin_rate (rad per
##   unit of flight progress), flight_z_index, ring_color (hex String), ring_alpha (0..1), ring_width (px).
## - sound: mix_rate (Hz), duration (s), volume (0..1), pitch_rise (end/start frequency ratio),
##   throttle_ms (minimum gap between blips), pitch {copper, silver, gem} (Hz).
static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("ChestTiers: data file not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ChestTiers: data file is not a valid JSON object: %s" % path)
		return {}
	var data: Dictionary = parsed
	var problem: String = _find_problem(data)
	if not problem.is_empty():
		push_error("ChestTiers: invalid data file %s: %s" % [path, problem])
		return {}
	return data


## Chest value needed to reach `tier`: tier threshold * run scale.
static func threshold(config: Dictionary, tier: int, run_scale: float) -> float:
	var tiers: Array = config["tiers"]
	var entry: Dictionary = tiers[tier]
	return float(entry["threshold"]) * run_scale


## Tier of a chest holding `value`: the highest tier whose scaled threshold is <= value.
static func tier_of(config: Dictionary, value: float, run_scale: float) -> int:
	var tiers: Array = config["tiers"]
	var result: int = 0
	for i: int in tiers.size():
		if value >= threshold(config, i, run_scale):
			result = i
	return result


## Base multiplier of a tier (1 / 1.25 / 1.5 / 2 / 3), before the chest level bonus.
static func base_multiplier(config: Dictionary, tier: int) -> float:
	var tiers: Array = config["tiers"]
	var entry: Dictionary = tiers[tier]
	return float(entry["multiplier"])


## Tier multiplier: base multiplier + bonus per level * chest level * tier number.
static func multiplier(config: Dictionary, tier: int, chest_level: int) -> float:
	var bonus: float = float(config["chest_bonus_per_level"]) * chest_level
	return base_multiplier(config, tier) + bonus * tier


## Final payout: round(chest value * tier multiplier).
static func total(config: Dictionary, value: float, tier: int, chest_level: int) -> int:
	return roundi(value * multiplier(config, tier, chest_level))


## Display name of a tier.
static func tier_name(config: Dictionary, tier: int) -> String:
	var tiers: Array = config["tiers"]
	var entry: Dictionary = tiers[tier]
	return entry["name"]


## Display color of a tier.
static func tier_color(config: Dictionary, tier: int) -> Color:
	var tiers: Array = config["tiers"]
	var entry: Dictionary = tiers[tier]
	return Color.html(entry["color"])


## Returns a description of the first schema problem, or "" when the data is valid.
static func _find_problem(data: Dictionary) -> String:
	var schema: Dictionary = {
		"chest_bonus_per_level": TYPE_FLOAT,
		"tiers": TYPE_ARRAY,
		"chest": {"bottom_offset": TYPE_FLOAT, "bump_decay": TYPE_FLOAT, "bump_scale": TYPE_FLOAT,
			"bump_lift": TYPE_FLOAT},
		"magnet": {"base_radius": TYPE_FLOAT, "radius_per_level": TYPE_FLOAT, "fly_speed": TYPE_FLOAT,
			"control_x_range": TYPE_FLOAT, "control_rise_min": TYPE_FLOAT, "control_rise_max": TYPE_FLOAT,
			"arrival_height": TYPE_FLOAT, "flight_spin_rate": TYPE_FLOAT, "flight_z_index": TYPE_FLOAT,
			"ring_color": TYPE_STRING, "ring_alpha": TYPE_FLOAT, "ring_width": TYPE_FLOAT},
		"sound": {"mix_rate": TYPE_FLOAT, "duration": TYPE_FLOAT, "volume": TYPE_FLOAT,
			"pitch_rise": TYPE_FLOAT, "throttle_ms": TYPE_FLOAT, "pitch": TYPE_DICTIONARY},
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
	var tiers: Array = data["tiers"]
	if tiers.is_empty():
		return "'tiers' must not be empty"
	var previous: float = -INF
	for i: int in tiers.size():
		if typeof(tiers[i]) != TYPE_DICTIONARY:
			return "'tiers[%d]' must be an object" % i
		var entry: Dictionary = tiers[i]
		for sub_key: String in ["name", "color"]:
			if typeof(entry.get(sub_key)) != TYPE_STRING:
				return "'tiers[%d].%s' missing or not a string" % [i, sub_key]
		for sub_key: String in ["threshold", "multiplier"]:
			if typeof(entry.get(sub_key)) != TYPE_FLOAT:
				return "'tiers[%d].%s' missing or not a number" % [i, sub_key]
		if float(entry["threshold"]) < previous:
			return "'tiers[%d].threshold' must not decrease" % i
		previous = entry["threshold"]
	for kind: String in ["copper", "silver", "gem"]:
		if typeof(data["sound"]["pitch"].get(kind)) != TYPE_FLOAT:
			return "sound.pitch.%s missing or not a number" % kind
	return ""
