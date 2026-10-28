class_name RunHud
extends CanvasLayer
## The run HUD: gold, collected loot, the remaining-time bar (red while low), the chest tier name and
## progress bar, the base-gold count-up over the open chest, the final-harvest timer and bonus, and a
## start button. A pure view: the run scene hands it a state Dictionary every frame.
##
## Implements production/epics/slime-nodaji/story-004-run-timer-burst.md. Layout and texts come from
## the "ui" section of assets/data/run.json.

## Emitted when the start button is pressed.
signal start_pressed

var _ui: Dictionary = {}
var _text: Dictionary = {}
var _gold_label: Label
var _collected_label: Label
var _time_back: ColorRect
var _time_fill: ColorRect
var _time_label: Label
var _tier_label: Label
var _tier_back: ColorRect
var _tier_fill: ColorRect
var _burst_label: Label
var _multiplier_label: Label
var _harvest_label: Label
var _start_button: Button
var _time_bar_width: float = 0.0
var _tier_bar_width: float = 0.0


## Builds the controls. `ui` is the "ui" section of run.json, `field_size` the viewport size and
## `ring_top_y` / `ring_bottom_y` the y of the top and bottom edge of the loot ring (ChestBurst.ring_top_y,
## ring_bottom_y): the tier and gold labels sit ui.ring_label_margin above the top edge, the harvest
## timer and bonus the same margin below the bottom edge.
##
## State keys of `show_state`: gold (int), collected (int), phase (RunController.Phase), time_ratio and
## time_left (run time), low_time (bool), tier_name, tier_color (Color), tier_ratio (0..1), opened (bool),
## shown_gold (float), multiplier (float), harvest_left (float), harvest_bonus (int).
func setup(ui: Dictionary, field_size: Vector2, ring_top_y: float, ring_bottom_y: float) -> void:
	_ui = ui
	_text = ui["text"]
	var margin: float = ui["margin"]
	var font_size: int = int(ui["font_size"])
	var big_size: int = int(ui["big_font_size"])
	_gold_label = _make_label(font_size, 150.0, HORIZONTAL_ALIGNMENT_LEFT, Vector2(margin, margin))
	_collected_label = _make_label(font_size, 150.0, HORIZONTAL_ALIGNMENT_LEFT, Vector2(margin, margin + 14.0))
	var time_size: Array = ui["time_bar_size"]
	_time_bar_width = float(time_size[0])
	var time_pos := Vector2((field_size.x - _time_bar_width) / 2.0, margin)
	_time_back = _make_rect(time_pos, Vector2(_time_bar_width, float(time_size[1])), _color("bar_back"))
	_time_fill = _make_rect(time_pos, Vector2(_time_bar_width, float(time_size[1])), _color("time_bar"))
	_time_label = _make_label(font_size, _time_bar_width, HORIZONTAL_ALIGNMENT_CENTER,
			time_pos + Vector2(0.0, float(time_size[1]) + 1.0))
	var tier_width: float = ui["tier_label_width"]
	var tier_x: float = field_size.x - margin - tier_width
	_tier_label = _make_label(font_size, tier_width, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(tier_x, margin))
	var bar_size: Array = ui["tier_bar_size"]
	_tier_bar_width = float(bar_size[0])
	var bar_pos := Vector2(field_size.x - margin - _tier_bar_width, margin + 15.0)
	_tier_back = _make_rect(bar_pos, Vector2(_tier_bar_width, float(bar_size[1])), _color("bar_back"))
	_tier_fill = _make_rect(bar_pos, Vector2(0.0, float(bar_size[1])), Color.WHITE)
	# The labels over the chest stack upwards from just above the loot ring: tier and multiplier right
	# above it (ring_label_margin apart), then the base gold. The harvest timer and bonus sit below it.
	var margin_ring: float = ui["ring_label_margin"]
	_multiplier_label = _make_label(font_size, field_size.x, HORIZONTAL_ALIGNMENT_CENTER, Vector2.ZERO)
	_multiplier_label.position.y = ring_top_y - margin_ring - _text_height(_multiplier_label, 1)
	_burst_label = _make_label(big_size, field_size.x, HORIZONTAL_ALIGNMENT_CENTER, Vector2.ZERO)
	_burst_label.position.y = _multiplier_label.position.y - _text_height(_burst_label, 1)
	_harvest_label = _make_label(big_size, field_size.x, HORIZONTAL_ALIGNMENT_CENTER,
			Vector2(0.0, ring_bottom_y + margin_ring))
	_harvest_label.add_theme_color_override("font_color", _color("bonus"))
	_start_button = Button.new()
	_start_button.text = _text["start"]
	var button_size: Array = ui["button_size"]
	_start_button.size = Vector2(float(button_size[0]), float(button_size[1]))
	_start_button.position = (field_size - _start_button.size) / 2.0
	_start_button.pressed.connect(func() -> void: start_pressed.emit())
	add_child(_start_button)
	_start_button.visible = false


## Shows the start button and gives it keyboard focus.
func show_start() -> void:
	_start_button.visible = true
	_start_button.grab_focus()


## Hides the start button.
func hide_start() -> void:
	_start_button.visible = false


## Updates every element from `state` (keys documented on `setup`).
func show_state(state: Dictionary) -> void:
	var phase: int = state["phase"]
	_gold_label.text = _text["gold"] % int(state["gold"])
	_collected_label.text = _text["collected"] % int(state["collected"])
	var running: bool = phase == RunController.Phase.RUNNING
	_time_back.visible = running
	_time_fill.visible = running
	_time_label.visible = running
	if running:
		_time_fill.size.x = _time_bar_width * clampf(float(state["time_ratio"]), 0.0, 1.0)
		var low: bool = state["low_time"]
		_time_fill.color = _color("time_low" if low else "time_bar")
		_time_label.text = _text["time"] % float(state["time_left"])
		_time_label.add_theme_color_override("font_color", _color("time_low" if low else "text"))
	var tier_color: Color = state["tier_color"]
	_tier_label.text = state["tier_name"]
	_tier_label.add_theme_color_override("font_color", tier_color)
	_tier_fill.color = tier_color
	_tier_fill.size.x = _tier_bar_width * clampf(float(state["tier_ratio"]), 0.0, 1.0)
	var opened: bool = state["opened"]
	_burst_label.visible = opened
	_multiplier_label.visible = opened
	if opened:
		_burst_label.text = _text["base_gold"] % roundi(float(state["shown_gold"]))
		_multiplier_label.text = _text["tier_multiplier"] % [state["tier_name"], float(state["multiplier"])]
		_multiplier_label.add_theme_color_override("font_color", tier_color)
	var harvesting: bool = phase == RunController.Phase.HARVEST
	_harvest_label.visible = harvesting
	if harvesting:
		_harvest_label.text = "%s %s\n%s" % [_text["harvest_title"],
				_text["harvest_time"] % float(state["harvest_left"]),
				_text["harvest_bonus"] % int(state["harvest_bonus"])]


func _color(key: String) -> Color:
	return Color.html(_ui["colors"][key])


## Height of `lines` text lines in the label's font (measured with placeholder text, then cleared).
func _text_height(label: Label, lines: int) -> float:
	var placeholder: PackedStringArray = []
	for i: int in lines:
		placeholder.append("0")
	label.text = "\n".join(placeholder)
	var height: float = label.get_minimum_size().y
	label.text = ""
	return height


func _make_rect(position: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = position
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _make_label(font_size: int, width: float, align: HorizontalAlignment, position: Vector2) -> Label:
	var label := Label.new()
	label.position = position
	label.custom_minimum_size = Vector2(width, 0.0)
	label.size = Vector2(width, 0.0)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", _color("text"))
	label.add_theme_color_override("font_outline_color", _color("text_outline"))
	label.add_theme_constant_override("outline_size", int(_ui["outline_size"]))
	add_child(label)
	return label
