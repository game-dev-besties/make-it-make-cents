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
@onready var _background_image: TextureRect = %BackgroundImage

var _background_tween: Tween


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


func apply_dialogic_text(info: Dictionary) -> bool:
	var character := info.get("character") as DialogicCharacter
	var character_id := &""
	var display_name := ""
	var expression := ""
	if character != null:
		character_id = StringName(character.get_identifier())
		display_name = character.get_display_name_translated()
		expression = String(info.get("portrait", ""))
		if expression.is_empty():
			expression = character.default_portrait

	var matched := false
	for slot in _actor_slots():
		var is_speaker := not character_id.is_empty() and slot.character_id == character_id
		slot.is_active = is_speaker
		if not is_speaker:
			continue
		matched = true
		slot.set_actor(
			display_name if not display_name.is_empty() else String(character_id),
			expression,
		)
	return matched


## Applies Dialogic's native background state inside the editor-authored stage.
## This keeps backgrounds behind props and actors instead of using Dialogic's
## full-screen fallback layer, which would cover the stage.
func apply_dialogic_background(info: Dictionary) -> bool:
	if not is_instance_valid(_background_image):
		return false

	var image_path := String(info.get("argument", "")).strip_edges()
	var fade_time := maxf(0.0, float(info.get("fade_time", 0.0)))
	_stop_background_tween()

	if image_path.is_empty():
		_clear_background(fade_time)
		return true
	if not ResourceLoader.exists(image_path, "Texture2D"):
		push_warning("Dialogic background texture '%s' does not exist." % image_path)
		return false

	var texture := ResourceLoader.load(image_path, "Texture2D") as Texture2D
	if texture == null:
		push_warning("Dialogic background '%s' is not a Texture2D." % image_path)
		return false

	_background_image.texture = texture
	if fade_time <= 0.0:
		_background_image.modulate.a = 1.0
		return true

	_background_image.modulate.a = 0.0
	_background_tween = create_tween()
	_background_tween.tween_property(_background_image, "modulate:a", 1.0, fade_time)
	return true


func _actor_slots() -> Array[StageActorSlot]:
	var slots: Array[StageActorSlot] = []
	var actor_slots := get_node_or_null("ActorSlots")
	if actor_slots == null:
		return slots
	for child in actor_slots.get_children():
		var slot := child as StageActorSlot
		if slot != null:
			slots.append(slot)
	return slots


func _clear_background(fade_time: float) -> void:
	if fade_time <= 0.0 or _background_image.texture == null:
		_background_image.texture = null
		_background_image.modulate.a = 1.0
		return

	_background_tween = create_tween()
	_background_tween.tween_property(_background_image, "modulate:a", 0.0, fade_time)
	_background_tween.finished.connect(_finish_background_clear)


func _finish_background_clear() -> void:
	_background_image.texture = null
	_background_image.modulate.a = 1.0
	_background_tween = null


func _stop_background_tween() -> void:
	if _background_tween != null and _background_tween.is_valid():
		_background_tween.kill()
	_background_tween = null


func _refresh_editor_label() -> void:
	if is_instance_valid(_title_label):
		_title_label.text = stage_title


func _on_animation_finished(animation_name: StringName) -> void:
	cue_finished.emit(animation_name)
