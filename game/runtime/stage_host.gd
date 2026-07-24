class_name StageHost
extends Node
## Owns the one currently mounted episode presentation.

signal presentation_changed(presentation: Node)

const GROUP_NAME := &"story_stage_host"

@export var presentation_container: NodePath

var current_presentation: Node


func _enter_tree() -> void:
	add_to_group(GROUP_NAME)


func show_presentation(scene: PackedScene) -> Node:
	clear_presentation()
	if scene == null:
		return null
	var presentation := scene.instantiate()
	var container := _get_container()
	container.add_child(presentation)
	current_presentation = presentation
	presentation_changed.emit(current_presentation)
	return current_presentation


func clear_presentation() -> void:
	if is_instance_valid(current_presentation):
		current_presentation.queue_free()
	current_presentation = null
	presentation_changed.emit(null)


func play_cue(cue_id: StringName) -> bool:
	if not is_instance_valid(current_presentation):
		push_warning("Cannot play stage cue '%s' without a mounted presentation." % cue_id)
		return false
	if not current_presentation.has_method("play_cue"):
		push_warning("Mounted presentation '%s' does not support stage cues." % current_presentation.name)
		return false
	return bool(current_presentation.call("play_cue", cue_id))


func apply_dialogic_text(info: Dictionary) -> bool:
	if not is_instance_valid(current_presentation):
		return false
	if not current_presentation.has_method("apply_dialogic_text"):
		return false
	return bool(current_presentation.call("apply_dialogic_text", info))


func apply_dialogic_background(info: Dictionary) -> bool:
	if not is_instance_valid(current_presentation):
		return false
	if not current_presentation.has_method("apply_dialogic_background"):
		return false
	return bool(current_presentation.call("apply_dialogic_background", info))


func _get_container() -> Node:
	if not presentation_container.is_empty():
		var configured_container := get_node_or_null(presentation_container)
		if configured_container != null:
			return configured_container
	return self
