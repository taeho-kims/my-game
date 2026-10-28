class_name Hero
extends Node2D
## A knight: falls from the sky onto the clicked spot, then chases the nearest slime and
## swings at it. A falling knight neither moves nor attacks.
##
## Implements design/game-brief.md (MVP 1) via production/epics/slime-nodaji/story-002-hero-drop-combat.md.
## Values ported from slime-nodaji.html (pointerdown, update hero section, drawHero, SPR.knight).
## The node position is the knight's ground point (feet); the body is drawn above it.
##
## States: FALLING -> GROUNDED (once, when the height reaches zero; emits `landed`).
## There is no transition back.

## Emitted once, on the frame the knight touches the ground.
signal landed(hero: Hero)
## Emitted when a swing connects; the owner applies the damage.
signal hit_dealt(target: Slime, amount: float)

enum State { FALLING, GROUNDED }

const SPRITE_SCALE: float = 2.0
const KNIGHT_ROWS: Array[String] = [
	"...hhh..",
	"..hhhhh.",
	"..hvvvh.",
	"...sss..",
	"w.aaaaa.",
	"wbaaaaab",
	"..aaaa..",
	"..l..l..",
]
const KNIGHT_PALETTE: Dictionary = {
	"h": Color("#c3cbd6"),
	"v": Color("#3d4350"),
	"s": Color("#f1c49a"),
	"a": Color("#3f6fd8"),
	"w": Color("#eef3f8"),
	"b": Color("#2f55ad"),
	"l": Color("#2c2f3a"),
}
const SHADOW_COLOR: Color = Color(20.0 / 255.0, 40.0 / 255.0, 15.0 / 255.0, 0.35)
const SWING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
const SWING_CENTER: Vector2 = Vector2(7.0, -8.0)
const SWING_RADIUS: float = 8.0
const SWING_WIDTH: float = 2.0

var state: State = State.FALLING
## Height above the ground point, in pixels.
var height: float = 0.0

var _config: Dictionary = {}
var _slimes: Array[Slime] = []
var _rng: RandomNumberGenerator
var _dmg_level: int = 0
var _spd_level: int = 0
var _vz: float = 0.0
var _cooldown: float = 0.0
var _swing_left: float = 0.0
var _bob_time: float = 0.0
var _flip: bool = false
var _walking: bool = false


func _process(delta: float) -> void:
	advance(delta)


## Attack cooldown in seconds: base / (1 + per_level * spd level).
static func attack_cooldown(config: Dictionary, spd_level: int) -> float:
	var combat: Dictionary = config["combat"]
	return float(combat["base_cooldown"]) / (1.0 + float(combat["cooldown_speed_per_level"]) * spd_level)


## Swing damage: base * (1 + per_level * dmg level) * variance roll (caller supplies the roll).
static func attack_damage(config: Dictionary, dmg_level: int, variance_roll: float) -> float:
	var combat: Dictionary = config["combat"]
	return float(combat["base_damage"]) * (1.0 + float(combat["damage_per_level"]) * dmg_level) * variance_roll


## Distance at which the knight attacks a slime of the given radius.
static func attack_range(config: Dictionary, slime_radius: float) -> float:
	return float(config["combat"]["range_base"]) + slime_radius


## Starts the drop at `ground_pos`. `slimes` is the live slime list of the field (read each
## frame, never modified here); levels come from the skill tree.
func setup(config: Dictionary, slimes: Array[Slime], rng: RandomNumberGenerator, ground_pos: Vector2,
		dmg_level: int, spd_level: int) -> void:
	_config = config
	_slimes = slimes
	_rng = rng
	_dmg_level = dmg_level
	_spd_level = spd_level
	position = ground_pos
	height = config["drop"]["height"]
	_cooldown = config["drop"]["initial_cooldown"]
	queue_redraw()


## Steps the knight by `delta` seconds.
func advance(delta: float) -> void:
	match state:
		State.FALLING:
			_fall(delta)
		State.GROUNDED:
			_fight(delta)
	queue_redraw()


func _fall(delta: float) -> void:
	_vz += float(_config["drop"]["gravity"]) * delta
	height -= _vz * delta
	if height <= 0.0:
		height = 0.0
		_vz = 0.0
		state = State.GROUNDED
		landed.emit(self)


func _fight(delta: float) -> void:
	_cooldown -= delta
	_swing_left = maxf(0.0, _swing_left - delta)
	_bob_time += delta
	var target: Slime = _nearest_slime()
	if target == null:
		_walking = false
		return
	var to_target: Vector2 = target.position - position
	var distance: float = to_target.length()
	_flip = to_target.x < 0.0
	if distance > attack_range(_config, target.radius):
		position += to_target / distance * float(_config["combat"]["chase_speed"]) * delta
		_walking = true
		return
	_walking = false
	if _cooldown <= 0.0:
		var combat: Dictionary = _config["combat"]
		var roll: float = _rng.randf_range(combat["damage_variance_min"], combat["damage_variance_max"])
		_cooldown = attack_cooldown(_config, _spd_level)
		_swing_left = combat["swing_time"]
		hit_dealt.emit(target, attack_damage(_config, _dmg_level, roll))


func _nearest_slime() -> Slime:
	var best: Slime = null
	var best_distance: float = INF
	for slime: Slime in _slimes:
		var distance: float = position.distance_to(slime.position)
		if distance < best_distance:
			best_distance = distance
			best = slime
	return best


func _draw() -> void:
	if _config.is_empty():
		return
	var drop: Dictionary = _config["drop"]
	var shadow_scale: float = 1.0
	if height > 0.0:
		shadow_scale = maxf(float(drop["shadow_min_scale"]), 1.0 - height / float(drop["shadow_shrink_height"]))
	var shadow_r: float = float(drop["shadow_radius"]) * shadow_scale
	Slime.fill_ellipse(self, Vector2.ZERO, Vector2(shadow_r, shadow_r * 0.4), SHADOW_COLOR)

	var bob: float = 0.0
	if _walking:
		var walk: Dictionary = _config["walk"]
		bob = roundf(absf(sin(_bob_time * float(walk["bob_frequency"]))) * float(walk["bob_height"]))
	var base_y: float = -roundf(height) - bob
	for row: int in 8:
		var line: String = KNIGHT_ROWS[row]
		for col: int in 8:
			var key: String = line[col]
			if key == ".":
				continue
			var cx: int = 7 - col if _flip else col
			draw_rect(Rect2(roundf(float(cx - 4) * SPRITE_SCALE), base_y + float(row - 8) * SPRITE_SCALE,
					SPRITE_SCALE, SPRITE_SCALE), KNIGHT_PALETTE[key])

	if _swing_left > 0.0:
		var dir: float = -1.0 if _flip else 1.0
		var start_angle: float = -1.2 if dir > 0.0 else PI - 0.4
		var end_angle: float = 0.4 if dir > 0.0 else PI + 1.2
		draw_arc(Vector2(SWING_CENTER.x * dir, base_y + SWING_CENTER.y), SWING_RADIUS, start_angle, end_angle,
				8, SWING_COLOR, SWING_WIDTH)
