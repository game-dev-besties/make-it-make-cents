class_name StageHost
extends Node
## Owns the one currently mounted episode presentation.

signal presentation_changed(presentation: Node)

@export var presentation_container: NodePath

var current_presentation: Node


func show_presentation(scene: PackedScene) -> Node:
	clear_presentation()
	if scene == null:
		return null
	var presentation := scene.instantiate()
	var container := _get_container()
	container.add_child(presentation)
	presentation.add_to_group(&"active_story_presentation")
	current_presentation = presentation
	presentation_changed.emit(current_presentation)
	return current_presentation


func clear_presentation() -> void:
	if is_instance_valid(current_presentation):
		current_presentation.queue_free()
	current_presentation = null
	presentation_changed.emit(null)


func _get_container() -> Node:
	if not presentation_container.is_empty():
		var configured_container := get_node_or_null(presentation_container)
		if configured_container != null:
			return configured_container
	return self
