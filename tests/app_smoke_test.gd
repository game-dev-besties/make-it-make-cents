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
	var stage_host := app.get_node_or_null("%StageHost") as StageHost
	var campaign_player := app.get_node_or_null("%CampaignPlayer") as CampaignPlayer
	var chapter_transition := app.get_node_or_null("%ChapterTransition") as ChapterTransition
	var has_startup_path := (
		start_button != null
		and stage_host != null
		and campaign_player != null
		and chapter_transition != null
	)
	_check(has_startup_path, "The app should expose its playable startup path.")
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
		await campaign_player.abort_campaign()
		await process_frame
		_check(
			stage_host.current_presentation == null,
			"Aborting the campaign should clear the opening stage.",
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
