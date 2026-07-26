extends SceneTree

const NEIGHBORS_STAGE := preload("res://content/episodes/neighbors/stage.tscn")
const ACTOR_SLOT_NAMES := [
	&"Left",
	&"Center",
	&"Right",
	&"Crush",
	&"Interviewer",
	&"Doctor",
	&"Penny",
]
const TEST_SIZES := [
	Vector2i(1920, 648),
	Vector2i(1152, 900),
	Vector2i(1920, 1080),
]
const CHAPTER_SIX_BEATS := [
	{
		"name": "family opening",
		"cues": [&"RESET"],
	},
	{
		"name": "Percy and Clementine",
		"cues": [&"RESET", &"neighbors_transition_out", &"neighbors_transition_in"],
	},
	{
		"name": "connected Percy and Clementine",
		"cues": [
			&"RESET",
			&"neighbors_transition_out",
			&"neighbors_transition_in_connected",
		],
	},
	{
		"name": "adult introductions",
		"cues": [
			&"RESET",
			&"neighbors_transition_out",
			&"neighbors_transition_in",
			&"hosts_enter",
		],
	},
	{
		"name": "Grandma and the hosts",
		"cues": [
			&"RESET",
			&"neighbors_transition_out",
			&"neighbors_transition_in",
			&"hosts_enter",
			&"grandma_returns",
		],
	},
	{
		"name": "connected host introduction",
		"cues": [
			&"RESET",
			&"neighbors_transition_out",
			&"neighbors_transition_in_connected",
			&"hosts_enter_connected",
		],
	},
	{
		"name": "connected Grandma return",
		"cues": [
			&"RESET",
			&"neighbors_transition_out",
			&"neighbors_transition_in_connected",
			&"hosts_enter_connected",
			&"grandma_returns_connected",
		],
	},
	{
		"name": "family return",
		"cues": [
			&"RESET",
			&"neighbors_transition_out",
			&"neighbors_transition_in",
			&"hosts_enter",
			&"grandma_returns",
			&"dinner_fade",
			&"back_at_home",
		],
	},
	{
		"name": "Pennybot ending",
		"cues": [
			&"RESET",
			&"neighbors_transition_out",
			&"neighbors_transition_in",
			&"hosts_enter",
			&"grandma_returns",
			&"dinner_fade",
			&"back_at_home",
			&"pennybot_reveal",
		],
	},
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := NEIGHBORS_STAGE.instantiate() as StoryStage
	root.add_child(stage)
	await process_frame
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	stage.position = Vector2.ZERO
	stage.size = StoryStage.REFERENCE_SIZE
	await process_frame

	_finish_animation(stage.animation_player, &"RESET")
	var reference_layout := _normalized_actor_layout(stage)

	for test_size: Vector2i in TEST_SIZES:
		stage.size = Vector2(test_size)
		await process_frame
		# Position tracks are deliberately applied after the resize. They must
		# stay in the stage's authored coordinate system.
		_finish_animation(stage.animation_player, &"RESET")
		await process_frame
		_check_frame(stage, test_size)
		_check_layout_matches(
			reference_layout,
			_normalized_actor_layout(stage),
			"RESET at %s" % test_size,
		)

	for beat: Dictionary in CHAPTER_SIX_BEATS:
		stage.size = StoryStage.REFERENCE_SIZE
		await process_frame
		_finish_sequence(stage.animation_player, beat["cues"])
		var reference_beat := _normalized_actor_layout(stage)

		stage.size = Vector2(1920, 648)
		await process_frame
		_finish_sequence(stage.animation_player, beat["cues"])
		await process_frame
		_check_layout_matches(
			reference_beat,
			_normalized_actor_layout(stage),
			"%s at 1920x648" % beat["name"],
		)

	stage.queue_free()
	await process_frame
	_finish()


func _normalized_actor_layout(stage: StoryStage) -> Dictionary:
	var frame := (stage.get_node("%BackgroundImage") as Control).get_global_rect()
	var result := {}
	for slot_name: StringName in ACTOR_SLOT_NAMES:
		var slot := stage.get_node("ActorSlots/%s" % slot_name) as Control
		var rect := slot.get_global_rect()
		result[slot_name] = Rect2(
			(rect.position - frame.position) / frame.size,
			rect.size / frame.size,
		)
	return result


func _check_frame(stage: StoryStage, viewport_size: Vector2i) -> void:
	var viewport_vector := Vector2(viewport_size)
	var scale_factor := minf(
		viewport_vector.x / StoryStage.REFERENCE_SIZE.x,
		viewport_vector.y / StoryStage.REFERENCE_SIZE.y,
	)
	var expected_size := StoryStage.REFERENCE_SIZE * scale_factor
	var expected_position := (viewport_vector - expected_size) * 0.5
	var frame := (stage.get_node("%BackgroundImage") as Control).get_global_rect()
	_check(
		frame.position.is_equal_approx(expected_position)
		and frame.size.is_equal_approx(expected_size),
		(
			"The story frame should stay centered and letterboxed at %s; "
			+ "expected %s, got %s."
		)
		% [viewport_size, Rect2(expected_position, expected_size), frame],
	)


func _check_layout_matches(
	expected: Dictionary,
	actual: Dictionary,
	context: String,
) -> void:
	for slot_name: StringName in expected:
		var expected_rect: Rect2 = expected[slot_name]
		var actual_rect: Rect2 = actual[slot_name]
		_check(
			expected_rect.position.is_equal_approx(actual_rect.position)
			and expected_rect.size.is_equal_approx(actual_rect.size),
			"%s should keep the %s actor aligned to the background." % [
				context,
				slot_name,
			],
		)


func _finish_animation(
	animation_player: AnimationPlayer,
	animation_name: StringName,
) -> void:
	var animation := animation_player.get_animation(animation_name)
	animation_player.play(animation_name)
	animation_player.seek(animation.length, true)
	animation_player.stop(true)


func _finish_sequence(
	animation_player: AnimationPlayer,
	animation_names: Array,
) -> void:
	for animation_name: StringName in animation_names:
		_finish_animation(animation_player, animation_name)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Responsive stage layout checks passed.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("FAIL: ", failure)
	quit(1)
