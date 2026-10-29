class_name HeroRoster
extends RefCounted
## The heroes still to be dropped in one run, per type, and the type selected for the next drop.
## Pure logic behind the hotbar: no scene is needed, so the rules are unit-testable.
##
## Implements design/game-brief.md (MVP 6) via production/epics/slime-nodaji/story-006-archer-berserker-hotbar.md.
## Rules ported from slime-nodaji.html (pointerdown, keydown, updateHotbar): a type the player does not
## own (count 0 at the start of the run) is hidden; a type with none left cannot be selected; when the
## selected type runs out the first type in hotbar order that still has heroes is selected; once the run
## ends the roster is disabled and refuses everything.

## Emitted whenever the counts, the selection or the enabled flag change.
signal changed

## The selected type id.
var selected: String = ""
## False once the run ended: nothing can be selected or taken.
var enabled: bool = true

var _order: Array[String] = []
var _remaining: Dictionary = {}
var _owned: Dictionary = {}


## `order` is the hotbar order; `counts` maps each type id to the heroes available at the start of the run.
## The first type that has heroes starts selected.
func _init(order: Array[String], counts: Dictionary) -> void:
	_order = order
	for type: String in order:
		_remaining[type] = int(counts.get(type, 0))
		_owned[type] = _remaining[type] > 0
	selected = _first_available()


## Builds a roster whose counts are the PlayerStats counts (`stats` keys equal the type ids).
static func from_stats(order: Array[String], stats: Dictionary) -> HeroRoster:
	var counts: Dictionary = {}
	for type: String in order:
		counts[type] = int(stats[type])
	return HeroRoster.new(order, counts)


## Heroes of `type` still to be dropped.
func remaining(type: String) -> int:
	return int(_remaining.get(type, 0))


## Heroes of all types still to be dropped.
func total_remaining() -> int:
	var total: int = 0
	for type: String in _order:
		total += _remaining[type]
	return total


## True when the player had at least one hero of `type` at the start of the run (the card is shown).
func is_owned(type: String) -> bool:
	return bool(_owned.get(type, false))


## Selects `type`. Returns false (nothing changes) when the roster is disabled, the type is unknown or
## none of it is left.
func select(type: String) -> bool:
	if not enabled or remaining(type) <= 0:
		return false
	selected = type
	changed.emit()
	return true


## Takes one hero of the selected type for a drop and returns its type id, or "" when the roster is
## disabled or empty. When the selected type is already empty the first type with heroes is used. After
## the take, an exhausted selected type hands the selection to the first type with heroes left.
func take() -> String:
	if not enabled:
		return ""
	if remaining(selected) <= 0:
		var fallback: String = _first_available()
		if fallback.is_empty():
			return ""
		selected = fallback
	var type: String = selected
	_remaining[type] -= 1
	if _remaining[type] <= 0:
		var next: String = _first_available()
		if not next.is_empty():
			selected = next
	changed.emit()
	return type


## Disables the roster (the run ended).
func disable() -> void:
	enabled = false
	changed.emit()


func _first_available() -> String:
	for type: String in _order:
		if _remaining[type] > 0:
			return type
	return ""
