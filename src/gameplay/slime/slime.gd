class_name Slime
extends Node2D
## A normal slime: hops around the field, reflects off the field edges and
## dies when its hp reaches zero.
##
## Implements design/game-brief.md (MVP 2) via production/epics/slime-nodaji/story-001-slime-field.md.
## Values ported from slime-nodaji.html (spawnSlime, update, drawSlime).
## The node position is the slime's ground point (feet); the body is drawn above it.

## Emitted once when hp reaches zero. The owner is responsible for freeing the node.
signal died(slime: Slime)

## Body height as a fraction of radius (0.7 rect + 0.75 ellipse in the prototype).
const BODY_HEIGHT_RATIO: float = 1.45
const SHADOW_COLOR: Color = Color(20.0 / 255.0, 40.0 / 255.0, 15.0 / 255.0, 0.35)
const EYE_COLOR: Color = Color("#1b1612")
const HP_BAR_BACK_COLOR: Color = Color("#1b1612")
const HP_BAR_FILL_COLOR: Color = Color("#7ad06a")

var hp: float = 0.0
var max_hp: float = 0.0
var radius: float = 0.0

var _cfg: Dictionary = {}
var _fps: float = 60.0
var _rng: RandomNumberGenerator
var _bounds: Rect2
var _color: Color = Color.WHITE
var _velocity: Vector2 = Vector2.ZERO
var _hop_timer: float = 0.0
var _hop_left: float = 0.0
var _age: float = 0.0
var _flash_left: float = 0.0
var _dead: bool = false


## Initializes the slime. `config` is the full slime_field config, `bounds` is the
## field rectangle (x 0..width, y field top..field bottom).
func setup(config: Dictionary, rng: RandomNumberGenerator, bounds: Rect2, ground_pos: Vector2,
		max_hp_value: float, radius_value: float, body_color: Color) -> void:
	_cfg = config["slime"]
	_fps = config["reference_fps"]
	_rng = rng
	_bounds = bounds
	position = ground_pos
	max_hp = max_hp_value
	hp = max_hp_value
	radius = radius_value
	_color = body_color
	_hop_timer = rng.randf_range(_cfg["first_hop_min"], _cfg["first_hop_max"])
	_age = rng.randf_range(0.0, _cfg["age_phase_max"])
	queue_redraw()


## Applies damage; emits `died` once when hp drops to zero or below.
func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	_flash_left = _cfg["flash_time"]
	if hp <= 0.0:
		_dead = true
		died.emit(self)
	queue_redraw()


## True when a world-space point lies on the slime body (used for click picking).
func contains_point(world_point: Vector2) -> bool:
	var local: Vector2 = to_local(world_point)
	return absf(local.x) <= radius and local.y >= -radius * BODY_HEIGHT_RATIO and local.y <= 0.0


## Steps movement and timers by `delta` seconds.
func advance(delta: float) -> void:
	_age += delta
	_flash_left = maxf(0.0, _flash_left - delta)
	_hop_timer -= delta
	if _hop_timer <= 0.0:
		var speed: float = _rng.randf_range(_cfg["hop_speed_min"], _cfg["hop_speed_max"])
		var angle: float = _rng.randf_range(0.0, TAU)
		_velocity = Vector2(cos(angle), sin(angle) * float(_cfg["hop_y_ratio"])) * speed
		_hop_timer = _rng.randf_range(_cfg["hop_interval_min"], _cfg["hop_interval_max"])
		_hop_left = _cfg["hop_duration"]
	if _hop_left > 0.0:
		_hop_left -= delta
	else:
		_velocity *= pow(float(_cfg["glide_damping"]), delta * _fps)
	position += _velocity * delta
	_reflect()
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func _reflect() -> void:
	if position.x < radius:
		position.x = radius
		_velocity.x = absf(_velocity.x)
	if position.x > _bounds.end.x - radius:
		position.x = _bounds.end.x - radius
		_velocity.x = -absf(_velocity.x)
	if position.y < _bounds.position.y + radius:
		position.y = _bounds.position.y + radius
		_velocity.y = absf(_velocity.y)
	if position.y > _bounds.end.y:
		position.y = _bounds.end.y
		_velocity.y = -absf(_velocity.y)


func _draw() -> void:
	if _cfg.is_empty():
		return
	var r: float = radius
	fill_ellipse(self, Vector2.ZERO, Vector2(r, r * 0.4), SHADOW_COLOR)

	var hop_total: float = _cfg["hop_duration"]
	var hopping: float = sin((hop_total - _hop_left) / hop_total * PI) if _hop_left > 0.0 else 0.0
	var wobble: float = sin(_age * float(_cfg["wobble_speed"])) * float(_cfg["wobble_amplitude"])
	var sx: float = 1.0 - hopping * float(_cfg["hop_stretch_x"]) + wobble
	var sy: float = 1.0 + hopping * float(_cfg["hop_stretch_y"]) - wobble
	var lift: float = roundf(hopping * float(_cfg["hop_lift"]))
	draw_set_transform(Vector2(0.0, -lift), 0.0, Vector2.ONE)

	var col: Color = Color.WHITE if _flash_left > 0.0 else _color
	var rx: float = r * sx
	var cy: float = -r * 0.7 * sy
	fill_ellipse(self, Vector2(0.0, cy), Vector2(rx, r * 0.75 * sy), col)
	var left: float = roundf(-rx)
	var width: float = roundf(rx) - left
	var body_top: float = roundf(cy)
	draw_rect(Rect2(left, body_top, width, -body_top), col)
	draw_rect(Rect2(left, -2.0, width, 2.0), Color(0.0, 0.0, 0.0, 0.18))
	draw_rect(Rect2(roundf(-r * 0.55 * sx), roundf(-r * 1.15 * sy), roundf(r * 0.35), roundf(r * 0.25)),
			Color(1.0, 1.0, 1.0, 0.55))
	var eye_x: float = roundf(r * 0.35)
	var eye_y: float = roundf(-r * 0.75 * sy)
	draw_rect(Rect2(-eye_x - 1.0, eye_y, 2.0, 2.0), EYE_COLOR)
	draw_rect(Rect2(eye_x - 1.0, eye_y, 2.0, 2.0), EYE_COLOR)

	if hp < max_hp:
		var bar_w: float = _cfg["hp_bar_width"]
		var bar_y: float = roundf(-r * 1.6 * sy)
		draw_rect(Rect2(roundf(-bar_w / 2.0) - 1.0, bar_y - 1.0, bar_w + 2.0, 4.0), HP_BAR_BACK_COLOR)
		draw_rect(Rect2(roundf(-bar_w / 2.0), bar_y, roundf(bar_w * maxf(0.0, hp / max_hp)), 2.0), HP_BAR_FILL_COLOR)


## Fills an ellipse with one-pixel-high rows so it stays pixel-art crisp at base resolution.
static func fill_ellipse(item: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var first_row: int = floori(center.y - radii.y)
	var last_row: int = ceili(center.y + radii.y)
	for row in range(first_row, last_row):
		var dy: float = (float(row) + 0.5 - center.y) / radii.y
		if absf(dy) >= 1.0:
			continue
		var half: float = radii.x * sqrt(1.0 - dy * dy)
		var x0: float = roundf(center.x - half)
		var x1: float = roundf(center.x + half)
		item.draw_rect(Rect2(x0, float(row), x1 - x0, 1.0), color)
