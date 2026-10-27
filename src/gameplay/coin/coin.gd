class_name Coin
extends Node2D
## A dropped coin: pops up, scatters, bounces, blinks in its last seconds and expires.
## It is not collectable in this story (collection is story 003).
##
## Implements production/epics/slime-nodaji/story-001-slime-field.md.
## Values ported from slime-nodaji.html (dropCoins, update coins, drawCoin).
## The node position is the ground point; `height` is the altitude above it.

## Emitted once when the lifetime runs out. The owner is responsible for freeing the node.
signal expired(coin: Coin)

const SHADOW_COLOR: Color = Color(20.0 / 255.0, 40.0 / 255.0, 15.0 / 255.0, 0.35)

## "copper", "silver" or "gem".
var kind: String = ""
## Final coin value (base * run scale * coin level multiplier).
var value: float = 0.0
## Altitude above the ground point.
var height: float = 0.0

var _cfg: Dictionary = {}
var _fps: float = 60.0
var _bounds: Rect2
var _velocity: Vector2 = Vector2.ZERO
var _vertical_speed: float = 0.0
var _life_left: float = 0.0
var _age: float = 0.0
var _color_main: Color = Color.WHITE
var _color_edge: Color = Color.WHITE


## Initializes the coin. `config` is the full slime_field config, `bounds` the field rectangle,
## `velocity` the ground-plane scatter velocity and `pop_speed` the initial upward speed.
func setup(config: Dictionary, coin_kind: String, coin_value: float, bounds: Rect2,
		origin: Vector2, velocity: Vector2, pop_speed: float) -> void:
	_cfg = config["coin"]
	_fps = config["reference_fps"]
	kind = coin_kind
	value = coin_value
	_bounds = bounds
	position = origin
	_velocity = velocity
	_vertical_speed = pop_speed
	height = _cfg["start_height"]
	_life_left = _cfg["life"]
	var pair: Array = _cfg["colors"][coin_kind]
	_color_main = Color.html(pair[0])
	_color_edge = Color.html(pair[1])
	queue_redraw()


## True while the coin is in the blinking-off half of its final seconds.
func is_blinked_off() -> bool:
	return _life_left < float(_cfg["blink_time"]) and sin(_life_left * float(_cfg["blink_frequency"])) > 0.0


## Steps the physics and lifetime by `delta` seconds.
func advance(delta: float) -> void:
	_age += delta
	_vertical_speed -= float(_cfg["gravity"]) * delta
	height += _vertical_speed * delta
	if height < 0.0:
		height = 0.0
		_vertical_speed = -_vertical_speed * float(_cfg["bounce_restitution"])
		if _vertical_speed < float(_cfg["bounce_min_speed"]):
			_vertical_speed = 0.0
	position += _velocity * delta
	_velocity *= pow(float(_cfg["drag"]), delta * _fps)
	_life_left -= delta
	var margin_x: float = _cfg["margin_x"]
	position.x = clampf(position.x, margin_x, _bounds.end.x - margin_x)
	position.y = clampf(position.y, _bounds.position.y, _bounds.end.y + float(_cfg["bottom_slack"]))
	queue_redraw()
	if _life_left <= 0.0:
		set_process(false)
		expired.emit(self)


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	if _cfg.is_empty():
		return
	Slime.fill_ellipse(self, Vector2.ZERO, Vector2(2.0, 0.8), SHADOW_COLOR)
	if is_blinked_off():
		return
	var cx: float = 0.0
	var cy: float = roundf(-height - 2.0)
	if kind == "gem":
		for row in range(-3, 2):
			var half: float = float(row + 3) if row <= -1 else float(2 - row)
			draw_rect(Rect2(cx - half, cy + float(row), half * 2.0 + 1.0, 1.0), _color_edge)
		draw_rect(Rect2(cx - 1.0, cy - 2.0, 2.0, 2.0), _color_main)
		return
	var spin: float = _age * float(_cfg["spin_rate"]) + position.x
	var w: float = roundf(maxf(0.75, absf(cos(spin)) * 2.5))
	draw_rect(Rect2(cx - w, cy - 3.0, w * 2.0, 5.0), _color_edge)
	draw_rect(Rect2(cx - w + 1.0, cy - 2.0, w * 2.0 - 2.0, 3.0), _color_main)
