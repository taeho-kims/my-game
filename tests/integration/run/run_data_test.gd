## Story: slime-nodaji story-004 (design/game-brief.md, Brief MVP feature 4), Part A data.
## Reads the real assets/data/run.json (a data-conformance check, so it lives under integration/)
## and compares it with the prototype values in slime-nodaji.html (stats().time, beginBurst,
## updateBurst; spatial values halved for the 640x360 base) and with the story's harvest numbers.
extends GdUnitTestSuite

const DATA_PATH: String = "res://assets/data/run.json"
const CHEST_DATA_PATH: String = "res://assets/data/chest_tiers.json"


func test_data_file_loads_and_passes_validation() -> void:
	# Act
	var config: Dictionary = RunController.load_config(DATA_PATH)

	# Assert
	assert_bool(config.is_empty()).is_false()


func test_data_run_length_is_24_plus_4_per_time_level_with_a_5_second_warning() -> void:
	# Arrange
	var config: Dictionary = RunController.load_config(DATA_PATH)

	# Act / Assert
	assert_float(config["run"]["base_time"]).is_equal(24.0)
	assert_float(config["run"]["time_per_level"]).is_equal(4.0)
	assert_float(config["run"]["low_time_threshold"]).is_equal(5.0)
	assert_str(config["run"]["map_id"]).is_equal("meadow")


func test_data_burst_timing_matches_the_prototype() -> void:
	# Arrange — prototype: k = t / 1.1, scale 1 + e * 1.6, dim .45 * e, shake after .9, open at 1.3, count-up 1.6
	var burst: Dictionary = RunController.load_config(DATA_PATH)["burst"]

	# Act / Assert
	assert_float(burst["move_time"]).is_equal(1.1)
	assert_float(burst["open_time"]).is_equal(1.3)
	assert_float(burst["scale_gain"]).is_equal(1.6)
	assert_float(burst["dim_alpha_max"]).is_equal(0.45)
	assert_float(burst["shake_start"]).is_equal(0.9)
	assert_float(burst["count_up_time"]).is_equal(1.6)


func test_data_burst_spatial_values_are_the_prototype_values_halved() -> void:
	# Arrange — prototype: centre y H/2 + 20, chest shake +-4, screen shake 14
	var burst: Dictionary = RunController.load_config(DATA_PATH)["burst"]

	# Act / Assert
	assert_float(burst["center_offset_y"]).is_equal(10.0)
	assert_float(burst["shake_amplitude"]).is_equal(2.0)
	assert_float(burst["open_shake"]).is_equal(7.0)


func test_data_open_sound_is_a_sawtooth_220_hz_blip() -> void:
	# Arrange
	var sound: Dictionary = RunController.load_config(DATA_PATH)["burst"]["open_sound"]

	# Act / Assert — prototype: blip(220, .3, 'sawtooth', .06)
	assert_str(sound["wave"]).is_equal("sawtooth")
	assert_float(sound["frequency"]).is_equal(220.0)
	assert_float(sound["duration"]).is_equal(0.3)
	assert_float(sound["volume"]).is_equal(0.06)


func test_data_rain_count_formula_matches_the_prototype() -> void:
	# Arrange — prototype: Math.min(180, 40 + Math.sqrt(total) * 4 | 0)
	var rain: Dictionary = RunController.load_config(DATA_PATH)["rain"]

	# Act / Assert
	assert_float(rain["count_base"]).is_equal(40.0)
	assert_float(rain["count_per_sqrt_total"]).is_equal(4.0)
	assert_float(rain["count_max"]).is_equal(180.0)


func test_data_rain_kind_split_is_ten_twentyseven_sixtythree() -> void:
	# Arrange
	var chance: Dictionary = RunController.load_config(DATA_PATH)["rain"]["kind_chance"]

	# Act / Assert — copper is the remainder: 1 - 0.10 - 0.27 = 0.63
	assert_float(chance["gem"]).is_equal(0.10)
	assert_float(chance["silver"]).is_equal(0.27)
	assert_float(1.0 - float(chance["gem"]) - float(chance["silver"])).is_equal_approx(0.63, 0.0001)


func test_data_rain_gravity_and_spin_match_the_prototype_halved() -> void:
	# Arrange — prototype: gravity 1100, spin dt*10 (the floor-bounce keys went away with the ring layout)
	var rain: Dictionary = RunController.load_config(DATA_PATH)["rain"]

	# Act / Assert
	assert_float(rain["gravity"]).is_equal(550.0)
	assert_float(rain["spin_rate"]).is_equal(10.0)


func test_data_rain_blip_matches_the_prototype() -> void:
	# Arrange — prototype: Math.random() < .4 -> blip(rand(700, 1400), .04, 'square', .015)
	var blip: Dictionary = RunController.load_config(DATA_PATH)["rain"]["blip"]

	# Act / Assert
	assert_float(blip["chance"]).is_equal(0.4)
	assert_float(blip["frequency_min"]).is_equal(700.0)
	assert_float(blip["frequency_max"]).is_equal(1400.0)
	assert_float(blip["duration"]).is_equal(0.04)
	assert_float(blip["volume"]).is_equal(0.015)
	assert_str(blip["wave"]).is_equal("square")


func test_data_harvest_lasts_five_seconds() -> void:
	# Arrange
	var harvest: Dictionary = RunController.load_config(DATA_PATH)["harvest"]

	# Act / Assert
	assert_float(harvest["duration"]).is_equal(5.0)
	assert_float(harvest["start_max_wait"]).is_greater(0.0)


func test_data_ring_is_wider_than_one_magnet_pass_so_it_takes_several_laps() -> void:
	# Arrange — playtest values (story-004): inner radius 40, width 60 (outer 100); one lap of the
	# base magnet sweeps its diameter (2 x radius) of the width
	var ring: Dictionary = RunController.load_config(DATA_PATH)["ring"]
	var base_radius: float = ChestTiers.load_config(CHEST_DATA_PATH)["magnet"]["base_radius"]

	# Act / Assert
	assert_float(ring["inner_radius"]).is_equal(40.0)
	assert_float(ring["width"]).is_equal(60.0)
	assert_float(ring["width"]).is_greater(2.0 * base_radius)
	assert_float(ring["gem_band"]).is_between(0.0, 1.0)
	assert_float(ring["spread_speed"]).is_greater(0.0)


func test_data_harvest_magnet_radius_is_24_plus_5_per_level() -> void:
	# Arrange — the harvest reuses the magnet, whose radius comes from chest_tiers.json
	var chest_config: Dictionary = ChestTiers.load_config(CHEST_DATA_PATH)

	# Act / Assert
	assert_float(Magnet.radius(chest_config, 0)).is_equal(24.0)
	assert_float(Magnet.radius(chest_config, 3)).is_equal(39.0)
