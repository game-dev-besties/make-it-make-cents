extends Node
## Small procedural sound palette for UI and game-feel feedback.
##
## Every sound is rendered once to an AudioStreamWAV at startup, then reused.
## This keeps playback cheap, works in web exports, and avoids external samples.

const MIX_RATE := 22050
const PLAYER_COUNT := 8
const VOLUME_VARIATION_DB := 0.7
const BUTTON_WIRED_META := &"_procedural_sfx_wired"

const UI_PRESS := &"ui_press"
const UI_CONFIRM := &"ui_confirm"
const UI_CANCEL := &"ui_cancel"
const WORD_CUT := &"word_cut"
const WORD_RESTORE := &"word_restore"

const EFFECT_NAMES: Array[StringName] = [
	UI_PRESS,
	UI_CONFIRM,
	UI_CANCEL,
	WORD_CUT,
	WORD_RESTORE,
]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _pitch_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_build_library()
	_build_player_pool()
	_pitch_rng.randomize()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_wire_existing_buttons")


func play(effect_name: StringName, volume_db := 0.0, pitch_variation := -1.0) -> void:
	var stream := get_effect_stream(effect_name)
	if stream == null or _players.is_empty():
		return
	var resolved_pitch_variation := (
		_effect_pitch_variation(effect_name)
		if pitch_variation < 0.0
		else pitch_variation
	)
	var player := _next_available_player()
	player.stream = stream
	player.volume_db = volume_db + _pitch_rng.randf_range(
		-VOLUME_VARIATION_DB,
		VOLUME_VARIATION_DB,
	)
	player.pitch_scale = _pitch_rng.randf_range(
		1.0 - resolved_pitch_variation,
		1.0 + resolved_pitch_variation,
	)
	player.play()


func play_word_action(is_cut: bool) -> void:
	if is_cut:
		play(WORD_CUT, -3.5)
	else:
		play(WORD_RESTORE, -4.0)


func get_effect_stream(effect_name: StringName) -> AudioStreamWAV:
	return _streams.get(effect_name) as AudioStreamWAV


func available_effects() -> Array[StringName]:
	return EFFECT_NAMES.duplicate()


func _build_library() -> void:
	for effect_name: StringName in EFFECT_NAMES:
		_streams[effect_name] = _render_effect(effect_name)


func _build_player_pool() -> void:
	for player_index: int in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % (player_index + 1)
		player.bus = &"Master"
		add_child(player)
		_players.append(player)


func _next_available_player() -> AudioStreamPlayer:
	for offset: int in _players.size():
		var candidate_index := (_next_player + offset) % _players.size()
		var candidate := _players[candidate_index]
		if not candidate.playing:
			_next_player = (candidate_index + 1) % _players.size()
			return candidate
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	return player


func _wire_existing_buttons() -> void:
	_wire_buttons_below(get_tree().root)


func _wire_buttons_below(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)
	for child: Node in node.get_children():
		_wire_buttons_below(child)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)


func _wire_button(button: BaseButton) -> void:
	if button.has_meta(BUTTON_WIRED_META):
		return
	button.set_meta(BUTTON_WIRED_META, true)
	button.button_down.connect(_on_button_down.bind(button))


func _on_button_down(button: BaseButton) -> void:
	if not _button_can_make_sound(button):
		return
	play(UI_PRESS, -9.0)


func _button_can_make_sound(button: BaseButton) -> bool:
	return (
		is_instance_valid(button)
		and not button.disabled
		and button.is_visible_in_tree()
	)


func _render_effect(effect_name: StringName) -> AudioStreamWAV:
	var duration := _effect_duration(effect_name)
	var frame_count := ceili(duration * MIX_RATE)
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = hash(effect_name) as int
	for frame_index: int in frame_count:
		var time := float(frame_index) / float(MIX_RATE)
		var sample := _sample_effect(effect_name, time, duration, noise_rng)
		var pcm_value := clampi(roundi(sample * 32767.0), -32768, 32767)
		pcm.encode_s16(frame_index * 2, pcm_value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


func _effect_duration(effect_name: StringName) -> float:
	match effect_name:
		UI_PRESS:
			return 0.075
		UI_CONFIRM:
			return 0.15
		UI_CANCEL:
			return 0.11
		WORD_CUT:
			return 0.14
		WORD_RESTORE:
			return 0.11
	return 0.1


func _effect_pitch_variation(effect_name: StringName) -> float:
	match effect_name:
		UI_PRESS:
			return 0.06
		UI_CONFIRM:
			return 0.035
		UI_CANCEL:
			return 0.045
		WORD_CUT:
			return 0.055
		WORD_RESTORE:
			return 0.055
	return 0.04


func _sample_effect(
	effect_name: StringName,
	time: float,
	_duration: float,
	noise_rng: RandomNumberGenerator,
) -> float:
	match effect_name:
		UI_PRESS:
			return (
				_typewriter_tick(time, 0.0, 0.06, 760.0, 0.29)
				+ _typewriter_tick(time, 0.018, 0.055, 510.0, 0.12)
			)
		UI_CONFIRM:
			return _confirm_sample(time)
		UI_CANCEL:
			return _cancel_sample(time)
		WORD_CUT:
			var scrape_time := time - 0.012
			var scrape := 0.0
			if scrape_time >= 0.0 and scrape_time < 0.065:
				var scrape_progress := scrape_time / 0.065
				scrape = (
					noise_rng.randf_range(-1.0, 1.0)
					* sin(PI * scrape_progress)
					* 0.1
				)
			return clampf(
				(
					_typewriter_tick(time, 0.0, 0.09, 610.0, 0.38)
					+ _typewriter_tick(time, 0.038, 0.075, 920.0, 0.19)
					+ scrape
				),
				-1.0,
				1.0,
			)
		WORD_RESTORE:
			return _restore_sample(time)
	return 0.0


func _confirm_sample(time: float) -> float:
	return clampf(
		_typewriter_tick(time, 0.0, 0.075, 790.0, 0.28)
		+ _typewriter_tick(time, 0.045, 0.085, 940.0, 0.26),
		-1.0,
		1.0,
	)


func _cancel_sample(time: float) -> float:
	return (
		_typewriter_tick(time, 0.0, 0.07, 720.0, 0.25)
		+ _typewriter_tick(time, 0.035, 0.07, 520.0, 0.21)
	)


func _restore_sample(time: float) -> float:
	return clampf(
		_typewriter_tick(time, 0.0, 0.07, 650.0, 0.27)
		+ _typewriter_tick(time, 0.027, 0.075, 830.0, 0.23),
		-1.0,
		1.0,
	)


func _typewriter_tick(
	time: float,
	start_time: float,
	duration: float,
	frequency: float,
	amplitude: float,
) -> float:
	var local_time := time - start_time
	if local_time < 0.0 or local_time >= duration:
		return 0.0
	var decay := exp(-local_time * 44.0)
	var body := sin(TAU * frequency * local_time) * decay
	var dry_click := (
		sin(TAU * frequency * 2.13 * local_time + 0.4)
		* exp(-local_time * 92.0)
		* 0.28
	)
	var paper_texture := (
		(
			sin(TAU * 1733.0 * local_time)
			+ sin(TAU * 2591.0 * local_time + 0.7)
		)
		* exp(-local_time * 120.0)
		* 0.055
	)
	return (body + dry_click + paper_texture) * amplitude
