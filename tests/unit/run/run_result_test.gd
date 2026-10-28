## Story: slime-nodaji story-004 (design/game-brief.md, Brief MVP feature 4), Part A (logic and data).
## Covers ChestBurst (base gold, loot count, kind roll, burst transform, loot physics), FinalHarvest
## (bonus per kind, no tier multiplier), RunController (run length, low-time flag, phase order,
## RunResult contents, unpicked loot removal) and Magnet.set_target. Expected numbers come from the
## prototype slime-nodaji.html (beginBurst, updateBurst, finishRun, stats().time) and the story text.
extends GdUnitTestSuite

const FIELD_SIZE: Vector2 = Vector2(640.0, 360.0)
const CHEST_START: Vector2 = Vector2(320.0, 345.0)
const RUNS_TEN: int = 10
const STEP: float = 0.25
const MAX_STEPS: int = 400


## Fixture factory: the same keys and values as assets/data/run.json, inline so the suite does no file I/O.
func _run_config() -> Dictionary:
	return {
		"run": {"map_id": "meadow", "base_time": 24.0, "time_per_level": 4.0, "low_time_threshold": 5.0},
		"burst": {
			"move_time": 1.1, "open_time": 1.3, "scale_gain": 1.6, "dim_alpha_max": 0.45,
			"center_offset_y": 10.0, "shake_start": 0.9, "shake_amplitude": 2.0, "open_shake": 7.0,
			"count_up_time": 1.6, "count_up_min_rate": 60.0,
			"open_sound": {"wave": "sawtooth", "frequency": 220.0, "duration": 0.3, "volume": 0.06},
		},
		"rain": {
			"count_base": 40.0, "count_per_sqrt_total": 4.0, "count_max": 180.0,
			"kind_chance": {"gem": 0.1, "silver": 0.27},
			"gravity": 550.0, "spin_rate": 10.0, "spin_start_max": 6.0,
			"blip": {"wave": "square", "chance": 0.4, "frequency_min": 700.0, "frequency_max": 1400.0,
				"duration": 0.04, "volume": 0.015},
		},
		"ring": {"inner_radius": 48.0, "width": 24.0, "gem_band": 0.4, "spread_speed": 140.0},
		"harvest": {"duration": 5.0, "start_max_wait": 2.5},
	}


## Same keys and values as assets/data/chest_tiers.json (the sections the run reads and Magnet/Chest use).
func _chest_config() -> Dictionary:
	return {
		"chest_bonus_per_level": 0.1,
		"tiers": [
			{"name": "나무 상자", "threshold": 0.0, "multiplier": 1.0, "color": "#9b6b43"},
			{"name": "구리 상자", "threshold": 40.0, "multiplier": 1.25, "color": "#d0844f"},
			{"name": "은 상자", "threshold": 140.0, "multiplier": 1.5, "color": "#d5dce4"},
			{"name": "금 상자", "threshold": 400.0, "multiplier": 2.0, "color": "#f2c14e"},
			{"name": "수정 상자", "threshold": 1100.0, "multiplier": 3.0, "color": "#8fe3ff"},
		],
		"chest": {"bottom_offset": 15.0, "bump_decay": 5.0, "bump_scale": 0.2, "bump_lift": 5.0},
		"magnet": {
			"base_radius": 24.0, "radius_per_level": 5.0, "fly_speed": 2.4,
			"control_x_range": 30.0, "control_rise_min": 30.0, "control_rise_max": 70.0,
			"arrival_height": 10.0, "flight_spin_rate": 20.0, "flight_z_index": 1.0,
			"ring_color": "#f2c14e", "ring_alpha": 0.55, "ring_width": 2.0,
		},
		"sound": {
			"mix_rate": 22050.0, "duration": 0.05, "volume": 0.025, "pitch_rise": 1.5,
			"throttle_ms": 45.0, "pitch": {"copper": 760.0, "silver": 990.0, "gem": 1320.0},
		},
	}


## The slice of assets/data/slime_field.json that coin values and Coin.setup read.
func _slime_config() -> Dictionary:
	return {
		"reference_fps": 60.0,
		"run_scale_base": 1.07,
		"coin": {
			"base_value": {"copper": 1.0, "silver": 4.0, "gem": 15.0},
			"value_bonus_per_coin_level": 0.3,
			"colors": {
				"copper": ["#f2c14e", "#b9862a"],
				"silver": ["#e6ecf2", "#8e99a6"],
				"gem": ["#8fe3ff", "#3b8fb3"],
			},
			"start_height": 2.0, "life": 9.0,
		},
	}


func _new_controller(levels: Dictionary = {}, runs: int = 0, pending_flights: Callable = Callable()) -> RunController:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var all_levels: Dictionary = {"time": 0, "chest": 0, "coin": 0}
	all_levels.merge(levels, true)
	var controller: RunController = auto_free(RunController.new())
	controller.start(_run_config(), _chest_config(), _slime_config(), rng, FIELD_SIZE, CHEST_START, runs,
			all_levels, pending_flights)
	return controller


## Advances in STEP ticks until `target` is reached; the step cap keeps a broken flow from hanging.
func _advance_to(controller: RunController, target: RunController.Phase) -> void:
	var steps: int = 0
	while controller.phase != target and steps < MAX_STEPS:
		controller.advance(STEP)
		steps += 1


func _new_chest() -> Chest:
	var chest: Chest = auto_free(Chest.new())
	chest.setup(_chest_config(), FIELD_SIZE, 1.0, 0)
	return chest


func _new_coin(kind: String, value: float, position: Vector2) -> Coin:
	var coin: Coin = auto_free(Coin.new())
	coin.setup(_slime_config(), kind, value, Rect2(Vector2.ZERO, FIELD_SIZE), position, Vector2.ZERO, 0.0)
	return coin


func _new_magnet(coins: Array[Coin], chest: Chest) -> Magnet:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var magnet: Magnet = auto_free(Magnet.new())
	magnet.setup(_chest_config(), rng, coins, chest, FIELD_SIZE, 0)
	return magnet


# --- Base gold ---------------------------------------------------------------------------------

func test_base_gold_per_tier_is_value_times_the_base_multiplier() -> void:
	# Arrange — one value inside each tier at run scale 1: 10 -> x1, 100 -> x1.25, 200 -> x1.5, 500 -> x2, 2000 -> x3
	var config: Dictionary = _chest_config()
	var values: Array[float] = [10.0, 100.0, 200.0, 500.0, 2000.0]
	var expected: Array[int] = [10, 125, 300, 1000, 6000]

	# Act / Assert
	for tier: int in values.size():
		assert_int(ChestBurst.base_gold(config, values[tier], 1.0, 0)).is_equal(expected[tier])


func test_base_gold_half_rounds_away_from_zero() -> void:
	# Arrange — 42 * 1.25 = 52.5 and 141 * 1.5 = 211.5, both exact in binary
	var config: Dictionary = _chest_config()

	# Act
	var copper: int = ChestBurst.base_gold(config, 42.0, 1.0, 0)
	var silver: int = ChestBurst.base_gold(config, 141.0, 1.0, 0)

	# Assert — Math.round(52.5) = 53, Math.round(211.5) = 212
	assert_int(copper).is_equal(53)
	assert_int(silver).is_equal(212)


func test_base_gold_with_chest_level_uses_the_boosted_multiplier() -> void:
	# Arrange — silver at chest level 2: 1.5 + 0.1 * 2 * 2 = 1.9; crystal at level 3: 3 + 0.1 * 3 * 4 = 4.2
	var config: Dictionary = _chest_config()

	# Act
	var silver: int = ChestBurst.base_gold(config, 200.0, 1.0, 2)
	var crystal: int = ChestBurst.base_gold(config, 2000.0, 1.0, 3)

	# Assert
	assert_int(silver).is_equal(380)
	assert_int(crystal).is_equal(8400)


func test_base_gold_tier_follows_the_run_scale() -> void:
	# Arrange — after 10 runs the copper threshold is 40 * 1.07 ^ 10 (about 78.7), so 40 is still wooden (x1)
	var config: Dictionary = _chest_config()
	var scale: float = SlimeField.run_scale(_slime_config(), RUNS_TEN)

	# Act
	var result: int = ChestBurst.base_gold(config, 40.0, scale, 0)

	# Assert
	assert_int(result).is_equal(40)


# --- Loot count ----------------------------------------------------------------------------------

func test_drop_count_of_zero_gold_is_the_base_count() -> void:
	# Arrange / Act
	var result: int = ChestBurst.drop_count(_run_config(), 0)

	# Assert
	assert_int(result).is_equal(40)


func test_drop_count_floors_forty_plus_sqrt_total_times_four() -> void:
	# Arrange / Act / Assert — 100 -> 40 + 40 = 80; 2 -> floor(40 + 5.657) = 45
	var config: Dictionary = _run_config()
	assert_int(ChestBurst.drop_count(config, 100)).is_equal(80)
	assert_int(ChestBurst.drop_count(config, 2)).is_equal(45)


func test_drop_count_reaches_the_cap_at_1225_and_never_exceeds_it() -> void:
	# Arrange — 40 + sqrt(1225) * 4 = 180 exactly; 1224 floors to 179
	var config: Dictionary = _run_config()

	# Act / Assert
	assert_int(ChestBurst.drop_count(config, 1224)).is_equal(179)
	assert_int(ChestBurst.drop_count(config, 1225)).is_equal(180)
	assert_int(ChestBurst.drop_count(config, 100000)).is_equal(180)


# --- Loot kind roll --------------------------------------------------------------------------------

func test_roll_kind_boundaries_split_gem_silver_copper() -> void:
	# Arrange
	var config: Dictionary = _run_config()

	# Act / Assert — gem below 0.10, silver from 0.10 below 0.37, copper from 0.37
	assert_str(ChestBurst.roll_kind(config, 0.0)).is_equal("gem")
	assert_str(ChestBurst.roll_kind(config, 0.0999)).is_equal("gem")
	assert_str(ChestBurst.roll_kind(config, 0.1)).is_equal("silver")
	assert_str(ChestBurst.roll_kind(config, 0.3699)).is_equal("silver")
	assert_str(ChestBurst.roll_kind(config, 0.37)).is_equal("copper")
	assert_str(ChestBurst.roll_kind(config, 0.999)).is_equal("copper")


func test_roll_kind_boundaries_built_from_the_config_values_hold_despite_float_rounding() -> void:
	# Arrange — 0.10 + 0.27 need not equal the literal 0.37 in floating point, so build the edge from the config
	var config: Dictionary = _run_config()
	var chance: Dictionary = config["rain"]["kind_chance"]
	var gem: float = chance["gem"]
	var edge: float = gem + float(chance["silver"])

	# Act / Assert
	assert_str(ChestBurst.roll_kind(config, gem - 0.0001)).is_equal("gem")
	assert_str(ChestBurst.roll_kind(config, gem)).is_equal("silver")
	assert_str(ChestBurst.roll_kind(config, edge - 0.0001)).is_equal("silver")
	assert_str(ChestBurst.roll_kind(config, edge)).is_equal("copper")


func test_roll_kind_over_a_hundred_evenly_spaced_rolls_is_ten_twentyseven_sixtythree() -> void:
	# Arrange
	var config: Dictionary = _run_config()
	var counts: Dictionary = {"gem": 0, "silver": 0, "copper": 0}

	# Act — rolls 0.00, 0.01 ... 0.99
	for i: int in 100:
		counts[ChestBurst.roll_kind(config, float(i) / 100.0)] += 1

	# Assert
	assert_int(counts["gem"]).is_equal(10)
	assert_int(counts["silver"]).is_equal(27)
	assert_int(counts["copper"]).is_equal(63)


# --- Burst transform, shake, count-up, loot physics ------------------------------------------------

func test_ease_is_ease_out_cubic_of_the_clamped_progress() -> void:
	# Arrange
	var config: Dictionary = _run_config()

	# Act / Assert — k = 0.5 at t = 0.55 gives 1 - 0.5 ^ 3 = 0.875; clamped to 0 below 0 and to 1 past move_time
	assert_float(ChestBurst.ease_out(config, 0.0)).is_equal(0.0)
	assert_float(ChestBurst.ease_out(config, 0.55)).is_equal_approx(0.875, 0.0001)
	assert_float(ChestBurst.ease_out(config, 1.1)).is_equal_approx(1.0, 0.0001)
	assert_float(ChestBurst.ease_out(config, 5.0)).is_equal(1.0)
	assert_float(ChestBurst.ease_out(config, -1.0)).is_equal(0.0)


func test_chest_transform_moves_to_the_centre_and_grows_by_the_scale_gain() -> void:
	# Arrange
	var config: Dictionary = _run_config()

	# Act
	var at_start: Vector2 = ChestBurst.chest_position(config, CHEST_START, FIELD_SIZE, 0.0)
	var at_end: Vector2 = ChestBurst.chest_position(config, CHEST_START, FIELD_SIZE, 1.1)

	# Assert — target (W/2, H/2 + 10) = (320, 190); scale 1 -> 1 + 1.6
	assert_vector(at_start).is_equal(CHEST_START)
	assert_vector(at_end).is_equal_approx(Vector2(320.0, 190.0), Vector2(0.001, 0.001))
	assert_float(ChestBurst.chest_scale(config, 0.0)).is_equal(1.0)
	assert_float(ChestBurst.chest_scale(config, 1.1)).is_equal_approx(2.6, 0.0001)
	assert_float(ChestBurst.dim_alpha(config, 0.55)).is_equal_approx(0.45 * 0.875, 0.0001)


func test_chest_shakes_only_after_shake_start_and_until_it_is_opened() -> void:
	# Arrange
	var config: Dictionary = _run_config()

	# Act / Assert — strictly after 0.9 s, not once opened
	assert_bool(ChestBurst.is_shaking(config, 0.9, false)).is_false()
	assert_bool(ChestBurst.is_shaking(config, 0.91, false)).is_true()
	assert_bool(ChestBurst.is_shaking(config, 1.2, true)).is_false()
	assert_float(ChestBurst.shake_offset(config, 0.0)).is_equal(-2.0)
	assert_float(ChestBurst.shake_offset(config, 0.5)).is_equal(0.0)


func test_chest_opens_at_exactly_open_time() -> void:
	# Arrange
	var config: Dictionary = _run_config()

	# Act / Assert
	assert_bool(ChestBurst.is_open_time(config, 1.29)).is_false()
	assert_bool(ChestBurst.is_open_time(config, 1.3)).is_true()


func test_shown_gold_step_adds_the_rate_and_the_minimum_and_caps_at_the_total() -> void:
	# Arrange — at 60 fps the step is total / 96 + 1, the prototype's per-frame formula
	var config: Dictionary = _run_config()
	var delta: float = 1.0 / 60.0

	# Act
	var first: float = ChestBurst.shown_gold_step(config, 0.0, 150, delta)
	var capped: float = ChestBurst.shown_gold_step(config, 149.9, 150, delta)

	# Assert
	assert_float(first).is_equal_approx(150.0 / 1.6 / 60.0 + 1.0, 0.0001)
	assert_float(capped).is_equal(150.0)


func test_tally_drops_counts_per_kind_in_gem_silver_copper_order_and_skips_zero() -> void:
	# Arrange
	var loot: Array[Dictionary] = []
	for kind: String in ["copper", "gem", "copper", "copper"]:
		loot.append(ChestBurst.make_ring_loot(_run_config(), FIELD_SIZE, loot.size(), kind, 0.0, 0.5, 0.0))

	# Act
	var drops: Array = ChestBurst.tally_drops(loot)

	# Assert
	assert_array(drops).contains_exactly([{"kind": "gem", "count": 1}, {"kind": "copper", "count": 3}])


# --- Final harvest bonus -----------------------------------------------------------------------------

func test_harvest_bonus_per_kind_at_run_zero_and_coin_level_zero_is_one_four_fifteen() -> void:
	# Arrange
	var config: Dictionary = _slime_config()

	# Act / Assert
	assert_float(FinalHarvest.bonus_for(config, "copper", 0, 0)).is_equal_approx(1.0, 0.0001)
	assert_float(FinalHarvest.bonus_for(config, "silver", 0, 0)).is_equal_approx(4.0, 0.0001)
	assert_float(FinalHarvest.bonus_for(config, "gem", 0, 0)).is_equal_approx(15.0, 0.0001)


func test_harvest_bonus_scales_with_runs_and_coin_level() -> void:
	# Arrange
	var config: Dictionary = _slime_config()

	# Act / Assert — base * 1.07 ^ runs * (1 + 0.3 * coin level)
	assert_float(FinalHarvest.bonus_for(config, "gem", RUNS_TEN, 0)).is_equal_approx(15.0 * pow(1.07, 10.0), 0.0001)
	assert_float(FinalHarvest.bonus_for(config, "silver", 0, 3)).is_equal_approx(4.0 * 1.9, 0.0001)
	assert_float(FinalHarvest.bonus_for(config, "gem", RUNS_TEN, 3)).is_equal_approx(15.0 * pow(1.07, 10.0) * 1.9, 0.0001)


func test_harvest_pick_ignores_the_chest_tier_multiplier() -> void:
	# Arrange — a crystal chest (x3) must not change the bonus: the formula has no chest input at all
	var harvest := FinalHarvest.new(_run_config(), _slime_config(), 0, 0)

	# Act
	var amount: float = harvest.pick("gem")

	# Assert
	assert_float(amount).is_equal_approx(15.0, 0.0001)


func test_harvest_accumulates_several_picked_coins() -> void:
	# Arrange — runs 10, coin level 3: (1 + 4 + 15 + 1) * 1.07 ^ 10 * 1.9
	var harvest := FinalHarvest.new(_run_config(), _slime_config(), RUNS_TEN, 3)
	var expected: float = 21.0 * pow(1.07, 10.0) * 1.9

	# Act
	for kind: String in ["copper", "silver", "gem", "copper"]:
		harvest.pick(kind)

	# Assert
	assert_float(harvest.bonus).is_equal_approx(expected, 0.0001)
	assert_array(harvest.picked).contains_exactly(["copper", "silver", "gem", "copper"])
	assert_int(harvest.rounded_bonus()).is_equal(roundi(expected))


func test_harvest_timer_counts_down_to_zero_and_finishes() -> void:
	# Arrange
	var harvest := FinalHarvest.new(_run_config(), _slime_config(), 0, 0)

	# Act
	harvest.advance(4.0)
	var before_end: bool = harvest.is_finished()
	harvest.advance(2.0)

	# Assert
	assert_bool(before_end).is_false()
	assert_float(harvest.time_left).is_equal(0.0)
	assert_bool(harvest.is_finished()).is_true()


# --- Run length and low-time flag -----------------------------------------------------------------------

func test_run_duration_is_24_plus_4_per_time_level() -> void:
	# Arrange
	var config: Dictionary = _run_config()

	# Act / Assert
	assert_float(RunController.run_duration(config, 0)).is_equal(24.0)
	assert_float(RunController.run_duration(config, 1)).is_equal(28.0)
	assert_float(RunController.run_duration(config, 5)).is_equal(44.0)


func test_low_time_flag_is_set_below_five_seconds_and_not_at_five() -> void:
	# Arrange
	var config: Dictionary = _run_config()

	# Act / Assert
	assert_bool(RunController.is_low_time(config, 4.99)).is_true()
	assert_bool(RunController.is_low_time(config, 5.0)).is_false()
	assert_bool(RunController.is_low_time(config, 5.01)).is_false()


func test_controller_remaining_time_counts_down_and_flags_low_time_at_the_threshold() -> void:
	# Arrange — time level 2: 32 s
	var controller: RunController = _new_controller({"time": 2})

	# Act
	var at_start: float = controller.remaining_time()
	controller.advance(27.0)
	var low_at_five: bool = controller.is_time_low()
	var remaining_at_five: float = controller.remaining_time()
	controller.advance(0.5)

	# Assert
	assert_float(at_start).is_equal(32.0)
	assert_float(remaining_at_five).is_equal(5.0)
	assert_bool(low_at_five).is_false()
	assert_bool(controller.is_time_low()).is_true()
	assert_float(controller.time_ratio()).is_equal_approx(4.5 / 32.0, 0.0001)


# --- Phase flow --------------------------------------------------------------------------------------------

func test_phases_run_in_order_running_burst_harvest_result() -> void:
	# Arrange
	var controller: RunController = _new_controller()
	var phases: Array[int] = []
	controller.phase_changed.connect(func(p: int) -> void: phases.append(p))

	# Act
	_advance_to(controller, RunController.Phase.RESULT)

	# Assert
	assert_int(controller.phase).is_equal(RunController.Phase.RESULT)
	assert_array(phases).contains_exactly([RunController.Phase.BURST, RunController.Phase.HARVEST,
			RunController.Phase.RESULT])


func test_run_finished_is_emitted_exactly_once() -> void:
	# Arrange
	var controller: RunController = _new_controller()
	var results: Array[RunResult] = []
	controller.run_finished.connect(func(r: RunResult) -> void: results.append(r))

	# Act — keep advancing long after the result
	_advance_to(controller, RunController.Phase.RESULT)
	for i: int in 40:
		controller.advance(STEP)

	# Assert
	assert_int(results.size()).is_equal(1)
	assert_object(results[0]).is_same(controller.result)


func test_hero_drops_and_magnet_stop_when_the_burst_starts() -> void:
	# Arrange
	var controller: RunController = _new_controller()
	var before: bool = controller.hero_drop_allowed() and controller.magnet_allowed()

	# Act
	_advance_to(controller, RunController.Phase.BURST)

	# Assert
	assert_bool(before).is_true()
	assert_bool(controller.hero_drop_allowed()).is_false()
	assert_bool(controller.magnet_allowed()).is_false()


func test_chest_opens_once_at_open_time_and_loot_rains() -> void:
	# Arrange
	var controller: RunController = _new_controller()
	var opened: Array[int] = []
	controller.chest_opened.connect(func() -> void: opened.append(1))
	_advance_to(controller, RunController.Phase.BURST)

	# Act — burst time 1.0 s: still closed; 1.5 s: open
	controller.advance(0.5)
	controller.advance(0.5)
	var closed_at_one: bool = not controller.opened and controller.loot.is_empty()
	controller.advance(0.5)

	# Assert — total 0 gold rains the base count of 40
	assert_bool(closed_at_one).is_true()
	assert_bool(controller.opened).is_true()
	assert_int(opened.size()).is_equal(1)
	assert_int(controller.loot.size()).is_equal(40)


func test_chest_total_is_frozen_at_the_open_moment_not_at_the_burst_start() -> void:
	# Arrange — 100 collected when time runs out, a flying coin lands during the move: 200 at opening
	var controller: RunController = _new_controller({"chest": 2})
	controller.collected = 100.0
	_advance_to(controller, RunController.Phase.BURST)
	controller.collected = 200.0
	controller.advance(1.5)
	var frozen: int = controller.base_gold
	controller.collected = 5000.0
	controller.advance(STEP)

	# Assert — silver at chest level 2: round(200 * 1.9); later deposits do not change it
	assert_int(frozen).is_equal(380)
	assert_int(controller.base_gold).is_equal(380)
	assert_int(controller.chest_tier).is_equal(2)


func test_loot_coins_are_frozen_on_the_ring_when_the_harvest_starts() -> void:
	# Arrange — chest centre (320, 190); ring radii 48..72, gems only in 62.4..72
	var controller: RunController = _new_controller()
	var centre := Vector2(320.0, 190.0)

	# Act
	_advance_to(controller, RunController.Phase.HARVEST)

	# Assert
	assert_int(controller.loot.size()).is_equal(40)
	for coin: Dictionary in controller.loot:
		var radius: float = Vector2(coin["pos"]).distance_to(centre)
		assert_vector(coin["pos"]).is_equal_approx(coin["target"], Vector2(0.001, 0.001))
		assert_float(float(coin["height"])).is_equal(0.0)
		assert_float(radius).is_between(47.999, 72.001)
		if coin["kind"] == "gem":
			assert_float(radius).is_between(62.399, 72.001)


func test_ring_radius_spans_the_ring_and_gems_use_only_the_outer_band() -> void:
	# Arrange
	var config: Dictionary = _run_config()

	# Act / Assert — inner 48, outer 48 + 24 = 72, gem band 0.4 of the width = 62.4..72
	assert_float(ChestBurst.ring_radius(config, "copper", 0.0)).is_equal_approx(48.0, 0.0001)
	assert_float(ChestBurst.ring_radius(config, "silver", 1.0)).is_equal_approx(72.0, 0.0001)
	assert_float(ChestBurst.ring_radius(config, "gem", 0.0)).is_equal_approx(62.4, 0.0001)
	assert_float(ChestBurst.ring_radius(config, "gem", 1.0)).is_equal_approx(72.0, 0.0001)


func test_make_ring_loot_targets_the_angle_and_radius_around_the_chest_centre() -> void:
	# Arrange
	var config: Dictionary = _run_config()

	# Act — angle roll 0 points right, 0.25 points down; radius roll 0.5 of a copper = 60
	var right: Dictionary = ChestBurst.make_ring_loot(config, FIELD_SIZE, 0, "copper", 0.0, 0.5, 0.0)
	var down: Dictionary = ChestBurst.make_ring_loot(config, FIELD_SIZE, 1, "copper", 0.25, 0.5, 0.0)

	# Assert — the flight lasts 60 / 140 s and starts at the chest centre
	assert_vector(right["pos"]).is_equal_approx(Vector2(320.0, 190.0), Vector2(0.001, 0.001))
	assert_vector(right["target"]).is_equal_approx(Vector2(380.0, 190.0), Vector2(0.001, 0.001))
	assert_vector(down["target"]).is_equal_approx(Vector2(320.0, 250.0), Vector2(0.001, 0.001))
	assert_float(right["duration"]).is_equal_approx(60.0 / 140.0, 0.0001)
	assert_bool(right["landed"]).is_false()


func test_step_ring_loot_flies_on_an_arc_and_lands_on_its_target() -> void:
	# Arrange — duration 60 / 140 s
	var config: Dictionary = _run_config()
	var coin: Dictionary = ChestBurst.make_ring_loot(config, FIELD_SIZE, 0, "copper", 0.0, 0.5, 0.0)
	var duration: float = coin["duration"]

	# Act — halfway
	ChestBurst.step_ring_loot(config, coin, duration / 2.0)
	var halfway_pos: Vector2 = coin["pos"]
	var halfway_height: float = coin["height"]
	var halfway_landed: bool = coin["landed"]
	ChestBurst.step_ring_loot(config, coin, duration)

	# Assert — midpoint, peak height 550 / 2 * (d/2)^2, then on the target at height 0 and stays there
	assert_vector(halfway_pos).is_equal_approx(Vector2(350.0, 190.0), Vector2(0.001, 0.001))
	assert_float(halfway_height).is_equal_approx(0.5 * 550.0 * (duration / 2.0) * (duration / 2.0), 0.0001)
	assert_bool(halfway_landed).is_false()
	assert_bool(coin["landed"]).is_true()
	assert_vector(coin["pos"]).is_equal_approx(Vector2(380.0, 190.0), Vector2(0.001, 0.001))
	assert_float(coin["height"]).is_equal(0.0)


func test_settle_ring_loot_puts_the_coin_on_its_target() -> void:
	# Arrange
	var coin: Dictionary = ChestBurst.make_ring_loot(_run_config(), FIELD_SIZE, 0, "gem", 0.5, 1.0, 0.0)

	# Act
	ChestBurst.settle_ring_loot(coin)

	# Assert — angle roll 0.5 points left: 320 - 72
	assert_vector(coin["pos"]).is_equal_approx(Vector2(248.0, 190.0), Vector2(0.001, 0.001))
	assert_bool(coin["landed"]).is_true()


func test_harvest_waits_for_the_full_timer_and_for_flying_coins() -> void:
	# Arrange — two magnet coins still flying when the 5 s timer ends
	var flying: Array[int] = [2]
	var controller: RunController = _new_controller({}, 0, func() -> int: return flying[0])
	_advance_to(controller, RunController.Phase.HARVEST)

	# Act
	controller.advance(4.0)
	var phase_before_end: int = controller.phase
	var time_left: float = controller.harvest_time_left()
	controller.advance(1.0)
	var phase_with_flights: int = controller.phase
	flying[0] = 0
	controller.advance(STEP)

	# Assert
	assert_int(phase_before_end).is_equal(RunController.Phase.HARVEST)
	assert_float(time_left).is_equal_approx(1.0, 0.0001)
	assert_int(phase_with_flights).is_equal(RunController.Phase.HARVEST)
	assert_int(controller.phase).is_equal(RunController.Phase.RESULT)


func test_magnet_is_off_once_the_harvest_timer_ran_out() -> void:
	# Arrange
	var flying: Array[int] = [1]
	var controller: RunController = _new_controller({}, 0, func() -> int: return flying[0])
	_advance_to(controller, RunController.Phase.HARVEST)
	var during: bool = controller.magnet_allowed()

	# Act
	controller.advance(5.0)

	# Assert
	assert_bool(during).is_true()
	assert_bool(controller.magnet_allowed()).is_false()


func test_unpicked_loot_is_gone_at_the_harvest_end_and_picked_loot_counts_once() -> void:
	# Arrange
	var controller: RunController = _new_controller()
	_advance_to(controller, RunController.Phase.HARVEST)
	var first_id: int = controller.loot[0]["id"]

	# Act
	var picked: bool = controller.pick_loot(first_id)
	var picked_again: bool = controller.pick_loot(first_id)
	var left_after_pick: int = controller.loot.size()
	_advance_to(controller, RunController.Phase.RESULT)

	# Assert
	assert_bool(picked).is_true()
	assert_bool(picked_again).is_false()
	assert_int(left_after_pick).is_equal(39)
	assert_int(controller.loot.size()).is_equal(0)
	assert_bool(controller.pick_loot(first_id)).is_false()


func test_pick_loot_outside_the_harvest_does_nothing() -> void:
	# Arrange
	var controller: RunController = _new_controller()
	_advance_to(controller, RunController.Phase.BURST)
	for i: int in 3:
		controller.advance(0.5)

	# Act — burst time 1.5 s: open and raining, no coin on the floor yet
	var picked: bool = controller.pick_loot(controller.loot[0]["id"])

	# Assert
	assert_int(controller.phase).is_equal(RunController.Phase.BURST)
	assert_bool(picked).is_false()
	assert_int(controller.loot.size()).is_equal(40)


# --- RunResult -----------------------------------------------------------------------------------------------

func test_run_result_holds_gold_tier_multiplier_kills_and_map() -> void:
	# Arrange — silver chest at level 2 (x1.9), 200 collected, coin level 1: bonus per coin base * 1.3
	var controller: RunController = _new_controller({"chest": 2, "coin": 1})
	controller.collected = 200.0
	controller.kills = 17
	_advance_to(controller, RunController.Phase.HARVEST)
	var picked_kinds: Array[String] = []
	for i: int in 3:
		picked_kinds.append(controller.loot[0]["kind"])
		controller.pick_loot(controller.loot[0]["id"])
	var expected_bonus: float = 0.0
	for kind: String in picked_kinds:
		expected_bonus += FinalHarvest.bonus_for(_slime_config(), kind, 0, 1)

	# Act
	_advance_to(controller, RunController.Phase.RESULT)
	var result: RunResult = controller.result

	# Assert
	assert_str(result.map_id).is_equal("meadow")
	assert_int(result.base_gold).is_equal(380)
	assert_int(result.harvest_bonus).is_equal(roundi(expected_bonus))
	assert_int(result.chest_tier).is_equal(2)
	assert_str(result.chest_name).is_equal("은 상자")
	assert_float(result.multiplier).is_equal_approx(1.9, 0.0001)
	assert_float(result.collected).is_equal(200.0)
	assert_int(result.kills).is_equal(17)
	assert_bool(result.boss_defeated).is_false()
	assert_int(result.total_gold()).is_equal(380 + roundi(expected_bonus))


func test_run_result_drops_sum_to_the_loot_count() -> void:
	# Arrange — 380 base gold rains floor(40 + sqrt(380) * 4) = 117 coins
	var controller: RunController = _new_controller({"chest": 2})
	controller.collected = 200.0

	# Act
	_advance_to(controller, RunController.Phase.RESULT)
	var total: int = 0
	for entry: Dictionary in controller.result.drops:
		total += int(entry["count"])

	# Assert
	assert_int(total).is_equal(ChestBurst.drop_count(_run_config(), 380))
	assert_int(total).is_equal(117)


func test_run_result_without_any_pick_has_no_harvest_bonus() -> void:
	# Arrange
	var controller: RunController = _new_controller()
	controller.collected = 10.0

	# Act
	_advance_to(controller, RunController.Phase.RESULT)

	# Assert — wooden chest (x1): 10 gold, nothing picked, nothing added
	assert_int(controller.result.base_gold).is_equal(10)
	assert_int(controller.result.harvest_bonus).is_equal(0)
	assert_int(controller.result.total_gold()).is_equal(10)


func test_run_result_total_gold_is_base_plus_bonus() -> void:
	# Arrange
	var result := RunResult.new()
	result.base_gold = 380
	result.harvest_bonus = 12

	# Act / Assert
	assert_int(result.total_gold()).is_equal(392)


# --- Magnet.set_target ---------------------------------------------------------------------------------------

func test_magnet_with_a_target_calls_the_sink_once_and_leaves_the_chest_alone() -> void:
	# Arrange
	var chest: Chest = _new_chest()
	var coin: Coin = _new_coin("gem", 15.0, Vector2(100.0, 100.0))
	var coins: Array[Coin] = [coin]
	var magnet: Magnet = _new_magnet(coins, chest)
	var arrived: Array[Coin] = []
	magnet.set_target(Vector2(320.0, 190.0), func(c: Coin) -> void: arrived.append(c))

	# Act — absorb, then run well past the 0.417 s flight
	magnet.step(0.0, Vector2(100.0, 100.0), true)
	for i: int in 10:
		magnet.step(0.1, Vector2(100.0, 100.0), true)

	# Assert
	assert_int(arrived.size()).is_equal(1)
	assert_object(arrived[0]).is_same(coin)
	assert_float(chest.value).is_equal(0.0)
	assert_int(magnet.flying_count()).is_equal(0)


func test_magnet_with_a_target_does_not_call_the_sink_before_the_flight_ends() -> void:
	# Arrange
	var coins: Array[Coin] = [_new_coin("copper", 1.0, Vector2(100.0, 100.0))]
	var magnet: Magnet = _new_magnet(coins, _new_chest())
	var arrived: Array[Coin] = []
	magnet.set_target(Vector2(320.0, 190.0), func(c: Coin) -> void: arrived.append(c))

	# Act — 0.2 s of a 0.417 s flight
	magnet.step(0.0, Vector2(100.0, 100.0), true)
	magnet.step(0.2, Vector2(100.0, 100.0), true)

	# Assert
	assert_int(arrived.size()).is_equal(0)
	assert_int(magnet.flying_count()).is_equal(1)
