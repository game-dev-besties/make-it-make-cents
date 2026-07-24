extends SceneTree

const ACTOR_SLOT_SCENE := preload("res://game/components/stage_actor_slot.tscn")
const INTRO_STAGE_SCENE := preload("res://content/episodes/intro/stage.tscn")
const NEUTRAL_PORTRAIT := "res://content/characters/son/neutral.png"
const SHY_PORTRAIT := "res://content/characters/son/shy.png"
const SON_STAGE_SCENE := preload("res://content/episodes/son/stage.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var slot := ACTOR_SLOT_SCENE.instantiate() as StageActorSlot
	root.add_child(slot)
	await process_frame

	_check(
		StageActorSlot._decode_resource_path("\"%s\"" % NEUTRAL_PORTRAIT) == NEUTRAL_PORTRAIT,
		"Quoted Dialogic image overrides should decode to resource paths.",
	)
	_check(
		StageActorSlot._decode_resource_path(NEUTRAL_PORTRAIT) == NEUTRAL_PORTRAIT,
		"Plain Dialogic image overrides should remain unchanged.",
	)

	slot.actor_name = "Percy"
	slot.character_id = &"son"
	slot.expression = "neutral"
	var portrait_image := slot.get_node("%PortraitImage") as TextureRect
	var placeholder := slot.get_node("%Portrait") as ColorRect
	var name_label := slot.get_node("%NameLabel") as Label
	var expression_label := slot.get_node("%ExpressionLabel") as Label
	_check(portrait_image.texture != null, "Percy's registered neutral portrait should load.")
	_check(portrait_image.visible, "Registered portrait art should be visible.")
	_check(not placeholder.visible, "Portrait art should replace the color placeholder.")
	_check(not name_label.visible, "Portrait art should hide the placeholder name label.")
	_check(not expression_label.visible, "Portrait art should hide the placeholder expression label.")
	if portrait_image.texture != null:
		_check(
			portrait_image.texture.resource_path == NEUTRAL_PORTRAIT,
			"Percy's neutral expression should use the neutral texture.",
		)

	slot.expression = "nervous"
	_check(portrait_image.texture != null, "Percy's nervous portrait should load.")
	if portrait_image.texture != null:
		_check(
			portrait_image.texture.resource_path == SHY_PORTRAIT,
			"Percy's nervous expression should use the shy texture.",
		)

	slot.expression = "missing-expression"
	_check(portrait_image.texture != null, "An unknown expression should use the default portrait.")
	if portrait_image.texture != null:
		_check(
			portrait_image.texture.resource_path == NEUTRAL_PORTRAIT,
			"An unknown expression should fall back to Percy's neutral portrait.",
		)

	slot.character_id = &"crush"
	slot.expression = "neutral"
	_check(portrait_image.texture == null, "A character without portrait art should not show stale art.")
	_check(not portrait_image.visible, "A character without portrait art should hide the image node.")
	_check(placeholder.visible, "A character without portrait art should show the color placeholder.")
	_check(name_label.visible, "A character without portrait art should show the name label.")
	_check(expression_label.visible, "A character without portrait art should show the expression label.")

	var manual_texture := load(SHY_PORTRAIT) as Texture2D
	slot.character_id = &"unregistered-character"
	slot.portrait_texture = manual_texture
	_check(
		portrait_image.texture == manual_texture and portrait_image.visible,
		"A manual portrait should support props or unregistered characters.",
	)

	slot.queue_free()
	await process_frame
	await _check_authored_stage_preview(
		INTRO_STAGE_SCENE,
		"neutral",
		NEUTRAL_PORTRAIT,
		"Intro",
		"ActorSlots/Center",
	)
	await _check_authored_stage_preview(
		SON_STAGE_SCENE,
		"shy",
		SHY_PORTRAIT,
		"Son",
		"ActorSlots/Left",
	)
	_finish()


func _check_authored_stage_preview(
	stage_scene: PackedScene,
	expected_expression: String,
	expected_portrait: String,
	stage_name: String,
	slot_path: NodePath,
) -> void:
	var stage := stage_scene.instantiate() as StoryStage
	root.add_child(stage)
	await process_frame

	var slot := stage.get_node(slot_path) as StageActorSlot
	var portrait_image := slot.get_node("%PortraitImage") as TextureRect
	_check(
		slot.expression == expected_expression,
		"%s should retain its valid editor-authored portrait expression." % stage_name,
	)
	_check(
		portrait_image.texture != null and portrait_image.texture.resource_path == expected_portrait,
		"%s's stage should preview the portrait selected by its authored expression." % stage_name,
	)
	_check(
		portrait_image.position == Vector2.ZERO and portrait_image.size == slot.size,
		"%s's portrait should stay inside its authored actor slot." % stage_name,
	)
	_check(
		portrait_image.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
		and portrait_image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"%s's portrait should preserve its aspect ratio without changing stage layout." % stage_name,
	)

	stage.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Stage actor portrait checks passed.")
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	quit(1)
