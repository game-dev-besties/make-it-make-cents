extends SceneTree
## Deliberately small application smoke test.
##
## Interaction, focus, scrolling, and responsive geometry belong in manual
## playtesting. CI only verifies that the production app can boot and expose
## its essential entry points without a script or resource error.

const APP_SCENE := preload("res://app/app.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app := APP_SCENE.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame

	_check(app.get_node_or_null("%TitleScreen") != null, "The title screen should exist.")
	_check(app.get_node_or_null("%StartButton") != null, "The Start button should exist.")
	_check(app.get_node_or_null("%CreditsButton") != null, "The Credits button should exist.")
	_check(
		app.get_node_or_null("%CreditsBackButton") != null,
		"The credits Back button should exist.",
	)
	_check(app.get_node_or_null("%PennybotCredits") != null, "The Pennybot credits should exist.")
	_check(app.get_node_or_null("%CampaignPlayer") != null, "The campaign player should exist.")
	_check(app.get_node_or_null("%StageHost") != null, "The stage host should exist.")
	_check(root.get_node_or_null("GameStats") != null, "The GameStats autoload should exist.")
	_check(root.get_node_or_null("Dialogic") != null, "The Dialogic autoload should exist.")

	var credits_button := app.get_node_or_null("%CreditsButton") as BaseButton
	var credits_back_button := app.get_node_or_null("%CreditsBackButton") as BaseButton
	var credits_body := app.get_node_or_null("%CreditsBody") as TextureRect
	if (
		credits_button != null
		and credits_back_button != null
		and credits_body != null
	):
		credits_button.pressed.emit()
		await process_frame
		_check(credits_body.visible, "The Credits button should open the credits page.")
		_check(
			not credits_button.visible and credits_back_button.visible,
			"Credits should become Back on the credits page.",
		)
		_check(
			credits_body.texture != null,
			"The credits page should contain the supplied name artwork.",
		)
		credits_back_button.pressed.emit()
		await process_frame
		_check(not credits_body.visible, "The Back button should return to the title page.")
		_check(
			credits_button.visible and not credits_back_button.visible,
			"Back should restore the Credits image on the title page.",
		)

	var stage_host := app.get_node_or_null("%StageHost") as StageHost
	var campaign_player := app.get_node_or_null("%CampaignPlayer") as CampaignPlayer
	if stage_host != null and campaign_player != null:
		var start_button := app.get_node_or_null("%StartButton") as BaseButton
		if start_button != null:
			start_button.pressed.emit()
			await process_frame
			await process_frame
			_check(
				stage_host.current_presentation != null,
				"Play should mount the opening stage.",
			)
		await campaign_player.abort_campaign()
		await process_frame
		_check(
			stage_host.current_presentation == null,
			"Returning to title should clear the speaking character's stage.",
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
