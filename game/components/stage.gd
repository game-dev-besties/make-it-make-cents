@tool
class_name StoryStage
extends Control

## Base visual stage for an episode.  Designers arrange Background, Props,
## ActorSlots and Effects directly in the scene tree, then author named cues in
## its AnimationPlayer.  Gameplay only needs to call play_cue("cue_name").

signal cue_started(cue_name: StringName)
signal cue_finished(cue_name: StringName)

@export_category("Stage")
@export var stage_title := "Untitled stage":
	set(value):
		stage_title = value
		_refresh_editor_label()

@export_category("Editor Preview")
@export var preview_cue: StringName = &"":
	set(value):
		preview_cue = value

@export var play_preview_cue := false:
	set(value):
		play_preview_cue = value
		if value:
			call_deferred("play_cue", preview_cue)
			play_preview_cue = false

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var _title_label: Label = %StageTitle


func _ready() -> void:
	_refresh_editor_label()
	if animation_player.animation_finished.is_connected(_on_animation_finished) == false:
		animation_player.animation_finished.connect(_on_animation_finished)


func play_cue(cue_name: StringName, custom_blend := -1.0) -> bool:
	if cue_name.is_empty() or not animation_player.has_animation(cue_name):
		push_warning("Stage cue '%s' does not exist on %s." % [cue_name, name])
		return false

	animation_player.play(cue_name, custom_blend)
	cue_started.emit(cue_name)
	return true


func stop_cue() -> void:
	animation_player.stop()


func set_actor(slot_name: StringName, actor_name: String, expression := "neutral") -> void:
	var slot := get_node_or_null("ActorSlots/%s" % slot_name) as StageActorSlot
	if slot == null:
		push_warning("Unknown actor slot '%s' on %s." % [slot_name, name])
		return
	slot.set_actor(actor_name, expression)


func set_actor_active(slot_name: StringName, active: bool) -> void:
	var slot := get_node_or_null("ActorSlots/%s" % slot_name) as StageActorSlot
	if slot != null:
		slot.is_active = active


func _refresh_editor_label() -> void:
	if is_instance_valid(_title_label):
		_title_label.text = stage_title


func _on_animation_finished(animation_name: StringName) -> void:
	cue_finished.emit(animation_name)
