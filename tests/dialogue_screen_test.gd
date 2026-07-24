extends SceneTree
## End-to-end smoke test for the title -> tutorial -> title flow.

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	var title := main.get_node("TitleScreen") as Control
	var screen := main.get_node("DialogueScreen") as Control
	var start_button := main.get_node(
		"TitleScreen/SafeMargin/Center/Menu/StartButton"
	) as Button
	var continue_button := screen.get_node("%ContinueButton") as Button
	var phrase_panel := screen.get_node("%PhraseCutPanel") as Control

	start_button.pressed.emit()
	await process_frame
	_check(not title.visible, "Start should hide the title screen.")
	_check(screen.visible, "Start should show the dialogue screen.")
	_check(
		(screen.get_node("%SpeakerLabel") as Label).text == "Narrator",
		"The tutorial should start on its narrator line.",
	)

	await _advance_until_phrase(continue_button, phrase_panel)
	var confirm_button := phrase_panel.get_node("%ConfirmButton") as Button
	_check(not confirm_button.disabled, "The first complete phrase should be affordable.")
	confirm_button.pressed.emit()
	await process_frame
	_check(not phrase_panel.visible, "Submitting a phrase should close the overlay.")
	_check(
		(screen.get_node("%DialogueText") as Label).text.begins_with("Hello,"),
		"The selected utterance should appear before the NPC response.",
	)

	# Show the reply, then continue through the declaration setup.
	continue_button.pressed.emit()
	await process_frame
	await _advance_until_phrase(continue_button, phrase_panel)

	# The full declaration is over budget after the expensive greeting. Keep only
	# "No," to exercise chip toggling and the exact-response path.
	var chips_flow := phrase_panel.get_node("%ChipsFlow") as HFlowContainer
	for index in range(1, chips_flow.get_child_count()):
		var chip := chips_flow.get_child(index) as Button
		chip.set_pressed_no_signal(false)
		chip.toggled.emit(false)
	_check(not confirm_button.disabled, "Keeping only 'No' should fit the remaining budget.")
	confirm_button.pressed.emit()
	await process_frame

	# The declaration response intentionally empties the tutorial budget.
	continue_button.pressed.emit()
	await process_frame
	await _advance_until_phrase(continue_button, phrase_panel)
	_check(
		(phrase_panel.get_node("%BrokePrompt") as Label).visible,
		"Zero budget should show the recovery choices.",
	)
	(phrase_panel.get_node("%SilenceButton") as Button).pressed.emit()
	await process_frame
	_check(
		(screen.get_node("%DialogueText") as Label).text == "Penny says nothing.",
		"Silence should be presented as the player's chosen delivery.",
	)
	continue_button.pressed.emit()
	await process_frame
	_check(
		(screen.get_node("%DialogueText") as Label).text.begins_with("Sweet, sweet nothing"),
		"Silence should select its custom response.",
	)

	# Reply -> three closing nodes -> end screen -> title.
	for _step in range(5):
		continue_button.pressed.emit()
		await process_frame
	_check(title.visible, "Finishing the tutorial should return to the title.")

	var dad_button := main.get_node(
		"TitleScreen/SafeMargin/Center/Menu/DadInterviewButton"
	) as Button
	dad_button.pressed.emit()
	await process_frame
	_check(
		(screen.get_node("%SceneLabel") as Label).text == "Dad Job Interview",
		"The authored Dad interview should be reachable from the title.",
	)
	_check(
		(screen.get_node("%BudgetLabel") as Label).text == "Budget: $30",
		"The Dad interview should begin with a constraining budget.",
	)

	# A positive but insufficient budget must still allow free silence.
	var phrase_cut: Variant = phrase_panel
	phrase_cut.setup(
		[
			{"id": "one", "text": "one", "cost": 1},
			{"id": "two", "text": "two", "cost": 1},
		],
		1,
		"tester",
		true,
		true,
	)
	await process_frame
	var recovery_chips := phrase_cut.get_node("%ChipsFlow") as HFlowContainer
	for child: Button in recovery_chips.get_children():
		child.set_pressed_no_signal(false)
		child.toggled.emit(false)
	_check(
		not (phrase_cut.get_node("%ConfirmButton") as Button).disabled,
		"Silence should remain legal when the selected phrases are unaffordable.",
	)

	main.queue_free()
	if _failures.is_empty():
		print("DialogueScreen: end-to-end smoke test passed")
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	quit(1)


func _advance_until_phrase(continue_button: Button, phrase_panel: Control) -> void:
	var remaining := 40
	while not phrase_panel.visible and remaining > 0:
		continue_button.pressed.emit()
		await process_frame
		remaining -= 1
	_check(phrase_panel.visible, "Dialogue should reach a phrase choice.")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
