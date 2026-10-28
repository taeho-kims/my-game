class_name HeroSquad
extends Node2D
## Owns one run's knights: the remaining-knights count, click-to-drop, the landing preview,
## landing impact application and damage-number popups. Wires Hero and LandingImpact to a
## SlimeField. Add this node BEFORE the SlimeField in the tree so the preview is drawn under
## the slimes and knights (effects and popups draw on top via z_index).
##
## Implements design/game-brief.md (MVP 1) via production/epics/slime-nodaji/story-002-hero-drop-combat.md.
## Values ported from slime-nodaji.html (stats, pointerdown, land, hurt, draw landing ghost).
## Config, field, randomness and levels are injected through `setup` (no singletons).

## Emitted when the remaining-knights count changes.
signal remaining_changed(remaining: int)
## Emitted when a knight starts falling.
signal hero_dropped(hero: Hero)
## Emitted at the landing moment, after effects and damage were applied.
signal landed(impact_pos: Vector2, impact_radius: float)
## Emitted for every hit on a slime (landing or sword), after the damage was applied.
signal slime_hit(slime: Slime, amount: float)
## Relays LandingImpact.shake_changed: pixel offset to apply to the view.
signal shake_changed(offset: Vector2)

const DASH_PHASE_FACTOR: float = 2.0

## Knights still available to drop.
var remaining: int = 0

var _config: Dictionary = {}
var _field: SlimeField
var _rng: RandomNumberGenerator
var _impact: LandingImpact
var _popup_layer: Node2D
var _popups: Array[Dictionary] = []
var _land_level: int = 0
var _dmg_level: int = 0
var _spd_level: int = 0
var _run_scale: float = 1.0
var _drop_top: float = 0.0
var _drop_bottom: float = 0.0
var _pointer: Vector2 = Vector2.ZERO
var _pointer_inside: bool = false


## Loads and validates the hero data file; returns an empty Dictionary (after push_error)
## when the file is missing or invalid. Schema: see assets/data/hero_knight.json - sections
## squad, drop, combat, walk, landing, preview, sound, popup; every value is a number except
## the *color keys, which are hex strings.
static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("HeroSquad: data file not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("HeroSquad: data file is not a valid JSON object: %s" % path)
		return {}
	var data: Dictionary = parsed
	var problem: String = _find_problem(data)
	if not problem.is_empty():
		push_error("HeroSquad: invalid data file %s: %s" % [path, problem])
		return {}
	return data


## Knights available at the start of a run: base + per_level * hero level.
static func squad_size(config: Dictionary, hero_level: int) -> int:
	var squad: Dictionary = config["squad"]
	return int(squad["base_count"]) + int(squad["count_per_hero_level"]) * hero_level


## Prepares the squad. `slime_config` is the slime_field config (for field bounds and the run
## scale), `field_size` the viewport size, `runs` the completed runs, `levels` a Dictionary with
## int entries "hero", "land", "spd", "dmg".
func setup(config: Dictionary, slime_config: Dictionary, field: SlimeField, rng: RandomNumberGenerator,
		field_size: Vector2, runs: int, levels: Dictionary) -> void:
	_config = config
	_field = field
	_rng = rng
	_land_level = levels["land"]
	_dmg_level = levels["dmg"]
	_spd_level = levels["spd"]
	_run_scale = SlimeField.run_scale(slime_config, runs)
	_drop_top = float(slime_config["field"]["top"]) + float(config["squad"]["drop_margin_top"])
	_drop_bottom = field_size.y - float(slime_config["field"]["bottom_margin"])
	remaining = squad_size(config, levels["hero"])

	_impact = LandingImpact.new()
	_impact.z_index = 1
	add_child(_impact)
	_impact.setup(config, rng)
	_impact.shake_changed.connect(shake_changed.emit)

	_popup_layer = Node2D.new()
	_popup_layer.z_index = 1
	add_child(_popup_layer)
	_popup_layer.draw.connect(_draw_popups)
	remaining_changed.emit(remaining)


## Drops one knight at `point` (y clamped to the field). Returns false when none are left.
func drop_hero(point: Vector2) -> bool:
	if remaining <= 0:
		return false
	remaining -= 1
	var hero := Hero.new()
	_field.add_child(hero)
	hero.setup(_config, _field.slimes, _rng, _clamp_to_field(point), _dmg_level, _spd_level)
	hero.landed.connect(_on_hero_landed)
	hero.hit_dealt.connect(_on_hero_hit_dealt)
	remaining_changed.emit(remaining)
	hero_dropped.emit(hero)
	return true


func _process(delta: float) -> void:
	_pointer = get_local_mouse_position()
	var popup: Dictionary = _config["popup"] if not _config.is_empty() else {}
	for i: int in range(_popups.size() - 1, -1, -1):
		_popups[i]["age"] += delta
		if _popups[i]["age"] >= float(popup["lifetime"]):
			_popups.remove_at(i)
	if _popup_layer != null:
		_popup_layer.queue_redraw()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _config.is_empty():
		return
	if event is InputEventMouseMotion:
		_pointer_inside = true
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_pointer_inside = true
		drop_hero(get_local_mouse_position())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_pointer_inside = false


func _clamp_to_field(point: Vector2) -> Vector2:
	return Vector2(point.x, clampf(point.y, _drop_top, _drop_bottom))


func _hit(slime: Slime, amount: float) -> void:
	var popup: Dictionary = _config["popup"]
	var jitter: float = popup["jitter_x"]
	_popups.append({
		"pos": slime.position + Vector2(_rng.randf_range(-jitter, jitter), -slime.radius * float(popup["y_ratio"])),
		"text": str(roundi(maxf(1.0, amount))),
		"age": 0.0,
	})
	slime.take_damage(amount)
	slime_hit.emit(slime, amount)


func _on_hero_landed(hero: Hero) -> void:
	var impact_radius: float = LandingImpact.radius(_config, _land_level)
	_impact.trigger(hero.position, impact_radius, LandingImpact.shake_amplitude(_config, _land_level))
	var amount: float = LandingImpact.damage(_config, _land_level, _run_scale)
	for slime: Slime in LandingImpact.find_victims(_config, _field.slimes, hero.position, impact_radius):
		_hit(slime, amount)
	landed.emit(hero.position, impact_radius)


func _on_hero_hit_dealt(target: Slime, amount: float) -> void:
	_hit(target, amount)


## Dashed landing-range ellipse under the pointer.
func _draw() -> void:
	if _config.is_empty() or remaining <= 0 or not _pointer_inside:
		return
	var preview: Dictionary = _config["preview"]
	var color := Color(Color.html(preview["color"]), float(preview["alpha"]))
	var center: Vector2 = _clamp_to_field(_pointer)
	var rx: float = LandingImpact.radius(_config, _land_level)
	var ry: float = rx * float(_config["landing"]["ellipse_ratio"])
	var dash: float = preview["dash"]
	var count: int = int(preview["points"])
	var travelled: float = 0.0
	var previous: Vector2 = center + Vector2(rx, 0.0)
	for i: int in range(1, count + 1):
		var angle: float = TAU * float(i) / float(count)
		var current: Vector2 = center + Vector2(cos(angle) * rx, sin(angle) * ry)
		var length: float = previous.distance_to(current)
		if fmod(travelled + length * 0.5, dash * DASH_PHASE_FACTOR) < dash:
			draw_line(previous, current, color, float(preview["width"]))
		travelled += length
		previous = current


func _draw_popups() -> void:
	if _config.is_empty():
		return
	var popup: Dictionary = _config["popup"]
	var font: Font = ThemeDB.fallback_font
	var size: int = int(popup["font_size"])
	var text_color: Color = Color.html(popup["color"])
	var outline_color: Color = Color.html(popup["outline_color"])
	for entry: Dictionary in _popups:
		var fade: float = 1.0 - float(entry["age"]) / float(popup["lifetime"])
		var pos: Vector2 = (Vector2(entry["pos"]) - Vector2(0.0, float(entry["age"]) * float(popup["rise_speed"]))).round()
		var origin := Vector2(pos.x - 50.0, pos.y)
		_popup_layer.draw_string(font, origin + Vector2.ONE, entry["text"], HORIZONTAL_ALIGNMENT_CENTER, 100.0,
				size, Color(outline_color, fade))
		_popup_layer.draw_string(font, origin, entry["text"], HORIZONTAL_ALIGNMENT_CENTER, 100.0,
				size, Color(text_color, fade))


## Returns a description of the first schema problem, or "" when the data is valid.
static func _find_problem(data: Dictionary) -> String:
	var num: int = TYPE_FLOAT
	var str_type: int = TYPE_STRING
	var schema: Dictionary = {
		"squad": {"base_count": num, "count_per_hero_level": num, "drop_margin_top": num},
		"drop": {"height": num, "gravity": num, "initial_cooldown": num, "shadow_radius": num,
			"shadow_shrink_height": num, "shadow_min_scale": num},
		"combat": {"chase_speed": num, "range_base": num, "base_cooldown": num, "cooldown_speed_per_level": num,
			"base_damage": num, "damage_per_level": num, "damage_variance_min": num, "damage_variance_max": num,
			"swing_time": num},
		"walk": {"bob_frequency": num, "bob_height": num},
		"landing": {"base_radius": num, "radius_per_level": num, "base_damage": num, "damage_per_level": num,
			"run_scale_exponent": num, "vertical_weight": num, "ellipse_ratio": num, "shake_base": num,
			"shake_per_level": num, "shake_decay": num, "shake_offset_factor": num, "particle_count": num,
			"particle_speed_x": num, "particle_vy_min": num, "particle_vy_max": num, "particle_gravity": num,
			"particle_life": num, "particle_size": num, "particle_color": str_type, "ring_time": num,
			"ring_width": num, "ring_shrink": num, "ring_color": str_type},
		"preview": {"dash": num, "width": num, "points": num, "alpha": num, "color": str_type},
		"sound": {"frequency": num, "duration": num, "pitch_rise": num, "volume": num, "mix_rate": num},
		"popup": {"lifetime": num, "rise_speed": num, "jitter_x": num, "y_ratio": num, "font_size": num,
			"color": str_type, "outline_color": str_type},
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
	if float(data["sound"]["volume"]) <= 0.0 or float(data["popup"]["lifetime"]) <= 0.0 \
			or float(data["landing"]["ring_time"]) <= 0.0 or float(data["landing"]["particle_life"]) <= 0.0 \
			or float(data["preview"]["points"]) < 3.0 or float(data["drop"]["shadow_shrink_height"]) <= 0.0:
		return "sound.volume, popup.lifetime, landing.ring_time, landing.particle_life, drop.shadow_shrink_height must be > 0 and preview.points >= 3"
	return ""
