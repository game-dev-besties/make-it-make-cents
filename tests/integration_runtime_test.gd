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
	_test_non_stacking_goto()
	_test_type_sound_lifecycle()
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
	_check(
		state.money_total_saved == 0,
		"Unused sponsor credit should expire instead of becoming family savings.",
	)
	state.end_cutscene()
	_check(state.money_total_saved == 0, "Ending a cutscene twice must not create savings.")

	state.begin_cutscene(2)
	_check(not state.pity_used and not state.sponsor_used, "Recovery choices should reset per cutscene.")
	state.free()

	var discarded_sponsor_state: GameStateStore = GAME_STATE_SCRIPT.new()
	discarded_sponsor_state.begin_cutscene(0)
	discarded_sponsor_state.use_sponsor(3)
	discarded_sponsor_state.set_remaining_budget(0)
	_check(
		discarded_sponsor_state.cutscene_reserved_savings == 0,
		"Removing sponsor credit should not convert it into reserved savings.",
	)
	discarded_sponsor_state.end_cutscene()
	_check(
		discarded_sponsor_state.money_total_saved == 0,
		"Discarded sponsor credit should never enter persistent savings.",
	)
	discarded_sponsor_state.free()

	var score_state: GameStateStore = GAME_STATE_SCRIPT.new()
	score_state.son_success = 2
	score_state.son_silly = 4
	var son_episode := EpisodeDefinition.new()
	son_episode.id = &"son"
	son_episode.word_budget = 80
	son_episode.score_owner = &"son"
	score_state.apply_episode(son_episode)
	_check(
		score_state.son_success == 5 and score_state.son_silly == 0,
		"Percy's scored conversation should start neutral after the forced tutorial sponsor.",
	)
	score_state.free()

	var forced_state: GameStateStore = GAME_STATE_SCRIPT.new()
	var budget_changes: Array = []
	forced_state.budget_changed.connect(
		func(current_budget: int, previous_budget: int) -> void:
			budget_changes.append([current_budget, previous_budget])
	)
	forced_state.begin_cutscene(10)
	forced_state.spend(4)
	_check(
		forced_state.set_remaining_budget(0) == 0,
		"Tutorial events should be able to force the remaining budget to zero.",
	)
	_check(forced_state.remaining_budget() == 0, "The forced budget should be exact.")
	_check(
		forced_state.cutscene_spent == 4,
		"Setting the remaining budget should preserve the words already spent.",
	)
	_check(
		budget_changes[-1] == [0, 6],
		"Setting the remaining budget should emit the existing budget signal.",
	)
	forced_state.free()

	var conserved_state: GameStateStore = GAME_STATE_SCRIPT.new()
	conserved_state.begin_cutscene(30)
	conserved_state.spend(25)
	conserved_state.set_remaining_budget(0)
	_check(
		conserved_state.cutscene_reserved_savings == 5,
		"Forcing a practice balance should reserve words the player already conserved.",
	)
	_check(
		conserved_state.use_sponsor(3),
		"The Chapter 1 sponsor should refill three words after budget practice.",
	)
	conserved_state.spend(2)
	var restored_conserved_state: GameStateStore = GAME_STATE_SCRIPT.new()
	restored_conserved_state.load_dictionary(conserved_state.to_dictionary())
	_check(
		restored_conserved_state.cutscene_reserved_savings == 5,
		"Reserved cutscene savings should survive serialization.",
	)
	_check(
		restored_conserved_state.remaining_budget() == 1,
		"The sponsor refill should retain one active word after spending two.",
	)
	_check(
		restored_conserved_state.cutscene_sponsor_credit == 1,
		"Remaining sponsor credit should survive serialization.",
	)
	restored_conserved_state.end_cutscene()
	_check(
		restored_conserved_state.money_total_saved == 5,
		"Chapter 1 should save conserved words without banking sponsor credit.",
	)
	_check(
		restored_conserved_state.cutscene_reserved_savings == 0,
		"Ending a cutscene should transfer and clear its reserved savings.",
	)
	conserved_state.free()
	restored_conserved_state.free()


func _test_state_round_trip() -> void:
	var original: GameStateStore = GAME_STATE_SCRIPT.new()
	original.begin_cutscene(10)
	original.spend(4)
	original.crush_fondness = 7
	original.dad_silly = 4
	original.intro_grandma_praised_for_silence = true
	original.intro_pills_confiscated = true
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
		restored.intro_grandma_praised_for_silence,
		"Serialized state should preserve the silence tutorial flag.",
	)
	_check(restored.intro_pills_confiscated, "Serialized state should preserve the customs outcome flag.")
	_check(
		restored.get_value(&"dad_job_result") == "creative_hire",
		"Serialized state should preserve campaign outcomes.",
	)
	restored.reset_for_new_game()
	_check(
		not restored.intro_grandma_praised_for_silence and not restored.intro_pills_confiscated,
		"Starting a new game should clear Chapter 1 flags.",
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
	_check(
		subsystem.set_recovery_policy(&"pity"),
		"The phrase subsystem should accept a pity-only recovery policy.",
	)
	var pity_policy := subsystem.consume_recovery_policy()
	_check(
		pity_policy.get("allow_pity") and not pity_policy.get("allow_sponsor"),
		"A pity-only policy should hide sponsor recovery.",
	)
	_check(
		subsystem.consume_recovery_policy().is_empty(),
		"A recovery policy should be consumed by one phrase-cut event.",
	)
	_check(
		subsystem.set_recovery_policy(&"pity,sponsor"),
		"The phrase subsystem should accept the compiler's combined policy.",
	)
	var combined_policy := subsystem.consume_recovery_policy()
	_check(
		combined_policy.get("allow_pity") and combined_policy.get("allow_sponsor"),
		"A combined policy should leave both recovery options available.",
	)
	_check(
		not subsystem.set_recovery_policy(&"invalid"),
		"The phrase subsystem should reject unknown recovery policies.",
	)
	subsystem.free()


func _test_type_sound_lifecycle() -> void:
	var type_sound := DialogicNode_TypeSounds.new()
	var authored_sound := AudioStreamWAV.new()
	type_sound.sounds = [authored_sound]
	type_sound.end_sound = authored_sound
	root.add_child(type_sound)
	root.remove_child(type_sound)
	_check(
		type_sound.sounds == [authored_sound] and type_sound.end_sound == authored_sound,
		"Removing a type-sound node from the tree should preserve its authored sounds.",
	)
	root.add_child(type_sound)

	var mood_sound := AudioStreamWAV.new()
	var shared_mood := {
		"sounds": [mood_sound],
		"mode": DialogicNode_TypeSounds.Modes.AWAIT,
	}
	type_sound.load_overwrite(shared_mood)
	type_sound.current_overwrite_data["mode"] = DialogicNode_TypeSounds.Modes.INTERRUPT
	(type_sound.current_overwrite_data["sounds"] as Array).clear()
	_check(
		shared_mood["mode"] == DialogicNode_TypeSounds.Modes.AWAIT
		and shared_mood["sounds"] == [mood_sound],
		"Type-sound overrides should not mutate shared character mood data.",
	)
	type_sound.free()


func _test_non_stacking_goto() -> void:
	var goto_event := DialogicGotoLabelEvent.new()
	goto_event.from_text("goto_label retry")
	_check(goto_event.label_name == "retry", "goto_label should parse a local label.")
	_check(
		goto_event.to_text() == "goto_label retry",
		"goto_label should round-trip to timeline text.",
	)
	_check(
		not goto_event.is_valid_event("goto_label not-valid"),
		"goto_label should reject invalid label identifiers.",
	)

	var dialogic_handler := root.get_node_or_null("Dialogic") as DialogicGameHandler
	_check(dialogic_handler != null, "The goto_label runtime check requires Dialogic.")
	if dialogic_handler == null:
		return
	var previous_timeline: DialogicTimeline = dialogic_handler.current_timeline
	var previous_events: Array = dialogic_handler.current_timeline_events
	var previous_event_index: int = dialogic_handler.current_event_idx
	var previous_jump_stack: Array = dialogic_handler.Jump.jump_stack.duplicate(true)
	var loop_timeline := DialogicTimeline.new()
	loop_timeline.from_text("label retry\n[end_timeline]")
	loop_timeline.process()
	dialogic_handler.current_timeline = loop_timeline
	dialogic_handler.current_timeline_events = loop_timeline.events
	dialogic_handler.current_event_idx = 1
	dialogic_handler.Jump.jump_stack.clear()
	goto_event.dialogic = dialogic_handler
	goto_event.call("_execute")
	_check(
		dialogic_handler.current_event_idx == -1,
		"goto_label should move execution to the requested local label.",
	)
	_check(
		dialogic_handler.Jump.jump_stack.is_empty(),
		"goto_label should not add a return-stack entry.",
	)
	dialogic_handler.current_timeline = previous_timeline
	dialogic_handler.current_timeline_events = previous_events
	dialogic_handler.current_event_idx = previous_event_index
	dialogic_handler.Jump.jump_stack = previous_jump_stack


func _test_campaign_and_stage() -> void:
	for character_id: String in [
		"son",
		"dad",
		"grandma",
		"crush",
		"doctor",
		"interviewer",
		"officer",
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
		"penny": ["neutral"],
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
			_check(phrase_data.size() >= 5, "Chapter 1 should include all tutorial phrase-cut lines.")
			var first_line: Dictionary = phrase_data.get("intro_L001", {})
			var first_line_cost := 0
			for segment: Variant in first_line.get("segments", []):
				if segment is Dictionary:
					first_line_cost += int(segment.get("cost", 0))
			_check(
				first_line_cost > 0 and first_line_cost <= intro.word_budget,
				"The first phrase-cut lesson should be affordable from the opening budget.",
			)
	var timeline_file := FileAccess.open(intro.dialogue_timeline_path, FileAccess.READ)
	_check(timeline_file != null, "The intro timeline should be readable.")
	if timeline_file != null:
		var timeline_text := timeline_file.get_as_text()
		_check(
			"budget_set 0" in timeline_text,
			"Chapter 1 should explicitly enter zero-budget practice.",
		)
		_check(
			"recovery_policy pity" in timeline_text,
			"Chapter 1 should include a pity-only practice line.",
		)
		_check(
			"recovery_policy sponsor" in timeline_text,
			"Chapter 1 should include a sponsor-only practice line.",
		)

	var host: StageHost = STAGE_HOST_SCRIPT.new()
	root.add_child(host)
	host.show_presentation(intro.presentation_scene)
	await process_frame
	_check(host.is_in_group(&"story_stage_host"), "StageHost should register for presentation cues.")
	_check(host.current_presentation != null, "The intro presentation should mount on the StageHost.")
	for cue_id: StringName in [
		&"intro_reveal",
		&"penny_reveal",
		&"sponsor_blackout",
		&"sponsor_return",
		&"customs_focus",
		&"home_reveal",
		&"clementine_reveal",
	]:
		_check(
			host.play_cue(cue_id),
			"The intro stage should expose its `%s` editor-authored cue." % cue_id,
		)
	var intro_stage := host.current_presentation as StoryStage
	if intro_stage != null:
		_check(
			(intro_stage.get_node("ActorSlots/Left") as StageActorSlot).character_id == &"dad",
			"The intro's left actor slot should follow Dad's dialogue expressions.",
		)
		_check(
			(intro_stage.get_node("ActorSlots/Center") as StageActorSlot).character_id == &"son",
			"The intro's center actor slot should follow Percy's dialogue expressions.",
		)
		_check(
			(intro_stage.get_node("ActorSlots/Right") as StageActorSlot).character_id == &"grandma",
			"The intro's right actor slot should follow Grandma's dialogue expressions.",
		)
		var animation_player := intro_stage.get_node("AnimationPlayer") as AnimationPlayer
		var penny_sprite := intro_stage.get_node("Effects/PennySprite") as TextureRect
		_check(
			penny_sprite.texture != null,
			"The intro should use Moneybot's illustrated sprite instead of the placeholder card.",
		)
		host.play_cue(&"penny_reveal")
		animation_player.advance(0.35)
		_check(
			is_equal_approx(penny_sprite.modulate.a, 1.0),
			"The Penny reveal cue should show the Moneybot sprite.",
		)
		host.play_cue(&"home_reveal")
		animation_player.advance(0.25)
		_check(
			is_zero_approx(penny_sprite.modulate.a),
			"The home reveal should dismiss the Moneybot sprite.",
		)
		var clementine_sprite := intro_stage.get_node("Effects/ClementineSprite") as TextureRect
		_check(
			clementine_sprite.texture != null,
			"The intro's home scene should use Clementine's finished portrait.",
		)
		host.play_cue(&"clementine_reveal")
		animation_player.advance(0.35)
		_check(
			is_equal_approx(clementine_sprite.modulate.a, 1.0),
			"The Clementine reveal should show her portrait instead of a placeholder card.",
		)
		var sponsor_blackout := intro_stage.get_node("Effects/SponsorBlackout") as Control
		host.play_cue(&"sponsor_blackout")
		animation_player.advance(0.15)
		_check(
			is_equal_approx(sponsor_blackout.modulate.a, 1.0),
			"The sponsor cue should fully reveal the tariff message.",
		)
		host.play_cue(&"sponsor_return")
		animation_player.advance(0.05)
		_check(
			sponsor_blackout.modulate.a > 0.0,
			"The sponsor return cue should begin by fading the tariff message.",
		)
		host.play_cue(&"customs_focus")
		_check(
			is_zero_approx(sponsor_blackout.modulate.a),
			"Interrupting sponsor return should still fully dismiss the tariff message.",
		)
	host.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
