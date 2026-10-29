## Story: slime-nodaji story-005 (design/game-brief.md, Brief MVP feature 5 and the "확장 설계 원칙 — 저장 데이터").
## Reads the real assets/data/skill_tree.json (a data-conformance check against the prototype's NODES in
## slime-nodaji.html) and checks the skill tree rules, the next-run stats and the versioned save, including
## the file round trip under user://. Expected numbers are computed by hand from the prototype formulas.
extends GdUnitTestSuite

const TREE_PATH: String = "res://assets/data/skill_tree.json"
const HERO_PATH: String = "res://assets/data/hero_knight.json"
const SLIME_PATH: String = "res://assets/data/slime_field.json"
const CHEST_PATH: String = "res://assets/data/chest_tiers.json"
const RUN_PATH: String = "res://assets/data/run.json"
const TEST_SAVE_PATH: String = "user://skill_tree_save_test.json"
const VERSION: int = 1

## Prototype NODES: id -> [x, y, max, base, g, req].
const PROTOTYPE_NODES: Dictionary = {
	"hero": [3, 2, 10, 8, 1.55, ""], "dmg": [2, 2, 10, 12, 1.6, "hero"], "spd": [1, 2, 8, 30, 1.7, "dmg"],
	"archer": [2, 1, 5, 40, 1.9, "dmg"], "arrows": [1, 1, 4, 90, 2.1, "archer"], "land": [3, 1, 8, 15, 1.6, "hero"],
	"barb": [4, 1, 3, 160, 2.4, "land"], "magnet": [4, 2, 8, 10, 1.55, "hero"], "coin": [5, 2, 10, 20, 1.6, "magnet"],
	"golden": [5, 1, 5, 70, 1.9, "coin"], "chest": [5, 3, 6, 60, 1.8, "coin"], "boss": [6, 2, 1, 400, 1.0, "coin"],
	"time": [3, 3, 8, 14, 1.65, "hero"], "density": [2, 3, 8, 18, 1.6, "time"], "rain": [1, 3, 3, 120, 2.0, "density"],
	"goblin": [4, 3, 1, 220, 1.0, "time"],
}


func after_test() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


# --- Data: the 16 nodes -------------------------------------------------------------------------------

func test_data_file_loads_and_defines_the_16_prototype_nodes() -> void:
	# Arrange
	var config: Dictionary = SkillTree.load_config(TREE_PATH)

	# Act
	var ids: Array[String] = []
	for node: Dictionary in config["nodes"]:
		ids.append(node["id"])

	# Assert
	assert_int(ids.size()).is_equal(16)
	assert_array(ids).contains_exactly_in_any_order(PROTOTYPE_NODES.keys())


func test_data_nodes_match_the_prototype_max_base_growth_prerequisite_and_grid_position() -> void:
	# Arrange
	var config: Dictionary = SkillTree.load_config(TREE_PATH)

	# Act / Assert
	for id: String in PROTOTYPE_NODES:
		var expected: Array = PROTOTYPE_NODES[id]
		var node: Dictionary = SkillTree.find_node(config, id)
		assert_int(int(node["x"])).is_equal(expected[0])
		assert_int(int(node["y"])).is_equal(expected[1])
		assert_int(int(node["max"])).is_equal(expected[2])
		assert_float(node["base"]).is_equal(float(expected[3]))
		assert_float(node["g"]).is_equal_approx(float(expected[4]), 0.0001)
		assert_str(str(node.get("req", ""))).is_equal(expected[5])


# --- Cost, unlock, purchase ---------------------------------------------------------------------------

func test_cost_is_base_times_growth_to_the_current_level_rounded() -> void:
	# Arrange — hero: 8 * 1.55^0 = 8, 8 * 1.55^3 = 29.79 -> 30; coin: 20 * 1.6^2 = 51.2 -> 51
	var config: Dictionary = SkillTree.load_config(TREE_PATH)

	# Act / Assert
	assert_int(SkillTree.cost(SkillTree.find_node(config, "hero"), 0)).is_equal(8)
	assert_int(SkillTree.cost(SkillTree.find_node(config, "hero"), 3)).is_equal(30)
	assert_int(SkillTree.cost(SkillTree.find_node(config, "coin"), 2)).is_equal(51)


func test_node_needs_its_prerequisite_at_level_one() -> void:
	# Arrange
	var config: Dictionary = SkillTree.load_config(TREE_PATH)

	# Act / Assert
	assert_bool(SkillTree.is_unlocked(config, {}, "hero")).is_true()
	assert_bool(SkillTree.is_unlocked(config, {}, "dmg")).is_false()
	assert_bool(SkillTree.is_unlocked(config, {"hero": 1}, "dmg")).is_true()


func test_purchase_spends_the_cost_and_raises_the_level_without_touching_the_input() -> void:
	# Arrange
	var config: Dictionary = SkillTree.load_config(TREE_PATH)
	var levels: Dictionary = {"hero": 1}

	# Act — hero at level 1 costs round(8 * 1.55) = 12
	var outcome: Dictionary = SkillTree.purchase(config, levels, 20, "hero")

	# Assert
	assert_bool(outcome["ok"]).is_true()
	assert_int(outcome["gold"]).is_equal(8)
	assert_int((outcome["levels"] as Dictionary)["hero"]).is_equal(2)
	assert_int(levels["hero"]).is_equal(1)


func test_purchase_reports_the_missing_gold_when_it_is_too_little() -> void:
	# Arrange
	var config: Dictionary = SkillTree.load_config(TREE_PATH)

	# Act — hero level 0 costs 8
	var outcome: Dictionary = SkillTree.purchase(config, {}, 5, "hero")

	# Assert
	assert_bool(outcome["ok"]).is_false()
	assert_str(outcome["reason"]).is_equal(SkillTree.REASON_GOLD)
	assert_int(outcome["shortfall"]).is_equal(3)
	assert_int(outcome["gold"]).is_equal(5)


func test_purchase_refuses_a_locked_a_maxed_and_an_unknown_node() -> void:
	# Arrange
	var config: Dictionary = SkillTree.load_config(TREE_PATH)

	# Act / Assert
	assert_str(SkillTree.purchase(config, {}, 9999, "dmg")["reason"]).is_equal(SkillTree.REASON_LOCKED)
	assert_str(SkillTree.purchase(config, {"hero": 10}, 9999, "hero")["reason"]).is_equal(SkillTree.REASON_MAX)
	assert_str(SkillTree.purchase(config, {}, 9999, "nope")["reason"]).is_equal(SkillTree.REASON_UNKNOWN)


func test_node_state_is_locked_maxed_affordable_or_unaffordable() -> void:
	# Arrange
	var config: Dictionary = SkillTree.load_config(TREE_PATH)

	# Act / Assert — hero level 0 costs 8
	assert_int(SkillTree.node_state(config, {}, 999, "spd")).is_equal(SkillTree.State.LOCKED)
	assert_int(SkillTree.node_state(config, {"hero": 10}, 0, "hero")).is_equal(SkillTree.State.MAXED)
	assert_int(SkillTree.node_state(config, {}, 8, "hero")).is_equal(SkillTree.State.AFFORDABLE)
	assert_int(SkillTree.node_state(config, {}, 7, "hero")).is_equal(SkillTree.State.UNAFFORDABLE)


# --- Stats from the levels ----------------------------------------------------------------------------

func test_player_stats_apply_the_prototype_formulas_to_the_levels() -> void:
	# Arrange
	var tree: Dictionary = SkillTree.load_config(TREE_PATH)
	var levels: Dictionary = {"hero": 3, "dmg": 4, "spd": 2, "arrows": 2, "land": 2, "magnet": 3, "coin": 5,
			"time": 2, "density": 3, "golden": 2, "rain": 2, "chest": 4, "goblin": 1, "archer": 1, "barb": 1}

	# Act
	var stats: Dictionary = PlayerStats.compute(levels, HeroSquad.load_config(HERO_PATH), SlimeField.load_config(SLIME_PATH),
			ChestTiers.load_config(CHEST_PATH), RunController.load_config(RUN_PATH), tree)

	# Assert
	assert_int(stats["knight"]).is_equal(5)
	assert_float(stats["dmg"]).is_equal_approx(10.0, 0.0001)
	assert_float(stats["cooldown"]).is_equal_approx(0.75 / 1.3, 0.0001)
	assert_int(stats["arrows"]).is_equal(3)
	assert_float(stats["land_damage"]).is_equal_approx(28.0, 0.0001)
	assert_float(stats["land_radius"]).is_equal_approx(30.0, 0.0001)
	assert_float(stats["magnet_radius"]).is_equal_approx(39.0, 0.0001)
	assert_float(stats["coin_multiplier"]).is_equal_approx(2.5, 0.0001)
	assert_float(stats["time"]).is_equal_approx(32.0, 0.0001)
	assert_int(stats["max_slimes"]).is_equal(24)
	assert_float(stats["golden"]).is_equal_approx(0.055, 0.0001)
	assert_float(stats["rain"]).is_equal_approx(0.6, 0.0001)
	assert_float(stats["chest_bonus"]).is_equal_approx(0.4, 0.0001)
	assert_bool(stats["goblin"]).is_true()
	assert_bool(stats["boss"]).is_false()


# --- Save: format, migration, preservation ------------------------------------------------------------

func test_save_round_trips_gold_runs_best_and_levels_through_a_file() -> void:
	# Arrange
	var data: SaveData = SaveData.new_game(VERSION)
	data.gold = 123
	data.runs = 4
	data.best = 99
	data.levels = {"hero": 2, "coin": 1}

	# Act
	var written: bool = data.save_file(TEST_SAVE_PATH)
	var loaded: SaveData = SaveData.load_file(TEST_SAVE_PATH, VERSION)

	# Assert
	assert_bool(written).is_true()
	assert_int(loaded.gold).is_equal(123)
	assert_int(loaded.runs).is_equal(4)
	assert_int(loaded.best).is_equal(99)
	assert_int(loaded.levels["hero"]).is_equal(2)
	assert_int(loaded.levels["coin"]).is_equal(1)


func test_save_file_has_a_top_level_version_and_system_sub_keys() -> void:
	# Arrange
	var data: SaveData = SaveData.new_game(VERSION)
	data.gold = 7
	data.levels = {"hero": 1}

	# Act
	var raw: Dictionary = data.to_dict()

	# Assert
	assert_int(raw["version"]).is_equal(VERSION)
	assert_int(raw["meta"]["gold"]).is_equal(7)
	assert_bool((raw["meta"] as Dictionary).has("runs")).is_true()
	assert_bool((raw["meta"] as Dictionary).has("best")).is_true()
	assert_int(raw["skill_tree"]["levels"]["hero"]).is_equal(1)


func test_missing_keys_take_their_defaults() -> void:
	# Act
	var loaded: SaveData = SaveData.from_variant({"version": 1, "meta": {"gold": 5}}, VERSION)

	# Assert
	assert_int(loaded.gold).is_equal(5)
	assert_int(loaded.runs).is_equal(0)
	assert_int(loaded.best).is_equal(0)
	assert_bool(loaded.levels.is_empty()).is_true()


func test_unknown_keys_are_kept_and_written_back_unchanged() -> void:
	# Arrange — keys of later systems at the top level and inside meta and skill_tree
	var raw: Dictionary = {"version": 1, "meta": {"gold": 5, "streak": 7},
			"skill_tree": {"levels": {"hero": 1, "future_node": 3}, "tab": "a"},
			"maps": {"meadow": {"cleared": true}}, "cards": [1, 2]}

	# Act
	var written: Dictionary = SaveData.from_variant(raw, VERSION).to_dict()

	# Assert
	assert_bool(written["maps"]["meadow"]["cleared"]).is_true()
	assert_int((written["cards"] as Array).size()).is_equal(2)
	assert_int(written["meta"]["streak"]).is_equal(7)
	assert_str(written["skill_tree"]["tab"]).is_equal("a")
	assert_int(written["skill_tree"]["levels"]["future_node"]).is_equal(3)


func test_version_zero_prototype_save_is_migrated_to_the_sub_key_format() -> void:
	# Arrange — the prototype's flat {gold, runs, lv, best}
	var legacy: Dictionary = {"gold": 50, "runs": 3, "lv": {"hero": 2}, "best": 40}

	# Act
	var loaded: SaveData = SaveData.from_variant(legacy, VERSION)

	# Assert
	assert_int(loaded.gold).is_equal(50)
	assert_int(loaded.runs).is_equal(3)
	assert_int(loaded.best).is_equal(40)
	assert_int(loaded.levels["hero"]).is_equal(2)
	assert_int(loaded.version).is_equal(VERSION)
	assert_bool((loaded.to_dict() as Dictionary).has("lv")).is_false()


func test_a_missing_or_corrupt_file_or_garbage_content_starts_a_new_game() -> void:
	# Arrange
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()

	# Act / Assert
	assert_int(SaveData.load_file(TEST_SAVE_PATH, VERSION).gold).is_equal(0)
	assert_int(SaveData.load_file("user://no_such_save_file.json", VERSION).runs).is_equal(0)
	assert_int(SaveData.from_variant("oops", VERSION).gold).is_equal(0)
	assert_int(SaveData.from_variant(null, VERSION).runs).is_equal(0)


func test_wrong_types_and_negative_numbers_fall_back_to_the_defaults() -> void:
	# Arrange
	var raw: Dictionary = {"version": 1, "meta": {"gold": "lots", "runs": -4},
			"skill_tree": {"levels": {"hero": "x", "dmg": -2}}}

	# Act
	var loaded: SaveData = SaveData.from_variant(raw, VERSION)

	# Assert
	assert_int(loaded.gold).is_equal(0)
	assert_int(loaded.runs).is_equal(0)
	assert_bool(loaded.levels.has("hero")).is_false()
	assert_int(loaded.levels["dmg"]).is_equal(0)
