class_name Magnet
extends Node2D
## The cursor magnet: tracks the pointer, pulls ground coins inside its radius along a curved
## path into the chest, deposits each coin's value exactly once on arrival, draws the radius
## ring at the cursor and plays a throttled pitch-per-kind blip.
##
## Implements design/game-brief.md (MVP 3) via production/epics/slime-nodaji/story-003-magnet-chest-tiers.md.
## Values ported from slime-nodaji.html (stats().magnet, update coin loop, blip, draw magnet ring),
## spatial values halved for the 640x360 base.
## Cursor and coin positions are in the shared field coordinates: the Magnet, the SlimeField and
## the Chest must share the same parent and have an identity transform relative to it.

## Amplitude floor of the synthesised blip's exponential decay (prototype: 0.0001).
const SOUND_FLOOR: float = 0.0001
## "Never played" marker for the blip throttle, far enough in the past to always pass.
const NEVER_PLAYED: int = -(1 << 31)
const RING_POINTS: int = 48

var _config: Dictionary = {}
var _rng: RandomNumberGenerator
var _coins: Array[Coin]
var _chest: Chest
var _field_rect: Rect2
var _radius: float = 0.0
var _flights: Array[Dictionary] = []
var _cursor: Vector2 = Vector2.ZERO
var _cursor_active: bool = false
var _player: AudioStreamPlayer
var _streams: Dictionary = {}
var _last_blip_msec: int = NEVER_PLAYED


## Magnet radius: base + per_level * magnet level.
static func radius(config: Dictionary, magnet_level: int) -> float:
	var magnet: Dictionary = config["magnet"]
	return float(magnet["base_radius"]) + float(magnet["radius_per_level"]) * magnet_level


## True when a coin at `coin_pos` is inside the magnet: hypot(dx, dy) < radius (strict).
static func in_range(cursor: Vector2, coin_pos: Vector2, magnet_radius: float) -> bool:
	return cursor.distance_to(coin_pos) < magnet_radius


## Point on the quadratic Bezier curve start -> control -> end at progress `t` in [0, 1].
static func bezier(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return start * (u * u) + control * (2.0 * u * t) + end * (t * t)


## True when a blip may play: more than `throttle_ms` since the last one that played.
static func blip_allowed(last_msec: int, now_msec: int, throttle_ms: float) -> bool:
	return float(now_msec - last_msec) > throttle_ms


## Synthesises one absorb blip: a square wave whose pitch rises by `pitch_rise` over `duration`
## while its volume decays exponentially (the prototype's oscillator + gain ramp).
## `sound` is the config's "sound" section, `frequency` the starting pitch in Hz.
static func make_blip(sound: Dictionary, frequency: float) -> AudioStreamWAV:
	var rate: int = int(sound["mix_rate"])
	var count: int = maxi(1, int(float(rate) * float(sound["duration"])))
	var volume: float = sound["volume"]
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	for i: int in count:
		var progress: float = float(i) / float(count)
		var freq: float = frequency * pow(float(sound["pitch_rise"]), progress)
		var gain: float = volume * pow(SOUND_FLOOR / volume, progress)
		phase = fposmod(phase + freq / float(rate), 1.0)
		var sample: float = gain if phase < 0.5 else -gain
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


## Number of coins currently flying towards the chest.
func flying_count() -> int:
	return _flights.size()


## Prepares the magnet. `config` is the full chest_tiers config; `coins` is the live ground
## coin list of the SlimeField (taken by reference: absorbed coins are removed from it);
## `field_size` is the viewport size, used to decide whether the cursor is inside the field.
func setup(config: Dictionary, rng: RandomNumberGenerator, coins: Array[Coin], chest: Chest,
		field_size: Vector2, magnet_level: int) -> void:
	_config = config
	_rng = rng
	_coins = coins
	_chest = chest
	_field_rect = Rect2(Vector2.ZERO, field_size)
	_radius = radius(config, magnet_level)
	var sound: Dictionary = config["sound"]
	var pitch: Dictionary = sound["pitch"]
	for kind: String in pitch:
		_streams[kind] = make_blip(sound, pitch[kind])
	_player = AudioStreamPlayer.new()
	add_child(_player)


## Takes a ground coin over: removes it from the coin list and sends it flying to the chest.
## Returns false (and does nothing) when the coin is not in the list, so a coin is never
## taken, and therefore never deposited, twice.
func absorb(coin: Coin) -> bool:
	var index: int = _coins.find(coin)
	if index < 0:
		return false
	_coins.remove_at(index)
	var magnet: Dictionary = _config["magnet"]
	var chest_pos: Vector2 = _chest.position
	var control_range: float = magnet["control_x_range"]
	var control := Vector2(
			(coin.position.x + chest_pos.x) / 2.0 + _rng.randf_range(-control_range, control_range),
			minf(coin.position.y, chest_pos.y)
					- _rng.randf_range(magnet["control_rise_min"], magnet["control_rise_max"]))
	_flights.append({
		"coin": coin,
		"t": 0.0,
		"start": Vector2(coin.position.x, coin.position.y - coin.height),
		"control": control,
		"end": Vector2(chest_pos.x, chest_pos.y - float(magnet["arrival_height"])),
	})
	coin.begin_flight()
	coin.z_index = int(magnet["flight_z_index"])
	return true


## Advances the flights, then absorbs every ground coin inside the radius around `cursor`.
## `cursor_active` is false while the cursor is outside the field (the magnet is off).
## Coins absorbed in this call start moving on the next one, like the prototype.
func step(delta: float, cursor: Vector2, cursor_active: bool) -> void:
	_cursor = cursor
	_cursor_active = cursor_active
	_advance_flights(delta)
	if cursor_active:
		for i: int in range(_coins.size() - 1, -1, -1):
			if in_range(cursor, _coins[i].position, _radius):
				absorb(_coins[i])
	queue_redraw()


func _process(delta: float) -> void:
	if not _config.is_empty():
		step(delta, _cursor, _cursor_active)


func _input(event: InputEvent) -> void:
	if _config.is_empty():
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_cursor = (make_input_local(motion) as InputEventMouseMotion).position
		_cursor_active = _field_rect.has_point(_cursor)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_cursor_active = false


func _advance_flights(delta: float) -> void:
	var magnet: Dictionary = _config["magnet"]
	var speed: float = magnet["fly_speed"]
	var spin_rate: float = magnet["flight_spin_rate"]
	for i: int in range(_flights.size() - 1, -1, -1):
		var flight: Dictionary = _flights[i]
		flight["t"] += delta * speed
		var coin: Coin = flight["coin"]
		if flight["t"] >= 1.0:
			_flights.remove_at(i)
			_chest.deposit(coin.value)
			_play_blip(coin.kind)
			coin.queue_free()
		else:
			var t: float = flight["t"]
			coin.fly_to(bezier(flight["start"], flight["control"], flight["end"], t), t * spin_rate)


func _play_blip(kind: String) -> void:
	if not is_inside_tree():
		return
	var sound: Dictionary = _config["sound"]
	var now: int = Time.get_ticks_msec()
	if not blip_allowed(_last_blip_msec, now, sound["throttle_ms"]):
		return
	_last_blip_msec = now
	_player.stream = _streams[kind]
	_player.play()


func _draw() -> void:
	if _config.is_empty() or not _cursor_active:
		return
	var magnet: Dictionary = _config["magnet"]
	var color := Color(Color.html(magnet["ring_color"]), float(magnet["ring_alpha"]))
	draw_arc(_cursor, _radius, 0.0, TAU, RING_POINTS, color, float(magnet["ring_width"]))
