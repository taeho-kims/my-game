## Story: slime-nodaji story-003 (design/game-brief.md, Brief MVP feature 3).
## Covers ChestTiers (thresholds, multipliers, payout), coin values feeding the chest, the
## Chest deposit/bump and the Magnet's absorb-once rule. Expected numbers come from the
## prototype slime-nodaji.html (TIERS, tierOf, multOf, update coin loop, blip).
extends GdUnitTestSuite

const FIELD_SIZE: Vector2 = Vector2(640.0, 360.0)
const RUNS_TEN: int = 10


## Fixture factory: the same keys and values as assets/data/chest_tiers.json, inline so the
## suite does no file I/O.
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
		"chest": {"bottom_offset": 15.0, "bump_decay": 5.0, "bump_scale": 0.08, "bump_lift": 2.0},
		"magnet": {
			"base_radius": 17.0, "radius_per_level": 5.0, "fly_speed": 2.4,
			"control_x_range": 30.0, "control_rise_min": 30.0, "control_rise_max": 70.0,
			"arrival_height": 10.0, "flight_spin_rate": 20.0, "flight_z_index": 1.0,
			"ring_color": "#f2c14e", "ring_alpha": 0.55, "ring_width": 1.0,
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


func _new_chest(run_scale: float, chest_level: int) -> Chest:
	var chest: Chest = auto_free(Chest.new())
	chest.setup(_chest_config(), FIELD_SIZE, run_scale, chest_level)
	return chest


func _new_coin(kind: String, value: float, position: Vector2) -> Coin:
	var coin: Coin = auto_free(Coin.new())
	coin.setup(_slime_config(), kind, value, Rect2(Vector2.ZERO, FIELD_SIZE), position, Vector2.ZERO, 0.0)
	return coin


func _new_magnet(coins: Array[Coin], chest: Chest, magnet_level: int) -> Magnet:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var magnet: Magnet = auto_free(Magnet.new())
	magnet.setup(_chest_config(), rng, coins, chest, FIELD_SIZE, magnet_level)
	return magnet


# --- Tier thresholds -------------------------------------------------------------------

func test_tier_of_value_zero_is_wooden() -> void:
	# Arrange
	var config: Dictionary = _chest_config()

	# Act
	var result: int = ChestTiers.tier_of(config, 0.0, 1.0)

	# Assert
	assert_int(result).is_equal(0)


func test_tier_of_exact_threshold_at_run_scale_one_reaches_that_tier() -> void:
	# Arrange
	var config: Dictionary = _chest_config()
	var thresholds: Array[float] = [40.0, 140.0, 400.0, 1100.0]

	# Act / Assert — tiers 1..4 start at 40 / 140 / 400 / 1100
	for i: int in thresholds.size():
		assert_int(ChestTiers.tier_of(config, thresholds[i], 1.0)).is_equal(i + 1)


func test_tier_of_just_below_threshold_at_run_scale_one_is_previous_tier() -> void:
	# Arrange
	var config: Dictionary = _chest_config()
	var thresholds: Array[float] = [40.0, 140.0, 400.0, 1100.0]

	# Act / Assert
	for i: int in thresholds.size():
		assert_int(ChestTiers.tier_of(config, thresholds[i] - 0.001, 1.0)).is_equal(i)


func test_tier_of_exact_scaled_threshold_after_ten_runs_reaches_that_tier() -> void:
	# Arrange — thresholds are multiplied by 1.07 ^ 10
	var config: Dictionary = _chest_config()
	var scale: float = SlimeField.run_scale(_slime_config(), RUNS_TEN)

	# Act / Assert
	for tier: int in range(1, 5):
		var edge: float = float([0, 40, 140, 400, 1100][tier]) * scale
		assert_float(ChestTiers.threshold(config, tier, scale)).is_equal_approx(edge, 0.0001)
		assert_int(ChestTiers.tier_of(config, ChestTiers.threshold(config, tier, scale), scale)).is_equal(tier)


func test_tier_of_just_below_scaled_threshold_after_ten_runs_is_previous_tier() -> void:
	# Arrange
	var config: Dictionary = _chest_config()
	var scale: float = SlimeField.run_scale(_slime_config(), RUNS_TEN)

	# Act / Assert
	for tier: int in range(1, 5):
		var below: float = ChestTiers.threshold(config, tier, scale) - 0.001
		assert_int(ChestTiers.tier_of(config, below, scale)).is_equal(tier - 1)


func test_tier_of_unscaled_threshold_after_ten_runs_is_not_enough() -> void:
	# Arrange — 40 reaches copper at scale 1 but not once thresholds grow by 1.07 ^ 10 (about 1.97)
	var config: Dictionary = _chest_config()
	var scale: float = SlimeField.run_scale(_slime_config(), RUNS_TEN)

	# Act
	var result: int = ChestTiers.tier_of(config, 40.0, scale)

	# Assert
	assert_int(result).is_equal(0)


func test_tier_of_huge_value_is_crystal() -> void:
	# Arrange
	var config: Dictionary = _chest_config()

	# Act
	var result: int = ChestTiers.tier_of(config, 1000000.0, 1.0)

	# Assert
	assert_int(result).is_equal(4)


# --- Multipliers and payout --------------------------------------------------------------

func test_multiplier_at_chest_level_zero_is_the_base_multiplier() -> void:
	# Arrange
	var config: Dictionary = _chest_config()
	var expected: Array[float] = [1.0, 1.25, 1.5, 2.0, 3.0]

	# Act / Assert
	for tier: int in expected.size():
		assert_float(ChestTiers.multiplier(config, tier, 0)).is_equal_approx(expected[tier], 0.0001)


func test_multiplier_at_chest_level_two_adds_point_two_per_tier_number() -> void:
	# Arrange — base + 0.1 * 2 * tier
	var config: Dictionary = _chest_config()
	var expected: Array[float] = [1.0, 1.45, 1.9, 2.6, 3.8]

	# Act / Assert
	for tier: int in expected.size():
		assert_float(ChestTiers.multiplier(config, tier, 2)).is_equal_approx(expected[tier], 0.0001)


func test_multiplier_at_chest_level_six_adds_point_six_per_tier_number() -> void:
	# Arrange — base + 0.1 * 6 * tier
	var config: Dictionary = _chest_config()
	var expected: Array[float] = [1.0, 1.85, 2.7, 3.8, 5.4]

	# Act / Assert
	for tier: int in expected.size():
		assert_float(ChestTiers.multiplier(config, tier, 6)).is_equal_approx(expected[tier], 0.0001)


func test_total_rounds_value_times_multiplier() -> void:
	# Arrange — 100 * 1.5 = 150 (silver); 2 * 1.25 = 2.5 rounds up to 3 like Math.round
	var config: Dictionary = _chest_config()

	# Act
	var silver: int = ChestTiers.total(config, 100.0, 2, 0)
	var half_up: int = ChestTiers.total(config, 2.0, 1, 0)

	# Assert
	assert_int(silver).is_equal(150)
	assert_int(half_up).is_equal(3)


func test_total_at_chest_level_two_uses_the_boosted_multiplier() -> void:
	# Arrange — 200 * 1.9 = 380 (silver tier, chest level 2)
	var config: Dictionary = _chest_config()

	# Act
	var result: int = ChestTiers.total(config, 200.0, 2, 2)

	# Assert
	assert_int(result).is_equal(380)


# --- Coin values and chest accumulation ------------------------------------------------------

func test_coin_value_per_kind_at_run_zero_and_coin_level_zero_is_one_four_fifteen() -> void:
	# Arrange
	var config: Dictionary = _slime_config()

	# Act
	var copper: float = SlimeField.coin_value(config, "copper", 0, 0)
	var silver: float = SlimeField.coin_value(config, "silver", 0, 0)
	var gem: float = SlimeField.coin_value(config, "gem", 0, 0)

	# Assert
	assert_float(copper).is_equal_approx(1.0, 0.0001)
	assert_float(silver).is_equal_approx(4.0, 0.0001)
	assert_float(gem).is_equal_approx(15.0, 0.0001)


func test_coin_value_scales_with_runs_and_coin_level() -> void:
	# Arrange — 15 * 1.07 ^ 10 * (1 + 0.3 * 2)
	var config: Dictionary = _slime_config()
	var expected: float = 15.0 * pow(1.07, 10.0) * 1.6

	# Act
	var result: float = SlimeField.coin_value(config, "gem", RUNS_TEN, 2)

	# Assert
	assert_float(result).is_equal_approx(expected, 0.0001)


func test_chest_deposits_of_a_coin_sequence_sum_their_values() -> void:
	# Arrange — copper + silver + gem + copper at coin level 2: (1 + 4 + 15 + 1) * 1.6
	var config: Dictionary = _slime_config()
	var chest: Chest = _new_chest(1.0, 0)

	# Act
	for kind: String in ["copper", "silver", "gem", "copper"]:
		chest.deposit(SlimeField.coin_value(config, kind, 0, 2))

	# Assert
	assert_float(chest.value).is_equal_approx(33.6, 0.0001)


func test_chest_deposit_restarts_the_bump_and_it_decays_to_zero() -> void:
	# Arrange
	var chest: Chest = _new_chest(1.0, 0)

	# Act
	chest.deposit(1.0)
	var after_deposit: float = chest.bump
	chest.advance(0.1)
	var after_tenth: float = chest.bump
	chest.advance(1.0)

	# Assert — decays at 5 per second
	assert_float(after_deposit).is_equal(1.0)
	assert_float(after_tenth).is_equal_approx(0.5, 0.0001)
	assert_float(chest.bump).is_equal(0.0)


func test_chest_tier_follows_deposits_across_the_scaled_threshold() -> void:
	# Arrange — after 10 runs copper needs 40 * 1.07 ^ 10
	var scale: float = SlimeField.run_scale(_slime_config(), RUNS_TEN)
	var chest: Chest = _new_chest(scale, 0)

	# Act
	chest.deposit(40.0)
	var below: int = chest.tier()
	chest.deposit(40.0 * scale)
	var above: int = chest.tier()

	# Assert
	assert_int(below).is_equal(0)
	assert_int(above).is_equal(1)


func test_chest_total_applies_the_tier_multiplier_and_chest_level() -> void:
	# Arrange — silver tier (value 200 >= 140), chest level 2: 200 * 1.9
	var chest: Chest = _new_chest(1.0, 2)

	# Act
	chest.deposit(200.0)

	# Assert
	assert_int(chest.tier()).is_equal(2)
	assert_int(chest.total()).is_equal(380)


# --- Magnet ------------------------------------------------------------------------------------

func test_magnet_radius_is_seventeen_plus_five_per_level() -> void:
	# Arrange
	var config: Dictionary = _chest_config()

	# Act / Assert
	assert_float(Magnet.radius(config, 0)).is_equal(17.0)
	assert_float(Magnet.radius(config, 3)).is_equal(32.0)


func test_magnet_absorbs_coin_inside_radius_and_removes_it_from_the_coin_list() -> void:
	# Arrange
	var coin: Coin = _new_coin("copper", 1.0, Vector2(100.0, 100.0))
	var coins: Array[Coin] = [coin]
	var magnet: Magnet = _new_magnet(coins, _new_chest(1.0, 0), 0)

	# Act
	magnet.step(0.0, Vector2(110.0, 100.0), true)

	# Assert
	assert_int(coins.size()).is_equal(0)
	assert_int(magnet.flying_count()).is_equal(1)
	assert_bool(coin.flying).is_true()


func test_magnet_ignores_coin_exactly_at_the_radius() -> void:
	# Arrange — strict comparison: distance 17 is not inside radius 17
	var coins: Array[Coin] = [_new_coin("copper", 1.0, Vector2(117.0, 100.0))]
	var magnet: Magnet = _new_magnet(coins, _new_chest(1.0, 0), 0)

	# Act
	magnet.step(0.0, Vector2(100.0, 100.0), true)

	# Assert
	assert_int(coins.size()).is_equal(1)
	assert_int(magnet.flying_count()).is_equal(0)


func test_magnet_is_off_while_the_cursor_is_outside_the_field() -> void:
	# Arrange
	var coins: Array[Coin] = [_new_coin("copper", 1.0, Vector2(100.0, 100.0))]
	var magnet: Magnet = _new_magnet(coins, _new_chest(1.0, 0), 0)

	# Act
	magnet.step(0.0, Vector2(100.0, 100.0), false)

	# Assert
	assert_int(coins.size()).is_equal(1)
	assert_int(magnet.flying_count()).is_equal(0)


func test_magnet_level_widens_the_pick_up_range() -> void:
	# Arrange — a coin 30 px away: outside level 0 (17), inside level 3 (32)
	var near_coins: Array[Coin] = [_new_coin("copper", 1.0, Vector2(130.0, 100.0))]
	var far_coins: Array[Coin] = [_new_coin("copper", 1.0, Vector2(130.0, 100.0))]
	var level_zero: Magnet = _new_magnet(far_coins, _new_chest(1.0, 0), 0)
	var level_three: Magnet = _new_magnet(near_coins, _new_chest(1.0, 0), 3)

	# Act
	level_zero.step(0.0, Vector2(100.0, 100.0), true)
	level_three.step(0.0, Vector2(100.0, 100.0), true)

	# Assert
	assert_int(far_coins.size()).is_equal(1)
	assert_int(near_coins.size()).is_equal(0)


func test_magnet_deposits_nothing_before_the_flight_ends() -> void:
	# Arrange
	var chest: Chest = _new_chest(1.0, 0)
	var coins: Array[Coin] = [_new_coin("silver", 4.0, Vector2(100.0, 100.0))]
	var magnet: Magnet = _new_magnet(coins, chest, 0)

	# Act — 0.2 s of a 1 / 2.4 = 0.417 s flight
	magnet.step(0.0, Vector2(100.0, 100.0), true)
	magnet.step(0.2, Vector2(300.0, 300.0), true)

	# Assert
	assert_float(chest.value).is_equal(0.0)
	assert_int(magnet.flying_count()).is_equal(1)


func test_magnet_deposits_the_coin_value_into_the_chest_once_when_it_arrives() -> void:
	# Arrange
	var chest: Chest = _new_chest(1.0, 0)
	var coins: Array[Coin] = [_new_coin("gem", 15.0, Vector2(100.0, 100.0))]
	var magnet: Magnet = _new_magnet(coins, chest, 0)

	# Act — absorb, then run well past the flight time in 0.1 s steps
	magnet.step(0.0, Vector2(100.0, 100.0), true)
	for i: int in 10:
		magnet.step(0.1, Vector2(100.0, 100.0), true)

	# Assert
	assert_float(chest.value).is_equal(15.0)
	assert_float(chest.bump).is_greater(0.0)
	assert_int(magnet.flying_count()).is_equal(0)


func test_absorbing_the_same_coin_twice_deposits_it_only_once() -> void:
	# Arrange
	var chest: Chest = _new_chest(1.0, 0)
	var coin: Coin = _new_coin("silver", 4.0, Vector2(100.0, 100.0))
	var coins: Array[Coin] = [coin]
	var magnet: Magnet = _new_magnet(coins, chest, 0)

	# Act
	var first: bool = magnet.absorb(coin)
	var second: bool = magnet.absorb(coin)
	for i: int in 10:
		magnet.step(0.1, Vector2(100.0, 100.0), true)

	# Assert
	assert_bool(first).is_true()
	assert_bool(second).is_false()
	assert_float(chest.value).is_equal(4.0)


func test_magnet_sums_several_coins_absorbed_in_the_same_step() -> void:
	# Arrange — copper 1 + silver 4 + gem 15, all inside the ring
	var chest: Chest = _new_chest(1.0, 0)
	var coins: Array[Coin] = [
		_new_coin("copper", 1.0, Vector2(100.0, 100.0)),
		_new_coin("silver", 4.0, Vector2(105.0, 100.0)),
		_new_coin("gem", 15.0, Vector2(100.0, 105.0)),
	]
	var magnet: Magnet = _new_magnet(coins, chest, 0)

	# Act
	magnet.step(0.0, Vector2(100.0, 100.0), true)
	for i: int in 10:
		magnet.step(0.1, Vector2(100.0, 100.0), true)

	# Assert
	assert_float(chest.value).is_equal(20.0)


func test_bezier_starts_at_start_ends_at_end_and_bends_towards_the_control_point() -> void:
	# Arrange
	var start := Vector2(0.0, 100.0)
	var control := Vector2(50.0, 0.0)
	var end := Vector2(100.0, 100.0)

	# Act
	var begin: Vector2 = Magnet.bezier(start, control, end, 0.0)
	var middle: Vector2 = Magnet.bezier(start, control, end, 0.5)
	var finish: Vector2 = Magnet.bezier(start, control, end, 1.0)

	# Assert — midpoint = 0.25 start + 0.5 control + 0.25 end
	assert_vector(begin).is_equal(start)
	assert_vector(middle).is_equal(Vector2(50.0, 50.0))
	assert_vector(finish).is_equal(end)


func test_blip_is_allowed_only_after_more_than_the_throttle_window() -> void:
	# Arrange / Act / Assert — window 45 ms, strict like the prototype
	assert_bool(Magnet.blip_allowed(1000, 1044, 45.0)).is_false()
	assert_bool(Magnet.blip_allowed(1000, 1045, 45.0)).is_false()
	assert_bool(Magnet.blip_allowed(1000, 1046, 45.0)).is_true()
	assert_bool(Magnet.blip_allowed(Magnet.NEVER_PLAYED, 0, 45.0)).is_true()


func test_make_blip_has_one_sample_per_tick_of_the_configured_duration() -> void:
	# Arrange — 22050 Hz * 0.05 s = 1102 samples of 2 bytes
	var sound: Dictionary = _chest_config()["sound"]

	# Act
	var stream: AudioStreamWAV = Magnet.make_blip(sound, 760.0)

	# Assert
	assert_int(stream.data.size()).is_equal(1102 * 2)
