extends SceneTree
## Stable phrase-choice behavior only.
##
## Pixel geometry, animation timing, focus ownership, and synthetic input are
## intentionally left to manual playtesting.

const OVERLAY_SCENE := preload("res://ui/phrase_cut/phrase_cut_overlay.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_initial_recovery_choices()
	await _test_zero_budget_state()
	await _test_dynamic_phrase_labels()
	await _test_adjacent_cut_connections()
	await _test_long_phrase_wraps_inside_panel()
	if _failures.is_empty():
		print("Phrase-choice behavior checks passed.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("FAIL: ", failure)
	quit(1)


func _test_initial_recovery_choices() -> void:
	var overlay: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(overlay)
	overlay.setup(
		[{"type": "phrase", "id": "only", "text": "Anything", "cost": 1}],
		4,
		"Dad",
		{"can_use_pity": true, "can_use_sponsor": true},
	)
	await process_frame

	_check(
		overlay.get_node("%RecoveryBox").visible,
		"Recovery choices should be visible before phrase editing begins.",
	)
	_check(overlay.get_node("%SilenceButton").visible, "No response should be available.")
	_check(overlay.get_node("%PityButton").visible, "HNF should be available.")
	_check(overlay.get_node("%SponsorButton").visible, "Sponsor should be available.")

	var chip := overlay.get_node("%Chips").get_child(0) as Button
	chip.set_pressed_no_signal(false)
	overlay.call("_recompute")
	_check(
		overlay.get_node("%RecoveryBox").visible,
		"Recovery choices should stay in place once phrase editing begins.",
	)
	_check(
		not overlay.get_node("%RecoveryLabel").visible,
		"Positive-budget lines should not show recovery flavor text.",
	)
	_check(
		overlay.get_node("%ConfirmButton").visible,
		"An edited empty response should remain confirmable.",
	)

	overlay.call("_on_confirm")
	_check(overlay.result.delivery_mode == &"silence", "An empty edit should submit silence.")
	_check(overlay.result.cost == 0, "Silence should cost nothing.")
	overlay.queue_free()
	await process_frame


func _test_zero_budget_state() -> void:
	var overlay: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(overlay)
	overlay.setup(
		[{"type": "phrase", "id": "only", "text": "Anything", "cost": 1}],
		0,
		"Dad",
		{"can_use_pity": true, "can_use_sponsor": false},
	)
	await process_frame

	_check(
		overlay.get_node("%RecoveryBox").visible,
		"Recovery choices should remain visible when the budget is empty.",
	)
	_check(
		overlay.get_node("%RecoveryLabel").visible,
		"An empty budget should show a concise fallback prompt.",
	)
	_check(
		(overlay.get_node("%Chips").get_child(0) as Button).disabled,
		"Paid phrases should be disabled when the budget is empty.",
	)
	_check(overlay.get_node("%PityButton").visible, "Available HNF should be visible.")
	_check(not overlay.get_node("%SponsorButton").visible, "Used sponsor should stay hidden.")
	overlay.queue_free()
	await process_frame


func _test_dynamic_phrase_labels() -> void:
	var overlay: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(overlay)
	overlay.setup(
		[
			{"type": "phrase", "id": "no", "text": "No,", "cost": 1},
			{"type": "phrase", "id": "answer", "text": "I don’t", "cost": 2},
		],
		3,
		"Dad",
	)
	await process_frame

	var no_chip := overlay.get_node("%Chips").get_child(0) as Button
	var answer_chip := overlay.get_node("%Chips").get_child(1) as Button
	answer_chip.set_pressed_no_signal(false)
	overlay.call("_recompute")
	_check(no_chip.text == "No.", "A retained terminal comma should display as a period.")
	answer_chip.set_pressed_no_signal(true)
	overlay.call("_recompute")
	_check(no_chip.text == "No,", "Restoring a continuation should restore its comma.")
	overlay.queue_free()
	await process_frame


func _test_adjacent_cut_connections() -> void:
	root.size = Vector2i(1152, 648)
	var overlay: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(overlay)
	overlay.setup(
		[
			{"type": "phrase", "id": "a", "text": "Really", "cost": 1},
			{"type": "phrase", "id": "b", "text": "very", "cost": 1},
			{"type": "fixed", "text": "and"},
			{"type": "phrase", "id": "c", "text": "truly", "cost": 1},
		],
		3,
		"Percy",
	)
	await process_frame

	var chips := overlay.get_node("%Chips") as FlowContainer
	var first := chips.get_child(0) as PhraseCutWord
	var second := chips.get_child(1) as PhraseCutWord
	var after_fixed := chips.get_child(3) as PhraseCutWord
	first.set_pressed_no_signal(false)
	second.set_pressed_no_signal(false)
	after_fixed.set_pressed_no_signal(false)
	overlay.call("_recompute")
	await process_frame
	overlay.call("_refresh_strike_connections")

	_check(
		first.get_strike_connections().y > 0.0
		and second.get_strike_connections().x > 0.0,
		"Adjacent cut words on one row should share a continuous strike.",
	)
	_check(
		is_zero_approx(second.get_strike_connections().y)
		and is_zero_approx(after_fixed.get_strike_connections().x),
		"Fixed text should break a connected strike.",
	)
	_check(
		first.get_theme_color("font_color").is_equal_approx(
			Color(0.917647, 0.498039, 0.345098, 1),
		),
		"Cut word text should match the orange strike color.",
	)
	overlay.queue_free()
	await process_frame


func _test_long_phrase_wraps_inside_panel() -> void:
	root.size = Vector2i(1152, 648)
	var overlay: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(overlay)
	overlay.setup(
		[
			{
				"type": "phrase",
				"id": "balance",
				"text": (
					"My balance is completely, utterly, absolutely, fine. "
					+ "It has literally never been better."
				),
				"cost": 13,
			},
			{"type": "phrase", "id": "im", "text": "I’m", "cost": 1},
		],
		13,
		"Percy",
	)
	await process_frame

	var chips := overlay.get_node("%Chips") as FlowContainer
	var balance_chip := chips.get_child(0) as Button
	_check(
		balance_chip.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"The long balance phrase should enable word wrapping.",
	)
	_check(
		balance_chip.size.x <= chips.size.x + 0.5,
		"The long balance phrase should remain inside the phrase row.",
	)
	_check(
		balance_chip.size.y > 46.0,
		"The long balance phrase should grow vertically when it wraps.",
	)
	var strike_lines: Array = balance_chip.call("_strike_line_rects")
	_check(
		strike_lines.size() > 1,
		"A wrapped phrase should draw a separate strike through each text line.",
	)
	var previous_line_y := -INF
	for strike_line: Variant in strike_lines:
		var line_rect := strike_line as Rect2
		_check(
			line_rect.get_center().y > previous_line_y,
			"Wrapped phrase strikes should follow the rendered line positions.",
		)
		previous_line_y = line_rect.get_center().y
	overlay.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
