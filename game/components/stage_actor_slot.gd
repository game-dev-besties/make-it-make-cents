@tool
class_name StageActorSlot
extends Control

## A designer-editable position for an on-stage actor.  Replace the placeholder
## panel with a portrait scene later; its name and expression stay useful for
## editor previews and accessibility text.

@export_category("Actor")
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

@export var is_active := true:
	set(value):
		is_active = value
		_refresh()

@onready var _name_label: Label = %NameLabel
@onready var _expression_label: Label = %ExpressionLabel
@onready var _portrait: ColorRect = %Portrait


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

	_name_label.text = actor_name
	_expression_label.text = expression
	_portrait.color = accent_color
	modulate.a = 1.0 if is_active else 0.45
