class_name EventBanner
extends Label
## The big event banner ("슬라임 비!", ...): pops in, stays and fades out over about one second.
## Display only; the owner calls `show_text`. A new banner replaces the one showing.
##
## Implements production/epics/slime-nodaji/story-007-run-events.md. Values: the "banner" section of
## assets/data/run_events.json.

var _config: Dictionary = {}
var _age: float = 0.0


## `banner_config` is the "banner" section of run_events.json, `field_size` the viewport size.
func setup(banner_config: Dictionary, field_size: Vector2) -> void:
	_config = banner_config
	size = Vector2(field_size.x, float(banner_config["font_size"]) * 2.0)
	position = Vector2(0.0, field_size.y * float(banner_config["top_ratio"]))
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", int(banner_config["font_size"]))
	add_theme_color_override("font_color", Color.html(banner_config["color"]))
	add_theme_color_override("font_outline_color", Color.html(banner_config["outline_color"]))
	add_theme_constant_override("outline_size", int(banner_config["outline_size"]))
	visible = false


## Shows `banner_text` from the start of its animation.
func show_text(banner_text: String) -> void:
	text = banner_text
	_age = 0.0
	visible = true
	_apply()


func _process(delta: float) -> void:
	if not visible:
		return
	_age += delta
	if _age >= float(_config["duration"]):
		visible = false
		return
	_apply()


func _apply() -> void:
	var duration: float = _config["duration"]
	var pop_time: float = _config["pop_time"]
	var pop: float = 1.0 + (float(_config["pop_scale"]) - 1.0) * maxf(0.0, 1.0 - _age / pop_time)
	pivot_offset = size / 2.0
	scale = Vector2.ONE * pop
	var fade_start: float = float(_config["fade_start"]) * duration
	modulate.a = 1.0 if _age <= fade_start else 1.0 - (_age - fade_start) / maxf(0.0001, duration - fade_start)
