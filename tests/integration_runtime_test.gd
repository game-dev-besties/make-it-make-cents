extends SceneTree
## Core state and custom-event behavior.
##
## Scene composition, animation timing, portraits, and input routing are
## deliberately excluded because they are better covered by playtesting.

const GAME_STATE_SCRIPT := preload("res://game/runtime/game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_budget_and_recovery()
	_test_state_round_trip()
	_test_story_flags_and_history()
	_test_phrase_recovery_policy()
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
	_check(state.use_pity(), "HNF should be usable once.")
	_check(not state.use_pity(), "HNF should not be reusable in one cutscene.")
	_check(state.use_sponsor(3), "Sponsor should be usable once.")
	_check(state.remaining_budget() == 8, "Sponsor should add three dollars.")
	_check(state.spend(10) == 8, "Spending should not overdraw the budget.")
	_check(state.remaining_budget() == 0, "Spending should reach zero exactly.")
	_check(not state.use_sponsor(3), "Sponsor should not be reusable in one cutscene.")
	state.end_cutscene()
	_check(
		state.money_total_saved == 0,
		"Unused sponsor credit should not become persistent savings.",
	)

	state.begin_cutscene(2)
	_check(not state.pity_used and not state.sponsor_used, "Recovery use should reset.")
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
	original.dad_success = 99
	original.son_silly = -4
	_check(original.dad_success == 10, "Success stats should clamp to ten.")
	_check(original.son_silly == 0, "Silly stats should clamp to zero.")

	var restored: GameStateStore = GAME_STATE_SCRIPT.new()
	restored.load_dictionary(original.to_dictionary())
	_check(restored.remaining_budget() == 6, "Save data should preserve active budget.")
	_check(restored.son_success == 7, "Save data should preserve success stats.")
	_check(restored.dad_silly == 4, "Save data should preserve silly stats.")
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
