extends SceneTree
## Verifies one critical path through the production app. UI structure,
## artwork, responsive layout, and individual menu controls belong in manual
## playtesting rather than this boot smoke.

const APP_SCENE := preload("res://app/app.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app := APP_SCENE.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame

	var start_button := app.get_node_or_null("%StartButton") as BaseButton
	var title_screen := app.get_node_or_null("%TitleScreen") as Control
	var back_to_title_button := app.get_node_or_null("%BackToTitleButton") as BaseButton
	var paused_run_actions := app.get_node_or_null("%PausedRunActions") as Control
	var resume_button := app.get_node_or_null("%ResumeButton") as BaseButton
	var play_again_button := app.get_node_or_null("%PlayAgainButton") as BaseButton
	var results_screen := app.get_node_or_null("%ResultsScreen") as ResultsScreen
	var results_title_button := (
		results_screen.get_node_or_null("%MainMenuButton") as BaseButton
		if results_screen != null
		else null
	)
	var stage_host := app.get_node_or_null("%StageHost") as StageHost
	var campaign_player := app.get_node_or_null("%CampaignPlayer") as CampaignPlayer
	var chapter_transition := app.get_node_or_null("%ChapterTransition") as ChapterTransition
	var soundtrack := app.get_node_or_null("%Soundtrack") as AudioStreamPlayer
	var game_stats := root.get_node_or_null("GameStats") as GameStateStore
	var dialogic := root.get_node_or_null("Dialogic") as DialogicGameHandler
	var has_startup_path := (
		start_button != null
		and title_screen != null
		and back_to_title_button != null
		and paused_run_actions != null
		and resume_button != null
		and play_again_button != null
		and results_screen != null
		and results_title_button != null
		and stage_host != null
		and campaign_player != null
		and chapter_transition != null
		and game_stats != null
		and dialogic != null
	)
	_check(has_startup_path, "The app should expose its playable startup path.")
	_check(
		soundtrack != null
		and soundtrack.stream is AudioStreamMP3
		and (soundtrack.stream as AudioStreamMP3).loop
		and (soundtrack.stream as AudioStreamMP3).get_length() > 177.4
		and (soundtrack.stream as AudioStreamMP3).get_length() < 177.5
		and is_equal_approx(soundtrack.pitch_scale, 1.0)
		and soundtrack.autoplay
		and soundtrack.bus == &"Music"
		and AudioServer.get_bus_index(&"Music") >= 0,
		"The app should loop the full main soundtrack at normal speed on the Music bus.",
	)
	if has_startup_path:
		start_button.pressed.emit()
		await process_frame
		_check(
			chapter_transition.visible,
			"Play should show the opening chapter transition.",
		)
		chapter_transition.skip()
		await process_frame
		await process_frame
		_check(
			stage_host.current_presentation != null,
			"Completing the transition should mount the opening stage.",
		)
		var opening_episode := campaign_player.current_episode
		var opening_presentation_id := stage_host.current_presentation.get_instance_id()
		game_stats.son_silly = 4
		game_stats.spend(1)
		var paused_budget := game_stats.remaining_budget()
		back_to_title_button.pressed.emit()
		await process_frame
		_check(
			title_screen.visible
			and paused_run_actions.visible
			and resume_button.visible
			and play_again_button.visible,
			"Return to Title should offer Resume and Play Again.",
		)
		_check(
			campaign_player.current_episode == opening_episode
			and stage_host.current_presentation != null
			and stage_host.current_presentation.get_instance_id() == opening_presentation_id
			and stage_host.current_presentation.process_mode == Node.PROCESS_MODE_DISABLED
			and game_stats.remaining_budget() == paused_budget
			and game_stats.son_silly == 4,
			"Returning to the title should preserve the active run.",
		)
		_check(
			dialogic.paused,
			"Returning to the title should pause the active dialogue.",
		)
		resume_button.pressed.emit()
		await process_frame
		_check(
			not title_screen.visible
			and not dialogic.paused
			and campaign_player.current_episode == opening_episode
			and stage_host.current_presentation != null
			and stage_host.current_presentation.get_instance_id() == opening_presentation_id
			and stage_host.current_presentation.process_mode == Node.PROCESS_MODE_INHERIT
			and game_stats.remaining_budget() == paused_budget,
			"Resume should continue the same run from the same state.",
		)

		back_to_title_button.pressed.emit()
		await process_frame
		play_again_button.pressed.emit()
		for wait_frame: int in range(30):
			if chapter_transition.visible:
				break
			await process_frame
		_check(
			chapter_transition.visible and game_stats.son_silly == 0,
			"Play Again should reset the run and show the opening transition.",
		)
		chapter_transition.skip()
		await process_frame
		await process_frame
		_check(
			campaign_player.current_episode != null
			and stage_host.current_presentation != null
			and stage_host.current_presentation.get_instance_id() != opening_presentation_id,
			"Play Again should mount a fresh opening stage.",
		)
		await campaign_player.abort_campaign()
		await process_frame
		_check(
			stage_host.current_presentation == null,
			"Aborting the campaign should clear the opening stage.",
		)

		game_stats.money_total_spent = 23
		game_stats.delivery_jingles_sung = 2
		game_stats.delivery_grunts_said = 1
		game_stats.delivery_nothings_said = 4
		game_stats.set_story_flag(&"dad_offended_interviewer", "none")
		game_stats.set_story_flag(&"dad_got_job", true)
		game_stats.set_story_flag(&"got_prescription", true)
		game_stats.set_story_flag(&"got_the_girl", "no")
		game_stats.set_story_flag(&"family_stays", true)
		campaign_player.finish_campaign()
		await process_frame
		_check(
			results_screen.visible
			and not title_screen.visible
			and (results_screen.get_node("%MoneySpentValue") as Label).text == "$23",
			"Finishing the campaign should show the populated results screen.",
		)
		results_title_button.pressed.emit()
		await process_frame
		_check(
			not results_screen.visible and title_screen.visible,
			"The results screen should return to the title.",
		)

	app.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Application boot smoke test passed.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("FAIL: ", failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
