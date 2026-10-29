class_name Berserker
extends Hero
## A berserker: the knight's drop and chase logic with a short range. Each attack is a spinning slash
## that hits every slime within the slash radius around the berserker.
##
## Implements design/game-brief.md (MVP 6) via production/epics/slime-nodaji/story-006-archer-berserker-hotbar.md.
## Values ported from slime-nodaji.html (update hero section, barb branch; drawHero); config:
## hero_types.json types.barb. The slash hits slimes whose centre is within radius + slime radius.


## Attack cooldown: the knight's cooldown x types.barb.cooldown_multiplier.
static func cooldown(hero_config: Dictionary, type_config: Dictionary, spd_level: int) -> float:
	return attack_cooldown(hero_config, spd_level) * float(type_config["cooldown_multiplier"])


## Damage of one slash per slime: the knight's average swing damage x slash.damage_multiplier (no variance).
static func slash_damage(hero_config: Dictionary, type_config: Dictionary, dmg_level: int) -> float:
	return attack_damage(hero_config, dmg_level, 1.0) * float(type_config["slash"]["damage_multiplier"])


## Distance at which the berserker slashes a slime of the given radius: range_base + the slime radius.
static func attack_range_for(type_config: Dictionary, slime_radius: float) -> float:
	return float(type_config["range_base"]) + slime_radius


## Slimes caught by a slash at `center`: distance < slash.radius + slime radius. Returns a new array.
static func find_victims(type_config: Dictionary, slimes: Array[Slime], center: Vector2) -> Array[Slime]:
	var radius: float = type_config["slash"]["radius"]
	var victims: Array[Slime] = []
	for slime: Slime in slimes:
		if not slime.is_airborne() and center.distance_to(slime.position) < radius + slime.radius:
			victims.append(slime)
	return victims


func _chase_speed() -> float:
	return float(_type_config["chase_speed"])


func _range_to(target: Slime) -> float:
	return attack_range_for(_type_config, target.radius)


func _attack(_target: Slime) -> void:
	_cooldown = cooldown(_config, _type_config, _spd_level)
	_swing_left = float(_type_config["slash"]["swing_time"])
	var amount: float = slash_damage(_config, _type_config, _dmg_level)
	for victim: Slime in find_victims(_type_config, _slimes, position):
		hit_dealt.emit(victim, amount)


## The slash: a spinning arc around the body and a ring of the slash radius that fades with the swing.
func _draw_attack(base_y: float) -> void:
	var slash: Dictionary = _type_config["slash"]
	var color: Color = Color.html(slash["color"])
	var spin: float = _swing_left * float(slash["arc_spin"])
	draw_arc(Vector2(0.0, base_y + float(slash["arc_center_y"])), float(slash["arc_radius"]), spin,
			spin + float(slash["arc_span"]), 12, color, float(slash["arc_width"]))
	var ring_left: float = clampf(_swing_left - (float(slash["swing_time"]) - float(slash["ring_life"])), 0.0,
			float(slash["ring_life"]))
	if ring_left > 0.0:
		draw_arc(Vector2.ZERO, float(slash["radius"]), 0.0, TAU, 32,
				Color(color, color.a * ring_left / float(slash["ring_life"])), float(slash["arc_width"]))
