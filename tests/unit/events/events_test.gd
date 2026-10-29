## Story: slime-nodaji story-007 (design/game-brief.md, Brief MVP feature 7).
## Covers the four run events: golden slime chance/hp/coins, slime rain scheduling, treasure goblin
## (timing, hit drop, kill coins, 9 s despawn, flee), boss pudding (timing, hp, landing, kill coins),
## "no events without the node" and the banner duration. Every expected value is read from
## assets/data/run_events.json, skill_tree.json and slime_field.json (no magic numbers, except range
## sanity checks); randomness is a seeded RandomNumberGenerator and time is stepped by hand.
extends GdUnitTestSuite

const EVENTS_PATH: String = "res://assets/data/run_events.json"
const SLIME_PATH: String = "res://assets/data/slime_field.json"
const HERO_PATH: String = "res://assets/data/hero_knight.json"
const CHEST_PATH: String = "res://assets/data/chest_tiers.json"
const RUN_PATH: String = "res://assets/data/run.json"
const TREE_PATH: String = "res://assets/data/skill_tree.json"
const FIELD_SIZE: Vector2 = Vector2(640.0, 360.0)
const DURATION: float = 40.0
const STEP: float = 0.05
const SEEDS: int = 300


func _events() -> Dictionary:
	return RunEvents.load_config(EVENTS_PATH)


func _slime_cfg() -> Dictionary:
	return SlimeField.load_config(SLIME_PATH)


func _tree() -> Dictionary:
	return SkillTree.load_config(TREE_PATH)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _stats(levels: Dictionary) -> Dictionary:
	return PlayerStats.compute(levels, HeroSquad.load_config(HERO_PATH), _slime_cfg(), ChestTiers.load_config(CHEST_PATH),
			RunController.load_config(RUN_PATH), _tree())


## A RunEvents for a run with the given node levels.
func _start(levels: Dictionary, seed_value: int = 1) -> RunEvents:
	var events := RunEvents.new()
	events.start(_events(), _stats(levels), DURATION, _rng(seed_value))
	return events


func _max_level(id: String) -> int:
	return int(SkillTree.find_node(_tree(), id)["max"])


## A field with the event data and the given golden chance; `runs` completed runs.
func _field(golden_chance: float = 0.0, runs: int = 0, seed_value: int = 7) -> SlimeField:
	var field: SlimeField = auto_free(SlimeField.new())
	field.setup(_slime_cfg(), _rng(seed_value), FIELD_SIZE, runs, 0, 0, _events(), golden_chance)
	return field


# --- golden slime ---------------------------------------------------------------------------

func test_golden_chance_is_base_plus_per_level_times_level() -> void:
	var stats: Dictionary = _tree()["stats"]
	for level in range(0, _max_level("golden") + 1):
		var events: RunEvents = _start({"golden": level})
		var expected: float = float(stats["golden_base"]) + float(stats["golden_per_level"]) * level
		assert_float(events.golden_chance).is_equal_approx(expected, 0.00001)


func test_golden_chance_is_the_base_chance_when_node_not_bought() -> void:
	var stats: Dictionary = _tree()["stats"]

	assert_float(_start({}).golden_chance).is_equal_approx(float(stats["golden_base"]), 0.00001)


func test_golden_hp_scales_with_run_count() -> void:
	var cfg: Dictionary = _events()
	var slime_cfg: Dictionary = _slime_cfg()
	for runs in [0, 3, 10]:
		var expected: float = float(cfg["golden"]["base_hp"]) * pow(float(slime_cfg["run_scale_base"]), runs)
		assert_float(RunEvents.hp(cfg, slime_cfg, "golden", runs)).is_equal_approx(expected, 0.0001)


func test_golden_field_spawns_golden_slimes_with_scaled_hp_when_chance_is_one() -> void:
	var field: SlimeField = _field(1.0, 4)
	for slime: Slime in field.slimes:
		assert_bool(slime is GoldenSlime).is_true()
		assert_float(slime.max_hp).is_equal_approx(RunEvents.hp(_events(), _slime_cfg(), "golden", 4), 0.0001)


func test_golden_field_spawns_no_golden_slime_when_chance_is_zero() -> void:
	var field: SlimeField = _field(0.0)
	for i in 50:
		field.spawn_slime()
	for slime: Slime in field.slimes:
		assert_bool(slime is GoldenSlime).is_false()


func test_golden_kill_drops_the_event_coin_count() -> void:
	var field: SlimeField = _field(1.0)
	var golden: Slime = field.slimes[0]

	golden.take_damage(golden.max_hp)

	assert_int(field.coins.size()).is_equal(RunEvents.kill_coins(_events(), "golden"))


func test_rich_coin_kind_follows_the_gem_and_silver_chances() -> void:
	var chance: Dictionary = _events()["rich_coin_kind_chance"]
	var gem: float = chance["gem"]
	var silver: float = chance["silver"]

	assert_str(SlimeField.pick_coin_kind(chance, gem - 0.0001)).is_equal("gem")
	assert_str(SlimeField.pick_coin_kind(chance, gem)).is_equal("silver")
	assert_str(SlimeField.pick_coin_kind(chance, gem + silver - 0.0001)).is_equal("silver")
	assert_str(SlimeField.pick_coin_kind(chance, gem + silver)).is_equal("copper")


# --- slime rain -----------------------------------------------------------------------------

func test_rain_is_never_scheduled_without_the_node() -> void:
	for seed_value in SEEDS:
		assert_float(_start({}, seed_value).rain_at).is_less(0.0)


func test_rain_frequency_matches_chance_per_level() -> void:
	var per_level: float = _tree()["stats"]["rain_per_level"]
	for level in range(1, _max_level("rain") + 1):
		var hits: int = 0
		for seed_value in 1000:
			if _start({"rain": level}, seed_value).rain_at >= 0.0:
				hits += 1
		assert_float(float(hits) / 1000.0).is_equal_approx(per_level * level, 0.06)


func test_rain_time_is_inside_the_window() -> void:
	var rain: Dictionary = _events()["rain"]
	var scheduled: int = 0
	for seed_value in SEEDS:
		var at: float = _start({"rain": _max_level("rain")}, seed_value).rain_at
		if at < 0.0:
			continue
		scheduled += 1
		assert_float(at).is_between(float(rain["window_start"]), DURATION - float(rain["window_end_margin"]))
	assert_int(scheduled).is_greater(0)


func test_rain_fires_once_at_its_time() -> void:
	var events: RunEvents = _start({"rain": _max_level("rain")}, 1)
	for seed_value in SEEDS:
		events = _start({"rain": _max_level("rain")}, seed_value)
		if events.rain_at >= 0.0:
			break
	var at: float = events.rain_at

	assert_array(events.poll(at - 0.01)).is_empty()
	assert_array(events.poll(at)).contains_exactly([RunEvents.RAIN])
	assert_array(events.poll(at + 1.0)).is_empty()


func test_rain_slime_falls_from_given_height_and_lands() -> void:
	var rain: Dictionary = _events()["rain"]
	var field: SlimeField = _field()
	var height: float = rain["height_max"]
	var slime: Slime = field.spawn_slime(height)
	var landed: Array[bool] = [false]
	slime.landed.connect(func(_s: Slime) -> void: landed[0] = true)

	assert_bool(slime.is_airborne()).is_true()
	assert_float(slime.height).is_equal(height)
	for i in 400:
		slime.advance(STEP)

	assert_bool(slime.is_airborne()).is_false()
	assert_bool(landed[0]).is_true()


func test_rain_data_has_a_valid_height_range_and_count() -> void:
	var rain: Dictionary = _events()["rain"]
	assert_float(float(rain["height_min"])).is_less(float(rain["height_max"]))
	assert_int(int(rain["count"])).is_greater(0)


func test_airborne_slime_is_not_a_target() -> void:
	var field: SlimeField = _field()
	var slime: Slime = field.spawn_slime(_events()["rain"]["height_min"])
	var only: Array[Slime] = [slime]

	assert_object(Hero.nearest_slime(only, slime.position)).is_null()
	slime.height = 0.0
	assert_object(Hero.nearest_slime(only, slime.position)).is_same(slime)


# --- treasure goblin ------------------------------------------------------------------------

func test_goblin_is_never_scheduled_without_the_node() -> void:
	for seed_value in SEEDS:
		assert_float(_start({}, seed_value).goblin_at).is_less(0.0)


func test_goblin_time_is_inside_the_window_when_node_bought() -> void:
	var goblin: Dictionary = _events()["goblin"]
	for seed_value in SEEDS:
		var at: float = _start({"goblin": 1}, seed_value).goblin_at
		assert_float(at).is_between(float(goblin["window_start"]), DURATION * float(goblin["window_end_ratio"]))


func test_goblin_hp_scales_with_run_count() -> void:
	var slime_cfg: Dictionary = _slime_cfg()
	var expected: float = float(_events()["goblin"]["base_hp"]) * pow(float(slime_cfg["run_scale_base"]), 5)
	assert_float(RunEvents.hp(_events(), slime_cfg, "goblin", 5)).is_equal_approx(expected, 0.0001)


func test_goblin_hit_drop_follows_the_chance_boundary() -> void:
	var cfg: Dictionary = _events()
	var chance: float = cfg["goblin"]["hit_drop_chance"]

	assert_bool(RunEvents.goblin_hit_drops(cfg, chance - 0.0001)).is_true()
	assert_bool(RunEvents.goblin_hit_drops(cfg, chance)).is_false()


func test_goblin_hits_drop_coins_at_about_the_hit_drop_chance() -> void:
	var field: SlimeField = _field(0.0, 0, 11)
	var goblin: Slime = field.spawn_event("goblin")
	var hits: int = 500

	for i in hits:
		goblin.take_damage(0.0001)

	var expected: float = float(_events()["goblin"]["hit_drop_chance"]) * float(_events()["goblin"]["hit_drop_coins"])
	assert_float(float(field.coins.size()) / float(hits)).is_equal_approx(expected, 0.08)


func test_goblin_kill_drops_the_event_coin_count() -> void:
	var field: SlimeField = _field(0.0, 0, 11)
	var goblin: Slime = field.spawn_event("goblin")
	goblin.hp = 0.0001
	var before: int = field.coins.size()

	goblin.take_damage(1.0)

	# The killing hit may also drop its hit coin first (as the prototype), so kill coins + 0..hit coins.
	var dropped: int = field.coins.size() - before
	var kill: int = RunEvents.kill_coins(_events(), "goblin")
	assert_int(dropped).is_between(kill, kill + int(_events()["goblin"]["hit_drop_coins"]))


func test_goblin_despawn_happens_at_its_life() -> void:
	var cfg: Dictionary = _events()
	var life: float = cfg["goblin"]["life"]

	assert_bool(RunEvents.goblin_expired(cfg, life - 0.01)).is_false()
	assert_bool(RunEvents.goblin_expired(cfg, life)).is_true()


func test_goblin_stays_before_its_life_and_leaves_without_drops_after() -> void:
	var field: SlimeField = _field(0.0, 0, 11)
	var goblin: Slime = field.spawn_event("goblin")
	var escaped: Array[bool] = [false]
	(goblin as TreasureGoblin).escaped.connect(func(_g: TreasureGoblin) -> void: escaped[0] = true)
	var life: float = _events()["goblin"]["life"]
	var elapsed: float = 0.0

	while elapsed < life - STEP:
		goblin.advance(STEP)
		elapsed += STEP
	assert_bool(escaped[0]).is_false()
	assert_bool(field.slimes.has(goblin)).is_true()

	while elapsed < 120.0 and not escaped[0]:
		goblin.advance(STEP)
		elapsed += STEP
	assert_bool(escaped[0]).is_true()
	assert_bool(field.slimes.has(goblin)).is_false()


func test_goblin_flees_away_from_the_nearest_hero() -> void:
	var field: SlimeField = _field(0.0, 0, 11)
	var goblin: Slime = field.spawn_event("goblin")
	var start: Vector2 = goblin.position
	var hero: Vector2 = start - Vector2(30.0, 0.0)
	field.hero_locator = func(_from: Vector2) -> Variant: return hero
	(goblin as TreasureGoblin).apply_event(_events(), field.hero_locator)

	for i in 10:
		goblin.advance(STEP)

	assert_float(goblin.position.x - start.x).is_greater(0.0)


# --- boss pudding ---------------------------------------------------------------------------

func test_boss_is_never_scheduled_without_the_node() -> void:
	assert_float(_start({}).boss_at).is_less(0.0)


func test_boss_time_is_the_fixed_share_of_the_run() -> void:
	assert_float(_start({"boss": 1}).boss_at).is_equal_approx(DURATION * float(_events()["boss"]["time_ratio"]), 0.0001)


func test_boss_spawns_in_the_field_centre_falling_with_scaled_hp_and_radius() -> void:
	var boss_cfg: Dictionary = _events()["boss"]
	var field: SlimeField = _field(0.0, 6)

	var boss: Slime = field.spawn_event("boss")

	assert_bool(boss is BossPudding).is_true()
	assert_float(boss.radius).is_equal(float(boss_cfg["radius"]))
	assert_float(boss.max_hp).is_equal_approx(RunEvents.hp(_events(), _slime_cfg(), "boss", 6), 0.0001)
	assert_float(boss.height).is_equal(float(boss_cfg["drop_height"]))
	assert_float(boss.position.x).is_equal_approx(FIELD_SIZE.x / 2.0, 0.001)
	assert_bool(boss.counts_toward_cap).is_false()


func test_boss_emits_landed_once_its_fall_is_over() -> void:
	var field: SlimeField = _field()
	var boss: Slime = field.spawn_event("boss")
	var landings: Array[int] = [0]
	boss.landed.connect(func(_s: Slime) -> void: landings[0] += 1)

	for i in 400:
		boss.advance(STEP)

	assert_int(landings[0]).is_equal(1)
	assert_float(_events()["boss"]["landing_shake"]).is_greater(0.0)


func test_boss_kill_drops_the_event_coin_count() -> void:
	var field: SlimeField = _field()
	var boss: Slime = field.spawn_event("boss")

	boss.take_damage(boss.max_hp)

	assert_int(field.coins.size()).is_equal(RunEvents.kill_coins(_events(), "boss"))


func test_boss_and_goblin_do_not_take_normal_population_slots() -> void:
	var field: SlimeField = _field()
	var before: int = field.slimes.size()
	field.spawn_event("boss")
	field.spawn_event("goblin")
	var counted: int = 0
	for slime: Slime in field.slimes:
		if slime.counts_toward_cap:
			counted += 1

	assert_int(counted).is_equal(before)


# --- no node, no events ---------------------------------------------------------------------

func test_no_timed_events_when_no_node_was_bought() -> void:
	for seed_value in SEEDS:
		var events: RunEvents = _start({}, seed_value)
		assert_array(events.poll(DURATION)).is_empty()


func test_all_events_are_scheduled_when_every_node_was_bought() -> void:
	var levels: Dictionary = {"golden": 1, "rain": _max_level("rain"), "goblin": 1, "boss": 1}
	var seen: Dictionary = {}
	for seed_value in SEEDS:
		for id: String in _start(levels, seed_value).poll(DURATION):
			seen[id] = true

	assert_bool(seen.has(RunEvents.RAIN)).is_true()
	assert_bool(seen.has(RunEvents.GOBLIN)).is_true()
	assert_bool(seen.has(RunEvents.BOSS)).is_true()


# --- banner ---------------------------------------------------------------------------------

func test_banner_duration_is_about_one_second() -> void:
	assert_float(float(_events()["banner"]["duration"])).is_between(0.8, 1.2)


func test_banner_shows_for_its_duration_then_hides() -> void:
	var banner_cfg: Dictionary = _events()["banner"]
	var banner: EventBanner = auto_free(EventBanner.new())
	banner.setup(banner_cfg, FIELD_SIZE)
	var duration: float = banner_cfg["duration"]

	banner.show_text(banner_cfg["text"]["rain"])
	assert_bool(banner.visible).is_true()
	banner._process(duration - 0.01)
	assert_bool(banner.visible).is_true()
	banner._process(0.02)
	assert_bool(banner.visible).is_false()


func test_banner_texts_exist_for_every_event() -> void:
	var text: Dictionary = _events()["banner"]["text"]
	for id: String in [RunEvents.RAIN, RunEvents.GOBLIN, RunEvents.BOSS, "boss_killed"]:
		assert_bool(text.has(id) and not String(text[id]).is_empty()).is_true()
