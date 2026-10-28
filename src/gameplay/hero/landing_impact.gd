class_name LandingImpact
extends Node2D
## Landing effects of a dropped knight: expanding ring, dust particles, screen shake amplitude
## and a low sawtooth blip. Also holds the pure landing formulas (radius, damage, shake,
## victim selection) so they stay testable.
##
## Implements design/game-brief.md (MVP 1) via production/epics/slime-nodaji/story-002-hero-drop-combat.md.
## Values ported from slime-nodaji.html (land, blip, shake handling in update/draw).
## Screen shake is reported through `shake_changed`; the owner decides what to move.

## Emitted every frame while shaking with the pixel offset to apply, then once with ZERO.
signal shake_changed(offset: Vector2)

## Amplitude floor of the synthesised blip's exponential decay (prototype: 0.0001).
const SOUND_FLOOR: float = 0.0001
const RING_POINTS: int = 32

var _config: Dictionary = {}
var _rng: RandomNumberGenerator
var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _shake: float = 0.0
var _sound: AudioStreamPlayer


func _process(delta: float) -> void:
	advance(delta)


## Impact radius: base + per_level * land level.
static func radius(config: Dictionary, land_level: int) -> float:
	var landing: Dictionary = config["landing"]
	return float(landing["base_radius"]) + float(landing["radius_per_level"]) * land_level


## Impact damage: (base + per_level * land level) * run_scale ^ exponent. `run_scale` is the
## per-run growth factor (1.07 ^ runs); the 0.5 exponent gives the 1.07 ^ (runs / 2) rule.
static func damage(config: Dictionary, land_level: int, run_scale: float) -> float:
	var landing: Dictionary = config["landing"]
	var base: float = float(landing["base_damage"]) + float(landing["damage_per_level"]) * land_level
	return base * pow(run_scale, float(landing["run_scale_exponent"]))


## Screen shake amplitude in pixels: base + per_level * land level.
static func shake_amplitude(config: Dictionary, land_level: int) -> float:
	var landing: Dictionary = config["landing"]
	return float(landing["shake_base"]) + float(landing["shake_per_level"]) * land_level


## True when a slime is hit: hypot(dx, dy * vertical_weight) < radius + slime radius.
static func is_hit(config: Dictionary, impact_pos: Vector2, impact_radius: float,
		slime_pos: Vector2, slime_radius: float) -> bool:
	var delta: Vector2 = slime_pos - impact_pos
	var weight: float = config["landing"]["vertical_weight"]
	return Vector2(delta.x, delta.y * weight).length() < impact_radius + slime_radius


## Slimes caught by an impact. All slimes are grounded for now, so no height check is needed
## (airborne slimes would be skipped here). Returns a new array, safe to iterate while killing.
static func find_victims(config: Dictionary, slimes: Array[Slime], impact_pos: Vector2,
		impact_radius: float) -> Array[Slime]:
	var victims: Array[Slime] = []
	for slime: Slime in slimes:
		if is_hit(config, impact_pos, impact_radius, slime.position, slime.radius):
			victims.append(slime)
	return victims


## Synthesises the landing blip: a sawtooth whose pitch rises by `pitch_rise` over `duration`
## while its volume decays exponentially (the prototype's oscillator + gain ramp).
static func make_blip(sound: Dictionary) -> AudioStreamWAV:
	var rate: int = int(sound["mix_rate"])
	var count: int = maxi(1, int(float(rate) * float(sound["duration"])))
	var volume: float = sound["volume"]
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	for i: int in count:
		var progress: float = float(i) / float(count)
		var freq: float = float(sound["frequency"]) * pow(float(sound["pitch_rise"]), progress)
		var gain: float = volume * pow(SOUND_FLOOR / volume, progress)
		phase = fposmod(phase + freq / float(rate), 1.0)
		data.encode_s16(i * 2, int(clampf((phase * 2.0 - 1.0) * gain, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


## Prepares the effects from the full hero_knight config.
func setup(config: Dictionary, rng: RandomNumberGenerator) -> void:
	_config = config
	_rng = rng
	_sound = AudioStreamPlayer.new()
	_sound.stream = make_blip(config["sound"])
	add_child(_sound)


## Plays the landing effects at `ground_pos`: ring, dust, blip and a shake of `shake_amount` px.
func trigger(ground_pos: Vector2, impact_radius: float, shake_amount: float) -> void:
	var landing: Dictionary = _config["landing"]
	_shake = maxf(_shake, shake_amount)
	_rings.append({"pos": ground_pos, "radius": impact_radius, "age": 0.0})
	var speed_x: float = landing["particle_speed_x"]
	for i: int in int(landing["particle_count"]):
		_particles.append({
			"pos": ground_pos,
			"vel": Vector2(_rng.randf_range(-speed_x, speed_x),
					_rng.randf_range(landing["particle_vy_min"], landing["particle_vy_max"])),
			"age": 0.0,
		})
	_sound.play()


## Steps the rings, particles and shake by `delta` seconds.
func advance(delta: float) -> void:
	if _config.is_empty():
		return
	var landing: Dictionary = _config["landing"]
	for i: int in range(_rings.size() - 1, -1, -1):
		_rings[i]["age"] += delta
		if _rings[i]["age"] >= float(landing["ring_time"]):
			_rings.remove_at(i)
	for i: int in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[i]
		particle["age"] += delta
		var velocity: Vector2 = particle["vel"]
		velocity.y += float(landing["particle_gravity"]) * delta
		particle["vel"] = velocity
		particle["pos"] = Vector2(particle["pos"]) + velocity * delta
		if particle["age"] >= float(landing["particle_life"]):
			_particles.remove_at(i)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - float(landing["shake_decay"]) * delta)
		var offset := Vector2.ZERO
		if _shake > 0.0:
			offset = (Vector2(_rng.randf_range(-_shake, _shake), _rng.randf_range(-_shake, _shake))
					* float(landing["shake_offset_factor"])).round()
		shake_changed.emit(offset)
	queue_redraw()


func _draw() -> void:
	if _config.is_empty():
		return
	var landing: Dictionary = _config["landing"]
	var ring_color: Color = Color.html(landing["ring_color"])
	for ring: Dictionary in _rings:
		var remaining: float = 1.0 - float(ring["age"]) / float(landing["ring_time"])
		var rx: float = float(ring["radius"]) * (1.0 - float(landing["ring_shrink"]) * remaining)
		var ry: float = rx * float(landing["ellipse_ratio"])
		var points := PackedVector2Array()
		for i: int in RING_POINTS + 1:
			var angle: float = TAU * float(i) / float(RING_POINTS)
			points.append((ring["pos"] + Vector2(cos(angle) * rx, sin(angle) * ry)).round())
		draw_polyline(points, Color(ring_color, remaining), float(landing["ring_width"]))
	var dust_color: Color = Color.html(landing["particle_color"])
	var size: float = landing["particle_size"]
	for particle: Dictionary in _particles:
		var remaining: float = 1.0 - float(particle["age"]) / float(landing["particle_life"])
		draw_rect(Rect2(particle["pos"].round(), Vector2(size, size)), Color(dust_color, remaining))
