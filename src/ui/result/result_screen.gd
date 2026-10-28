class_name ResultScreen
extends CanvasLayer
## The result screen after the final harvest: collected loot, chest tier and multiplier, kills, base
## gold, harvest bonus and the gold gained (base + bonus), with two buttons that are both reachable
## by keyboard focus (left/right, Enter).
##
## Implements production/epics/slime-nodaji/story-004-run-timer-burst.md. Layout and texts come from
## the "ui" section of assets/data/run.json.

## Emitted by the "바로 재출격" button.
signal retry_pressed
## Emitted by the "스킬 트리로" button (the skill tree screen itself is story 005).
signal skill_tree_pressed

var _ui: Dictionary = {}
var _text: Dictionary = {}
var _values: Dictionary = {}
var _retry_button: Button
var _skill_tree_button: Button


## Builds the screen. `ui` is the "ui" section of run.json, `field_size` the viewport size.
func setup(ui: Dictionary, field_size: Vector2) -> void:
	_ui = ui
	_text = ui["text"]
	var shade := ColorRect.new()
	shade.size = field_size
	shade.color = _color("screen_dim")
	add_child(shade)
	var panel_size: Array = ui["panel_size"]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(float(panel_size[0]), float(panel_size[1]))
	panel.size = panel.custom_minimum_size
	panel.position = (field_size - panel.size) / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = _color("panel")
	style.border_color = _color("panel_border")
	style.set_border_width_all(1)
	style.set_content_margin_all(float(ui["margin"]) + 4.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(ui["panel_separation"]))
	panel.add_child(column)
	var title := _make_label(_text["result_title"], int(ui["title_font_size"]), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", _color("bonus"))
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	column.add_child(grid)
	for row: String in ["collected", "tier", "multiplier", "kills", "base", "bonus", "total"]:
		var name_label := _make_label(_text["row_" + row], int(ui["font_size"]), HORIZONTAL_ALIGNMENT_LEFT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var value_label := _make_label("", int(ui["font_size"]), HORIZONTAL_ALIGNMENT_RIGHT)
		grid.add_child(value_label)
		_values[row] = value_label
	(_values["bonus"] as Label).add_theme_color_override("font_color", _color("bonus"))
	(_values["total"] as Label).add_theme_color_override("font_color", _color("bonus"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", int(ui["button_gap"]))
	column.add_child(buttons)
	var button_size: Array = ui["button_size"]
	_skill_tree_button = _make_button(_text["button_skill_tree"], button_size)
	_retry_button = _make_button(_text["button_retry"], button_size)
	buttons.add_child(_skill_tree_button)
	buttons.add_child(_retry_button)
	_skill_tree_button.focus_neighbor_right = _skill_tree_button.get_path_to(_retry_button)
	_skill_tree_button.focus_neighbor_left = _skill_tree_button.get_path_to(_retry_button)
	_retry_button.focus_neighbor_left = _retry_button.get_path_to(_skill_tree_button)
	_retry_button.focus_neighbor_right = _retry_button.get_path_to(_skill_tree_button)
	_skill_tree_button.pressed.connect(func() -> void: skill_tree_pressed.emit())
	_retry_button.pressed.connect(func() -> void: retry_pressed.emit())


## Fills the rows from `result` and opens the screen with keyboard focus on the retry button.
func show_result(result: RunResult) -> void:
	(_values["collected"] as Label).text = _text["value_int"] % roundi(result.collected)
	(_values["tier"] as Label).text = result.chest_name
	(_values["multiplier"] as Label).text = _text["value_multiplier"] % result.multiplier
	(_values["kills"] as Label).text = _text["value_int"] % result.kills
	(_values["base"] as Label).text = _text["value_int"] % result.base_gold
	(_values["bonus"] as Label).text = _text["value_bonus"] % result.harvest_bonus
	(_values["total"] as Label).text = _text["value_int"] % result.total_gold()
	visible = true
	_retry_button.grab_focus()


## Closes the screen.
func hide_result() -> void:
	visible = false


func _color(key: String) -> Color:
	return Color.html(_ui["colors"][key])


func _make_label(text: String, font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", _color("text"))
	return label


func _make_button(text: String, button_size: Array) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(float(button_size[0]), float(button_size[1]))
	button.add_theme_font_size_override("font_size", int(_ui["font_size"]))
	return button
