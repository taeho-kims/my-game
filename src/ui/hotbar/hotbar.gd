class_name Hotbar
extends CanvasLayer
## The hero hotbar: one card per owned hero type with its pixel-art icon, name, remaining count and a
## selection highlight. A pure view of a HeroRoster: it never changes the roster, it asks for a type
## with `type_requested` (card click or the number keys 1, 2, 3 in hotbar order).
##
## Implements design/game-brief.md (MVP 6) via production/epics/slime-nodaji/story-006-archer-berserker-hotbar.md.
## Values ported from slime-nodaji.html (buildHotbar, updateHotbar, keydown); layout and texts come from
## the "hotbar" section of assets/data/hero_types.json. The cards sit in the bottom-left corner.

## Emitted when the player clicks a card or presses its number key.
signal type_requested(type: String)

const STYLE_STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]

var _ui: Dictionary = {}
var _order: Array[String] = []
var _roster: HeroRoster
var _cards: Dictionary = {}
var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat


## Builds the cards. `types_config` is hero_types.json, `roster` the run's roster to show and
## `field_size` the viewport size.
func setup(types_config: Dictionary, roster: HeroRoster, field_size: Vector2) -> void:
	_ui = types_config["hotbar"]
	_roster = roster
	_order.assign(types_config["order"])
	var colors: Dictionary = _ui["colors"]
	_normal_style = _make_style(Color.html(colors["card_back"]), Color.html(colors["card_border"]))
	_selected_style = _make_style(Color.html(colors["selected_back"]), Color.html(colors["selected_border"]))
	var size_array: Array = _ui["card_size"]
	var card_size := Vector2(float(size_array[0]), float(size_array[1]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_ui["gap"]))
	row.position = Vector2(float(_ui["margin"]), field_size.y - float(_ui["margin"]) - card_size.y)
	add_child(row)
	for i: int in _order.size():
		var type: String = _order[i]
		_cards[type] = _make_card(row, type, i, card_size, types_config["types"][type])
	roster.changed.connect(refresh)
	refresh()


## Updates every card from the roster: shown only when owned, the remaining count, dimmed when it cannot
## be selected, highlighted when selected.
func refresh() -> void:
	for type: String in _order:
		var card: Dictionary = _cards[type]
		var button: Button = card["button"]
		var left: int = _roster.remaining(type)
		var usable: bool = _roster.enabled and left > 0
		button.visible = _roster.is_owned(type)
		button.disabled = not usable
		button.modulate.a = 1.0 if usable else float(_ui["disabled_alpha"])
		(card["count"] as Label).text = str(left)
		var style: StyleBoxFlat = _selected_style if _roster.enabled and type == _roster.selected else _normal_style
		for state: String in STYLE_STATES:
			button.add_theme_stylebox_override(state, style)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index: int = key.keycode - KEY_1
	if index >= 0 and index < _order.size():
		type_requested.emit(_order[index])
		get_viewport().set_input_as_handled()


func _make_card(row: HBoxContainer, type: String, index: int, card_size: Vector2, entry: Dictionary) -> Dictionary:
	var colors: Dictionary = _ui["colors"]
	var button := Button.new()
	button.custom_minimum_size = card_size
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = String(_ui["text"]["tooltip"]) % (index + 1)
	button.pressed.connect(func() -> void: type_requested.emit(type))
	row.add_child(button)

	var box: float = _ui["icon_box"]
	var inset: float = _ui["icon_inset"]
	var icon := ColorRect.new()
	icon.color = Color.html(colors["icon_back"])
	icon.position = Vector2(inset, (card_size.y - box) / 2.0)
	icon.size = Vector2(box, box)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var sprite: Dictionary = entry["sprite"]
	var palette: Dictionary = HeroTypes.palette(sprite)
	var icon_scale: float = _ui["icon_scale"]
	# The sprite's feet-centre sits at the bottom middle of its 8x8 cells, centred in the icon box.
	var origin := Vector2(box / 2.0, (box + icon_scale * 8.0) / 2.0)
	icon.draw.connect(func() -> void: HeroTypes.draw_sprite(icon, sprite, palette, origin, icon_scale, false))

	var name_label := _make_label(Color.html(colors["name"]))
	name_label.text = entry["name"]
	name_label.position = Vector2(float(_ui["name_x"]), 0.0)
	name_label.size = Vector2(card_size.x - float(_ui["name_x"]), card_size.y)
	button.add_child(name_label)
	var count_label := _make_label(Color.html(colors["count"]))
	count_label.position = Vector2.ZERO
	count_label.size = Vector2(card_size.x - float(_ui["count_right_inset"]), card_size.y)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_child(count_label)
	return {"button": button, "count": count_label}


func _make_label(color: Color) -> Label:
	var colors: Dictionary = _ui["colors"]
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", int(_ui["font_size"]))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.html(colors["text_outline"]))
	label.add_theme_constant_override("outline_size", int(_ui["outline_size"]))
	return label


func _make_style(back: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = back
	style.border_color = border
	style.set_border_width_all(int(_ui["border_width"]))
	return style
