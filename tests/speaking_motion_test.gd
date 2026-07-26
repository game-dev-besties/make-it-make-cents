extends SceneTree
## Speaking-motion behavior that can be verified without rendering screenshots.

const STAGE_SCENE := preload("res://game/components/stage.tscn")
const SLOT_SCENE := preload("res://game/components/stage_actor_slot.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_slot_motion_and_cleanup()
	await _test_disabled_motion()
	await _test_stage_routes_motion_to_current_speaker()

	if _failures.is_empty():
		print("Speaking motion checks passed.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("FAIL: ", failure)
	quit(1)


func _test_slot_motion_and_cleanup() -> void:
	var slot := SLOT_SCENE.instantiate() as StageActorSlot
	root.add_child(slot)
	slot.size = Vector2(220.0, 330.0)
	await process_frame

	var motion_root := slot.get_node("%MotionRoot") as Control
	slot.start_speaking(
		{
			"portrait": "happy",
			"text": "This is a long and enthusiastic speaking test!",
		},
	)
	_check(slot.is_speaking(), "A speaking slot should report its active state.")
	await create_timer(0.08).timeout
	_check(
		not motion_root.position.is_equal_approx(Vector2.ZERO)
		or not motion_root.scale.is_equal_approx(Vector2.ONE)
		or not is_zero_approx(motion_root.rotation),
		"Speaking should move the inner motion root.",
	)

	slot.stop_speaking(true)
	_check(not slot.is_speaking(), "Stopping should clear the speaking state.")
	_check(
		motion_root.position.is_equal_approx(Vector2.ZERO)
		and motion_root.scale.is_equal_approx(Vector2.ONE)
		and is_zero_approx(motion_root.rotation),
		"Immediate cleanup should restore the exact resting transform.",
	)
	slot.queue_free()
	await process_frame


func _test_disabled_motion() -> void:
	var slot := SLOT_SCENE.instantiate() as StageActorSlot
	slot.speaking_motion_enabled = false
	root.add_child(slot)
	await process_frame
	slot.start_speaking({"portrait": "neutral", "text": "No movement."})
	_check(
		not slot.is_speaking(),
		"Slots with speaking motion disabled should remain still.",
	)
	slot.queue_free()
	await process_frame


func _test_stage_routes_motion_to_current_speaker() -> void:
	var stage := STAGE_SCENE.instantiate() as StoryStage
	root.add_child(stage)
	stage.size = StoryStage.REFERENCE_SIZE
	await process_frame

	var dad_slot := stage.get_node("ActorSlots/Left") as StageActorSlot
	var son_slot := stage.get_node("ActorSlots/Center") as StageActorSlot
	dad_slot.character_id = &"dad"
	son_slot.character_id = &"son"

	var dad := DialogicCharacter.new()
	dad.set_identifier("dad")
	dad.display_name = "Dad"
	var son := DialogicCharacter.new()
	son.set_identifier("son")
	son.display_name = "Percy"

	var dad_line := {
		"character": dad,
		"portrait": "happy",
		"text": "We finally made it across the border!",
		"append": false,
	}
	stage.apply_dialogic_text(dad_line)
	_check(
		not dad_slot.is_speaking(),
		"Selecting a speaker before reveal should not start motion early.",
	)
	_check(
		stage.start_dialogic_speaking(dad_line),
		"An on-stage Dialogic speaker should start speaking motion.",
	)
	_check(
		dad_slot.is_speaking() and not son_slot.is_speaking(),
		"Only the matching actor slot should move.",
	)

	var son_line := {
		"character": son,
		"portrait": "nervous",
		"text": "Are you sure this is going to work?",
		"append": false,
	}
	stage.apply_dialogic_text(son_line)
	stage.start_dialogic_speaking(son_line)
	_check(
		not dad_slot.is_speaking() and son_slot.is_speaking(),
		"A rapid speaker change should stop the previous actor.",
	)
	stage.stop_dialogic_speaking({}, true)
	_check(
		not dad_slot.is_speaking() and not son_slot.is_speaking(),
		"Finishing or skipping text should leave every actor at rest.",
	)

	var narration := {"character": null, "text": "Later that afternoon."}
	stage.apply_dialogic_text(narration)
	_check(
		not stage.start_dialogic_speaking(narration),
		"Narration without an on-stage character should not animate a slot.",
	)
	stage.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
