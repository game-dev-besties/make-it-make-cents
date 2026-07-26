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
	_check(app.get_node_or_null("%CampaignPlayer") != null, "The campaign player should exist.")
	_check(app.get_node_or_null("%StageHost") != null, "The stage host should exist.")
	_check(root.get_node_or_null("GameStats") != null, "The GameStats autoload should exist.")
	_check(root.get_node_or_null("Dialogic") != null, "The Dialogic autoload should exist.")

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
