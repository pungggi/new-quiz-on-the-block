class_name AudioManagerClass
extends Node
## Centralized audio management for the game
## Handles SFX, music, and volume control with sound pooling

signal volume_changed(bus_name: String, volume: float)

## Sound effect definitions - procedurally generated placeholders
enum SFX {
	BUTTON_CLICK,
	BUTTON_HOVER,
	PANEL_OPEN,
	PANEL_CLOSE,
	QUIZ_CORRECT,
	QUIZ_WRONG,
	BUILDING_PLACE,
	NPC_SPAWN,
	NPC_DESPAWN,
	POINTS_GAIN,
	UNLOCK,
}

## Audio bus names
const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"

## Pool size for simultaneous sounds
const SFX_POOL_SIZE: int = 8

## Audio players
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _music_player: AudioStreamPlayer

## Pregenerated audio streams for each SFX
var _sfx_streams: Dictionary = {}

## Volume settings (0.0 to 1.0)
var sfx_volume: float = 0.8:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_volume(BUS_SFX, sfx_volume)
		volume_changed.emit(BUS_SFX, sfx_volume)

var music_volume: float = 0.5:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_volume(BUS_MUSIC, music_volume)
		volume_changed.emit(BUS_MUSIC, music_volume)


func _ready() -> void:
	_setup_audio_buses()
	_create_sfx_pool()
	_create_music_player()
	_generate_placeholder_sounds()


func _setup_audio_buses() -> void:
	# Create SFX and Music buses if they don't exist
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, BUS_MASTER)

	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_MUSIC)
		AudioServer.set_bus_send(idx, BUS_MASTER)

	# Apply initial volumes
	_apply_volume(BUS_SFX, sfx_volume)
	_apply_volume(BUS_MUSIC, music_volume)


func _create_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_pool.append(player)


func _create_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)


func _apply_volume(bus_name: String, volume: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		var db := linear_to_db(volume) if volume > 0.0 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)


## Generate procedural placeholder sounds
func _generate_placeholder_sounds() -> void:
	_sfx_streams[SFX.BUTTON_CLICK] = _create_tone(800.0, 0.05, 0.3)
	_sfx_streams[SFX.BUTTON_HOVER] = _create_tone(600.0, 0.03, 0.15)
	_sfx_streams[SFX.PANEL_OPEN] = _create_sweep(400.0, 800.0, 0.1, 0.25)
	_sfx_streams[SFX.PANEL_CLOSE] = _create_sweep(800.0, 400.0, 0.1, 0.25)
	_sfx_streams[SFX.QUIZ_CORRECT] = _create_success_sound()
	_sfx_streams[SFX.QUIZ_WRONG] = _create_fail_sound()
	_sfx_streams[SFX.BUILDING_PLACE] = _create_pop_sound()
	_sfx_streams[SFX.NPC_SPAWN] = _create_sweep(300.0, 600.0, 0.15, 0.3)
	_sfx_streams[SFX.NPC_DESPAWN] = _create_sweep(600.0, 200.0, 0.2, 0.3)
	_sfx_streams[SFX.POINTS_GAIN] = _create_coin_sound()
	_sfx_streams[SFX.UNLOCK] = _create_fanfare_sound()


## Play a sound effect
func play_sfx(sfx: SFX, volume_scale: float = 1.0) -> void:
	if not _sfx_streams.has(sfx):
		push_warning("AudioManager: Unknown SFX %d" % sfx)
		return

	var player := _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE

	player.stream = _sfx_streams[sfx]
	player.volume_db = linear_to_db(volume_scale)
	player.play()


## Play background music
func play_music(stream: AudioStream, fade_in: float = 1.0) -> void:
	if _music_player.playing:
		var fade_out_tween := create_tween()
		fade_out_tween.tween_property(_music_player, "volume_db", -40.0, 0.5)
		await fade_out_tween.finished

	_music_player.stream = stream
	_music_player.volume_db = -40.0
	_music_player.play()

	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(_music_player, "volume_db", 0.0, fade_in)


## Stop music with fade out
func stop_music(fade_out: float = 1.0) -> void:
	if not _music_player.playing:
		return

	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, fade_out)
	await tween.finished
	_music_player.stop()


## Start ambient music loop (procedurally generated)
func start_ambient_music() -> void:
	var stream := _create_ambient_music()
	play_music(stream, 2.0)


#region Sound Generation Helpers

func _create_tone(freq: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / sample_rate
		var envelope := 1.0 - (float(i) / samples) # Fade out
		var sample_val := sin(t * freq * TAU) * envelope * volume
		var sample_int := int(sample_val * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


func _create_sweep(freq_start: float, freq_end: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var sample_rate := 44100
	var samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)

	var phase := 0.0
	for i in range(samples):
		var t := float(i) / samples
		var freq := lerpf(freq_start, freq_end, t)
		var envelope := 1.0 - t * 0.5
		phase += freq / sample_rate
		var sample_val := sin(phase * TAU) * envelope * volume
		var sample_int := int(sample_val * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


func _create_success_sound() -> AudioStreamWAV:
	# Two ascending tones
	var sample_rate := 44100
	var duration := 0.3
	var samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / sample_rate
		var envelope := 1.0 - (float(i) / samples) * 0.5
		var freq := 523.25 if t < 0.15 else 659.25 # C5 then E5
		var sample_val := sin(t * freq * TAU) * envelope * 0.4
		var sample_int := int(sample_val * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


func _create_fail_sound() -> AudioStreamWAV:
	# Descending buzz
	var sample_rate := 44100
	var duration := 0.25
	var samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / sample_rate
		var envelope := 1.0 - (float(i) / samples)
		var freq := 200.0 - t * 100.0
		# Square wave for buzzy sound
		var sample_val := (1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0) * envelope * 0.3
		var sample_int := int(sample_val * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


func _create_pop_sound() -> AudioStreamWAV:
	# Quick pop/plop sound
	var sample_rate := 44100
	var duration := 0.12
	var samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / sample_rate
		var envelope := exp(-t * 30.0) # Quick decay
		var freq := 400.0 + sin(t * 50.0) * 200.0
		var sample_val := sin(t * freq * TAU) * envelope * 0.5
		var sample_int := int(sample_val * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


func _create_coin_sound() -> AudioStreamWAV:
	# High-pitched ding
	var sample_rate := 44100
	var duration := 0.2
	var samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / sample_rate
		var envelope := exp(-t * 10.0)
		var sample_val := sin(t * 1200.0 * TAU) * envelope * 0.3
		sample_val += sin(t * 1800.0 * TAU) * envelope * 0.15 # Harmonic
		var sample_int := int(sample_val * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


func _create_fanfare_sound() -> AudioStreamWAV:
	# Triumphant ascending notes
	var sample_rate := 44100
	var duration := 0.5
	var samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)

	var notes := [523.25, 659.25, 783.99, 1046.5] # C5, E5, G5, C6
	var note_duration := duration / notes.size()

	for i in range(samples):
		var t := float(i) / sample_rate
		var note_idx := mini(int(t / note_duration), notes.size() - 1)
		var freq: float = notes[note_idx]
		var local_t := fmod(t, note_duration)
		var envelope := 1.0 - (local_t / note_duration) * 0.3
		var sample_val := sin(t * freq * TAU) * envelope * 0.35
		var sample_int := int(sample_val * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


func _create_ambient_music() -> AudioStreamWAV:
	# Simple ambient drone - calm, loopable
	var sample_rate := 44100
	var duration := 8.0 # 8 second loop
	var samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / sample_rate
		# Low drone with slow modulation
		var mod := sin(t * 0.5 * TAU) * 0.3 + 0.7
		var sample_val := sin(t * 110.0 * TAU) * 0.15 * mod # A2
		sample_val += sin(t * 165.0 * TAU) * 0.1 * mod # E3
		sample_val += sin(t * 220.0 * TAU) * 0.05 * mod # A3
		# Add some gentle movement
		sample_val += sin(t * 55.0 * TAU) * 0.08 # A1 sub
		var sample_int := int(sample_val * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	stream.data = data
	return stream

#endregion
