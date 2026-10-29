## Story: slime-nodaji story-006 (design/game-brief.md, Brief MVP feature 6).
## Covers the archer and berserker numbers (counts, arrows per volley, cooldowns, slash, damage), the
## hero types data file and the HeroRoster rules behind the hotbar. Every expected value is read from
## assets/data/hero_types.json, hero_knight.json and skill_tree.json, so a tuning change cannot break
## the suite; the suite only loads those data files and does no other I/O.
extends GdUnitTestSuite

const TYPES_PATH: String = "res://assets/data/hero_types.json"
const HERO_PATH: String = "res://assets/data/hero_knight.json"
const SLIME_PATH: String = "res://assets/data/slime_field.json"
const CHEST_PATH: String = "res://assets/data/chest_tiers.json"
const RUN_PATH: String = "res://assets/data/run.json"
const TREE_PATH: String = "res://assets/data/skill_tree.json"


func _types() -> Dictionary:
	return HeroTypes.load_config(TYPES_PATH)


func _hero() -> Dictionary:
	return HeroSquad.load_config(HERO_PATH)


func _tree() -> Dictionary:
	return SkillTree.load_config(TREE_PATH)


func _order() -> Array[String]:
	var order: Array[String] = []
	order.assign(_types()["order"])
	return order


## The highest level of a skill tree node, from the data.
func _max_level(id: String) -> int:
	return int(SkillTree.find_node(_tree(), id)["max"])


## PlayerStats of the given node levels, computed from the data files.
func _stats(levels: Dictionary) -> Dictionary:
	return PlayerStats.compute(levels, _hero(), SlimeField.load_config(SLIME_PATH), ChestTiers.load_config(CHEST_PATH),
			RunController.load_config(RUN_PATH), _tree())


func _slime(position: Vector2, radius: float) -> Slime:
	var slime: Slime = auto_free(Slime.new())
	slime.position = position
	slime.radius = radius
	return slime


func _roster(counts: Dictionary) -> HeroRoster:
	return HeroRoster.new(_order(), counts)


# --- data file --------------------------------------------------------------

func test_hero_types_file_loads_and_validates() -> void:
	# Act
	var config: Dictionary = _types()

	# Assert
	assert_bool(config.is_empty()).is_false()
	assert_array(config["order"]).is_equal(["knight", "archer", "barb"])


# --- counts -----------------------------------------------------------------

func test_archer_count_at_max_archer_level_equals_the_level() -> void:
	# Arrange
	var level: int = _max_level("archer")
	var stats: Dictionary = _stats({"archer": level})

	# Act
	var roster: HeroRoster = HeroRoster.from_stats(_order(), stats)

	# Assert
	assert_int(roster.remaining("archer")).is_equal(level)


func test_berserker_count_at_max_barb_level_equals_the_level() -> void:
	# Arrange
	var level: int = _max_level("barb")
	var stats: Dictionary = _stats({"barb": level})

	# Act
	var roster: HeroRoster = HeroRoster.from_stats(_order(), stats)

	# Assert
	assert_int(roster.remaining("barb")).is_equal(level)


func test_knight_count_matches_the_squad_size_of_the_hero_level() -> void:
	# Arrange
	var level: int = _max_level("hero")

	# Act
	var roster: HeroRoster = HeroRoster.from_stats(_order(), _stats({"hero": level}))

	# Assert
	assert_int(roster.remaining("knight")).is_equal(HeroSquad.squad_size(_hero(), level))


func test_arrows_per_volley_is_base_plus_arrows_level() -> void:
	# Arrange
	var level: int = _max_level("arrows")
	var base: int = int(_tree()["stats"]["arrows_base"])

	# Act
	var stats: Dictionary = _stats({"archer": 1, "arrows": level})

	# Assert
	assert_int(stats["arrows"]).is_equal(base + level)


# --- archer -----------------------------------------------------------------

func test_volley_with_enough_slimes_shoots_every_arrow_at_a_different_target() -> void:
	# Arrange
	var near: Slime = _slime(Vector2(10, 0), 5.0)
	var middle: Slime = _slime(Vector2(20, 0), 5.0)
	var far: Slime = _slime(Vector2(30, 0), 5.0)
	var slimes: Array[Slime] = [far, near, middle]

	# Act
	var targets: Array[Slime] = Archer.pick_targets(slimes, Vector2.ZERO, slimes.size(), near)

	# Assert
	assert_array(targets).is_equal([near, middle, far])


func test_volley_with_fewer_slimes_than_arrows_sends_the_rest_to_the_fallback_target() -> void:
	# Arrange
	var near: Slime = _slime(Vector2(10, 0), 5.0)
	var far: Slime = _slime(Vector2(30, 0), 5.0)
	var slimes: Array[Slime] = [far, near]
	var arrows: int = _stats({"archer": 1, "arrows": _max_level("arrows")})["arrows"]

	# Act
	var targets: Array[Slime] = Archer.pick_targets(slimes, Vector2.ZERO, arrows, near)

	# Assert
	assert_int(targets.size()).is_equal(arrows)
	assert_object(targets[0]).is_same(near)
	assert_object(targets[1]).is_same(far)
	for i: int in range(2, arrows):
		assert_object(targets[i]).is_same(near)


func test_volley_with_one_slime_shoots_all_arrows_at_it() -> void:
	# Arrange
	var only: Slime = _slime(Vector2(10, 0), 5.0)
	var slimes: Array[Slime] = [only]

	# Act
	var targets: Array[Slime] = Archer.pick_targets(slimes, Vector2.ZERO, 3, only)

	# Assert
	assert_array(targets).is_equal([only, only, only])


func test_archer_cooldown_is_knight_cooldown_times_multiplier() -> void:
	# Arrange
	var archer: Dictionary = _types()["types"]["archer"]
	var spd_level: int = _max_level("spd")

	# Act
	var result: float = Archer.cooldown(_hero(), archer, spd_level)

	# Assert
	assert_float(result).is_equal_approx(
			Hero.attack_cooldown(_hero(), spd_level) * float(archer["cooldown_multiplier"]), 0.0001)
	assert_float(result).is_greater(Hero.attack_cooldown(_hero(), spd_level))


func test_arrow_damage_is_attack_damage_times_multiplier() -> void:
	# Arrange
	var archer: Dictionary = _types()["types"]["archer"]
	var dmg_level: int = _max_level("dmg")

	# Act
	var result: float = Archer.arrow_damage(_hero(), archer, dmg_level)

	# Assert
	assert_float(result).is_equal_approx(
			Hero.attack_damage(_hero(), dmg_level, 1.0) * float(archer["damage_multiplier"]), 0.0001)


# --- berserker --------------------------------------------------------------

func test_berserker_cooldown_is_knight_cooldown_times_multiplier() -> void:
	# Arrange
	var barb: Dictionary = _types()["types"]["barb"]
	var spd_level: int = _max_level("spd")

	# Act
	var result: float = Berserker.cooldown(_hero(), barb, spd_level)

	# Assert
	assert_float(result).is_equal_approx(
			Hero.attack_cooldown(_hero(), spd_level) * float(barb["cooldown_multiplier"]), 0.0001)


func test_slash_damage_is_attack_damage_times_slash_multiplier() -> void:
	# Arrange
	var barb: Dictionary = _types()["types"]["barb"]
	var dmg_level: int = _max_level("dmg")

	# Act
	var result: float = Berserker.slash_damage(_hero(), barb, dmg_level)

	# Assert
	assert_float(result).is_equal_approx(
			Hero.attack_damage(_hero(), dmg_level, 1.0) * float(barb["slash"]["damage_multiplier"]), 0.0001)


func test_berserker_range_is_range_base_plus_slime_radius() -> void:
	# Arrange
	var barb: Dictionary = _types()["types"]["barb"]
	var radius: float = 6.0

	# Act
	var result: float = Berserker.attack_range_for(barb, radius)

	# Assert
	assert_float(result).is_equal(float(barb["range_base"]) + radius)


func test_slash_hits_every_slime_inside_the_radius_and_none_outside() -> void:
	# Arrange
	var barb: Dictionary = _types()["types"]["barb"]
	var reach: float = float(barb["slash"]["radius"])
	var radius: float = 6.0
	var inside_a: Slime = _slime(Vector2(reach + radius - 1.0, 0), radius)
	var inside_b: Slime = _slime(Vector2(0, -(reach + radius - 1.0)), radius)
	var outside: Slime = _slime(Vector2(reach + radius + 1.0, 0), radius)
	var slimes: Array[Slime] = [inside_a, outside, inside_b]

	# Act
	var victims: Array[Slime] = Berserker.find_victims(barb, slimes, Vector2.ZERO)

	# Assert
	assert_array(victims).is_equal([inside_a, inside_b])


# --- roster / hotbar --------------------------------------------------------

func test_roster_reports_remaining_count_per_hero_type() -> void:
	# Arrange
	var roster: HeroRoster = _roster({"knight": 4, "archer": 2, "barb": 1})

	# Act
	roster.take()

	# Assert
	assert_int(roster.remaining("knight")).is_equal(3)
	assert_int(roster.remaining("archer")).is_equal(2)
	assert_int(roster.remaining("barb")).is_equal(1)
	assert_int(roster.total_remaining()).is_equal(6)


func test_roster_hides_unowned_types() -> void:
	# Arrange
	var roster: HeroRoster = _roster({"knight": 3, "archer": 0, "barb": 2})

	# Assert
	assert_bool(roster.is_owned("knight")).is_true()
	assert_bool(roster.is_owned("archer")).is_false()
	assert_bool(roster.is_owned("barb")).is_true()


func test_roster_keeps_an_owned_type_shown_after_it_ran_out() -> void:
	# Arrange
	var roster: HeroRoster = _roster({"knight": 1, "archer": 1, "barb": 0})

	# Act
	roster.take()
	roster.take()

	# Assert
	assert_int(roster.remaining("knight")).is_equal(0)
	assert_bool(roster.is_owned("knight")).is_true()


func test_roster_refuses_to_select_a_type_with_none_left() -> void:
	# Arrange
	var roster: HeroRoster = _roster({"knight": 3, "archer": 0, "barb": 2})

	# Act
	var accepted: bool = roster.select("archer")

	# Assert
	assert_bool(accepted).is_false()
	assert_str(roster.selected).is_equal("knight")


func test_roster_selects_a_type_that_has_heroes_left() -> void:
	# Arrange
	var roster: HeroRoster = _roster({"knight": 3, "archer": 1, "barb": 2})

	# Act
	var accepted: bool = roster.select("barb")

	# Assert
	assert_bool(accepted).is_true()
	assert_str(roster.selected).is_equal("barb")


func test_roster_switches_to_the_next_type_with_heroes_when_the_selected_one_runs_out() -> void:
	# Arrange
	var roster: HeroRoster = _roster({"knight": 1, "archer": 0, "barb": 2})

	# Act
	var taken: String = roster.take()

	# Assert
	assert_str(taken).is_equal("knight")
	assert_str(roster.selected).is_equal("barb")


func test_roster_returns_the_dropped_type_and_counts_it_down() -> void:
	# Arrange
	var roster: HeroRoster = _roster({"knight": 2, "archer": 2, "barb": 0})
	roster.select("archer")

	# Act
	var taken: String = roster.take()

	# Assert
	assert_str(taken).is_equal("archer")
	assert_int(roster.remaining("archer")).is_equal(1)
	assert_str(roster.selected).is_equal("archer")


func test_roster_take_with_everything_used_returns_nothing() -> void:
	# Arrange
	var roster: HeroRoster = _roster({"knight": 1, "archer": 0, "barb": 0})
	roster.take()

	# Act
	var taken: String = roster.take()

	# Assert
	assert_str(taken).is_equal("")
	assert_int(roster.total_remaining()).is_equal(0)


func test_disabled_roster_refuses_selection_and_drops() -> void:
	# Arrange
	var roster: HeroRoster = _roster({"knight": 2, "archer": 2, "barb": 2})

	# Act
	roster.disable()

	# Assert
	assert_bool(roster.select("archer")).is_false()
	assert_str(roster.take()).is_equal("")
	assert_int(roster.total_remaining()).is_equal(6)
	assert_bool(roster.enabled).is_false()


func test_roster_from_stats_uses_the_player_stats_counts() -> void:
	# Arrange
	var stats: Dictionary = _stats({"archer": 2, "barb": 1})

	# Act
	var roster: HeroRoster = HeroRoster.from_stats(_order(), stats)

	# Assert
	assert_int(roster.remaining("knight")).is_equal(int(stats["knight"]))
	assert_int(roster.remaining("archer")).is_equal(int(stats["archer"]))
	assert_int(roster.remaining("barb")).is_equal(int(stats["barb"]))
