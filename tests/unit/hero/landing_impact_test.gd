## Story: slime-nodaji story-002 (design/game-brief.md, Brief MVP feature 1).
## Covers the landing formulas in LandingImpact and the squad size in HeroSquad.
extends GdUnitTestSuite


## Fixture factory: the same keys and values as assets/data/hero_knight.json, inline so the
## suite does no file I/O.
func _config() -> Dictionary:
	return {
		"squad": {"base_count": 2, "count_per_hero_level": 1},
		"landing": {
			"base_radius": 23.0, "radius_per_level": 3.5,
			"base_damage": 8.0, "damage_per_level": 10.0, "run_scale_exponent": 0.5,
			"shake_base": 1.5, "shake_per_level": 0.25,
		},
	}


func test_radius_at_land_level_two_adds_seven() -> void:
	# Arrange
	var config: Dictionary = _config()

	# Act
	var result: float = LandingImpact.radius(config, 2)

	# Assert
	assert_float(result).is_equal(30.0)


func test_damage_at_level_zero_with_run_scale_four_doubles_base() -> void:
	# Arrange — 8 * 4 ^ 0.5 = 16
	var config: Dictionary = _config()

	# Act
	var result: float = LandingImpact.damage(config, 0, 4.0)

	# Assert
	assert_float(result).is_equal_approx(16.0, 0.0001)


func test_damage_at_land_level_one_without_run_growth_is_eighteen() -> void:
	# Arrange
	var config: Dictionary = _config()

	# Act
	var result: float = LandingImpact.damage(config, 1, 1.0)

	# Assert
	assert_float(result).is_equal_approx(18.0, 0.0001)


func test_shake_amplitude_at_land_level_four_is_two_and_a_half() -> void:
	# Arrange
	var config: Dictionary = _config()

	# Act
	var result: float = LandingImpact.shake_amplitude(config, 4)

	# Assert
	assert_float(result).is_equal(2.5)


func test_squad_size_at_hero_level_three_is_five() -> void:
	# Arrange
	var config: Dictionary = _config()

	# Act
	var result: int = HeroSquad.squad_size(config, 3)

	# Assert
	assert_int(result).is_equal(5)
