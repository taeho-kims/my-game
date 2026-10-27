extends Node2D
## DEV HARNESS ONLY, not part of the game. Hosts a SlimeField at the base resolution so
## story-001 can be seen: slimes spawn and hop, a left click damages the slime under the
## cursor, kills drop coins that bounce, blink and expire. Coins are not collected here
## (that is story 003).

const CONFIG_PATH: String = "res://assets/data/slime_field.json"
const GRASS_COLOR: Color = Color("#4f8a3c")

## Completed runs (drives the 1.07^runs scale).
@export var runs: int = 0
## Density upgrade level (raises the slime cap by 4 per level).
@export var density_level: int = 0
## Coin upgrade level (raises coin value by 30% per level).
@export var coin_level: int = 0
## Damage dealt by one left click (prototype base hero damage).
@export var click_damage: float = 5.0
## When above 0, damages a random slime every this many seconds (unattended screenshots).
@export var auto_hit_interval: float = 0.0

var _field: SlimeField
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _label: Label
var _auto_hit_timer: float = 0.0


func _ready() -> void:
	var config: Dictionary = SlimeField.load_config(CONFIG_PATH)
	if config.is_empty():
		return
	_rng.randomize()
	_field = SlimeField.new()
	add_child(_field)
	_field.setup(config, _rng, get_viewport_rect().size, runs, density_level, coin_level)
	_label = Label.new()
	_label.position = Vector2(4.0, 2.0)
	_label.add_theme_font_size_override("font_size", 10)
	add_child(_label)


func _process(delta: float) -> void:
	if _field == null:
		return
	_label.text = "slimes %d  coins %d  runs %d" % [_field.slimes.size(), _field.coins.size(), runs]
	if auto_hit_interval > 0.0 and not _field.slimes.is_empty():
		_auto_hit_timer -= delta
		if _auto_hit_timer <= 0.0:
			_auto_hit_timer = auto_hit_interval
			_field.slimes[_rng.randi_range(0, _field.slimes.size() - 1)].take_damage(click_damage)


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if _field == null or click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var point: Vector2 = get_global_mouse_position()
	for i in range(_field.slimes.size() - 1, -1, -1):
		if _field.slimes[i].contains_point(point):
			_field.slimes[i].take_damage(click_damage)
			return


func _draw() -> void:
	draw_rect(get_viewport_rect(), GRASS_COLOR)
