extends Node2D
## One timed run, end to end (production/epics/slime-nodaji/story-004-run-timer-burst.md): start button,
## the run (slime field, knights, magnet, chest), the burst (chest to the centre, opening, loot rain),
## the final harvest (the magnet picks the landed loot up again) and the result screen, then a quick
## re-run. Wires RunController to the HUD, the result screen and the view. Gold and the run count live
## in memory only (saving is story 005).
##
## Dev options: the exports below, plus the command-line user args (after `--`):
##   --run-seconds=N   overrides the run length            --autostart   starts without the button
##   --auto-drop=N     drops a knight every N seconds      --runs=N      starts at run N

const RUN_CONFIG_PATH: String = "res://assets/data/run.json"
const SLIME_CONFIG_PATH: String = "res://assets/data/slime_field.json"
const HERO_CONFIG_PATH: String = "res://assets/data/hero_knight.json"
const CHEST_CONFIG_PATH: String = "res://assets/data/chest_tiers.json"
const HUD_SCENE: PackedScene = preload("res://src/ui/hud/hud.tscn")
const RESULT_SCENE: PackedScene = preload("res://src/ui/result/result_screen.tscn")
const GRASS_COLOR: Color = Color("#4f8a3c")
const AUTO_DROP_MARGIN: Vector2 = Vector2(20.0, 40.0)
## Amplitude floor of the synthesised tones' exponential decay (as Magnet.SOUND_FLOOR).
const SOUND_FLOOR: float = 0.0001
const SHAKE_EPSILON: float = 0.05

## Completed runs (drives the 1.07^runs scale); counts up on every re-run.
@export var runs: int = 0
## Upgrade levels (the skill tree that sets them is story 005).
@export var time_level: int = 0
@export var density_level: int = 0
@export var coin_level: int = 0
@export var hero_level: int = 0
@export var land_level: int = 0
@export var spd_level: int = 0
@export var dmg_level: int = 0
@export var magnet_level: int = 0
@export var chest_level: int = 0
## Dev: when above 0, overrides the run length in seconds.
@export var run_seconds_override: float = 0.0
## Dev: drops a knight at a random point every this many seconds while above 0.
@export var auto_drop_interval: float = 0.0
## Dev: starts the first run without the start button.
@export var autostart: bool = false

var _run_config: Dictionary = {}
var _slime_config: Dictionary = {}
var _hero_config: Dictionary = {}
var _chest_config: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _size: Vector2 = Vector2.ZERO
var _gold: int = 0
var _world: Node2D
var _field: SlimeField
var _squad: HeroSquad
var _chest: Chest
var _magnet: Magnet
var _view: RunView
var _controller: RunController
var _hud: RunHud
var _result_screen: ResultScreen
var _sfx_player: AudioStreamPlayer
var _blip_player: AudioStreamPlayer
var _squad_shake: Vector2 = Vector2.ZERO
var _open_shake: float = 0.0
var _auto_drop_timer: float = 0.0
var _run_scale: float = 1.0


## Emitted by the result screen's "스킬 트리로" button; the skill tree screen is story 005.
signal skill_tree_requested


func _ready() -> void:
	_run_config = RunController.load_config(RUN_CONFIG_PATH)
	_slime_config = SlimeField.load_config(SLIME_CONFIG_PATH)
	_hero_config = HeroSquad.load_config(HERO_CONFIG_PATH)
	_chest_config = ChestTiers.load_config(CHEST_CONFIG_PATH)
	if _run_config.is_empty() or _slime_config.is_empty() or _hero_config.is_empty() or _chest_config.is_empty():
		return
	_apply_user_args()
	_rng.randomize()
	_size = get_viewport_rect().size
	var ui: Dictionary = _run_config["ui"]
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_hud.setup(ui, _size)
	_hud.start_pressed.connect(_start_run)
	_result_screen = RESULT_SCENE.instantiate()
	add_child(_result_screen)
	_result_screen.setup(ui, _size)
	_result_screen.retry_pressed.connect(_on_retry)
	_result_screen.skill_tree_pressed.connect(_on_skill_tree)
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	_blip_player = AudioStreamPlayer.new()
	add_child(_blip_player)
	if autostart:
		_start_run()
	else:
		_hud.show_start()


func _process(delta: float) -> void:
	if _controller == null:
		return
	_update_world_shake(delta)
	_update_chest()
	_update_harvest_coins()
	_auto_drop(delta)
	_hud.show_state(_hud_state())


## Starts a run with a fresh field, squad, chest, magnet and controller.
func _start_run() -> void:
	_hud.hide_start()
	_result_screen.hide_result()
	_clear_run()
	_run_scale = SlimeField.run_scale(_slime_config, runs)
	_world = Node2D.new()
	add_child(_world)
	var grass := ColorRect.new()
	grass.size = _size
	grass.color = GRASS_COLOR
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(grass)
	# The squad goes first so its landing preview is drawn under the slimes and knights; the chest after
	# the view so it draws over the dim and the raining loot; the magnet last for its ring.
	_squad = HeroSquad.new()
	_world.add_child(_squad)
	_field = SlimeField.new()
	_world.add_child(_field)
	_field.setup(_slime_config, _rng, _size, runs, density_level, coin_level)
	_squad.setup(_hero_config, _slime_config, _field, _rng, _size, runs,
			{"hero": hero_level, "land": land_level, "spd": spd_level, "dmg": dmg_level})
	_squad.shake_changed.connect(func(offset: Vector2) -> void: _squad_shake = offset)
	_view = RunView.new()
	_world.add_child(_view)
	_chest = Chest.new()
	_world.add_child(_chest)
	_chest.setup(_chest_config, _size, _run_scale, chest_level)
	_magnet = Magnet.new()
	_world.add_child(_magnet)
	_magnet.setup(_chest_config, _rng, _field.coins, _chest, _size, magnet_level)
	_controller = RunController.new()
	add_child(_controller)
	_controller.start(_run_config, _chest_config, _slime_config, _rng, _size, _chest.position, runs,
			{"time": time_level, "chest": chest_level, "coin": coin_level}, _magnet.flying_count)
	if run_seconds_override > 0.0:
		_controller.duration = run_seconds_override
	_view.setup(_run_config, _slime_config, _controller, _size)
	_field.slime_killed.connect(func(_slime: Slime) -> void: _controller.kills += 1)
	_chest.deposited.connect(func(amount: float, _total: float) -> void: _controller.collected += amount)
	_controller.chest_opened.connect(_on_chest_opened)
	_controller.rain_blip.connect(_on_rain_blip)
	_controller.phase_changed.connect(_on_phase_changed)
	_controller.run_finished.connect(_on_run_finished)
	_auto_drop_timer = 0.0
	_open_shake = 0.0
	_squad_shake = Vector2.ZERO


func _clear_run() -> void:
	for node: Node in [_world, _controller]:
		if node != null:
			node.queue_free()
	_world = null
	_controller = null


func _on_phase_changed(phase: int) -> void:
	match phase:
		RunController.Phase.BURST:
			# The field and the knights freeze; ground coins vanish so the magnet takes nothing new
			# (coins already flying keep going and count, see RunController).
			_field.process_mode = Node.PROCESS_MODE_DISABLED
			_squad.process_mode = Node.PROCESS_MODE_DISABLED
			_squad_shake = Vector2.ZERO
			_free_ground_coins()
		RunController.Phase.HARVEST:
			_spawn_harvest_coins()
			_magnet.set_target(_controller.chest_position(), _on_harvest_coin_arrived)
		RunController.Phase.RESULT:
			_free_ground_coins()


func _on_chest_opened() -> void:
	var burst: Dictionary = _run_config["burst"]
	_open_shake = float(burst["open_shake"])
	_play(_sfx_player, burst["open_sound"], float(burst["open_sound"]["frequency"]))


func _on_rain_blip(frequency: float) -> void:
	_play(_blip_player, _run_config["rain"]["blip"], frequency)


func _on_run_finished(result: RunResult) -> void:
	_gold += result.total_gold()
	_result_screen.show_result(result)


func _on_retry() -> void:
	runs += 1
	_start_run()


func _on_skill_tree() -> void:
	skill_tree_requested.emit()
	runs += 1
	_clear_run()
	_result_screen.hide_result()
	_hud.show_start()


## Puts one real Coin on the floor per remaining loot entry so the magnet can pick it up again.
func _spawn_harvest_coins() -> void:
	var bounds := Rect2(Vector2.ZERO, _size)
	for loot: Dictionary in _controller.loot:
		var coin := Coin.new()
		_view.add_child(coin)
		coin.setup(_slime_config, loot["kind"], 0.0, bounds, loot["pos"], Vector2.ZERO, 0.0)
		# The loot sits on the ring around the chest, not where Coin.advance's own physics and field
		# limits would put it, so those stay off; the final harvest decides when it disappears.
		coin.height = 0.0
		coin.set_process(false)
		coin.set_meta("loot_id", loot["id"])
		_field.coins.append(coin)


## Magnet sink: a harvest coin arrived at the chest.
func _on_harvest_coin_arrived(coin: Coin) -> void:
	_controller.pick_loot(int(coin.get_meta("loot_id")))
	_chest.bump = 1.0


func _free_ground_coins() -> void:
	for coin: Coin in _field.coins:
		coin.queue_free()
	_field.coins.clear()


## Once the harvest timer ran out the remaining loot is gone and the magnet takes nothing more.
func _update_harvest_coins() -> void:
	if _controller.phase == RunController.Phase.HARVEST and not _controller.magnet_allowed():
		_free_ground_coins()


func _update_chest() -> void:
	if _controller.phase == RunController.Phase.RUNNING:
		return
	var offset := Vector2.ZERO
	if _controller.chest_shaking():
		offset.x = ChestBurst.shake_offset(_run_config, _rng.randf())
	_chest.position = _controller.chest_position() + offset
	_chest.scale = Vector2.ONE * _controller.chest_scale()


func _update_world_shake(delta: float) -> void:
	var decay: float = pow(float(_run_config["ui"]["shake_decay_per_frame"]),
			delta * float(_slime_config["reference_fps"]))
	_open_shake = _open_shake * decay if _open_shake > SHAKE_EPSILON else 0.0
	var jitter := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _open_shake
	_world.position = _squad_shake + jitter


func _auto_drop(delta: float) -> void:
	if auto_drop_interval <= 0.0 or _controller.phase != RunController.Phase.RUNNING:
		return
	_auto_drop_timer -= delta
	if _auto_drop_timer <= 0.0:
		_auto_drop_timer = auto_drop_interval
		_squad.drop_hero(Vector2(
				_rng.randf_range(AUTO_DROP_MARGIN.x, _size.x - AUTO_DROP_MARGIN.x),
				_rng.randf_range(AUTO_DROP_MARGIN.y, _size.y - AUTO_DROP_MARGIN.y)))


func _hud_state() -> Dictionary:
	var tier: int = _chest.tier()
	var tiers: Array = _chest_config["tiers"]
	var ratio: float = 1.0
	if tier < tiers.size() - 1:
		var low: float = ChestTiers.threshold(_chest_config, tier, _run_scale)
		var high: float = ChestTiers.threshold(_chest_config, tier + 1, _run_scale)
		ratio = (_chest.value - low) / (high - low)
	var shown_tier: int = _controller.chest_tier if _controller.opened else tier
	return {
		"gold": _gold,
		"collected": roundi(_chest.value),
		"phase": _controller.phase,
		"time_ratio": _controller.time_ratio(),
		"time_left": _controller.remaining_time(),
		"low_time": _controller.is_time_low(),
		"tier_name": ChestTiers.tier_name(_chest_config, shown_tier),
		"tier_color": ChestTiers.tier_color(_chest_config, shown_tier),
		"tier_ratio": ratio,
		"opened": _controller.opened,
		"shown_gold": _controller.shown_gold,
		"multiplier": _controller.multiplier,
		"harvest_left": _controller.harvest_time_left(),
		"harvest_bonus": roundi(_controller.harvest_bonus()),
	}


## Plays a synthesised tone: `spec` has wave ("sawtooth" | "square"), duration (s) and volume.
func _play(player: AudioStreamPlayer, spec: Dictionary, frequency: float) -> void:
	player.stream = _make_tone(spec, frequency)
	player.play()


func _make_tone(spec: Dictionary, frequency: float) -> AudioStreamWAV:
	var rate: int = int(_run_config["ui"]["sound_mix_rate"])
	var count: int = maxi(1, int(float(rate) * float(spec["duration"])))
	var volume: float = spec["volume"]
	var saw: bool = spec["wave"] == "sawtooth"
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	for i: int in count:
		var progress: float = float(i) / float(count)
		var gain: float = volume * pow(SOUND_FLOOR / volume, progress)
		phase = fposmod(phase + frequency / float(rate), 1.0)
		var wave: float = phase * 2.0 - 1.0 if saw else (1.0 if phase < 0.5 else -1.0)
		data.encode_s16(i * 2, int(clampf(wave * gain, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _apply_user_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--run-seconds="):
			run_seconds_override = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--auto-drop="):
			auto_drop_interval = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--runs="):
			runs = arg.get_slice("=", 1).to_int()
		elif arg == "--autostart":
			autostart = true
