class_name Arrow
extends Node2D
## An archer's arrow: flies straight at its target (the slime's body centre, so it follows hops) and
## deals the damage on arrival through `hit`. It disappears when the target died or was freed first.
##
## Implements design/game-brief.md (MVP 6) via production/epics/slime-nodaji/story-006-archer-berserker-hotbar.md.
## Values ported from slime-nodaji.html (update arrows, draw shots); config: hero_types.json types.archer.arrow.

## Emitted once on arrival; the owner applies the damage.
signal hit(target: Slime, amount: float)

var _config: Dictionary = {}
var _target: Slime
var _amount: float = 0.0
var _angle: float = 0.0


func _process(delta: float) -> void:
	advance(delta)


## Starts the flight at `origin` (the parent's coordinates). `arrow_config` is types.archer.arrow.
func setup(arrow_config: Dictionary, origin: Vector2, target: Slime, amount: float) -> void:
	_config = arrow_config
	_target = target
	_amount = amount
	position = origin
	queue_redraw()


## Steps the arrow by `delta` seconds; a step never overshoots the target.
func advance(delta: float) -> void:
	if _config.is_empty():
		return
	if not is_instance_valid(_target) or _target.hp <= 0.0:
		queue_free()
		return
	var aim: Vector2 = _target.position - Vector2(0.0, _target.radius * float(_config["aim_height_ratio"]))
	var to_aim: Vector2 = aim - position
	var distance: float = to_aim.length()
	_angle = to_aim.angle()
	if distance < float(_config["hit_distance"]):
		hit.emit(_target, _amount)
		queue_free()
		return
	position += to_aim / distance * minf(float(_config["speed"]) * delta, distance)
	queue_redraw()


func _draw() -> void:
	if _config.is_empty():
		return
	draw_line(Vector2.ZERO, -Vector2.from_angle(_angle) * float(_config["length"]),
			Color.html(_config["color"]), float(_config["width"]))
