extends Node2D
## The whole game loop (production/epics/slime-nodaji/story-004-run-timer-burst.md and story-005-skill-tree-save.md):
## start button, the run (slime field, knights, magnet, chest), the burst (chest to the centre, opening,
## loot rain), the final harvest (the magnet picks the landed loot up again), the result screen, and the
## skill tree where the gold is spent. Wires RunController to the HUD, the result screen and the view,
## and the save file (SaveData) to the tree: gold, run count, best record and node levels are saved after
## every run and every purchase and restored on the next start.
##
## Dev options: the exports below, plus the command-line user args (after `--`):
##   --run-seconds=N   overrides the run length            --autostart   starts without the button
##   --auto-drop=N     drops a knight every N seconds
##   --force-events    all four run events fire early (rain 2 s, goblin 4 s, boss 6 s, golden slimes frequent),
##                     whatever the skill tree level (assets/data/run_events.json "force")

const RUN_CONFIG_PATH: String = "res://assets/data/run.json"
const SLIME_CONFIG_PATH: String = "res://assets/data/slime_field.json"
const HERO_CONFIG_PATH: String = "res://assets/data/hero_knight.json"
const TYPES_CONFIG_PATH: String = "res://assets/data/hero_types.json"
const CHEST_CONFIG_PATH: String = "res://assets/data/chest_tiers.json"
const TREE_CONFIG_PATH: String = "res://assets/data/skill_tree.json"
const EVENTS_CONFIG_PATH: String = "res://assets/data/run_events.json"
const HUD_SCENE: PackedScene = preload("res://src/ui/hud/hud.tscn")
const HOTBAR_SCENE: PackedScene = preload("res://src/ui/hotbar/hotbar.tscn")
const RESULT_SCENE: PackedScene = preload("res://src/ui/result/result_screen.tscn")
const TREE_SCENE: PackedScene = preload("res://src/ui/skill_tree/skill_tree_screen.tscn")
const GRASS_COLOR: Color = Color("#4f8a3c")
const AUTO_DROP_MARGIN: Vector2 = Vector2(20.0, 40.0)
## Amplitude floor of the synthesised tones' exponential decay (as Magnet.SOUND_FLOOR).
const SOUND_FLOOR: float = 0.0001
const SHAKE_EPSILON: float = 0.05

## Dev: when above 0, overrides the run length in seconds.
@export var run_seconds_override: float = 0.0
## Dev: drops a knight at a random point every this many seconds while above 0.
@export var auto_drop_interval: float = 0.0
## Dev: starts the first run without the start button.
@export var autostart: bool = false
## Dev: schedules every run event early, ignoring the skill tree (see --force-events).
@export var force_events: bool = false

var _run_config: Dictionary = {}
var _slime_config: Dictionary = {}
var _hero_config: Dictionary = {}
var _types_config: Dictionary = {}
var _chest_config: Dictionary = {}
var _tree_config: Dictionary = {}
var _events_config: Dictionary = {}
var _events: RunEvents
var _banner: EventBanner
var _save: SaveData
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _size: Vector2 = Vector2.ZERO
var _world: Node2D
var _field: SlimeField
var _squad: HeroSquad
var _chest: Chest
var _magnet: Magnet
var _view: RunView
var _controller: RunController
var _hud: RunHud
var _hotbar: Hotbar
var _result_screen: ResultScreen
var _tree_screen: SkillTreeScreen
var _sfx_player: AudioStreamPlayer
var _blip_player: AudioStreamPlayer
var _squad_shake: Vector2 = Vector2.ZERO
var _open_shake: float = 0.0
var _auto_drop_timer: float = 0.0
var _run_scale: float = 1.0


func _ready() -> void:
	_run_config = RunController.load_config(RUN_CONFIG_PATH)
	_slime_config = SlimeField.load_config(SLIME_CONFIG_PATH)
	_hero_config = HeroSquad.load_config(HERO_CONFIG_PATH)
	_types_config = HeroTypes.load_config(TYPES_CONFIG_PATH)
	_chest_config = ChestTiers.load_config(CHEST_CONFIG_PATH)
	_tree_config = SkillTree.load_config(TREE_CONFIG_PATH)
	_events_config = RunEvents.load_config(EVENTS_CONFIG_PATH)
	if _events_config.is_empty() or _run_config.is_empty() or _slime_config.is_empty() or _hero_config.is_empty() or _types_config.is_empty() \
			or _chest_config.is_empty() or _tree_config.is_empty():
		return
	_apply_user_args()
	_save = SaveData.load_file(_tree_config["save"]["path"], int(_tree_config["save"]["version"]))
	_rng.randomize()
	_size = get_viewport_rect().size
	var ui: Dictionary = _run_config["ui"]
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_hud.setup(ui, _size, ChestBurst.ring_top_y(_run_config, _size), ChestBurst.ring_bottom_y(_run_config, _size))
	_hud.start_pressed.connect(_on_start_pressed)
	_banner = EventBanner.new()
	add_child(_banner)
	_banner.setup(_events_config["banner"], _size)
	_result_screen = RESULT_SCENE.instantiate()
	add_child(_result_screen)
	_result_screen.setup(ui, _size)
	_result_screen.retry_pressed.connect(_start_run)
	_result_screen.skill_tree_pressed.connect(_open_tree)
	_tree_screen = TREE_SCENE.instantiate()
	add_child(_tree_screen)
	_tree_screen.setup(_tree_config, _size)
	_tree_screen.node_pressed.connect(_on_tree_node_pressed)
	_tree_screen.start_pressed.connect(_start_run)
	_tree_screen.reset_confirmed.connect(_on_reset_confirmed)
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
	_update_events()
	_update_chest()
	_update_harvest_coins()
	_auto_drop(delta)
	_hud.show_state(_hud_state())


## Starts a run with a fresh field, squad, chest, magnet and controller.
func _start_run() -> void:
	_hud.hide_start()
	_result_screen.hide_result()
	_tree_screen.hide_tree()
	_clear_run()
	var runs: int = _save.runs
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
	# Hero counts, arrows per volley and the run events come from PlayerStats, the one place that turns
	# levels into stats. Event times are decided once, here (story-007).
	var stats: Dictionary = PlayerStats.compute(_save.levels, _hero_config, _slime_config, _chest_config,
			_run_config, _tree_config)
	var duration: float = run_seconds_override if run_seconds_override > 0.0 			else RunController.run_duration(_run_config, _level("time"))
	_events = RunEvents.new()
	_events.start(_events_config, stats, duration, _rng)
	if force_events:
		_events.force_all(_events_config)
	_field.setup(_slime_config, _rng, _size, runs, _level("density"), _level("coin"), _events_config,
			_events.golden_chance)
	_field.hero_locator = _nearest_hero_position
	_squad.setup(_hero_config, _types_config, _slime_config, _field, _rng, _size, runs,
			{"land": _level("land"), "spd": _level("spd"), "dmg": _level("dmg")}, stats)
	_squad.shake_changed.connect(func(offset: Vector2) -> void: _squad_shake = offset)
	# Just below the result screen in the tree, so a result panel covers the (disabled) hotbar.
	_hotbar = HOTBAR_SCENE.instantiate()
	add_child(_hotbar)
	move_child(_hotbar, _result_screen.get_index())
	# The banner is a plain Control and the world's grass covers the screen: draw the banner after the world.
	move_child(_banner, get_child_count() - 1)
	_hotbar.setup(_types_config, _squad.roster, _size)
	_hotbar.type_requested.connect(func(type: String) -> void: _squad.roster.select(type))
	_view = RunView.new()
	_world.add_child(_view)
	_chest = Chest.new()
	_world.add_child(_chest)
	_chest.setup(_chest_config, _size, _run_scale, _level("chest"))
	_magnet = Magnet.new()
	_world.add_child(_magnet)
	_magnet.setup(_chest_config, _rng, _field.coins, _chest, _size, _level("magnet"))
	_controller = RunController.new()
	add_child(_controller)
	_controller.start(_run_config, _chest_config, _slime_config, _rng, _size, _chest.position, runs,
			{"time": _level("time"), "chest": _level("chest"), "coin": _level("coin")}, _magnet.flying_count)
	if run_seconds_override > 0.0:
		_controller.duration = run_seconds_override
	_view.setup(_run_config, _slime_config, _controller, _size)
	_field.slime_killed.connect(_on_slime_killed)
	_chest.deposited.connect(func(amount: float, _total: float) -> void: _controller.collected += amount)
	_controller.chest_opened.connect(_on_chest_opened)
	_controller.rain_blip.connect(_on_rain_blip)
	_controller.phase_changed.connect(_on_phase_changed)
	_controller.run_finished.connect(_on_run_finished)
	_auto_drop_timer = 0.0
	_open_shake = 0.0
	_squad_shake = Vector2.ZERO


func _on_slime_killed(slime: Slime) -> void:
	_controller.kills += 1
	if slime is BossPudding:
		_banner.show_text(_events_config["banner"]["text"]["boss_killed"])


## Fires the run events that became due (RUNNING only) - story-007.
func _update_events() -> void:
	if _controller.phase != RunController.Phase.RUNNING:
		return
	var text: Dictionary = _events_config["banner"]["text"]
	for id: String in _events.poll(_controller.duration - _controller.remaining_time()):
		_banner.show_text(text[id])
		match id:
			RunEvents.RAIN:
				var rain: Dictionary = _events_config["rain"]
				for i in int(rain["count"]):
					_field.spawn_slime(_rng.randf_range(rain["height_min"], rain["height_max"]))
			RunEvents.GOBLIN:
				_field.spawn_event("goblin")
			RunEvents.BOSS:
				var boss: Slime = _field.spawn_event("boss")
				boss.landed.connect(func(landed: Slime) -> void:
					_squad.impact_at(landed.position, float(_events_config["boss"]["landing_shake"])))


## The nearest landed hero to `from` (goblin flee target), or null when none is on the ground.
func _nearest_hero_position(from: Vector2) -> Variant:
	var best: Variant = null
	var best_distance: float = INF
	for child: Node in _field.get_children():
		var hero := child as Hero
		if hero != null and hero.state == Hero.State.GROUNDED and from.distance_to(hero.position) < best_distance:
			best_distance = from.distance_to(hero.position)
			best = hero.position
	return best


func _clear_run() -> void:
	for node: Node in [_world, _controller, _hotbar]:
		if node != null:
			node.queue_free()
	_world = null
	_controller = null
	_hotbar = null


func _on_phase_changed(phase: int) -> void:
	match phase:
		RunController.Phase.BURST:
			_squad.roster.disable()
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


## Applies the run's gold, run count and best record to the save (the result handler of the run) and
## writes it, then opens the result screen.
func _on_run_finished(result: RunResult) -> void:
	_save.gold += result.total_gold()
	_save.runs += 1
	_save.best = maxi(_save.best, result.total_gold())
	_persist()
	_result_screen.show_result(result)


## The start button of the first screen: the tree after the first run (as the prototype), else a run.
func _on_start_pressed() -> void:
	if _save.runs > 0:
		_hud.hide_start()
		_open_tree()
	else:
		_start_run()


func _open_tree() -> void:
	_clear_run()
	_result_screen.hide_result()
	_hud.hide_start()
	_tree_screen.show_tree(_tree_view())


func _on_tree_node_pressed(id: String) -> void:
	var node: Dictionary = SkillTree.find_node(_tree_config, id)
	var outcome: Dictionary = SkillTree.purchase(_tree_config, _save.levels, _save.gold, id)
	var texts: Dictionary = _tree_config["ui"]["text"]
	if outcome["ok"]:
		_save.gold = int(outcome["gold"])
		_save.levels = outcome["levels"] as Dictionary
		_persist()
		_tree_screen.show_tree(_tree_view())
		_tree_screen.show_message(texts["learned"] % [node["name"], SkillTree.level(_save.levels, id)])
	elif outcome["reason"] == SkillTree.REASON_GOLD:
		_tree_screen.show_message(texts["short"] % SkillTree.format_amount(int(outcome["shortfall"])))


func _on_reset_confirmed() -> void:
	_save = SaveData.new_game(int(_tree_config["save"]["version"]))
	_persist()
	_tree_screen.show_tree(_tree_view())


func _persist() -> void:
	_save.save_file(_tree_config["save"]["path"])


func _level(id: String) -> int:
	return SkillTree.level(_save.levels, id)


## What the tree screen shows: gold, best record, the next run's stats and every node's level and state.
func _tree_view() -> Dictionary:
	var nodes: Array[Dictionary] = []
	for node: Dictionary in _tree_config["nodes"]:
		var id: String = node["id"]
		nodes.append({"id": id, "level": _level(id),
				"state": SkillTree.node_state(_tree_config, _save.levels, _save.gold, id)})
	return {"gold": _save.gold, "best": _save.best, "nodes": nodes,
			"stats": PlayerStats.compute(_save.levels, _hero_config, _slime_config, _chest_config,
					_run_config, _tree_config)}


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
		"gold": _save.gold,
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
		elif arg == "--force-events":
			force_events = true
		elif arg == "--autostart":
			autostart = true
