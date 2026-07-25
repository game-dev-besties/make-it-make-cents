extends SceneTree

const OVERLAY_SCENE := preload("res://ui/phrase_cut/phrase_cut_overlay.tscn")
const PHRASE_MEMORY_SCRIPT := preload("res://game/runtime/phrase_memory.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var normal: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(normal)
	normal.setup(
		[
			{"type": "phrase", "id": "intro", "text": "I have", "cost": 2},
			{"type": "phrase", "id": "learner", "text": "learn very fast"},
		],
		5,
		"Dad",
	)
	await process_frame

	var normal_chips: Array[Node] = normal.get_node("%Chips").get_children()
	_assert(normal_chips.size() == 2, "expected two phrase chips")
	_assert(
		normal.get_node("%TitleLabel").text == "DAD",
		"the overlay should retain its compact speaker label",
	)
	_assert(
		(normal.get_node("%MoneybotIcon") as TextureRect).texture != null,
		"the phrase selector should include a subtle Moneybot identity mark",
	)
	_assert(
		normal.get_node("%BudgetLabel").text == "AVAILABLE: $5",
		"the overlay should show the remaining spendable budget",
	)
	_assert(
		(normal.get_node("%ConfirmButton") as Button).text == "Say it  /  $5",
		"the action should carry the initial line cost",
	)
	var first_normal_chip := normal_chips[0] as Button
	_assert(
		first_normal_chip.text == "I have",
		"a kept phrase should read as part of the sentence without state or cost copy",
	)
	_assert(
		first_normal_chip.tooltip_text.begins_with("I have costs $2."),
		"a kept chip should explain its state, cost, and available action",
	)
	_assert(
		not first_normal_chip.tooltip_text.contains("Space"),
		"the chip tooltip should not advertise Space as an editing action",
	)
	# The panel is ledger paper (light), so "more prominent" means higher
	# contrast against that background, not simply higher luminance.
	var panel_luminance := Color(0.992157, 0.984314, 0.956863).get_luminance()
	var pressed_contrast := absf(
		panel_luminance - first_normal_chip.get_theme_color("font_pressed_color").get_luminance()
	)
	var cut_contrast := absf(
		panel_luminance - first_normal_chip.get_theme_color("font_color").get_luminance()
	)
	_assert(
		pressed_contrast > cut_contrast,
		"spoken text should carry stronger contrast than struck-through text",
	)
	_assert(
		normal.get_viewport().gui_get_focus_owner() == first_normal_chip,
		"the first phrase should receive keyboard focus when trimming begins",
	)
	var space_press := InputEventKey.new()
	space_press.keycode = KEY_SPACE
	space_press.pressed = true
	Input.parse_input_event(space_press)
	await process_frame
	_assert(
		first_normal_chip.button_pressed,
		"Space should not toggle the focused phrase chip",
	)
	_assert(normal.result.is_empty(), "Space should not resolve the phrase selector")
	var space_release := InputEventKey.new()
	space_release.keycode = KEY_SPACE
	Input.parse_input_event(space_release)
	await process_frame
	first_normal_chip.set_pressed_no_signal(false)
	first_normal_chip.toggled.emit(false)
	_assert(
		first_normal_chip.text == "I have",
		"cutting a phrase should preserve the sentence text for the strike-through treatment",
	)
	_assert(
		first_normal_chip.tooltip_text.begins_with('Cut: "I have" will be omitted, saving $2.'),
		"a cut chip should explain its savings and how to restore it",
	)
	_assert(
		(normal.get_node("%ConfirmButton") as Button).text == "Say it  /  $3",
		"the action should carry the live cost after a phrase is cut",
	)
	normal.call("_on_confirm")
	_assert(normal.result.delivery_mode == &"normal", "kept text should be a normal delivery")
	_assert(normal.result.kept_text == "learn very fast", "chip state should determine assembled text")
	_assert(normal.result.cost == 3, "missing phrase cost should be counted from words")
	_assert(normal.result.kept_ids == ["learner"], "only pressed chip IDs should be kept")
	normal.queue_free()

	var over_budget: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(over_budget)
	over_budget.setup(
		[
			{"type": "phrase", "id": "one", "text": "Expensive opening", "cost": 4},
			{"type": "phrase", "id": "two", "text": "Expensive ending", "cost": 3},
		],
		5,
		"Dad",
	)
	await process_frame
	_assert(
		(over_budget.get_node("%ConfirmButton") as Button).text == "Cut $2 more  /  $7",
		"an unaffordable action should carry the exact remaining cut and its price",
	)
	_assert(
		(over_budget.get_node("%ConfirmButton") as Button).disabled,
		"an unaffordable selection should not be confirmable",
	)
	over_budget.queue_free()

	var responsive: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(responsive)
	await process_frame
	responsive.size = Vector2(400, 600)
	responsive.call("_update_panel_width")
	_assert(
		is_equal_approx(
			(responsive.get_node("%Panel") as PanelContainer).custom_minimum_size.x,
			352.0,
		),
		"the phrase panel should shrink with a narrow viewport and preserve its gutter",
	)
	responsive.size = Vector2(1600, 900)
	responsive.call("_update_panel_width")
	_assert(
		is_equal_approx(
			(responsive.get_node("%Panel") as PanelContainer).custom_minimum_size.x,
			780.0,
		),
		"the phrase panel should stop growing at its readable maximum width",
	)
	responsive.queue_free()

	var short_overlay: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(short_overlay)
	short_overlay.setup(
		[
			{"type": "phrase", "id": "one", "text": "A fairly long opening", "cost": 4},
			{"type": "phrase", "id": "two", "text": "with another phrase", "cost": 3},
			{"type": "phrase", "id": "three", "text": "and one final phrase", "cost": 4},
		],
		0,
		"Dad",
		{"can_use_pity": true, "can_use_sponsor": true},
	)
	await process_frame
	short_overlay.size = Vector2(420, 260)
	short_overlay.call("_update_panel_width")
	await process_frame
	await process_frame
	var panel_scroll := short_overlay.get_node("%PanelScroll") as ScrollContainer
	_assert(
		panel_scroll.size.y <= 228.0,
		"the outer phrase scroll should stay inside the short viewport's safe margins",
	)
	_assert(
		panel_scroll.get_v_scroll_bar().visible,
		"a short viewport should offer vertical scrolling instead of clipping actions",
	)
	panel_scroll.ensure_control_visible(short_overlay.get_node("%SponsorButton") as Control)
	await process_frame
	_assert(
		panel_scroll.scroll_vertical > 0,
		"the recovery actions should be reachable by scrolling in a short viewport",
	)
	short_overlay.queue_free()

	var silence: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(silence)
	silence.setup([{"type": "phrase", "id": "only", "text": "Anything", "cost": 1}], 4, "Dad")
	await process_frame
	(silence.get_node("%Chips").get_child(0) as Button).button_pressed = false
	silence.call("_on_confirm")
	_assert(silence.result.delivery_mode == &"silence", "all removed phrases should resolve as silence")
	_assert(silence.result.cost == 0, "silence should be free")
	silence.queue_free()

	var recovery: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(recovery)
	recovery.setup(
		[{"type": "phrase", "id": "only", "text": "Anything", "cost": 1}],
		0,
		"Dad",
		{
			"can_use_pity": true,
			"can_use_sponsor": false,
			"pity_text": "oof",
		},
	)
	await process_frame
	_assert(recovery.get_node("%RecoveryBox").visible, "zero budget should reveal recovery choices")
	_assert((recovery.get_node("%Chips").get_child(0) as Button).disabled, "zero budget should disable phrase delivery")
	_assert(recovery.get_node("%PityButton").visible, "available pity choice should be visible")
	_assert(not recovery.get_node("%SponsorButton").visible, "unavailable sponsor choice should be hidden")
	_assert(
		(recovery.get_node("%PityButton") as Button).text == '"oof"  /  $0',
		"the pity action should show the exact custom word it will deliver and its cost",
	)
	_assert(
		recovery.get_viewport().gui_get_focus_owner() == recovery.get_node("%SilenceButton"),
		"silence should receive keyboard focus when the budget is empty",
	)
	_assert(
		(recovery.get_node("%Chips").get_child(0) as Button).tooltip_text == "Your budget is empty.",
		"a disabled paid phrase should explain why it is unavailable",
	)
	recovery.call("_on_pity")
	_assert(recovery.result.delivery_mode == &"pity", "pity button should report pity delivery")
	_assert(recovery.result.kept_text == "oof", "the custom pity word shown by the button should be delivered")
	recovery.queue_free()

	var free_phrase: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(free_phrase)
	free_phrase.setup(
		[
			{"type": "phrase", "id": "free", "text": "Free word", "cost": 0},
			{"type": "phrase", "id": "taxed", "text": "Taxed word", "cost": 1},
		],
		0,
		"Dad",
	)
	await process_frame
	var free_chips: Array[Node] = free_phrase.get_node("%Chips").get_children()
	_assert(not (free_chips[0] as Button).disabled, "a free phrase should remain usable at zero budget")
	_assert((free_chips[1] as Button).disabled, "a taxed phrase should remain unavailable at zero budget")
	_assert(free_phrase.get_node("%ConfirmButton").visible, "free delivery should remain confirmable")
	free_phrase.call("_on_confirm")
	_assert(free_phrase.result.delivery_mode == &"normal", "kept free text should be a normal delivery")
	_assert(free_phrase.result.cost == 0, "a free phrase should cost zero")
	free_phrase.queue_free()

	var free_fixed: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(free_fixed)
	free_fixed.setup(
		[{"type": "fixed", "text": "Untaxed sound", "cost": 0}],
		0,
		"Dad",
	)
	await process_frame
	_assert(free_fixed.get_node("%ConfirmButton").visible, "free fixed text should remain confirmable")
	free_fixed.call("_on_confirm")
	_assert(free_fixed.result.kept_text == "Untaxed sound", "free fixed text should be delivered")
	_assert(free_fixed.result.cost == 0, "free fixed text should cost zero")
	free_fixed.queue_free()

	var fixed_only: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(fixed_only)
	fixed_only.setup(
		[{"type": "fixed", "text": "Required words", "cost": 1}],
		3,
		"Dad",
	)
	await process_frame
	_assert(
		fixed_only.get_viewport().gui_get_focus_owner() == fixed_only.get_node("%ConfirmButton"),
		"confirm should receive keyboard focus when there are no phrase chips",
	)
	fixed_only.queue_free()

	var memory: Node = PHRASE_MEMORY_SCRIPT.new()
	memory.call("set_line", ["intro", "learner"], ["learner"], &"sponsor")
	_assert(memory.call("kept", "learner"), "phrase memory should retain kept IDs")
	_assert(memory.call("removed", "intro"), "phrase memory should retain removed IDs")
	_assert(memory.call("delivery_is", "sponsor"), "phrase memory should retain delivery mode")
	memory.free()

	var stats := GameStateStore.new()
	var phrase_event := DialogicPhraseCutEvent.new()
	phrase_event.from_text("phrase_cut teen-son (nervous) test_L001")
	_assert(phrase_event.speaker == "teen-son", "phrase events should accept compiler-valid hyphenated speakers")
	_assert(
		phrase_event.call("_policy_allows", {}, "allow_pity"),
		"phrase events should allow normal recovery when no one-shot policy is pending",
	)
	_assert(
		not phrase_event.call("_policy_allows", {"allow_pity": false}, "allow_pity"),
		"phrase events should honor a one-shot policy that hides pity",
	)
	phrase_event.speaker = "dad"
	stats.begin_cutscene(5)
	phrase_event.call(
		"_apply_delivery",
		stats,
		{"delivery_mode": &"normal", "kept_text": "three taxed words", "cost": 3},
	)
	_assert(stats.remaining_budget() == 2, "normal delivery should spend its phrase cost")
	stats.spend(2)
	var sponsor_result := {"delivery_mode": &"sponsor", "kept_text": "Sponsor", "cost": 0}
	phrase_event.call("_apply_delivery", stats, sponsor_result)
	_assert(stats.remaining_budget() == 3, "sponsor delivery should grant three budget")
	_assert(stats.sponsor_used, "sponsor recovery should be one-time state")
	_assert(stats.dad_success == 2, "sponsor delivery should tank the speaker's success score")
	stats.free()

	var budget_event := DialogicBudgetSetEvent.new()
	budget_event.from_text("budget_set 0")
	_assert(budget_event.amount == 0, "budget_set should parse an exact zero budget")
	_assert(budget_event.to_text() == "budget_set 0", "budget_set should round-trip to timeline text")
	_assert(
		not budget_event.is_valid_event("budget_set -1"),
		"budget_set should reject negative budgets",
	)

	var recovery_event := DialogicRecoveryPolicyEvent.new()
	recovery_event.from_text("recovery_policy pity,sponsor")
	_assert(
		recovery_event.policy == "both",
		"recovery_policy should parse the compiler's combined form",
	)
	_assert(
		recovery_event.to_text() == "recovery_policy pity,sponsor",
		"recovery_policy should round-trip to timeline text",
	)
	_assert(
		not recovery_event.is_valid_event("recovery_policy money"),
		"recovery_policy should reject unknown choices",
	)

	if not _failures.is_empty():
		for failure in _failures:
			printerr("FAIL: ", failure)
		quit(1)
		return
	print("Phrase-cut focused checks passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
