class_name ProceduralSfx
extends RefCounted

const SAMPLE_RATE: int = 44100
const MAX_PCM_16: float = 32767.0
const IMPACT_LEVELS: Array[float] = [0.2, 0.5, 0.85]
const BREAK_LEVELS: Array[float] = [0.3, 0.65, 1.0]

static var _impact_stream_cache: Dictionary = {}
static var _break_stream_cache: Dictionary = {}
static var _ui_click_stream: AudioStreamWAV = null
static var _ui_click_down_stream: AudioStreamWAV = null
static var _ui_click_up_stream: AudioStreamWAV = null
static var _hatch_open_stream: AudioStreamWAV = null
static var _hatch_close_stream: AudioStreamWAV = null
static var _is_primed: bool = false

static func prime_cache(color_count: int = 12) -> void:
	if _is_primed:
		return

	for color_index in range(color_count):
		for level in IMPACT_LEVELS:
			var impact_key := _make_impact_key(color_index, level)
			_impact_stream_cache[impact_key] = create_fragment_impact_stream(color_index, level)

	for level in BREAK_LEVELS:
		var break_key := _make_break_key(level)
		_break_stream_cache[break_key] = create_container_break_stream(level)

	_ui_click_down_stream = create_ui_click_down_stream()
	_ui_click_up_stream = create_ui_click_up_stream()
	_ui_click_stream = _ui_click_up_stream
	_hatch_open_stream = create_hatch_open_stream()
	_hatch_close_stream = create_hatch_close_stream()

	_is_primed = true

static func get_fragment_impact_stream(color_name: int, impact_strength: float = 0.5) -> AudioStreamWAV:
	if not _is_primed:
		prime_cache()
	var level: float = _closest_level(impact_strength, IMPACT_LEVELS)
	var impact_key := _make_impact_key(color_name, level)
	return _impact_stream_cache[impact_key]

static func get_container_break_stream(impact_strength: float = 1.0) -> AudioStreamWAV:
	if not _is_primed:
		prime_cache()
	var level: float = _closest_level(impact_strength, BREAK_LEVELS)
	var break_key := _make_break_key(level)
	return _break_stream_cache[break_key]

static func get_ui_click_stream() -> AudioStreamWAV:
	if not _is_primed:
		prime_cache()
	return _ui_click_stream

static func get_ui_click_down_stream() -> AudioStreamWAV:
	if not _is_primed:
		prime_cache()
	return _ui_click_down_stream

static func get_ui_click_up_stream() -> AudioStreamWAV:
	if not _is_primed:
		prime_cache()
	return _ui_click_up_stream

static func get_hatch_open_stream() -> AudioStreamWAV:
	if not _is_primed:
		prime_cache()
	return _hatch_open_stream

static func get_hatch_close_stream() -> AudioStreamWAV:
	if not _is_primed:
		prime_cache()
	return _hatch_close_stream

static func create_fragment_impact_stream(color_name: int, impact_strength: float = 0.5) -> AudioStreamWAV:
	var duration := lerpf(0.030, 0.055, clampf(impact_strength, 0.0, 1.0))
	var sample_count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	var color_frequencies: Array[float] = [
		294.0, 311.13, 329.63, 349.23, 349.0, 392.0,
		415.3, 440.0, 440.0, 493.88, 523.25, 554.37
	]

	# Your base frequency, already multiplied upward
	var base := color_frequencies[color_name % color_frequencies.size()] * 5

	# Glass modal ratios (inharmonic)
	var m1 := base * 1.00
	var m2 := base * 1.13
	var m3 := base * 1.27
	var m4 := base * 1.51

	var strength := clampf(impact_strength, 0.0, 1.0)

	for i in range(sample_count):
		var t := float(i) / SAMPLE_RATE

		# Very fast attack
		var attack := minf(t * 1200.0, 1.0)

		# Modal damping (higher modes die faster)
		var d1 := exp(-45.0 * t)
		var d2 := exp(-60.0 * t)
		var d3 := exp(-75.0 * t)
		var d4 := exp(-95.0 * t)

		# Modal oscillators
		var s1 := sin(TAU * m1 * t) * d1
		var s2 := sin(TAU * m2 * t) * d2
		var s3 := sin(TAU * m3 * t) * d3
		var s4 := sin(TAU * m4 * t) * d4

		# Tiny metallic tail (2–3 kHz)
		var tail := sin(TAU * 2600.0 * t) * exp(-110.0 * t) * 0.08

		# Small noise burst
		var burst := (randf() * 2.0 - 1.0) * 0.035 * exp(-85.0 * t)

		var sample := (
			s1 * 0.55 +
			s2 * 0.25 +
			s3 * 0.12 +
			s4 * 0.08 +
			tail +
			burst
		) * attack * (0.45 + strength * 0.35)

		_write_pcm16_sample(data, i * 2, sample)

	return _build_stream(data)


static func create_container_break_stream(impact_strength: float = 1.0) -> AudioStreamWAV:
	var duration: float = lerpf(0.16, 0.30, clampf(impact_strength, 0.0, 1.0))
	var sample_count := int(float(SAMPLE_RATE) * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	var strength := clampf(impact_strength, 0.0, 1.0)

	# Core frequencies for realistic glass
	var crack_freq := 1800.0
	var shard_freq := 2600.0
	var tinkle_freq := 4200.0

	for i in range(sample_count):
		var t := float(i) / float(SAMPLE_RATE)

		# Faster decay for brittle material
		var envelope := exp(t)

		# Initial crack (wide-band, sharp)
		var crack := sin(TAU * crack_freq * t + randf_range(-0.2, 0.2)) * exp(-60.0 * t)

		# Chaotic shard cluster (bright, noisy)
		var shard := sin(TAU * shard_freq * t + randf_range(-1.0, 1.0)) * exp(-32.0 * t)

		# Tinkle tail (tiny pieces settling)
		var tinkle := sin(TAU * tinkle_freq * t + randf_range(-2.0, 2.0)) * exp(-22.0 * t)

		# Noise burst (crackle)
		var burst := (randf() * 2.0 - 1.0) * (0.28 + strength * 0.22) * exp(-24.0 * t)

		# Mix — weighted for realism
		var sample := (
			crack * 0.34 +
			shard * 0.28 +
			tinkle * 0.18 +
			burst
		) * envelope

		_write_pcm16_sample(data, i * 2, sample)

	return _build_stream(data)

static func create_ui_click_stream() -> AudioStreamWAV:
	return create_ui_click_up_stream()

static func create_ui_click_down_stream() -> AudioStreamWAV:
	var duration: float = 0.06
	var sample_count := int(float(SAMPLE_RATE) * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(SAMPLE_RATE)
		var attack: float = minf(t * 360.0, 1.0)
		var envelope: float = attack * exp(-44.0 * t) * 0.42
		var thunk: float = sin(TAU * 190.0 * t)
		var click: float = sin(TAU * 380.0 * t + 0.2)
		var texture: float = (randf() * 2.0 - 1.0) * 0.02 * exp(-64.0 * t)
		var sample: float = ((thunk * 0.62) + (click * 0.28) + texture) * envelope
		_write_pcm16_sample(data, i * 2, sample)

	return _build_stream(data)

static func create_ui_click_up_stream() -> AudioStreamWAV:
	var duration: float = 0.09
	var sample_count := int(float(SAMPLE_RATE) * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(SAMPLE_RATE)
		var attack: float = minf(t * 280.0, 1.0)
		var envelope: float = attack * exp(-30.0 * t) * 0.36
		var body: float = sin(TAU * 660.0 * t)
		var bell: float = sin(TAU * 990.0 * t + 0.3)
		var warmth: float = sin(TAU * 440.0 * t + 0.15)
		var sample: float = ((body * 0.54) + (bell * 0.18) + (warmth * 0.28)) * envelope
		_write_pcm16_sample(data, i * 2, sample)

	return _build_stream(data)

static func create_hatch_open_stream() -> AudioStreamWAV:
	var duration: float = 0.14
	var sample_count := int(float(SAMPLE_RATE) * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(SAMPLE_RATE)
		var attack: float = minf(t * 140.0, 1.0)
		var envelope: float = attack * exp(-12.0 * t) * 0.34
		var scrape: float = sin(TAU * 240.0 * t)
		var ring: float = sin(TAU * 520.0 * t + 0.18)
		var air: float = (randf() * 2.0 - 1.0) * 0.03 * exp(-20.0 * t)
		var sample: float = ((scrape * 0.58) + (ring * 0.22) + air) * envelope
		_write_pcm16_sample(data, i * 2, sample)

	return _build_stream(data)

static func create_hatch_close_stream() -> AudioStreamWAV:
	var duration: float = 0.12
	var sample_count := int(float(SAMPLE_RATE) * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(SAMPLE_RATE)
		var attack: float = minf(t * 300.0, 1.0)
		var envelope: float = attack * exp(-20.0 * t) * 0.36
		var thud: float = sin(TAU * 160.0 * t)
		var click: float = sin(TAU * 780.0 * t + 0.31)
		var sample: float = ((thud * 0.64) + (click * 0.2)) * envelope
		_write_pcm16_sample(data, i * 2, sample)

	return _build_stream(data)

static func play_break_at(root: Node, position: Vector2, impact_strength: float = 1.0) -> void:
	if root == null:
		return

	var player := AudioStreamPlayer2D.new()
	player.stream = get_container_break_stream(impact_strength)
	player.global_position = position
	player.volume_db = lerpf(-12.0, -6.0, clampf(impact_strength, 0.0, 1.0))
	root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

static func play_hatch_motion_at(root: Node, position: Vector2, opening: bool) -> void:
	if root == null:
		return

	var player := AudioStreamPlayer2D.new()
	player.stream = get_hatch_open_stream() if opening else get_hatch_close_stream()
	player.global_position = position
	player.volume_db = -4.0 if opening else -2.5
	player.attenuation = 0.0
	player.max_distance = 100000.0
	root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

static func _closest_level(value: float, levels: Array[float]) -> float:
	var clamped_value: float = clampf(value, 0.0, 1.0)
	var best_level: float = levels[0]
	var best_distance: float = absf(clamped_value - best_level)
	for level in levels:
		var distance: float = absf(clamped_value - level)
		if distance < best_distance:
			best_level = level
			best_distance = distance
	return best_level

static func _make_impact_key(color_name: int, impact_strength: float) -> String:
	return "%d_%.2f" % [color_name, impact_strength]

static func _make_break_key(impact_strength: float) -> String:
	return "break_%.2f" % impact_strength

static func _build_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

static func _write_pcm16_sample(data: PackedByteArray, offset: int, sample: float) -> void:
	var pcm := int(round(clamp(sample, -1.0, 1.0) * MAX_PCM_16))
	if pcm < 0:
		pcm += 65536
	data[offset] = pcm & 0xFF
	data[offset + 1] = (pcm >> 8) & 0xFF
