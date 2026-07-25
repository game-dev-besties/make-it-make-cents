extends SceneTree
## Semantic application smoke test. It drives production button signals and
## Dialogic's indexed timeline start, avoiding timing-sensitive mouse/key input.

const APP_SCENE := preload("res://app/app.tscn")
const INTRO_TIMELINE := "res://content/episodes/intro/dialogue.dtl"
const FIRST_PHRASE_ID := "intro_L001"

var _failures: Array[String] = []
var _dialogic: DialogicGameHandler


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_dialogic = root.get_node_or_null("Dialogic") as DialogicGameHandler
	if _dialogic == null:
		printerr("FAIL: The app should expose its Dialogic singleton.")
		quit(1)
		return
	_check(
		root.get_node_or_null("GameState") == null,
		"The app should only register the canonical GameStats state singleton.",
	)
	# Auto-skip suppresses per-letter typing audio in headless tests. The smoke
	# jumps by semantic event ID before its timer can advance production text.
	_dialogic.Inputs.auto_skip.enabled = true
	await _test_responsive_layout()
	await _test_developer_launcher()
	await _reset_runtime()
	await _test_return_to_title_stops_dialogue()
	await _reset_runtime()
	await _test_start_to_phrase_delivery()
	_dialogic.Inputs.auto_skip.enabled = false
	await _reset_runtime()

	if _failures.is_empty():
		print("Application start-to-phrase smoke test passed.")
		quit(0)
		return

	for failure in _failures:
		printerr("FAIL: ", failure)
	quit(1)


func _test_responsive_layout() -> void:
	var viewport_harness := Control.new()
	viewport_harness.size = Vector2(360.0, 640.0)
	root.add_child(viewport_harness)
	var app := APP_SCENE.instantiate() as Control
	viewport_harness.add_child(app)
	await process_frame
	await process_frame

	var viewport_rect := viewport_harness.get_global_rect()
	var title_panel := app.get_node("TitleScreen/Panel") as PanelContainer
	var developer_tools := app.get_node("%DeveloperTools") as Control
	_check(
		_rect_is_inside(viewport_rect, title_panel.get_global_rect()),
		"The title panel should fit inside a narrow portrait viewport.",
	)
	_check(
		not developer_tools.visible
			or _rect_is_inside(title_panel.get_global_rect(), developer_tools.get_global_rect()),
		"The debug launcher should stay inside the responsive title panel.",
	)

	var episode_label := app.get_node("%EpisodeLabel") as Label
	var budget_label := app.get_node("%BudgetLabel") as Label
	episode_label.text = "Chapter 1: Welcome to the Country"
	budget_label.show()
	await process_frame
	_check(
		not episode_label.visible,
		"The chapter title should stay hidden until the history view opens.",
	)
	_check(
		_rect_is_inside(viewport_rect, budget_label.get_global_rect()),
		"The narrow HUD rows should stay inside the viewport.",
	)

	viewport_harness.size = Vector2(640.0, 360.0)
	await process_frame
	await process_frame
	viewport_rect = viewport_harness.get_global_rect()
	_check(
		_rect_is_inside(viewport_rect, title_panel.get_global_rect()),
		"The compact title panel should fit inside a short landscape viewport.",
	)

	viewport_harness.queue_free()
	await process_frame


func _test_developer_launcher() -> void:
	var app := APP_SCENE.instantiate()
	root.add_child(app)
	await process_frame

	var developer_tools := app.get_node("%DeveloperTools") as Control
	_check(
		developer_tools.visible == OS.is_debug_build(),
		"Developer episode tools should only be visible in debug builds.",
	)
	if developer_tools.visible:
		var picker := app.get_node("%EpisodePicker") as OptionButton
		var dad_index := _find_picker_item(picker, "dad")
		_check(dad_index >= 0, "The developer launcher should list the Dad episode.")
		if dad_index >= 0:
			picker.select(dad_index)
			(app.get_node("%PlayEpisodeButton") as Button).pressed.emit()
			await process_frame
			await process_frame
			var campaign_player := app.get_node("%CampaignPlayer") as CampaignPlayer
			_check(
				campaign_player.current_episode != null
				and campaign_player.current_episode.id == &"dad",
				"The developer launcher should start the selected Dad episode.",
			)
			_check(
				not (app.get_node("%TitleScreen") as Control).visible,
				"Starting a developer episode should leave the title screen.",
			)

	app.queue_free()
	await process_frame


func _test_return_to_title_stops_dialogue() -> void:
	var app := APP_SCENE.instantiate()
	root.add_child(app)
	await process_frame

	var title_screen := app.get_node("%TitleScreen") as Control
	var campaign_player := app.get_node("%CampaignPlayer") as CampaignPlayer
	var history_controls := app.get_node("HistoryControls") as CanvasLayer
	var back_to_title_button := app.get_node("%BackToTitleButton") as Button
	_check(
		history_controls.layer > 1 and back_to_title_button.get_parent() == history_controls,
		"History controls should render above Dialogic's canvas layer.",
	)
	(app.get_node("%StartButton") as Button).pressed.emit()
	await process_frame
	await process_frame
	_check(
		campaign_player.current_episode != null and _dialogic.current_timeline != null,
		"Starting a campaign should create an active episode and Dialogic timeline.",
	)

	back_to_title_button.pressed.emit()
	for _attempt: int in 30:
		if _dialogic.current_timeline == null:
			break
		await process_frame
	await process_frame

	_check(title_screen.visible, "Returning to title should reveal the title screen.")
	_check(
		campaign_player.current_episode == null,
		"Returning to title should clear the active campaign episode.",
	)
	_check(
		_dialogic.current_timeline == null,
		"Returning to title should terminate the active Dialogic timeline.",
	)

	app.queue_free()
	await process_frame


func _test_start_to_phrase_delivery() -> void:
	var app := APP_SCENE.instantiate()
	root.add_child(app)
	await process_frame

	var title_screen := app.get_node("%TitleScreen") as Control
	var start_button := app.get_node("%StartButton") as Button
	_check(title_screen.visible, "The app should open on its title screen.")
	_check(
		start_button.get_viewport().gui_get_focus_owner() == start_button,
		"The title screen should give Start keyboard focus.",
	)

	start_button.pressed.emit()
	await process_frame
	await process_frame

	var campaign_player := app.get_node("%CampaignPlayer") as CampaignPlayer
	var stage_host := app.get_node("%StageHost") as StageHost
	var game_stats := root.get_node_or_null("GameStats") as GameStateStore
	_check(not title_screen.visible, "Start should hide the title screen.")
	_check(
		campaign_player.current_episode != null
			and campaign_player.current_episode.id == &"intro",
		"Start should enter the campaign's intro episode.",
	)
	_check(
		stage_host.current_presentation != null,
		"Starting the intro should mount its editor-authored stage.",
	)
	_check(game_stats != null, "The app should expose its GameStats singleton.")
	if game_stats == null:
		app.queue_free()
		await process_frame
		return
	_check(game_stats.remaining_budget() == 30, "The intro should begin with its $30 word budget.")
	_check(
		_dialogic.current_timeline != null
			and _dialogic.current_timeline.resource_path == INTRO_TIMELINE,
		"Starting the intro should load its compiled Dialogic timeline.",
	)

	var phrase_index := _find_phrase_event(FIRST_PHRASE_ID)
	_check(phrase_index >= 0, "The compiled intro should contain its first phrase-cut event.")
	if phrase_index < 0:
		app.queue_free()
		await process_frame
		return

	# Restarting at the semantic event index exercises the real compiled event,
	# phrase sidecar, stage bridge, overlay, and GameStats without replaying 30+
	# text reveals through synthetic input.
	await _dialogic.clear(DialogicGameHandler.ClearFlags.KEEP_VARIABLES)
	_dialogic.start(INTRO_TIMELINE, phrase_index)
	var overlay := await _wait_for_phrase_overlay()
	_check(overlay != null, "The first phrase event should open the production phrase overlay.")
	if overlay == null:
		app.queue_free()
		await process_frame
		return

	_check(
		(overlay.get_node("%ConfirmButton") as Button).text == "Say it  /  $15",
		"The production overlay should carry the live line cost in its primary action.",
	)
	_check(
		(overlay.get_node("%TitleLabel") as Label).text == "PERCY",
		"The phrase overlay should show the character's display name in its minimal header.",
	)
	var intro_stage := stage_host.current_presentation as StoryStage
	if intro_stage != null:
		var son_slot := intro_stage.get_node("ActorSlots/Center") as StageActorSlot
		_check(
			son_slot.character_id == &"son"
				and son_slot.expression == "shy"
				and son_slot.is_active,
			"The phrase event should focus Percy's shy stage portrait before selection.",
		)

	(overlay.get_node("%ConfirmButton") as Button).pressed.emit()
	await process_frame
	await process_frame
	_check(
		_find_phrase_overlay(root) == null,
		"Confirming the phrase selection should close the overlay.",
	)
	_check(
		game_stats.remaining_budget() == 15,
		"Confirming the full $15 line should spend against the live intro budget.",
	)
	var phrase_memory := root.get_node_or_null("PhraseMemory")
	_check(
		phrase_memory != null
			and phrase_memory.call("delivery_is", "normal")
			and int(phrase_memory.call("kept_count")) == 6,
		"Phrase delivery should reach the production phrase-memory branch state.",
	)
	_check(
		await _wait_for_history_text(
			"Hello, my name is Percy. I am pleased to be here in your beautiful country.",
		),
		"A delivered phrase-cut line should be recorded by Dialogic's history.",
	)

	app.queue_free()
	await process_frame


func _find_picker_item(picker: OptionButton, metadata: String) -> int:
	for item_index: int in picker.item_count:
		if String(picker.get_item_metadata(item_index)) == metadata:
			return item_index
	return -1


func _find_phrase_event(expected_line_id: String) -> int:
	for event_index: int in _dialogic.current_timeline_events.size():
		var event: Variant = _dialogic.current_timeline_events[event_index]
		if event is DialogicPhraseCutEvent and event.line_id == expected_line_id:
			return event_index
	return -1


func _wait_for_phrase_overlay() -> PhraseCutOverlay:
	for _attempt: int in 30:
		var overlay := _find_phrase_overlay(root)
		if overlay != null:
			return overlay
		await process_frame
	return null


func _find_phrase_overlay(node: Node) -> PhraseCutOverlay:
	if node is PhraseCutOverlay:
		return node as PhraseCutOverlay
	for child: Node in node.get_children():
		var found := _find_phrase_overlay(child)
		if found != null:
			return found
	return null


func _wait_for_history_text(expected_text: String) -> bool:
	for _attempt: int in 180:
		for entry: Dictionary in _dialogic.History.get_simple_history():
			if String(entry.get("text", "")) == expected_text:
				return true
		await process_frame
	return false


func _rect_is_inside(outer: Rect2, inner: Rect2) -> bool:
	const TOLERANCE := 0.5
	return (
		inner.position.x >= outer.position.x - TOLERANCE
		and inner.position.y >= outer.position.y - TOLERANCE
		and inner.end.x <= outer.end.x + TOLERANCE
		and inner.end.y <= outer.end.y + TOLERANCE
	)


func _reset_runtime() -> void:
	for type_sound: Node in get_nodes_in_group(&"dialogic_type_sounds"):
		if type_sound is AudioStreamPlayer:
			var type_sound_player := type_sound as AudioStreamPlayer
			type_sound_player.stop()
			type_sound_player.stream = null
		if type_sound is DialogicNode_TypeSounds:
			var dialogic_type_sound := type_sound as DialogicNode_TypeSounds
			dialogic_type_sound.sounds.clear()
			dialogic_type_sound.end_sound = null
			dialogic_type_sound.current_overwrite_data.clear()
		for child: Node in type_sound.get_children():
			if child is AudioStreamPlayer:
				var child_player := child as AudioStreamPlayer
				child_player.stop()
				child_player.stream = null
				child.queue_free()
	await _dialogic.clear(DialogicGameHandler.ClearFlags.FULL_CLEAR)
	if _dialogic.has_subsystem("Styles") and _dialogic.Styles.has_active_layout_node():
		_dialogic.Styles.get_layout_node().queue_free()
	var game_stats := root.get_node_or_null("GameStats") as GameStateStore
	if game_stats != null:
		game_stats.reset_for_new_game()
	await process_frame
	await create_timer(0.05).timeout


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
