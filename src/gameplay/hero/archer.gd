class_name Archer
extends Hero
## An archer: the knight's drop and chase logic with a long range. Each attack shoots one arrow per
## `arrows_per_volley` at different slimes, nearest first; when there are fewer slimes than arrows the
## rest go to the attack's own target. The owner spawns the arrows from `arrow_shot`.
##
## Implements design/game-brief.md (MVP 6) via production/epics/slime-nodaji/story-006-archer-berserker-hotbar.md.
## Values ported from slime-nodaji.html (update hero section, archer branch); config: hero_types.json types.archer.

## Emitted for every arrow of a volley: where it starts, its target and its damage.
signal arrow_shot(target: Slime, origin: Vector2, amount: float)

## Arrows per volley (PlayerStats "arrows"); set by the owner right after `setup`.
var arrows_per_volley: int = 1


## Attack cooldown: the knight's cooldown x types.archer.cooldown_multiplier.
static func cooldown(hero_config: Dictionary, type_config: Dictionary, spd_level: int) -> float:
	return attack_cooldown(hero_config, spd_level) * float(type_config["cooldown_multiplier"])


## Damage of one arrow: the knight's average swing damage x types.archer.damage_multiplier (no variance).
static func arrow_damage(hero_config: Dictionary, type_config: Dictionary, dmg_level: int) -> float:
	return attack_damage(hero_config, dmg_level, 1.0) * float(type_config["damage_multiplier"])


## The targets of a volley of `count` arrows from `from`: each arrow takes the nearest slime that no
## earlier arrow took; with no such slime left it goes to `fallback`.
static func pick_targets(slimes: Array[Slime], from: Vector2, count: int, fallback: Slime) -> Array[Slime]:
	var used: Dictionary = {}
	var targets: Array[Slime] = []
	for i: int in count:
		var target: Slime = nearest_slime(slimes, from, used)
		if target == null:
			target = fallback
		used[target] = true
		targets.append(target)
	return targets


func _chase_speed() -> float:
	return float(_type_config["chase_speed"])


func _range_to(_target: Slime) -> float:
	return float(_type_config["range"])


func _attack(target: Slime) -> void:
	_cooldown = cooldown(_config, _type_config, _spd_level)
	var amount: float = arrow_damage(_config, _type_config, _dmg_level)
	var origin: Vector2 = position + Vector2(0.0, float(_type_config["shot_origin_y"]))
	for victim: Slime in pick_targets(_slimes, position, arrows_per_volley, target):
		arrow_shot.emit(victim, origin, amount)
