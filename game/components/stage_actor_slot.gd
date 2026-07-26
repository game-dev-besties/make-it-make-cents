@tool
class_name StageActorSlot
extends Control

## A designer-editable position for an on-stage actor. Registered Dialogic
## characters use their portrait art; characters without art keep the readable
## placeholder so every stage remains useful in the editor.

@export_category("Actor")
## Dialogic's stable character identifier, such as `dad` or `interviewer`.
## StoryStage uses this to keep the editor-authored slot in sync with dialogue.
@export var character_id: StringName = &"":
	set(value):
		character_id = value
		_refresh()

@export var actor_name := "Actor":
	set(value):
		actor_name = value
		_refresh()

@export_multiline var expression := "neutral":
	set(value):
		expression = value
		_refresh()

@export var accent_color := Color("8ba7d6"):
	set(value):
		accent_color = value
		_refresh()

## Optional art for a character or prop that does not have a Dialogic portrait.
## A registered character portrait takes precedence when one is available.
@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		_refresh()

@export var is_active := true:
	set(value):
		is_active = value
		_refresh()

## Darkness filter strength while another character is speaking. Set this to
## 0.0 to leave inactive actors unchanged, or raise it to darken them further.
@export_range(0.0, 1.0, 0.01) var inactive_darkness := 0.35:
	set(value):
		inactive_darkness = value
		_refresh()

@export_category("Speaking Motion")
## Set this false for props or characters that should remain completely still.
@export var speaking_motion_enabled := true
## Optional shared tuning resource. A balanced default is used when left empty.
@export var speaking_motion_profile: SpeakingMotionProfile
@export_range(0.0, 2.0, 0.05) var speaking_motion_strength := 1.0
## A value of zero leans toward stage center. Use -1 or 1 to choose explicitly.
@export_range(-1.0, 1.0, 0.1) var speaking_lean_direction := 0.0

@onready var _name_label: Label = %NameLabel
@onready var _expression_label: Label = %ExpressionLabel
@onready var _motion_root: Control = %MotionRoot
@onready var _frame: Panel = $MotionRoot/Frame
@onready var _portrait: ColorRect = %Portrait
@onready var _portrait_image: TextureRect = %PortraitImage

var _default_speaking_profile := SpeakingMotionProfile.new()
var _motion_tween: Tween
var _speaking := false
var _motion_generation := 0


func _ready() -> void:
	_update_motion_pivot()
	resized.connect(_update_motion_pivot)
	_refresh()


func _exit_tree() -> void:
	_kill_motion_tween()


func set_actor(new_name: String, new_expression := "neutral") -> void:
	actor_name = new_name
	expression = new_expression


func clear_actor() -> void:
	stop_speaking(true)
	actor_name = ""
	expression = ""


func start_speaking(line_info: Dictionary = {}) -> void:
	_motion_generation += 1
	var generation := _motion_generation
	_speaking = speaking_motion_enabled and speaking_motion_strength > 0.0
	_kill_motion_tween()
	_reset_motion_transform()
	if not _speaking or not is_inside_tree():
		return

	var line_expression := String(line_info.get("portrait", expression))
	if line_expression.is_empty():
		line_expression = expression
	var profile := (
		speaking_motion_profile
		if speaking_motion_profile != null
		else _default_speaking_profile
	)
	var motion := profile.motion_for(
		line_expression,
		String(line_info.get("text", "")),
		speaking_motion_strength,
		_resolved_lean_direction(),
	)
	if bool(line_info.get("append", false)):
		_start_speaking_loop(generation, motion)
		return
	_play_opening_gesture(generation, motion)


func stop_speaking(immediate := false) -> void:
	_motion_generation += 1
	_speaking = false
	_kill_motion_tween()
	if not is_instance_valid(_motion_root):
		return
	if immediate or not is_inside_tree():
		_reset_motion_transform()
		return

	var profile := (
		speaking_motion_profile
		if speaking_motion_profile != null
		else _default_speaking_profile
	)
	_motion_tween = create_tween()
	_motion_tween.set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_SINE)
	_motion_tween.set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(
		_motion_root,
		"position",
		Vector2.ZERO,
		profile.return_duration,
	)
	_motion_tween.tween_property(
		_motion_root,
		"rotation",
		0.0,
		profile.return_duration,
	)
	_motion_tween.tween_property(
		_motion_root,
		"scale",
		Vector2.ONE,
		profile.return_duration,
	)
	_motion_tween.finished.connect(_on_return_finished)


func is_speaking() -> bool:
	return _speaking


func reset_motion() -> void:
	stop_speaking(true)


func _play_opening_gesture(generation: int, motion: Dictionary) -> void:
	var style := StringName(motion.get("style", &"neutral"))
	var lift := float(motion.get("entrance_lift", 0.0))
	var scale_amount := float(motion.get("entrance_scale", 0.0))
	var rotation_amount := float(motion.get("rotation", 0.0))
	var direction := _resolved_lean_direction()
	var accent_position := Vector2(
		float(motion.get("horizontal", 0.0)) * 0.7,
		-lift,
	)
	var accent_scale := Vector2.ONE * (1.0 + scale_amount)
	if style == &"nervous":
		accent_position = Vector2(direction * lift * 0.35, lift * 0.25)
		accent_scale = Vector2.ONE * (1.0 - scale_amount * 0.35)
	elif style == &"sad":
		accent_position = Vector2(0.0, lift * 0.5)
		accent_scale = Vector2.ONE * (1.0 - scale_amount * 0.2)
	elif style == &"surprised":
		rotation_amount *= 0.35

	var duration := float(motion.get("entrance_duration", 0.11))
	_motion_tween = create_tween()
	_motion_tween.set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_BACK)
	_motion_tween.set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(_motion_root, "position", accent_position, duration)
	_motion_tween.tween_property(_motion_root, "rotation", rotation_amount, duration)
	_motion_tween.tween_property(_motion_root, "scale", accent_scale, duration)
	_motion_tween.chain().tween_property(
		_motion_root,
		"position",
		Vector2.ZERO,
		duration,
	)
	_motion_tween.parallel().tween_property(_motion_root, "rotation", 0.0, duration)
	_motion_tween.parallel().tween_property(_motion_root, "scale", Vector2.ONE, duration)
	_motion_tween.finished.connect(
		_on_opening_gesture_finished.bind(generation, motion),
	)


func _on_opening_gesture_finished(generation: int, motion: Dictionary) -> void:
	_motion_tween = null
	if generation != _motion_generation or not _speaking:
		return
	if bool(motion.get("loop", true)):
		_start_speaking_loop(generation, motion)


func _start_speaking_loop(generation: int, motion: Dictionary) -> void:
	if generation != _motion_generation or not _speaking:
		return
	var vertical := float(motion.get("vertical", 0.0))
	var horizontal := float(motion.get("horizontal", 0.0))
	var rotation_amount := float(motion.get("rotation", 0.0))
	var scale_amount := float(motion.get("scale", 0.0))
	var half_cycle := float(motion.get("cycle_duration", 0.42)) * 0.5

	_motion_tween = create_tween().set_loops()
	_motion_tween.set_trans(Tween.TRANS_SINE)
	_motion_tween.set_ease(Tween.EASE_IN_OUT)
	_motion_tween.tween_property(
		_motion_root,
		"position",
		Vector2(horizontal, -vertical),
		half_cycle,
	)
	_motion_tween.parallel().tween_property(
		_motion_root,
		"rotation",
		rotation_amount,
		half_cycle,
	)
	_motion_tween.parallel().tween_property(
		_motion_root,
		"scale",
		Vector2.ONE * (1.0 + scale_amount),
		half_cycle,
	)
	_motion_tween.tween_property(
		_motion_root,
		"position",
		Vector2(-horizontal * 0.6, -vertical * 0.15),
		half_cycle,
	)
	_motion_tween.parallel().tween_property(
		_motion_root,
		"rotation",
		-rotation_amount * 0.65,
		half_cycle,
	)
	_motion_tween.parallel().tween_property(
		_motion_root,
		"scale",
		Vector2.ONE,
		half_cycle,
	)


func _on_return_finished() -> void:
	_motion_tween = null
	_reset_motion_transform()


func _kill_motion_tween() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null


func _reset_motion_transform() -> void:
	if not is_instance_valid(_motion_root):
		return
	_motion_root.position = Vector2.ZERO
	_motion_root.rotation = 0.0
	_motion_root.scale = Vector2.ONE


func _update_motion_pivot() -> void:
	if is_instance_valid(_motion_root):
		_motion_root.pivot_offset = _motion_root.size * Vector2(0.5, 0.9)


func _resolved_lean_direction() -> float:
	if not is_zero_approx(speaking_lean_direction):
		return speaking_lean_direction
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0:
		var center_x := position.x + size.x * 0.5
		return 1.0 if center_x <= parent_control.size.x * 0.5 else -1.0
	return 1.0


func _refresh() -> void:
	if not is_instance_valid(_name_label):
		return

	var texture := _resolve_portrait_texture()
	var uses_placeholder := texture == null
	_name_label.text = actor_name
	_name_label.visible = uses_placeholder
	_expression_label.text = expression
	_expression_label.visible = uses_placeholder
	_frame.visible = uses_placeholder
	_portrait.color = accent_color
	_portrait.visible = uses_placeholder
	_portrait_image.texture = texture
	_portrait_image.visible = not uses_placeholder
	# Keep actors opaque: RGB modulation darkens rendered pixels while retaining
	# their alpha, so transparent areas around a portrait stay transparent.
	var brightness := 1.0 if is_active else 1.0 - inactive_darkness
	modulate = Color(brightness, brightness, brightness, 1.0)


func _resolve_portrait_texture() -> Texture2D:
	if not character_id.is_empty():
		var character_directory: Dictionary = ProjectSettings.get_setting(
			"dialogic/directories/dch_directory",
			{},
		)
		var character_path := String(character_directory.get(String(character_id), ""))
		if not character_path.is_empty() and ResourceLoader.exists(character_path):
			var character := ResourceLoader.load(character_path) as DialogicCharacter
			if character != null:
				var portrait_info: Dictionary = character.get_portrait_info(expression.to_lower())
				var export_overrides: Dictionary = portrait_info.get("export_overrides", {})
				var character_texture := _load_texture_override(export_overrides.get("image"))
				if character_texture != null:
					return character_texture
	return portrait_texture


func _load_texture_override(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value
	if value == null:
		return null

	var image_path := _decode_resource_path(String(value))
	if image_path.is_empty() or not ResourceLoader.exists(image_path, "Texture2D"):
		return null
	return ResourceLoader.load(image_path, "Texture2D") as Texture2D


static func _decode_resource_path(value: String) -> String:
	var candidate := value.strip_edges()
	if candidate.is_empty():
		return ""

	# Dialogic stores scene export overrides as Variant text. Depending on how a
	# .dch file was authored, this can be either res://art.png or
	# "res://art.png". Decode the latter without requiring a vendor patch.
	var parsed: Variant = str_to_var(candidate)
	if parsed is String:
		candidate = String(parsed).strip_edges()
	elif candidate.length() >= 2:
		var is_double_quoted := candidate.begins_with("\"") and candidate.ends_with("\"")
		var is_single_quoted := candidate.begins_with("'") and candidate.ends_with("'")
		if is_double_quoted or is_single_quoted:
			candidate = candidate.substr(1, candidate.length() - 2).strip_edges()
	return candidate
