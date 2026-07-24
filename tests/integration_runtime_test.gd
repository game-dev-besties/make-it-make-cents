extends SceneTree

const GAME_STATE_SCRIPT := preload("res://game/runtime/game_state.gd")
const STAGE_HOST_SCRIPT := preload("res://game/runtime/stage_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_budget_and_recovery()
	_test_state_round_trip()
	_test_explicit_phrase_sidecar()
	await _test_campaign_and_stage()

	if _failures.is_empty():
		print("Integration runtime checks passed.")
		quit(0)
		return

	for failure in _failures:
		printerr("FAIL: ", failure)
	quit(1)


func _test_budget_and_recovery() -> void:
	var state: GameStateStore = GAME_STATE_SCRIPT.new()
	state.begin_cutscene(5)
	_check(state.remaining_budget() == 5, "A cutscene should start with its episode budget.")
	_check(not state.can_use_pity(), "Pity should only appear after the budget reaches zero.")
	_check(state.spend(8) == 5, "Spending should never overdraw the remaining budget.")
	_check(state.remaining_budget() == 0, "Spending the available words should reach zero.")
	_check(state.use_pity(), "The one-time pity grunt should be usable at zero.")
	_check(not state.use_pity(), "The pity grunt should only be usable once per cutscene.")
	_check(state.use_sponsor(3), "The one-time sponsor should be usable at zero.")
	_check(state.remaining_budget() == 3, "The sponsor should replenish three words.")
	_check(state.apply_sponsor_penalty(&"dad"), "Sponsor penalties should resolve family speakers.")
	_check(state.dad_success == 2, "A sponsor read should tank the speaker's success score.")
	_check(not state.use_sponsor(3), "The sponsor should only be usable once per cutscene.")

	state.end_cutscene()
	_check(state.money_total_saved == 3, "Unspent cutscene budget should be saved.")
	state.end_cutscene()
	_check(state.money_total_saved == 3, "Ending a cutscene twice must not double-count savings.")

	state.begin_cutscene(2)
	_check(not state.pity_used and not state.sponsor_used, "Recovery choices should reset per cutscene.")
	state.free()


func _test_state_round_trip() -> void:
	var original: GameStateStore = GAME_STATE_SCRIPT.new()
	original.begin_cutscene(10)
	original.spend(4)
	original.crush_fondness = 7
	original.dad_silly = 4
	original.set_value(&"dad_job_result", "creative_hire")
	original.dad_success = 99
	original.son_silly = -4
	_check(original.dad_success == 10, "Success stats should clamp to their maximum.")
	_check(original.son_silly == 0, "Silly stats should clamp to their minimum.")

	var restored: GameStateStore = GAME_STATE_SCRIPT.new()
	restored.load_dictionary(original.to_dictionary())
	_check(restored.remaining_budget() == 6, "Serialized state should preserve the active budget.")
	_check(restored.crush_fondness == 7, "Serialized state should preserve relationship stats.")
	_check(restored.dad_silly == 4, "Serialized state should preserve silly stats.")
	_check(
		restored.get_value(&"dad_job_result") == "creative_hire",
		"Serialized state should preserve campaign outcomes.",
	)
	original.free()
	restored.free()


func _test_explicit_phrase_sidecar() -> void:
	var subsystem := DialogicPhraseCutSubsystem.new()
	subsystem.load_for(
		"res://content/episodes/neighbors/phrases.json",
		"res://content/episodes/intro/dialogue.dtl",
	)
	subsystem.ensure_loaded_for_timeline("res://content/episodes/intro/dialogue.dtl")
	_check(
		not subsystem.get_data("neighbors_L001").is_empty(),
		"An explicitly selected phrase sidecar should not be replaced by the adjacent convention.",
	)
	subsystem.free()


func _test_campaign_and_stage() -> void:
	for character_id: String in [
		"son",
		"dad",
		"grandma",
		"crush",
		"doctor",
		"interviewer",
		"mom",
		"penny",
	]:
		_check(
			DialogicResourceUtil.get_character_resource(character_id) != null,
			"Dialogic should register the `%s` speaker resource." % character_id,
		)
	var expected_portraits := {
		"son": ["neutral", "shy", "nervous", "sad", "surprised"],
		"dad": ["happy", "nervous", "neutral", "sad"],
		"grandma": ["happy", "neutral"],
		"crush": ["happy", "nervous", "neutral"],
		"doctor": ["happy", "neutral"],
		"interviewer": ["confused", "happy", "nervous", "neutral"],
		"mom": ["happy", "neutral", "sad"],
	}
	for character_id: String in expected_portraits:
		var character := DialogicResourceUtil.get_character_resource(character_id)
		if character == null:
			continue
		for expression: String in expected_portraits[character_id]:
			_check(
				character.portraits.has(expression),
				"%s should have a `%s` portrait mapping." % [character.display_name, expression],
			)

	var campaign := load("res://content/campaign/campaign.tres") as CampaignDefinition
	_check(campaign != null, "The campaign resource should load.")
	if campaign == null:
		return

	var errors := campaign.validate()
	for error in errors:
		_failures.append("Campaign validation: %s" % error)
	_check(campaign.first_episode_id == &"intro", "The border tutorial should be the first episode.")

	var intro := campaign.get_episode(&"intro")
	_check(intro != null, "The campaign should contain the border tutorial.")
	if intro == null:
		return
	var phrase_file := FileAccess.open(intro.phrase_data_path, FileAccess.READ)
	_check(phrase_file != null, "The intro phrase sidecar should be readable.")
	if phrase_file != null:
		var phrase_data: Variant = JSON.parse_string(phrase_file.get_as_text())
		_check(phrase_data is Dictionary, "The intro phrase sidecar should contain a dictionary.")
		if phrase_data is Dictionary:
			_check(phrase_data.size() >= 3, "The tutorial should include recovery and refill follow-up lines.")
			var first_line: Dictionary = phrase_data.get("intro_L001", {})
			var first_line_cost := 0
			for segment: Variant in first_line.get("segments", []):
				if segment is Dictionary:
					first_line_cost += int(segment.get("cost", 0))
			_check(
				first_line_cost == intro.word_budget,
				"Keeping every phrase in the first tutorial line should exhaust the budget and expose recovery choices.",
			)

	var host: StageHost = STAGE_HOST_SCRIPT.new()
	root.add_child(host)
	host.show_presentation(intro.presentation_scene)
	await process_frame
	_check(host.is_in_group(&"story_stage_host"), "StageHost should register for presentation cues.")
	_check(host.current_presentation != null, "The intro presentation should mount on the StageHost.")
	_check(host.play_cue(&"intro_reveal"), "The intro stage should expose its editor-authored reveal cue.")
	host.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
