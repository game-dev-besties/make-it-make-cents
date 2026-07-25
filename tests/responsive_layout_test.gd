extends SceneTree

const INTRO_STAGE := preload("res://content/episodes/intro/stage.tscn")
const TEXTBOX_LAYER := preload("res://ui/dialogue/dialogue_hud.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_story_stage_composition()
	await _test_dialogue_hud_geometry()
	if _failures.is_empty():
		print("Responsive layout checks passed.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("FAIL: ", failure)
	quit(1)


func _test_story_stage_composition() -> void:
	var stage := INTRO_STAGE.instantiate() as StoryStage
	root.add_child(stage)
	stage.size = Vector2(360.0, 640.0)
	await process_frame
	var center := stage.get_node("ActorSlots/Center") as Control
	var background := stage.get_node("%BackgroundImage") as TextureRect
	_check(
		is_equal_approx(center.scale.x, 360.0 / 1152.0),
		"Portrait viewports should uniformly scale the authored stage composition.",
	)
	_check(
		background.size.is_equal_approx(Vector2(360.0, 202.5))
		and is_equal_approx(background.position.y, 218.75),
		"Tall viewports should letterbox the background with the scaled stage composition.",
	)
	stage.size = Vector2(1024.0, 768.0)
	await process_frame
	_check(
		is_equal_approx(center.scale.x, 1024.0 / 1152.0),
		"4:3 viewports should scale against their limiting dimension without distortion.",
	)
	_check(
		center.position.y > 96.0,
		"Letterbox space should center the authored stage composition vertically.",
	)
	stage.size = Vector2(2560.0, 1080.0)
	await process_frame
	_check(
		is_equal_approx(center.scale.x, 1080.0 / 648.0)
		and center.position.x > 320.0,
		"Ultrawide viewports should center a uniformly scaled stage instead of stretching it.",
	)
	stage.queue_free()
	await process_frame


func _test_dialogue_hud_geometry() -> void:
	var hud := TEXTBOX_LAYER.instantiate() as Control
	root.add_child(hud)
	await process_frame
	var sizer := hud.get_node("Anchor/AnimationParent/Sizer") as Control
	_check(
		sizer.get_global_rect().position.x >= 0.0
		and sizer.get_global_rect().end.x <= root.get_viewport().get_visible_rect().size.x,
		"The dialogue panel should stay within the live viewport's side gutters.",
	)
	_check(
		sizer.size.x <= 900.0 and sizer.size.y >= 144.0,
		"The dialogue panel should remain readable while respecting its maximum width.",
	)
	hud.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
