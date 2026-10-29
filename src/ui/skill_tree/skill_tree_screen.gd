class_name SkillTreeScreen
extends CanvasLayer
## The skill tree screen: 16 node buttons on a grid with prerequisite lines, the gold, a description
## line, the next-run summary, a start button and a reset button that must be pressed twice. A pure
## view: it owns no game state, reports intents through signals and is refreshed with `show_tree`.
## Nodes are buttons, so mouse, keyboard and gamepad focus all work.
##
## Implements production/epics/slime-nodaji/story-005-skill-tree-save.md. Layout, colors and texts come
## from assets/data/skill_tree.json ("layout" and "ui"); the screen is laid out for the 640x360 base.

## A node was pressed (clicked, or Enter/Space while focused).
signal node_pressed(id: String)
## The start button ("출격!") was pressed.
signal start_pressed
## The reset button was pressed a second time within `save.reset_confirm_seconds`.
signal reset_confirmed

var _config: Dictionary = {}
var _ui: Dictionary = {}
var _text: Dictionary = {}
var _view: Dictionary = {}
var _buttons: Dictionary = {}
var _lines: Control
var _gold_label: Label
var _desc_label: Label
var _info_label: Label
var _start_button: Button
var _reset_button: Button
var _reset_timer: Timer
var _reset_armed: bool = false
var _hover_id: String = ""
var _message: String = ""


## Builds the screen. `config` is the loaded skill_tree.json, `field_size` the viewport size.
func setup(config: Dictionary, field_size: Vector2) -> void:
	_config = config
	_ui = config["ui"]
	_text = _ui["text"]
	var margin: float = _ui["margin"]
	var shade := ColorRect.new()
	shade.size = field_size
	shade.color = _color("background")
	add_child(shade)
	_lines = Control.new()
	_lines.size = field_size
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	add_child(_lines)
	var title := _make_label(_text["title"], int(_ui["title_font_size"]), "gold")
	title.position = Vector2(margin, margin - 2.0)
	_gold_label = _make_label("", int(_ui["title_font_size"]), "gold")
	_gold_label.custom_minimum_size = Vector2(200.0, 0.0)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.position = Vector2(field_size.x - margin - 200.0, margin - 2.0)
	for node: Dictionary in config["nodes"]:
		var button: Button = _make_node_button(node)
		_buttons[node["id"]] = button
	_desc_label = _make_label("", int(_ui["font_size"]), "desc")
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(field_size.x - 2.0 * margin, float(_ui["desc_height"]))
	_desc_label.position = Vector2(margin, float(_ui["desc_y"]))
	var button_size: Array = _ui["button_size"]
	_start_button = Button.new()
	_start_button.text = _text["start"]
	_start_button.custom_minimum_size = Vector2(float(button_size[0]), float(button_size[1]))
	_start_button.size = _start_button.custom_minimum_size
	_start_button.position = Vector2(margin, float(_ui["bottom_y"]))
	_start_button.add_theme_font_size_override("font_size", int(_ui["font_size"]))
	_start_button.pressed.connect(func() -> void: start_pressed.emit())
	add_child(_start_button)
	_info_label = _make_label("", int(_ui["font_size"]), "text")
	_info_label.position = Vector2(margin + float(button_size[0]) + 8.0, float(_ui["bottom_y"]) + 6.0)
	var reset_size: Array = _ui["reset_button_size"]
	_reset_button = Button.new()
	_reset_button.text = _text["reset"]
	_reset_button.custom_minimum_size = Vector2(float(reset_size[0]), float(reset_size[1]))
	_reset_button.size = _reset_button.custom_minimum_size
	_reset_button.position = Vector2(field_size.x - margin - float(reset_size[0]),
			float(_ui["bottom_y"]) + float(button_size[1]) - float(reset_size[1]))
	_reset_button.add_theme_font_size_override("font_size", int(_ui["font_size"]))
	_reset_button.add_theme_color_override("font_color", _color("danger"))
	_reset_button.pressed.connect(_on_reset_pressed)
	add_child(_reset_button)
	_reset_timer = Timer.new()
	_reset_timer.one_shot = true
	_reset_timer.wait_time = float(config["save"]["reset_confirm_seconds"])
	_reset_timer.timeout.connect(_disarm_reset)
	add_child(_reset_timer)


## Opens the screen (if hidden) or refreshes it. `view` keys: gold (int), best (int), stats (the
## PlayerStats.compute result) and nodes: an Array of {id, level, state (SkillTree.State)}.
## Keyboard focus stays on the node that was focused; a freshly opened screen focuses the start button.
func show_tree(view: Dictionary) -> void:
	_view = view
	var was_hidden: bool = not visible
	visible = true
	_gold_label.text = _text["gold"] % SkillTree.format_amount(int(view["gold"]))
	for entry: Dictionary in view["nodes"]:
		_refresh_node(entry)
	_info_label.text = _run_info(view["stats"], int(view["best"]))
	_refresh_description()
	_lines.queue_redraw()
	if was_hidden:
		_message = ""
		_disarm_reset()
		_refresh_description()
		_start_button.grab_focus()


## Shows `text` in the description line until the next hover or focus change.
func show_message(text: String) -> void:
	_message = text
	_desc_label.text = text


## Closes the screen.
func hide_tree() -> void:
	visible = false
	_disarm_reset()


func _refresh_node(entry: Dictionary) -> void:
	var id: String = entry["id"]
	var node: Dictionary = SkillTree.find_node(_config, id)
	var button: Button = _buttons[id]
	var state: int = entry["state"]
	var current: int = entry["level"]
	var last_line: String = _text["node_max"] if state == SkillTree.State.MAXED \
			else SkillTree.format_amount(SkillTree.cost(node, current))
	button.text = "%s\n%s\n%s" % [node["name"], _text["node_level"] % [current, int(node["max"])], last_line]
	var locked: bool = state == SkillTree.State.LOCKED
	var border_key: String = "node_border"
	if state == SkillTree.State.AFFORDABLE:
		border_key = "node_can_border"
	elif state == SkillTree.State.MAXED:
		border_key = "node_max_border"
	# A locked node is dimmed with its own colors (not transparency, which would show the line behind it).
	var fill_key: String = "node_locked_fill" if locked else "node_fill"
	var hover_key: String = "node_locked_fill" if locked else "node_hover_fill"
	button.add_theme_stylebox_override("normal", _node_style(fill_key, border_key))
	button.add_theme_stylebox_override("hover", _node_style(hover_key, border_key))
	button.add_theme_stylebox_override("pressed", _node_style(hover_key, border_key))
	button.add_theme_stylebox_override("focus", _node_style(hover_key, "node_focus_border"))
	var text_color: Color = _color("text_locked" if locked else "text")
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, text_color)


func _refresh_description() -> void:
	if not _message.is_empty():
		_desc_label.text = _message
	elif _hover_id.is_empty() or _view.is_empty():
		_desc_label.text = _text["hint"]
	else:
		_desc_label.text = _describe(_hover_id)


## The description of node `id` for the current view: locked nodes name the prerequisite to learn first.
func _describe(id: String) -> String:
	var node: Dictionary = SkillTree.find_node(_config, id)
	var entry: Dictionary = _view_entry(id)
	var state: int = entry.get("state", SkillTree.State.UNAFFORDABLE)
	if state == SkillTree.State.LOCKED:
		var req: Dictionary = SkillTree.find_node(_config, node["req"])
		return _text["desc_locked"] % req["name"]
	var line: String = _text["desc_open"] % [node["name"], node["desc"]]
	if state == SkillTree.State.MAXED:
		return line + _text["desc_max"]
	return line + _text["desc_cost"] % SkillTree.format_amount(SkillTree.cost(node, int(entry.get("level", 0))))


func _view_entry(id: String) -> Dictionary:
	for entry: Dictionary in _view.get("nodes", []):
		if entry["id"] == id:
			return entry
	return {}


func _run_info(stats: Dictionary, best: int) -> String:
	var info: String = _text["run_info"] % [int(stats["time"]), int(stats["knight"])]
	if int(stats["archer"]) > 0:
		info += _text["run_archer"] % int(stats["archer"])
	if int(stats["barb"]) > 0:
		info += _text["run_barb"] % int(stats["barb"])
	return info + _text["run_best"] % SkillTree.format_amount(best)


func _on_node_hover(id: String) -> void:
	_hover_id = id
	_message = ""
	_refresh_description()


func _on_reset_pressed() -> void:
	if _reset_armed:
		_disarm_reset()
		reset_confirmed.emit()
		return
	_reset_armed = true
	_reset_button.text = _text["reset_confirm"]
	_reset_timer.start()


func _disarm_reset() -> void:
	_reset_armed = false
	_reset_timer.stop()
	if _reset_button != null:
		_reset_button.text = _text["reset"]


func _node_position(node: Dictionary) -> Vector2:
	var origin: Array = _config["layout"]["origin"]
	var step: Array = _config["layout"]["step"]
	return Vector2(float(origin[0]) + (float(node["x"]) - 1.0) * float(step[0]),
			float(origin[1]) + (float(node["y"]) - 1.0) * float(step[1]))


func _draw_lines() -> void:
	for node: Dictionary in _config["nodes"]:
		if not node.has("req"):
			continue
		var parent: Dictionary = SkillTree.find_node(_config, node["req"])
		var learned: bool = int(_view_entry(parent["id"]).get("level", 0)) > 0
		_lines.draw_line(_node_position(parent), _node_position(node),
				_color("line_on" if learned else "line_off"), float(_ui["line_width"]))


func _make_node_button(node: Dictionary) -> Button:
	var size_array: Array = _config["layout"]["node_size"]
	var button := Button.new()
	button.custom_minimum_size = Vector2(float(size_array[0]), float(size_array[1]))
	button.size = button.custom_minimum_size
	button.position = _node_position(node) - button.size / 2.0
	button.add_theme_font_size_override("font_size", int(_ui["node_font_size"]))
	var id: String = node["id"]
	button.pressed.connect(func() -> void: node_pressed.emit(id))
	button.mouse_entered.connect(_on_node_hover.bind(id))
	button.focus_entered.connect(_on_node_hover.bind(id))
	add_child(button)
	return button


func _node_style(fill_key: String, border_key: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _color(fill_key)
	style.border_color = _color(border_key)
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(2.0)
	return style


func _color(key: String) -> Color:
	return Color.html(_ui["colors"][key])


func _make_label(text: String, font_size: int, color_key: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", _color(color_key))
	label.add_theme_color_override("font_outline_color", _color("text_outline"))
	label.add_theme_constant_override("outline_size", int(_ui["outline_size"]))
	add_child(label)
	return label
