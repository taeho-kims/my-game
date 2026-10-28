class_name ChestBurst
extends RefCounted
## Chest opening ("burst") rules: the chest's move-to-centre transform, the shake and dim
## windows, the loot count and kind rolls, the count-up of the base gold and the loot's flight to
## the ring around the chest. Pure static functions on plain data, no node or rendering access.
##
## Implements design/game-brief.md (MVP 4) via production/epics/slime-nodaji/story-004-run-timer-burst.md.
## Values ported from slime-nodaji.html (beginBurst, updateBurst, draw burst); spatial values are
## halved for the 640x360 base. The loot lands on a ring around the chest instead of the prototype's
## floor (a playtest change, see design/game-brief.md). `config` is the full assets/data/run.json config.
##
## A loot coin is a Dictionary: "id" (int, unique per run), "pos" (Vector2, ground point), "kind"
## ("gem" | "silver" | "copper"), "spin" (float, radians), "landed" (bool, true once it reached its
## spot on the ring) plus the flight keys of `make_ring_loot`.

## Loot kinds in the order used for RunResult.drops.
const KINDS: Array[String] = ["gem", "silver", "copper"]


## Move progress k = clamp(t / move_time, 0, 1) after `t` seconds of the burst.
static func move_progress(config: Dictionary, t: float) -> float:
	return clampf(t / float(config["burst"]["move_time"]), 0.0, 1.0)


## Ease-out-cubic e = 1 - (1 - k) ^ 3 of the chest's move, 0 at t = 0 and 1 from move_time on.
static func ease_out(config: Dictionary, t: float) -> float:
	return 1.0 - pow(1.0 - move_progress(config, t), 3.0)


## Chest scale at time `t`: 1 + e * scale_gain.
static func chest_scale(config: Dictionary, t: float) -> float:
	return 1.0 + ease_out(config, t) * float(config["burst"]["scale_gain"])


## Where the open chest ends up: horizontal centre, vertical centre + center_offset_y.
static func chest_target(config: Dictionary, field_size: Vector2) -> Vector2:
	return Vector2(field_size.x / 2.0, field_size.y / 2.0 + float(config["burst"]["center_offset_y"]))


## Chest position at time `t`, moving from `start` (its field position) to the centre with the ease.
static func chest_position(config: Dictionary, start: Vector2, field_size: Vector2, t: float) -> Vector2:
	return start.lerp(chest_target(config, field_size), ease_out(config, t))


## Alpha of the dark screen overlay: dim_alpha_max * e.
static func dim_alpha(config: Dictionary, t: float) -> float:
	return float(config["burst"]["dim_alpha_max"]) * ease_out(config, t)


## True from open_time on: the chest opens at t >= open_time.
static func is_open_time(config: Dictionary, t: float) -> bool:
	return t >= float(config["burst"]["open_time"])


## True while the chest shakes: after shake_start (strict) and not yet opened.
static func is_shaking(config: Dictionary, t: float, opened: bool) -> bool:
	return not opened and t > float(config["burst"]["shake_start"])


## Horizontal shake offset in px for a uniform `roll` in [0, 1): between -amplitude and +amplitude.
static func shake_offset(config: Dictionary, roll: float) -> float:
	return (roll * 2.0 - 1.0) * float(config["burst"]["shake_amplitude"])


## Number of loot coins for a base gold `total`: min(count_max, floor(count_base + sqrt(total) * count_per_sqrt_total)).
static func drop_count(config: Dictionary, total: int) -> int:
	var rain: Dictionary = config["rain"]
	var raw: float = float(rain["count_base"]) + sqrt(float(total)) * float(rain["count_per_sqrt_total"])
	return mini(int(rain["count_max"]), floori(raw))


## Maps a uniform `roll` in [0, 1) to a loot kind: gem, then silver, then copper (10% / 27% / 63%).
static func roll_kind(config: Dictionary, roll: float) -> String:
	var chance: Dictionary = config["rain"]["kind_chance"]
	var gem: float = chance["gem"]
	var silver: float = chance["silver"]
	if roll < gem:
		return "gem"
	if roll < gem + silver:
		return "silver"
	return "copper"


## Base gold: round(chest value * tier multiplier) with the tier taken from the value and the run
## scale. `chest_config` is the chest_tiers config.
static func base_gold(chest_config: Dictionary, value: float, run_scale: float, chest_level: int) -> int:
	var tier: int = ChestTiers.tier_of(chest_config, value, run_scale)
	return ChestTiers.total(chest_config, value, tier, chest_level)


## One count-up step of the gold shown over the open chest, capped at `total`:
## shown + total * delta / count_up_time + count_up_min_rate * delta.
## The prototype added a flat +1 per frame; count_up_min_rate (units per second, 60 = the same at
## 60 fps) keeps the count-up frame-rate independent.
static func shown_gold_step(config: Dictionary, shown: float, total: int, delta: float) -> float:
	var burst: Dictionary = config["burst"]
	var step: float = float(total) * delta / float(burst["count_up_time"]) + float(burst["count_up_min_rate"]) * delta
	return minf(float(total), shown + step)


## True when a rain blip plays this frame: `roll` (uniform in [0, 1)) is below blip.chance.
static func blip_due(config: Dictionary, roll: float) -> bool:
	return roll < float(config["rain"]["blip"]["chance"])


## Pitch of a rain blip in Hz for a uniform `roll`: between blip.frequency_min and frequency_max.
static func blip_frequency(config: Dictionary, roll: float) -> float:
	var blip: Dictionary = config["rain"]["blip"]
	return lerpf(float(blip["frequency_min"]), float(blip["frequency_max"]), roll)


## Radius a loot coin lands at on the ring around the chest: between ring.inner_radius and
## inner_radius + ring.width for `roll` in [0, 1]; gems only use the outer ring.gem_band share of the width.
static func ring_radius(config: Dictionary, kind: String, roll: float) -> float:
	var ring: Dictionary = config["ring"]
	var inner: float = ring["inner_radius"]
	var outer: float = inner + float(ring["width"])
	var low: float = outer - float(ring["gem_band"]) * float(ring["width"]) if kind == "gem" else inner
	return lerpf(low, outer, roll)


## A new loot coin that pops out of the open chest and flies to a point on the ring around it:
## angle = `angle_roll` * TAU, radius from `ring_radius`. The flight lasts distance / ring.spread_speed.
## Besides the common keys it carries "origin", "target", "elapsed", "duration" and "height".
static func make_ring_loot(config: Dictionary, field_size: Vector2, id: int, kind: String, angle_roll: float,
		radius_roll: float, spin: float) -> Dictionary:
	var origin: Vector2 = chest_target(config, field_size)
	var target: Vector2 = origin + Vector2.from_angle(angle_roll * TAU) * ring_radius(config, kind, radius_roll)
	return {"id": id, "pos": origin, "kind": kind, "spin": spin, "landed": false,
			"origin": origin, "target": target, "elapsed": 0.0,
			"duration": origin.distance_to(target) / float(config["ring"]["spread_speed"]), "height": 0.0}


## Steps one ring loot coin by `delta` seconds: it moves in a straight line to its target at
## ring.spread_speed while its height follows a ballistic arc under rain.gravity (0 at both ends).
## Sets "landed" and snaps to the target when the flight is over.
static func step_ring_loot(config: Dictionary, loot: Dictionary, delta: float) -> void:
	if loot["landed"]:
		return
	var rain: Dictionary = config["rain"]
	var duration: float = loot["duration"]
	var elapsed: float = minf(float(loot["elapsed"]) + delta, duration)
	loot["elapsed"] = elapsed
	loot["spin"] = float(loot["spin"]) + delta * float(rain["spin_rate"])
	loot["pos"] = (loot["origin"] as Vector2).lerp(loot["target"], elapsed / duration)
	loot["height"] = 0.5 * float(rain["gravity"]) * elapsed * (duration - elapsed)
	if elapsed >= duration:
		loot["landed"] = true
		loot["height"] = 0.0


## Puts a ring loot coin on its target and stops it (start of the final harvest).
static func settle_ring_loot(loot: Dictionary) -> void:
	loot["pos"] = loot["target"]
	loot["height"] = 0.0
	loot["landed"] = true


## True when every loot coin reached its spot on the ring (an empty list counts as landed).
static func all_landed(loot: Array[Dictionary]) -> bool:
	for coin: Dictionary in loot:
		if not coin["landed"]:
			return false
	return true


## Counts the loot per kind for RunResult.drops: [{"kind", "count"}] in KINDS order, zero counts omitted.
static func tally_drops(loot: Array[Dictionary]) -> Array:
	var drops: Array = []
	for kind: String in KINDS:
		var count: int = 0
		for coin: Dictionary in loot:
			if coin["kind"] == kind:
				count += 1
		if count > 0:
			drops.append({"kind": kind, "count": count})
	return drops
