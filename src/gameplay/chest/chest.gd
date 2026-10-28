class_name Chest
extends Node2D
## The collection chest at the bottom of the field: accumulates the value of absorbed coins,
## shows its tier by color and bumps when a coin lands.
##
## Implements design/game-brief.md (MVP 3) via production/epics/slime-nodaji/story-003-magnet-chest-tiers.md.
## Values ported from slime-nodaji.html (chestPos, run.chest / chestBump, drawChest, tierOf, multOf),
## spatial values halved for the 640x360 base.
## The node position is the chest centre. Tier rules live in ChestTiers.

## Emitted for every deposit with the amount added and the new accumulated value.
signal deposited(amount: float, new_value: float)

const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
const FRAME_COLOR: Color = Color("#5a3a22")
const PANEL_COLOR: Color = Color("#7a5132")
const LID_COLOR: Color = Color("#6b4528")
const LOCK_COLOR: Color = Color("#1b1612")

## Accumulated value of every coin deposited so far.
var value: float = 0.0
## Bump animation, 1 right after a deposit, decaying to 0.
var bump: float = 0.0

var _config: Dictionary = {}
var _run_scale: float = 1.0
var _chest_level: int = 0


## Prepares the chest. `config` is the full chest_tiers config, `field_size` the viewport size.
## The chest sits centred horizontally, `chest.bottom_offset` above the bottom edge.
func setup(config: Dictionary, field_size: Vector2, run_scale: float, chest_level: int) -> void:
	_config = config
	_run_scale = run_scale
	_chest_level = chest_level
	position = Vector2(field_size.x / 2.0, field_size.y - float(config["chest"]["bottom_offset"]))
	queue_redraw()


## Adds `amount` to the chest value and restarts the bump.
func deposit(amount: float) -> void:
	value += amount
	bump = 1.0
	deposited.emit(amount, value)
	queue_redraw()


## Current tier index (0 = wooden).
func tier() -> int:
	return ChestTiers.tier_of(_config, value, _run_scale)


## Payout if the run ended now: round(value * multiplier of the current tier).
func total() -> int:
	return ChestTiers.total(_config, value, tier(), _chest_level)


## Decays the bump animation by `delta` seconds.
func advance(delta: float) -> void:
	if bump <= 0.0:
		return
	bump = maxf(0.0, bump - float(_config["chest"]["bump_decay"]) * delta)
	queue_redraw()


func _process(delta: float) -> void:
	if not _config.is_empty():
		advance(delta)


func _draw() -> void:
	if _config.is_empty():
		return
	var chest_cfg: Dictionary = _config["chest"]
	var tc: Color = ChestTiers.tier_color(_config, tier())
	var scale_factor: float = 1.0 + bump * float(chest_cfg["bump_scale"])
	draw_set_transform(Vector2(0.0, -bump * float(chest_cfg["bump_lift"])), 0.0, Vector2(scale_factor, scale_factor))
	draw_rect(Rect2(-13.0, 5.0, 26.0, 3.0), SHADOW_COLOR)
	draw_rect(Rect2(-12.0, -7.0, 24.0, 13.0), FRAME_COLOR)
	draw_rect(Rect2(-11.0, -6.0, 22.0, 11.0), PANEL_COLOR)
	draw_rect(Rect2(-12.0, -7.0, 24.0, 2.0), tc)
	draw_rect(Rect2(-12.0, 4.0, 24.0, 2.0), tc)
	draw_rect(Rect2(-2.0, -7.0, 4.0, 13.0), tc)
	draw_rect(Rect2(-12.5, -13.0, 25.0, 6.5), LID_COLOR)
	draw_rect(Rect2(-12.5, -13.0, 25.0, 1.5), tc)
	draw_rect(Rect2(-2.0, -13.0, 4.0, 6.5), tc)
	draw_rect(Rect2(-1.0, -8.0, 2.0, 2.5), LOCK_COLOR)
