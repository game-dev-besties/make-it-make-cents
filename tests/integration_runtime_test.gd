extends SceneTree
## Core state and custom-event behavior.
##
## Scene composition, animation timing, portraits, and input routing are
## deliberately excluded because they are better covered by playtesting.

const GAME_STATE_SCRIPT := preload("res://game/runtime/game_state.gd")
const PHRASE_MEMORY_SCRIPT := preload("res://game/runtime/phrase_memory.gd")
const DIALOGUE_HUD_SCENE := preload("res://ui/dialogue/dialogue_hud.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_budget_and_recovery()
	_test_phrase_affordability_memory()
	_test_campaign_totals()
	_test_state_round_trip()
	_test_story_flags_and_history()
	_test_phrase_recovery_policy()
	await _test_sponsor_jingle_playback()
	_test_non_stacking_goto()

	if _failures.is_empty():
		print("Core runtime checks passed.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("FAIL: ", failure)
	quit(1)


func _test_budget_and_recovery() -> void:
	var state: GameStateStore = GAME_STATE_SCRIPT.new()
	state.begin_cutscene(5)
	_check(state.remaining_budget() == 5, "A cutscene should start with its episode budget.")
	_check(state.can_use_pity(), "HNF should be available while budget remains.")
	_check(state.can_use_sponsor(), "Sponsor should be available while budget remains.")
	_check(state.use_pity(), "HNF should be usable.")
	_check(state.use_pity(), "HNF should remain available in the same cutscene.")
	_check(state.use_sponsor(3), "Sponsor should be usable.")
	_check(state.remaining_budget() == 8, "Sponsor should add three dollars.")
	_check(state.use_sponsor(3), "Sponsor should remain available in the same cutscene.")
	_check(state.remaining_budget() == 11, "Repeated sponsor use should add three more dollars.")
	_check(state.spend(20) == 11, "Spending should not overdraw the budget.")
	_check(state.remaining_budget() == 0, "Spending should reach zero exactly.")
	state.end_cutscene()
	_check(
		state.money_total_saved == 0,
		"Unused sponsor credit should not become persistent savings.",
	)

	state.begin_cutscene(2)
	_check(state.can_use_pity() and state.can_use_sponsor(), "Recovery should be available.")
	state.free()


func _test_phrase_affordability_memory() -> void:
	var phrase_event := DialogicPhraseCutEvent.new()
	var phrases: Array = [
		{"type": "phrase", "text": "Four words cost four", "cost": 4},
		{"type": "phrase", "text": "Five words cost five now", "cost": 5},
	]
	_check(
		not bool(phrase_event.call("_could_afford_speech", phrases, 2)),
		"A balance below every phrase cost should count as unable to speak.",
	)
	_check(
		bool(phrase_event.call("_could_afford_speech", phrases, 4)),
		"A balance covering one phrase should count as able to speak.",
	)

	var memory: Node = PHRASE_MEMORY_SCRIPT.new()
	memory.call("set_line", ["first", "second"], [], &"sponsor", false)
	_check(
		not bool(memory.call("could_afford_speech")),
		"Phrase memory should retain pre-jingle unaffordability.",
	)
	memory.call("set_line", ["first", "second"], [], &"sponsor", true)
	_check(
		bool(memory.call("could_afford_speech")),
		"Phrase memory should retain pre-jingle affordability.",
	)
	memory.free()


func _test_campaign_totals() -> void:
	var state: GameStateStore = GAME_STATE_SCRIPT.new()
	var phrase_event := DialogicPhraseCutEvent.new()
	phrase_event.speaker = "son"
	state.begin_cutscene(5)
	phrase_event.call(
		"_apply_delivery",
		state,
		{"delivery_mode": &"normal", "cost": 2},
	)
	phrase_event.call(
		"_apply_delivery",
		state,
		{"delivery_mode": &"pity", "cost": 0},
	)
	phrase_event.call(
		"_apply_delivery",
		state,
		{"delivery_mode": &"sponsor", "cost": 0},
	)
	phrase_event.call(
		"_apply_delivery",
		state,
		{"delivery_mode": &"silence", "cost": 0},
	)
	_check(state.money_total_spent == 2, "Paid words should accumulate across the campaign.")
	_check(state.delivery_jingles_sung == 1, "Sponsor deliveries should count jingles.")
	_check(state.delivery_grunts_said == 1, "Pity deliveries should count grunts.")
	_check(state.delivery_nothings_said == 1, "Silence deliveries should count nothings.")
	state.free()


func _test_state_round_trip() -> void:
	var original: GameStateStore = GAME_STATE_SCRIPT.new()
	original.begin_cutscene(10)
	original.spend(4)
	original.son_success = 7
	original.dad_silly = 4
	original.set_value(&"dad_job_result", "creative_hire")
	original.set_story_flag(&"dad_offended_interviewer", "soda")
	original.set_story_flag(&"dad_mentioned_family", true)
	original.record_delivery(&"sponsor")
	original.record_delivery(&"pity")
	original.record_delivery(&"silence")
	original.dad_success = 99
	original.son_silly = -4
	_check(original.dad_success == 10, "Success stats should clamp to ten.")
	_check(original.son_silly == 0, "Silly stats should clamp to zero.")

	var restored: GameStateStore = GAME_STATE_SCRIPT.new()
	restored.load_dictionary(original.to_dictionary())
	_check(restored.remaining_budget() == 6, "Save data should preserve active budget.")
	_check(restored.son_success == 7, "Save data should preserve success stats.")
	_check(restored.dad_silly == 4, "Save data should preserve silly stats.")
	_check(restored.money_total_spent == 4, "Save data should preserve money spent.")
	_check(restored.delivery_jingles_sung == 1, "Save data should preserve jingles.")
	_check(restored.delivery_grunts_said == 1, "Save data should preserve grunts.")
	_check(restored.delivery_nothings_said == 1, "Save data should preserve nothings.")
	_check(
		restored.get_value(&"dad_job_result") == "creative_hire",
		"Save data should preserve campaign values.",
	)
	_check(
		restored.get_story_flag(&"dad_offended_interviewer") == "soda",
		"Save data should preserve enum story flags.",
	)
	_check(
		restored.get_story_flag(&"dad_mentioned_family"),
		"Save data should preserve boolean story flags.",
	)
	restored.reset_for_new_game()
	_check(
		restored.get_story_flag(&"dad_offended_interviewer") == "none",
		"A new game should restore flag defaults.",
	)
	_check(
		not restored.get_story_flag(&"dad_mentioned_family"),
		"A new game should clear boolean flags.",
	)
	_check(
		restored.money_total_spent == 0
		and restored.delivery_jingles_sung == 0
		and restored.delivery_grunts_said == 0
		and restored.delivery_nothings_said == 0,
		"A new game should clear campaign totals.",
	)
	original.free()
	restored.free()


func _test_story_flags_and_history() -> void:
	var state: GameStateStore = GAME_STATE_SCRIPT.new()
	_check(
		state.set_story_flag(&"dad_offended_interviewer", "butts"),
		"Story flags should accept declared values.",
	)
	_check(
		state.story_flag_equals(&"dad_offended_interviewer", "butts"),
		"Story flag equality should expose the current value.",
	)
	state.free()

	var set_event := DialogicStoryFlagSetEvent.new()
	set_event.from_text(
		'story_flag_set {"name":"dad_offended_interviewer","value":"butts"}'
	)
	var check_event := DialogicStoryFlagCheckEvent.new()
	check_event.from_text(
		(
			'story_flag_check {"name":"dad_offended_interviewer",'
			+ '"operator":"!=","expected":"none","branch":"dad_did_not_get_the_job"}'
		)
	)
	_check(
		set_event.flag_name == "dad_offended_interviewer"
		and set_event.flag_value == "butts",
		"Generated SET events should parse.",
	)
	_check(
		check_event.operator == "!="
		and check_event.branch == "dad_did_not_get_the_job",
		"Generated CHECK events should parse.",
	)

	var dialogic := root.get_node_or_null("Dialogic") as DialogicGameHandler
	var game_stats := root.get_node_or_null("GameStats") as GameStateStore
	_check(dialogic != null and game_stats != null, "Story events require their autoloads.")
	if dialogic == null or game_stats == null:
		return
	var history := dialogic.get_subsystem("History")
	history.simple_history_content.clear()
	game_stats.reset_for_new_game()
	set_event.dialogic = dialogic
	set_event._execute()
	check_event.dialogic = dialogic
	check_event._execute()
	var entries: Array = history.get_simple_history()
	_check(
		entries.size() == 2
		and entries[0].get("debug_kind") == "SET"
		and entries[1].get("debug_kind") == "CHECK",
		"SET and CHECK should append ordered debug history entries.",
	)
	history.simple_history_content.clear()
	game_stats.reset_for_new_game()


func _test_phrase_recovery_policy() -> void:
	var subsystem := DialogicPhraseCutSubsystem.new()
	_check(
		subsystem.set_recovery_policy(&"pity,sponsor"),
		"The phrase subsystem should accept the compiler recovery policy.",
	)
	var policy := subsystem.consume_recovery_policy()
	_check(
		policy.get("allow_pity") and policy.get("allow_sponsor"),
		"The combined policy should enable both recovery responses.",
	)
	_check(
		subsystem.consume_recovery_policy().is_empty(),
		"A recovery policy should be consumed by one phrase prompt.",
	)
	_check(
		not subsystem.set_recovery_policy(&"invalid"),
		"Unknown recovery policies should be rejected.",
	)
	subsystem.free()


func _test_sponsor_jingle_playback() -> void:
	var dialogic := root.get_node_or_null("Dialogic") as DialogicGameHandler
	_check(dialogic != null, "Sponsor jingle playback requires Dialogic.")
	if dialogic == null:
		return
	var dialogue_hud := DIALOGUE_HUD_SCENE.instantiate()
	root.add_child(dialogue_hud)
	await process_frame
	var dialogue_text := (
		dialogue_hud.get_node_or_null("%DialogicNode_DialogText")
		as DialogicNode_DialogText
	)
	_check(dialogue_text != null, "Sponsor jingle coverage requires the dialogue HUD.")
	if dialogue_text != null:
		dialogue_text.textbox_root.show()
	var phrase_event := DialogicPhraseCutEvent.new()
	phrase_event.dialogic = dialogic
	var started := bool(phrase_event.call("_start_sponsor_jingle"))
	var player := (
		dialogic.Audio.current_audio_channels.get(
			DialogicPhraseCutEvent.SPONSOR_JINGLE_CHANNEL,
		)
		as AudioStreamPlayer
	)
	_check(
		started
		and player != null
		and player.stream is AudioStreamMP3
		and player.stream.resource_path
		== DialogicPhraseCutEvent.SPONSOR_JINGLE_PATH,
		"Every sponsor delivery should start the sponsor jingle.",
	)
	_check(
		player != null
		and not (player.stream as AudioStreamMP3).loop
		and is_equal_approx(player.pitch_scale, 1.0),
		"The sponsor jingle should be a normal-speed, non-looping one-shot.",
	)
	if started:
		await phrase_event.call("_finish_sponsor_jingle")
	_check(
		dialogue_text != null and dialogue_text.textbox_root.visible,
		"The dialogue box should remain visible until the sponsor jingle finishes.",
	)
	phrase_event.call("_stop_sponsor_jingle")
	dialogue_hud.queue_free()
	await process_frame


func _test_non_stacking_goto() -> void:
	var goto_event := DialogicGotoLabelEvent.new()
	goto_event.from_text("goto_label retry")
	_check(goto_event.label_name == "retry", "goto_label should parse a local label.")

	var dialogic := root.get_node_or_null("Dialogic") as DialogicGameHandler
	_check(dialogic != null, "goto_label requires the Dialogic autoload.")
	if dialogic == null:
		return
	var previous_timeline: DialogicTimeline = dialogic.current_timeline
	var previous_events: Array = dialogic.current_timeline_events
	var previous_event_index: int = dialogic.current_event_idx
	var previous_jump_stack: Array = dialogic.Jump.jump_stack.duplicate(true)
	var timeline := DialogicTimeline.new()
	timeline.from_text("label retry\n[end_timeline]")
	timeline.process()
	dialogic.current_timeline = timeline
	dialogic.current_timeline_events = timeline.events
	dialogic.current_event_idx = 1
	dialogic.Jump.jump_stack.clear()
	goto_event.dialogic = dialogic
	goto_event.call("_execute")
	_check(dialogic.current_event_idx == -1, "goto_label should jump to its label.")
	_check(dialogic.Jump.jump_stack.is_empty(), "goto_label should not add a return frame.")
	dialogic.current_timeline = previous_timeline
	dialogic.current_timeline_events = previous_events
	dialogic.current_event_idx = previous_event_index
	dialogic.Jump.jump_stack = previous_jump_stack


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
