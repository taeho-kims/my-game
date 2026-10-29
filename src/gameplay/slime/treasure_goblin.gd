class_name TreasureGoblin
extends Slime
## Treasure goblin: flees from the nearest landed hero, may drop a coin whenever it is hit, drops a big
## burst when killed and leaves the field (no drops) once its life ran out.
##
## Implements design/game-brief.md (MVP 7) via production/epics/slime-nodaji/story-007-run-events.md.
## Values: the "goblin" section of assets/data/run_events.json (speeds halved for the 640x360 base).
## Ported from slime-nodaji.html (goblin AI in update, hurt).

## Emitted when a hit made the goblin drop a coin (the owner creates the coin).
signal hit_dropped(goblin: TreasureGoblin)
## Emitted when the goblin left the field after its life ran out; the owner frees it.
signal escaped(goblin: TreasureGoblin)

var _event: Dictionary = {}
var _full_config: Dictionary = {}
var _hero_locator: Callable
var _life_left: float = 0.0
var _face_left: bool = false


## Applies the event rules from `full_config` (run_events.json). `hero_locator` takes the goblin position
## and returns the nearest landed hero's position as a Vector2, or null when there is none (it then wanders).
## Call after `setup`.
func apply_event(full_config: Dictionary, hero_locator: Callable) -> void:
	_full_config = full_config
	_event = full_config["goblin"]
	_hero_locator = hero_locator
	_life_left = _event["life"]
	drop_count = RunEvents.kill_coins(full_config, "goblin")
	counts_toward_cap = false


## Applies damage; a hit may first make the goblin drop a coin (also the killing one, as the prototype).
func take_damage(amount: float) -> void:
	if _dead:
		return
	if RunEvents.goblin_hit_drops(_full_config, _rng.randf()):
		hit_dropped.emit(self)
	super.take_damage(amount)


func advance(delta: float) -> void:
	if _dead:
		return
	_age += delta
	_flash_left = maxf(0.0, _flash_left - delta)
	_life_left -= delta
	var away := Vector2(cos(_age), sin(_age * float(_event["wander_speed_y_factor"])))
	var hero: Variant = _hero_locator.call(position) if _hero_locator.is_valid() else null
	if hero is Vector2:
		var offset: Vector2 = position - (hero as Vector2)
		away = offset / maxf(offset.length(), 0.001)
	var response: float = minf(1.0, delta * float(_event["flee_response"]))
	_velocity.x += (away.x * float(_event["flee_speed_x"]) - _velocity.x) * response
	_velocity.y += (away.y * float(_event["flee_speed_y"]) - _velocity.y) * response
	var leaving: bool = RunEvents.goblin_expired(_full_config, _event["life"] - _life_left)
	if leaving:
		_velocity.x *= pow(float(_event["exit_speed_boost"]), delta * _fps)
	position += _velocity * delta
	_face_left = _velocity.x < 0.0
	if leaving:
		if not _bounds.grow(float(_event["exit_margin"])).has_point(position):
			_dead = true
			escaped.emit(self)
	else:
		_reflect()
	queue_redraw()


func _draw() -> void:
	if _cfg.is_empty() or _event.is_empty():
		return
	var colors: Dictionary = _event["colors"]
	var r: float = radius
	fill_ellipse(self, Vector2.ZERO, Vector2(r, r * 0.4), SHADOW_COLOR)
	var flash: bool = _flash_left > 0.0
	var body := Color.html(colors["flash"] if flash else colors["body"])
	var ear := Color.html(colors["flash"] if flash else colors["ear"])
	var side: float = -1.0 if _face_left else 1.0
	draw_rect(Rect2(-r * 0.2 - side * r * 1.1, -r * 1.3, r * 0.8, r * 0.9), Color.html(colors["sack"]))
	draw_rect(Rect2(-r * 0.8, -r * 1.4, r * 1.6, r * 1.4), body)
	draw_rect(Rect2(-r * 0.7, -r * 2.3, r * 1.4, r * 0.9), body)
	draw_rect(Rect2(-r * 1.1, -r * 2.2, r * 0.4, r * 0.5), ear)
	draw_rect(Rect2(r * 0.7, -r * 2.2, r * 0.4, r * 0.5), ear)
	var eye := Color.html(colors["eye"])
	draw_rect(Rect2(-r * 0.4, -r * 2.0, 2.0, 2.0), eye)
	draw_rect(Rect2(r * 0.4 - 2.0, -r * 2.0, 2.0, 2.0), eye)
	if hp < max_hp:
		var bar_w: float = _cfg["hp_bar_width"]
		var bar_y: float = roundf(-r * 2.3 - 4.0)
		draw_rect(Rect2(roundf(-bar_w / 2.0) - 1.0, bar_y - 1.0, bar_w + 2.0, 4.0), HP_BAR_BACK_COLOR)
		draw_rect(Rect2(roundf(-bar_w / 2.0), bar_y, roundf(bar_w * maxf(0.0, hp / max_hp)), 2.0), HP_BAR_FILL_COLOR)
