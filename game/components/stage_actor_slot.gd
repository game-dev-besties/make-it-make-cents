@tool
class_name StageActorSlot
extends Control

## A designer-editable position for an on-stage actor.  A slot can show a
## registered Dialogic character portrait by setting character_id; otherwise it
## falls back to the editor-friendly color placeholder.

@export_category("Actor")
@export var actor_name := "Actor":
	set(value):
		actor_name = value
		_refresh()

## The Dialogic character identifier to display (for example, "leo").
## This is separate from actor_name so one portrait can represent a group such
## as "Mom and Leo" while keeping the authored stage label intact.
@export var character_id: StringName = &"":
	set(value):
		character_id = value
		_refresh()

@export_multiline var expression := "neutral":
	set(value):
		expression = value
		_refresh()

@export var accent_color := Color("8ba7d6"):
	set(value):
		accent_color = value
		_refresh()

## Optional art override for props or characters that are not registered yet.
## Registered character portraits take precedence so expression changes made by
## stage cues are always reflected on screen.
@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		_refresh()

@export var is_active := true:
	set(value):
		is_active = value
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
	var is_placeholder := texture == null
	_name_label.text = actor_name
	_name_label.visible = is_placeholder
	_expression_label.text = expression
	_expression_label.visible = is_placeholder
	_frame.visible = is_placeholder
	_portrait.color = accent_color
	_portrait.visible = is_placeholder
	_portrait_image.texture = texture
	_portrait_image.visible = not is_placeholder
	modulate.a = 1.0 if is_active else 0.45


func _resolve_portrait_texture() -> Texture2D:
	if not character_id.is_empty():
		var character_directory: Dictionary = ProjectSettings.get_setting("dialogic/directories/dch_directory", {})
		var character_path := String(character_directory.get(String(character_id), ""))
		var character := ResourceLoader.load(character_path) if not character_path.is_empty() else null
		if character != null:
			var portraits: Dictionary = character.get("portraits")
			var portrait_id := expression.to_lower()
			if not portraits.has(portrait_id):
				portrait_id = String(character.get("default_portrait"))
			var portrait: Dictionary = portraits.get(portrait_id, {})
			var export_overrides: Dictionary = portrait.get("export_overrides", {})
			var image_path := String(export_overrides.get("image", ""))
			if not image_path.is_empty():
				var character_texture := load(image_path) as Texture2D
				if character_texture != null:
					return character_texture
	return portrait_texture
