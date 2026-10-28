extends Node2D
## DEV HARNESS ONLY, not part of the game. Hosts a SlimeField and a HeroSquad at the base
## resolution so stories 001 and 002 can be seen: slimes spawn and hop, a left click drops a
## knight at the cursor (landing impact, then chase and sword attacks), kills drop coins that
## bounce, blink and expire. Coins are not collected here (story 003). The old story-001
## click-to-damage was removed because clicks now drop knights.

const SLIME_CONFIG_PATH: String = "res://assets/data/slime_field.json"
const HERO_CONFIG_PATH: String = "res://assets/data/hero_knight.json"
const GRASS_COLOR: Color = Color("#4f8a3c")
const AUTO_DROP_MARGIN: Vector2 = Vector2(20.0, 40.0)

## Completed runs (drives the 1.07^runs scale).
@export var runs: int = 0
## Density upgrade level (raises the slime cap by 4 per level).
@export var density_level: int = 0
## Coin upgrade level (raises coin value by 30% per level).
@export var coin_level: int = 0
## Hero upgrade level (knights per run = 2 + this).
@export var hero_level: int = 0
## Landing-impact upgrade level (radius, damage and shake).
@export var land_level: int = 0
## Attack-speed upgrade level.
@export var spd_level: int = 0
## Attack-damage upgrade level.
@export var dmg_level: int = 0
## When above 0, drops a knight at a random point every this many seconds (unattended screenshots).
@export var auto_drop_interval: float = 0.0

var _field: SlimeField
var _squad: HeroSquad
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _label: Label
var _auto_drop_timer: float = 0.0


func _ready() -> void:
	var slime_config: Dictionary = SlimeField.load_config(SLIME_CONFIG_PATH)
	var hero_config: Dictionary = HeroSquad.load_config(HERO_CONFIG_PATH)
	if slime_config.is_empty() or hero_config.is_empty():
		return
	_rng.randomize()
	var size: Vector2 = get_viewport_rect().size
	# The squad goes first so its landing preview is drawn under the slimes and knights.
	_squad = HeroSquad.new()
	add_child(_squad)
	_field = SlimeField.new()
	add_child(_field)
	_field.setup(slime_config, _rng, size, runs, density_level, coin_level)
	_squad.setup(hero_config, slime_config, _field, _rng, size, runs,
			{"hero": hero_level, "land": land_level, "spd": spd_level, "dmg": dmg_level})
	_squad.shake_changed.connect(_on_shake_changed)
	_label = Label.new()
	_label.position = Vector2(4.0, 2.0)
	_label.add_theme_font_size_override("font_size", 10)
	add_child(_label)


func _process(delta: float) -> void:
	if _field == null:
		return
	_label.text = "knights %d  slimes %d  coins %d  runs %d" % [
			_squad.remaining, _field.slimes.size(), _field.coins.size(), runs]
	if auto_drop_interval > 0.0:
		_auto_drop_timer -= delta
		if _auto_drop_timer <= 0.0:
			_auto_drop_timer = auto_drop_interval
			var size: Vector2 = get_viewport_rect().size
			_squad.drop_hero(Vector2(
					_rng.randf_range(AUTO_DROP_MARGIN.x, size.x - AUTO_DROP_MARGIN.x),
					_rng.randf_range(AUTO_DROP_MARGIN.y, size.y - AUTO_DROP_MARGIN.y)))


func _draw() -> void:
	draw_rect(get_viewport_rect(), GRASS_COLOR)


func _on_shake_changed(offset: Vector2) -> void:
	position = offset
