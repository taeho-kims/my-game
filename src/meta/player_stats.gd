class_name PlayerStats
extends RefCounted
## Final stats of the next run from the skill tree levels. The tree is the only source of modifiers
## in phase 1 (design/game-brief.md, "능력치"); equipment and cards will add sources later.
##
## Every stat that an existing system already owns is computed by that system's own static function
## (HeroSquad, Hero, LandingImpact, Magnet, SlimeField, RunController, ChestTiers), so a level is
## never turned into a stat by two different formulas. Only the stats nothing else owns yet (arrows,
## golden slime chance, slime rain chance) read assets/data/skill_tree.json "stats".
##
## Implements production/epics/slime-nodaji/story-005-skill-tree-save.md. Values ported from
## slime-nodaji.html (stats); spatial values are halved for the 640x360 base.

## Computes the stats for `levels` (a Dictionary {node id: int}). The configs are the loaded data
## files: hero_knight.json, slime_field.json, chest_tiers.json, run.json and skill_tree.json.
##
## Keys: knight, archer, barb (counts), dmg (average swing damage), cooldown (s), arrows, land_damage,
## land_radius (px), magnet_radius (px), coin_multiplier, time (s), max_slimes, golden (chance),
## rain (chance), goblin and boss (bool), chest_bonus (multiplier added per chest level and tier number).
static func compute(levels: Dictionary, hero_config: Dictionary, slime_config: Dictionary,
		chest_config: Dictionary, run_config: Dictionary, tree_config: Dictionary) -> Dictionary:
	var stats: Dictionary = tree_config["stats"]
	var copper_base: float = SlimeField.coin_value(slime_config, "copper", 0, 0)
	return {
		"knight": HeroSquad.squad_size(hero_config, SkillTree.level(levels, "hero")),
		"archer": SkillTree.level(levels, "archer"),
		"barb": SkillTree.level(levels, "barb"),
		"dmg": Hero.attack_damage(hero_config, SkillTree.level(levels, "dmg"), 1.0),
		"cooldown": Hero.attack_cooldown(hero_config, SkillTree.level(levels, "spd")),
		"arrows": int(stats["arrows_base"]) + SkillTree.level(levels, "arrows"),
		"land_damage": LandingImpact.damage(hero_config, SkillTree.level(levels, "land"), 1.0),
		"land_radius": LandingImpact.radius(hero_config, SkillTree.level(levels, "land")),
		"magnet_radius": Magnet.radius(chest_config, SkillTree.level(levels, "magnet")),
		"coin_multiplier": SlimeField.coin_value(slime_config, "copper", 0, SkillTree.level(levels, "coin")) / copper_base,
		"time": RunController.run_duration(run_config, SkillTree.level(levels, "time")),
		"max_slimes": SlimeField.max_slimes(slime_config, SkillTree.level(levels, "density")),
		"golden": float(stats["golden_base"]) + float(stats["golden_per_level"]) * SkillTree.level(levels, "golden"),
		"rain": float(stats["rain_per_level"]) * SkillTree.level(levels, "rain"),
		"goblin": SkillTree.level(levels, "goblin") > 0,
		"boss": SkillTree.level(levels, "boss") > 0,
		"chest_bonus": float(chest_config["chest_bonus_per_level"]) * SkillTree.level(levels, "chest"),
	}
