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

## Opacity used while another character is speaking. Set this to 1.0 to keep
## the actor fully visible, or lower it to make inactive actors fade further.
@export_range(0.0, 1.0, 0.01) var inactive_opacity := 0.45:
	set(value):
		inactive_opacity = value
		_refresh()

@onready var _name_label: Label = %NameLabel
@onready var _expression_label: Label = %ExpressionLabel
@onready var _frame: Panel = $Frame
@onready var _portrait: ColorRect = %Portrait
@onready var _portrait_image: TextureRect = %PortraitImage


func _ready() -> void:
	_refresh()


func set_actor(new_name: String, new_expression := "neutral") -> void:
	actor_name = new_name
	expression = new_expression


func clear_actor() -> void:
	actor_name = ""
	expression = ""


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
	modulate.a = 1.0 if is_active else inactive_opacity


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
