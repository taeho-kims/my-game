class_name SkillTree
extends RefCounted
## The skill tree rules: the node data file loader, cost, unlock and purchase rules and the node state
## shown on the tree screen. Pure static functions on plain data (the node config and a levels
## Dictionary {node id: int}), so every rule is unit-testable and no state lives here.
##
## Implements design/game-brief.md (MVP 5) via production/epics/slime-nodaji/story-005-skill-tree-save.md.
## Values ported from slime-nodaji.html (NODES, cost, unlocked, the purchase click handler); the
## magnet node's range text is halved for the 640x360 base. `config` is assets/data/skill_tree.json.

## Display state of a node: a locked node is dimmed, an affordable one gets the gold border.
enum State { LOCKED, MAXED, AFFORDABLE, UNAFFORDABLE }

## Why a purchase failed (the "reason" of `purchase`).
const REASON_UNKNOWN: String = "unknown"
const REASON_LOCKED: String = "locked"
const REASON_MAX: String = "max"
const REASON_GOLD: String = "gold"


## Loads and validates the skill tree data file; returns an empty Dictionary (after push_error)
## when the file is missing or invalid.
##
## Schema (see assets/data/skill_tree.json):
## - nodes: array of {id, name, desc (String), x, y (grid position), max (levels), base (first-level
##   cost), g (cost growth per level), req (optional id of the prerequisite node)}.
## - stats: arrows_base, golden_base, golden_per_level, rain_per_level (stats no other system owns yet).
## - save: path (String, user://), version (int), reset_confirm_seconds (s).
## - layout: origin / step / node_size, each [x, y] in px, for the tree screen.
## - ui: sizes, colors and texts of the tree screen (read by SkillTreeScreen).
static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("SkillTree: data file not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SkillTree: data file is not a valid JSON object: %s" % path)
		return {}
	var data: Dictionary = parsed
	var problem: String = _find_problem(data)
	if not problem.is_empty():
		push_error("SkillTree: invalid data file %s: %s" % [path, problem])
		return {}
	return data


## The node Dictionary with this id, or an empty Dictionary when there is none.
static func find_node(config: Dictionary, id: String) -> Dictionary:
	for node: Dictionary in config["nodes"]:
		if node["id"] == id:
			return node
	return {}


## Current level of a node (0 when it was never bought).
static func level(levels: Dictionary, id: String) -> int:
	return int(levels.get(id, 0))


## Cost of the next level: round(base * g ^ current level).
static func cost(node: Dictionary, current_level: int) -> int:
	return roundi(float(node["base"]) * pow(float(node["g"]), current_level))


## True when the node has no prerequisite or its prerequisite is at level 1 or more.
static func is_unlocked(config: Dictionary, levels: Dictionary, id: String) -> bool:
	var node: Dictionary = find_node(config, id)
	return not node.is_empty() and (not node.has("req") or level(levels, node["req"]) > 0)


## True when the node is at its maximum level.
static func is_max(config: Dictionary, levels: Dictionary, id: String) -> bool:
	var node: Dictionary = find_node(config, id)
	return not node.is_empty() and level(levels, id) >= int(node["max"])


## Display state of a node for `gold`: LOCKED (prerequisite missing), MAXED, AFFORDABLE or UNAFFORDABLE.
static func node_state(config: Dictionary, levels: Dictionary, gold: int, id: String) -> State:
	if not is_unlocked(config, levels, id):
		return State.LOCKED
	if is_max(config, levels, id):
		return State.MAXED
	var node: Dictionary = find_node(config, id)
	return State.AFFORDABLE if gold >= cost(node, level(levels, id)) else State.UNAFFORDABLE


## Tries to buy one level of node `id` with `gold`. Returns a Dictionary: "ok" (bool), "reason"
## (one of the REASON_ constants, "" when ok), "gold" (gold after the purchase), "levels" (a new
## levels Dictionary, the given one is never changed) and "shortfall" (missing gold, 0 unless the
## reason is REASON_GOLD).
static func purchase(config: Dictionary, levels: Dictionary, gold: int, id: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "gold": gold, "levels": levels.duplicate(), "shortfall": 0}
	var node: Dictionary = find_node(config, id)
	if node.is_empty():
		result["reason"] = REASON_UNKNOWN
		return result
	if not is_unlocked(config, levels, id):
		result["reason"] = REASON_LOCKED
		return result
	var current: int = level(levels, id)
	if current >= int(node["max"]):
		result["reason"] = REASON_MAX
		return result
	var price: int = cost(node, current)
	if gold < price:
		result["reason"] = REASON_GOLD
		result["shortfall"] = price - gold
		return result
	result["ok"] = true
	result["gold"] = gold - price
	(result["levels"] as Dictionary)[id] = current + 1
	return result


## Compact amount text as the prototype's fmt: below 10000 as is, then 1.2K / 123K, 1.2M, 1.2B.
static func format_amount(amount: int) -> String:
	if amount < 10000:
		return str(amount)
	if amount < 1000000:
		return ("%.1fK" if amount < 100000 else "%.0fK") % (amount / 1000.0)
	if amount < 1000000000:
		return "%.1fM" % (amount / 1000000.0)
	return "%.1fB" % (amount / 1000000000.0)


## Returns a description of the first schema problem, or "" when the data is valid.
static func _find_problem(data: Dictionary) -> String:
	for key: String in ["nodes", "stats", "save", "layout", "ui"]:
		if not data.has(key):
			return "missing section '%s'" % key
	if typeof(data["nodes"]) != TYPE_ARRAY or (data["nodes"] as Array).is_empty():
		return "'nodes' must be a non-empty array"
	var ids: Array[String] = []
	for entry: Variant in data["nodes"]:
		if typeof(entry) != TYPE_DICTIONARY:
			return "a node is not an object"
		var node: Dictionary = entry
		for field: String in ["id", "name", "desc", "x", "y", "max", "base", "g"]:
			if not node.has(field):
				return "node '%s' is missing '%s'" % [node.get("id", "?"), field]
		if ids.has(node["id"]):
			return "duplicate node id '%s'" % node["id"]
		if float(node["max"]) < 1.0 or float(node["base"]) <= 0.0 or float(node["g"]) < 1.0:
			return "node '%s' needs max >= 1, base > 0 and g >= 1" % node["id"]
		ids.append(node["id"])
	for entry: Dictionary in data["nodes"]:
		if entry.has("req") and not ids.has(entry["req"]):
			return "node '%s' requires unknown node '%s'" % [entry["id"], entry["req"]]
	for key: String in ["arrows_base", "golden_base", "golden_per_level", "rain_per_level"]:
		if not (data["stats"] as Dictionary).has(key):
			return "missing key 'stats.%s'" % key
	for key: String in ["path", "version", "reset_confirm_seconds"]:
		if not (data["save"] as Dictionary).has(key):
			return "missing key 'save.%s'" % key
	for key: String in ["origin", "step", "node_size"]:
		if not (data["layout"] as Dictionary).has(key):
			return "missing key 'layout.%s'" % key
	return ""
