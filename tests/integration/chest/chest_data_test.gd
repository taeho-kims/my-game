## Story: slime-nodaji story-003 (design/game-brief.md, Brief MVP feature 3).
## Reads the real assets/data/chest_tiers.json (a data-conformance check, so it lives under
## integration/) and compares it with the prototype's TIERS in slime-nodaji.html.
extends GdUnitTestSuite

const DATA_PATH: String = "res://assets/data/chest_tiers.json"

# Prototype TIERS (slime-nodaji.html): threshold, base multiplier.
const PROTOTYPE_THRESHOLDS: Array[float] = [0.0, 40.0, 140.0, 400.0, 1100.0]
const PROTOTYPE_MULTIPLIERS: Array[float] = [1.0, 1.25, 1.5, 2.0, 3.0]
const PROTOTYPE_COLORS: Array[String] = ["#9b6b43", "#d0844f", "#d5dce4", "#f2c14e", "#8fe3ff"]


func test_data_file_loads_and_passes_validation() -> void:
	# Act
	var config: Dictionary = ChestTiers.load_config(DATA_PATH)

	# Assert
	assert_bool(config.is_empty()).is_false()


func test_data_thresholds_match_the_prototype_tiers_at_run_scale_one() -> void:
	# Arrange
	var config: Dictionary = ChestTiers.load_config(DATA_PATH)

	# Act / Assert
	for tier: int in PROTOTYPE_THRESHOLDS.size():
		assert_float(ChestTiers.threshold(config, tier, 1.0)).is_equal(PROTOTYPE_THRESHOLDS[tier])


func test_data_thresholds_scale_with_run_scale_like_the_prototype() -> void:
	# Arrange — prototype: TIERS[k].t * 1.07 ^ runs
	var config: Dictionary = ChestTiers.load_config(DATA_PATH)
	var run_scale: float = pow(1.07, 10)

	# Act / Assert
	for tier: int in PROTOTYPE_THRESHOLDS.size():
		assert_float(ChestTiers.threshold(config, tier, run_scale)) \
				.is_equal_approx(PROTOTYPE_THRESHOLDS[tier] * run_scale, 0.0001)


func test_data_base_multipliers_match_the_prototype_at_chest_level_zero() -> void:
	# Arrange
	var config: Dictionary = ChestTiers.load_config(DATA_PATH)

	# Act / Assert
	for tier: int in PROTOTYPE_MULTIPLIERS.size():
		assert_float(ChestTiers.multiplier(config, tier, 0)).is_equal(PROTOTYPE_MULTIPLIERS[tier])


func test_data_chest_level_bonus_is_point_one_per_tier_number() -> void:
	# Arrange — prototype multOf: TIERS[i].m + 0.1 * chest level * i
	var config: Dictionary = ChestTiers.load_config(DATA_PATH)

	# Act / Assert
	for tier: int in PROTOTYPE_MULTIPLIERS.size():
		assert_float(ChestTiers.multiplier(config, tier, 3)) \
				.is_equal_approx(PROTOTYPE_MULTIPLIERS[tier] + 0.1 * 3.0 * float(tier), 0.0001)


func test_data_tier_colors_match_the_prototype() -> void:
	# Arrange
	var config: Dictionary = ChestTiers.load_config(DATA_PATH)

	# Act / Assert
	for tier: int in PROTOTYPE_COLORS.size():
		assert_that(ChestTiers.tier_color(config, tier)).is_equal(Color.html(PROTOTYPE_COLORS[tier]))
