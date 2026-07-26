extends SceneTree
## Structural and runtime checks for Moneybot's chapter-stage presence.

const MONEYBOT_SCENE := preload("res://game/components/moneybot_companion.tscn")
const CHAPTER_STAGE_PATHS := [
	"res://content/episodes/intro/stage.tscn",
	"res://content/episodes/dad/stage.tscn",
	"res://content/episodes/son/stage.tscn",
	"res://content/episodes/crush/stage.tscn",
	"res://content/episodes/grandma/stage.tscn",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_idle_motion()
	await _test_chapter_stage_presence()
	if _failures.is_empty():
		print("Moneybot companion checks passed.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("FAIL: ", failure)
	quit(1)


func _test_idle_motion() -> void:
	var moneybot := MONEYBOT_SCENE.instantiate() as MoneybotCompanion
	root.add_child(moneybot)
	await process_frame
	var motion_root := moneybot.get_node("%MotionRoot") as Control
	var starting_position := motion_root.position
	var starting_scale := motion_root.scale
	await create_timer(0.12).timeout
	_check(
		not motion_root.position.is_equal_approx(starting_position)
		or not motion_root.scale.is_equal_approx(starting_scale),
		"Moneybot's inner visual should move while idle motion is enabled.",
	)
	moneybot.idle_motion_enabled = false
	_check(
		motion_root.position.is_equal_approx(Vector2.ZERO)
		and motion_root.scale.is_equal_approx(Vector2.ONE)
		and is_zero_approx(motion_root.rotation),
		"Disabling idle motion should restore the exact authored transform.",
	)
	moneybot.queue_free()
	await process_frame


func _test_chapter_stage_presence() -> void:
	for stage_path: String in CHAPTER_STAGE_PATHS:
		var stage_scene := load(stage_path) as PackedScene
		_check(stage_scene != null, "%s should load as a PackedScene." % stage_path)
		if stage_scene == null:
			continue
		var stage := stage_scene.instantiate()
		root.add_child(stage)
		await process_frame
		var companions := stage.find_children("*", "MoneybotCompanion", true, false)
		_check(
			companions.size() == 1,
			"%s should contain exactly one reusable Moneybot companion." % stage_path,
		)
		stage.queue_free()
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
