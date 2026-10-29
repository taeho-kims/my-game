class_name SaveData
extends RefCounted
## The save file: gold, run count, best record and the skill tree levels, in a versioned format
## that other systems can extend (design/game-brief.md, "확장 설계 원칙 — 저장 데이터").
##
## File layout: {"version": int, "meta": {"gold", "runs", "best"}, "skill_tree": {"levels": {id: int}}}
## plus whatever other systems add (maps, equipment, cards, collection ...). Rules:
## - Old versions are lifted one step at a time by `_migrate_step` (version 0 is the prototype's flat
##   {gold, runs, lv, best} format, or a file without a version field).
## - Missing keys take their defaults; wrong types and negative numbers fall back to the defaults.
## - Keys this class does not know, at the top level and inside `meta` and `skill_tree`, are kept in
##   `_extra*` and written back unchanged.
## - A missing or corrupt file starts a new game.
##
## Implements production/epics/slime-nodaji/story-005-skill-tree-save.md.

const KEY_VERSION: String = "version"
const KEY_META: String = "meta"
const KEY_TREE: String = "skill_tree"
const KEY_GOLD: String = "gold"
const KEY_RUNS: String = "runs"
const KEY_BEST: String = "best"
const KEY_LEVELS: String = "levels"
## Flat keys of the version-0 (prototype) format.
const LEGACY_LEVELS: String = "lv"

## Version number of the loaded file (at least the current version after `from_variant`).
var version: int = 0
var gold: int = 0
var runs: int = 0
var best: int = 0
## Skill tree levels {node id: int}.
var levels: Dictionary = {}

var _extra: Dictionary = {}
var _extra_meta: Dictionary = {}
var _extra_tree: Dictionary = {}


## A new game at `current_version`.
static func new_game(current_version: int) -> SaveData:
	var data := SaveData.new()
	data.version = current_version
	return data


## Builds the save from parsed JSON (any Variant): not a Dictionary -> a new game; otherwise
## migrated to `current_version`, defaults filled in and unknown keys kept.
static func from_variant(raw: Variant, current_version: int) -> SaveData:
	if typeof(raw) != TYPE_DICTIONARY:
		return new_game(current_version)
	var source: Dictionary = (raw as Dictionary).duplicate(true)
	var file_version: int = _read_version(source)
	var step_version: int = file_version
	while step_version < current_version:
		source = _migrate_step(source, step_version)
		step_version += 1
	var data := SaveData.new()
	data.version = maxi(file_version, current_version)
	var meta: Dictionary = _read_section(source, KEY_META)
	data.gold = _read_count(meta, KEY_GOLD)
	data.runs = _read_count(meta, KEY_RUNS)
	data.best = _read_count(meta, KEY_BEST)
	var tree: Dictionary = _read_section(source, KEY_TREE)
	var raw_levels: Variant = tree.get(KEY_LEVELS, {})
	if typeof(raw_levels) == TYPE_DICTIONARY:
		for id: Variant in raw_levels:
			if typeof(raw_levels[id]) in [TYPE_INT, TYPE_FLOAT]:
				data.levels[str(id)] = maxi(0, int(raw_levels[id]))
	for key: Variant in meta:
		if not [KEY_GOLD, KEY_RUNS, KEY_BEST].has(key):
			data._extra_meta[key] = meta[key]
	for key: Variant in tree:
		if key != KEY_LEVELS:
			data._extra_tree[key] = tree[key]
	for key: Variant in source:
		if not [KEY_VERSION, KEY_META, KEY_TREE].has(key):
			data._extra[key] = source[key]
	return data


## Loads `path` (user://...): a missing, unreadable or corrupt file gives a new game.
static func load_file(path: String, current_version: int) -> SaveData:
	if not FileAccess.file_exists(path):
		return new_game(current_version)
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return new_game(current_version)
	return from_variant(parser.data, current_version)


## The file content as a Dictionary: the known keys plus every unknown key that was loaded.
func to_dict() -> Dictionary:
	var meta: Dictionary = _extra_meta.duplicate(true)
	meta[KEY_GOLD] = gold
	meta[KEY_RUNS] = runs
	meta[KEY_BEST] = best
	var tree: Dictionary = _extra_tree.duplicate(true)
	tree[KEY_LEVELS] = levels.duplicate()
	var out: Dictionary = _extra.duplicate(true)
	out[KEY_VERSION] = version
	out[KEY_META] = meta
	out[KEY_TREE] = tree
	return out


## Writes the save to `path`; returns false (after push_error) when the file cannot be written.
func save_file(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveData: cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	var written: bool = file.store_string(JSON.stringify(to_dict(), "\t"))
	if not written:
		push_error("SaveData: write failed %s" % path)
	return written


## Lifts a save Dictionary from `from_version` to `from_version + 1`. One match arm per version;
## add the next arm when the format changes.
static func _migrate_step(source: Dictionary, from_version: int) -> Dictionary:
	match from_version:
		0:
			return _migrate_v0_to_v1(source)
	return source


## Version 0 (the prototype's {gold, runs, lv, best}, or no version field) -> version 1 sub-keys.
static func _migrate_v0_to_v1(source: Dictionary) -> Dictionary:
	if source.has(KEY_META) or source.has(KEY_TREE):
		return source
	var out: Dictionary = source.duplicate(true)
	var meta: Dictionary = {}
	for key: String in [KEY_GOLD, KEY_RUNS, KEY_BEST]:
		if out.has(key):
			meta[key] = out[key]
			out.erase(key)
	out[KEY_META] = meta
	out[KEY_TREE] = {KEY_LEVELS: out.get(LEGACY_LEVELS, {})}
	out.erase(LEGACY_LEVELS)
	return out


static func _read_version(source: Dictionary) -> int:
	var raw: Variant = source.get(KEY_VERSION, 0)
	return maxi(0, int(raw)) if typeof(raw) in [TYPE_INT, TYPE_FLOAT] else 0


static func _read_section(source: Dictionary, key: String) -> Dictionary:
	var raw: Variant = source.get(key, {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


static func _read_count(section: Dictionary, key: String) -> int:
	var raw: Variant = section.get(key, 0)
	return maxi(0, int(raw)) if typeof(raw) in [TYPE_INT, TYPE_FLOAT] else 0
