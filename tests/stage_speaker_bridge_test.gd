extends SceneTree

const CAMPAIGN_PLAYER_SCRIPT := preload("res://game/runtime/campaign_player.gd")
const STAGE_HOST_SCRIPT := preload("res://game/runtime/stage_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dialogic := root.get_node_or_null("Dialogic")
	_check(dialogic != null, "The Dialogic autoload should be available.")
	if dialogic == null:
		_finish()
		return

	var text_subsystem := dialogic.call("get_subsystem", "Text") as Node
	_check(text_subsystem != null, "Dialogic should expose its Text subsystem.")
	if text_subsystem == null:
		_finish()
		return
	var background_subsystem := dialogic.call("get_subsystem", "Backgrounds") as Node
	_check(
		background_subsystem != null,
		"Dialogic should expose its Backgrounds subsystem.",
	)

	var host: StageHost = STAGE_HOST_SCRIPT.new()
	var player: CampaignPlayer = CAMPAIGN_PLAYER_SCRIPT.new()
	root.add_child(host)
	root.add_child(player)
	player.set_stage_host(host)
	player.set_dialogic(dialogic)

	var dad_stage := load("res://content/episodes/dad/stage.tscn") as PackedScene
	var stage := host.show_presentation(dad_stage) as StoryStage
	await process_frame
	_check(stage != null, "The Dad stage should mount for the speaker bridge test.")
	if stage == null:
		player.queue_free()
		host.queue_free()
		_finish()
		return

	var dad_slot := stage.get_node("ActorSlots/Left") as StageActorSlot
	var interviewer_slot := stage.get_node("ActorSlots/Right") as StageActorSlot
	_check(dad_slot.character_id == &"dad", "The Dad slot should opt into the `dad` Dialogic character.")
	_check(
		interviewer_slot.character_id == &"interviewer",
		"The interviewer slot should opt into the `interviewer` Dialogic character.",
	)

	var dad := DialogicResourceUtil.get_character_resource("dad")
	text_subsystem.emit_signal(
		"about_to_show_text",
		{"character": dad, "portrait": "happy", "text": "Hello.", "append": false},
	)
	_check(dad_slot.actor_name == "Dad", "The active slot should use Dialogic's display name.")
	_check(dad_slot.expression == "happy", "The active slot should use the line's portrait expression.")
	_check(dad_slot.is_active, "The speaking character should be emphasized.")
	_check(not interviewer_slot.is_active, "A non-speaking character should be de-emphasized.")
	_check(
		dad_slot.z_index > interviewer_slot.z_index,
		"The speaking character should render above overlapping ensemble portraits.",
	)

	var interviewer := DialogicResourceUtil.get_character_resource("interviewer")
	text_subsystem.emit_signal(
		"about_to_show_text",
		{"character": interviewer, "portrait": "", "text": "Next.", "append": false},
	)
	_check(not dad_slot.is_active, "Emphasis should move away from the previous speaker.")
	_check(interviewer_slot.is_active, "Emphasis should move to the new speaker.")
	_check(
		interviewer_slot.z_index > dad_slot.z_index,
		"Speaker depth should follow emphasis when the speaker changes.",
	)
	_check(
		interviewer_slot.actor_name == "Interviewer",
		"The matching slot should use the new speaker's display name.",
	)
	_check(
		interviewer_slot.expression == "neutral",
		"An omitted line expression should use the character's default portrait.",
	)

	var phrase_event := DialogicPhraseCutEvent.new()
	phrase_event.dialogic = dialogic
	phrase_event.portrait = "sad"
	phrase_event.call("_forward_speaker_to_stage", dad)
	_check(
		dad_slot.is_active and not interviewer_slot.is_active,
		"A phrase-cut line should emphasize its speaker before the player chooses a delivery.",
	)
	_check(
		dad_slot.expression == "sad",
		"A phrase-cut line should forward its expression before opening the selection UI.",
	)

	text_subsystem.emit_signal(
		"about_to_show_text",
		{"character": null, "portrait": "", "text": "Narration.", "append": false},
	)
	_check(
		not dad_slot.is_active and not interviewer_slot.is_active,
		"Narration should leave no actor emphasized.",
	)

	var background_image := stage.get_node("%BackgroundImage") as TextureRect
	dialogic.Styles.load_style()
	await process_frame
	await process_frame
	background_subsystem.call(
		"update_background",
		"",
		"res://icon.svg",
		0.0,
	)
	_check(
		background_image.texture != null
			and background_image.texture.resource_path == "res://icon.svg",
		"Native Dialogic background events should render inside the editor-authored stage.",
	)

	player.set_dialogic(null)
	dad_slot.set_actor("Unchanged", "still")
	background_image.texture = null
	text_subsystem.emit_signal(
		"about_to_show_text",
		{"character": dad, "portrait": "sad", "text": "Disconnected.", "append": false},
	)
	_check(
		dad_slot.actor_name == "Unchanged" and dad_slot.expression == "still",
		"Replacing Dialogic should safely disconnect the old Text signal.",
	)
	background_subsystem.emit_signal(
		"background_changed",
		{
			"scene": "",
			"argument": "res://icon.svg",
			"fade_time": 0.0,
			"same_scene": false,
		},
	)
	_check(
		background_image.texture == null,
		"Replacing Dialogic should safely disconnect the old Background signal.",
	)

	player.queue_free()
	host.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Stage speaker bridge checks passed.")
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	quit(1)
