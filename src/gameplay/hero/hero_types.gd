class_name HeroTypes
extends RefCounted
## The hero type data file (assets/data/hero_types.json): loader with validation, and the pixel-art
## sprite helpers shared by the heroes in the field and the hotbar card icons.
##
## Implements design/game-brief.md (MVP 6) via production/epics/slime-nodaji/story-006-archer-berserker-hotbar.md.
## Values ported from slime-nodaji.html (SPR, the hero part of update, buildHotbar); spatial values
## are halved for the 640x360 base and sprites are drawn at 2x instead of 3x.


## Loads and validates the hero types data file; returns an empty Dictionary (after push_error)
## when the file is missing or invalid.
##
## Schema (see assets/data/hero_types.json):
## - order: type ids in hotbar order; the number keys 1, 2, 3 pick them. Each id is also the key of the
##   PlayerStats count of that type (knight, archer, barb).
## - types.<id>: name (String) and sprite {scale, rows (8 strings of 8 chars, "." is empty), palette
##   {char: hex color}}.
## - types.archer: range, chase_speed (px, px/s), cooldown_multiplier and damage_multiplier (of the
##   knight's), shot_origin_y (px, arrow start above the feet), arrow {speed, hit_distance, aim_height_ratio
##   (of the slime radius), length, width, color}.
## - types.barb: range_base (px, plus the slime radius), chase_speed, cooldown_multiplier, slash {radius
##   (px, plus the slime radius), damage_multiplier, swing_time, ring_life (s), arc_radius, arc_center_y,
##   arc_width, arc_span (rad), arc_spin (rad/s), color}.
## - hotbar: card layout, colors and texts of the hotbar.
static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("HeroTypes: data file not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("HeroTypes: data file is not a valid JSON object: %s" % path)
		return {}
	var data: Dictionary = parsed
	var problem: String = _find_problem(data)
	if not problem.is_empty():
		push_error("HeroTypes: invalid data file %s: %s" % [path, problem])
		return {}
	return data


## Converts a sprite's palette (char -> hex string) to char -> Color.
static func palette(sprite: Dictionary) -> Dictionary:
	var colors: Dictionary = {}
	var source: Dictionary = sprite["palette"]
	for key: String in source:
		colors[key] = Color.html(source[key])
	return colors


## Draws a sprite on `item` with its feet-centre at `origin`: the sprite is 8 cells wide and 8 tall,
## `scale` pixels per cell, mirrored when `flip`. `colors` comes from `palette`.
static func draw_sprite(item: CanvasItem, sprite: Dictionary, colors: Dictionary, origin: Vector2,
		scale: float, flip: bool) -> void:
	var rows: Array = sprite["rows"]
	for row: int in 8:
		var line: String = rows[row]
		for col: int in 8:
			var key: String = line[col]
			if key == ".":
				continue
			var cx: int = 7 - col if flip else col
			item.draw_rect(Rect2(origin.x + roundf(float(cx - 4) * scale), origin.y + float(row - 8) * scale,
					scale, scale), colors[key])


## Returns a description of the first schema problem, or "" when the data is valid.
static func _find_problem(data: Dictionary) -> String:
	var num: int = TYPE_FLOAT
	var str_type: int = TYPE_STRING
	var arr: int = TYPE_ARRAY
	var sections: Array = [
		["types.archer", {"range": num, "chase_speed": num, "cooldown_multiplier": num, "damage_multiplier": num,
			"shot_origin_y": num, "arrow": TYPE_DICTIONARY}],
		["types.archer.arrow", {"speed": num, "hit_distance": num, "aim_height_ratio": num, "length": num,
			"width": num, "color": str_type}],
		["types.barb", {"range_base": num, "chase_speed": num, "cooldown_multiplier": num, "slash": TYPE_DICTIONARY}],
		["types.barb.slash", {"radius": num, "damage_multiplier": num, "swing_time": num, "ring_life": num,
			"arc_radius": num, "arc_center_y": num, "arc_width": num, "arc_span": num, "arc_spin": num,
			"color": str_type}],
		["hotbar", {"margin": num, "gap": num, "card_size": arr, "icon_scale": num, "icon_box": num,
			"icon_inset": num, "name_x": num, "count_right_inset": num, "font_size": num, "outline_size": num,
			"border_width": num, "disabled_alpha": num, "colors": TYPE_DICTIONARY, "text": TYPE_DICTIONARY}],
		["hotbar.colors", {"card_back": str_type, "card_border": str_type, "selected_back": str_type,
			"selected_border": str_type, "icon_back": str_type, "name": str_type, "count": str_type,
			"text_outline": str_type}],
		["hotbar.text", {"tooltip": str_type}],
	]
	if typeof(data.get("order")) != TYPE_ARRAY or typeof(data.get("types")) != TYPE_DICTIONARY:
		return "missing 'order' array or 'types' object"
	for id: Variant in data["order"]:
		if typeof(id) != TYPE_STRING or typeof(data["types"].get(id)) != TYPE_DICTIONARY:
			return "order entry '%s' has no entry in 'types'" % id
		var problem: String = _sprite_problem(data["types"][id], id)
		if not problem.is_empty():
			return problem
	for section: Array in sections:
		var node: Variant = data
		for step: String in String(section[0]).split("."):
			node = node.get(step) if typeof(node) == TYPE_DICTIONARY else null
		if typeof(node) != TYPE_DICTIONARY:
			return "missing or non-object section '%s'" % section[0]
		var expected: Dictionary = section[1]
		for key: String in expected:
			if not node.has(key):
				return "missing key '%s.%s'" % [section[0], key]
			if typeof(node[key]) != expected[key]:
				return "'%s.%s' has the wrong type" % [section[0], key]
	if (data["hotbar"]["card_size"] as Array).size() != 2:
		return "hotbar.card_size must be [width, height]"
	return ""


static func _sprite_problem(type_entry: Dictionary, id: String) -> String:
	var sprite: Variant = type_entry.get("sprite")
	if typeof(type_entry.get("name")) != TYPE_STRING or typeof(sprite) != TYPE_DICTIONARY \
			or typeof(sprite.get("scale")) != TYPE_FLOAT or typeof(sprite.get("rows")) != TYPE_ARRAY \
			or typeof(sprite.get("palette")) != TYPE_DICTIONARY:
		return "types.%s needs name, and sprite {scale, rows, palette}" % id
	if sprite["rows"].size() != 8:
		return "types.%s.sprite.rows must have 8 rows" % id
	for line: Variant in sprite["rows"]:
		if typeof(line) != TYPE_STRING or line.length() != 8:
			return "types.%s.sprite.rows must be 8 strings of 8 characters" % id
		for key: String in line:
			if key != "." and not sprite["palette"].has(key):
				return "types.%s.sprite uses '%s' which is not in the palette" % [id, key]
	return ""
