class_name RunView
extends Node2D
## Draws the burst overlay: the dark screen dim that follows the chest's move to the centre and the
## loot that rains out of the opened chest (the landed loot of the final harvest is drawn by real
## Coin nodes, see run_scene.gd). Reads RunController getters only and owns no state.
##
## Implements production/epics/slime-nodaji/story-004-run-timer-burst.md. Values: the "ui" section
## of assets/data/run.json (loot_size, colors) and coin.colors of assets/data/slime_field.json.

var _config: Dictionary = {}
var _coin_colors: Dictionary = {}
var _controller: RunController
var _field_size: Vector2 = Vector2.ZERO


## `config` is run.json, `slime_config` slime_field.json, `controller` the run being shown.
func setup(config: Dictionary, slime_config: Dictionary, controller: RunController, field_size: Vector2) -> void:
	_config = config
	_coin_colors = slime_config["coin"]["colors"]
	_controller = controller
	_field_size = field_size


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _controller == null:
		return
	var ui: Dictionary = _config["ui"]
	var dim_alpha: float = _controller.dim_alpha()
	if dim_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, _field_size), Color(Color.html(ui["colors"]["dim"]), dim_alpha))
	if _controller.phase != RunController.Phase.BURST:
		return
	var size: float = ui["loot_size"]
	for coin: Dictionary in _controller.loot:
		var pair: Array = _coin_colors[coin["kind"]]
		var half_width: float = maxf(0.75, absf(cos(float(coin["spin"]))) * size / 2.0)
		var ground: Vector2 = coin["pos"]
		if float(coin["height"]) > 0.0:
			draw_rect(Rect2(ground.x - size / 2.0, ground.y, size, 1.0), Color.html(ui["colors"]["loot_shadow"]))
		var center := Vector2(ground.x, ground.y - float(coin["height"]))
		draw_rect(Rect2(center.x - half_width, center.y - size / 2.0, half_width * 2.0, size), Color.html(pair[1]))
		draw_rect(Rect2(center.x - half_width + 1.0, center.y - size / 2.0 + 1.0, maxf(0.0, half_width * 2.0 - 2.0), size - 2.0),
				Color.html(pair[0]))
