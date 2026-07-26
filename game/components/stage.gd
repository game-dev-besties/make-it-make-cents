@tool
class_name StoryStage
extends Control

## Base visual stage for an episode.  Designers arrange Background, Props,
## ActorSlots and Effects directly in the scene tree, then author named cues in
## its AnimationPlayer.  Gameplay only needs to call play_cue("cue_name").

signal cue_started(cue_name: StringName)
signal cue_finished(cue_name: StringName)

## Episode scenes were authored against this landscape composition.  Keep the
## story action coherent on any viewport by scaling the scene into one framed
## composition; unused viewport space is intentionally letterboxed in black.
const REFERENCE_SIZE := Vector2(1152.0, 648.0)

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
@onready var _background: ColorRect = $Background

var _background_tween: Tween
var _composition_layers: Array[Control] = []
var _title_base_position := Vector2.ZERO
var _title_base_scale := Vector2.ONE
var _title_base_pivot := Vector2.ZERO
var _speaking_slot: StageActorSlot


func _ready() -> void:
	_refresh_editor_label()
	_background.color = Color.BLACK
	if animation_player.animation_finished.is_connected(_on_animation_finished) == false:
		animation_player.animation_finished.connect(_on_animation_finished)
	_cache_composition_layers()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func play_cue(cue_name: StringName, custom_blend := -1.0) -> bool:
	if not has_cue(cue_name):
		push_warning("Stage cue '%s' does not exist on %s." % [cue_name, name])
		return false

	_finish_active_cue()
	animation_player.play(cue_name, custom_blend)
	cue_started.emit(cue_name)
	return true


func has_cue(cue_name: StringName) -> bool:
	return not cue_name.is_empty() and animation_player.has_animation(cue_name)


func stop_cue() -> void:
	animation_player.stop()


## A new presentation cue supersedes the previous one. Apply the interrupted
## cue's final keys first so short fades cannot be stranded halfway when the
## player advances quickly or enables auto-skip.
func _finish_active_cue() -> void:
	if not animation_player.is_playing():
		return
	var active_cue := StringName(animation_player.current_animation)
	animation_player.seek(animation_player.current_animation_length, true)
	animation_player.stop(true)
	cue_finished.emit(active_cue)


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
		# Ensemble stages intentionally overlap portraits. Keep the current
		# speaker readable without requiring a bespoke animation for every line.
		slot.z_index = 10 if is_speaker else 0
		if not is_speaker:
			continue
		matched = true
		slot.set_actor(
			display_name if not display_name.is_empty() else String(character_id),
			expression,
		)
	return matched


## Begins procedural speaking motion once Dialogic actually starts revealing a
## line. Speaker selection and expression changes happen earlier in
## apply_dialogic_text(), so textbox transitions do not make actors move early.
func start_dialogic_speaking(info: Dictionary) -> bool:
	var character := info.get("character") as DialogicCharacter
	if character == null:
		stop_dialogic_speaking({}, true)
		return false
	var character_id := StringName(character.get_identifier())
	for slot in _actor_slots():
		if slot.character_id != character_id:
			if slot.is_speaking():
				slot.stop_speaking()
			continue
		if is_instance_valid(_speaking_slot) and _speaking_slot != slot:
			_speaking_slot.stop_speaking()
		_speaking_slot = slot
		slot.start_speaking(info)
		return true
	stop_dialogic_speaking({}, true)
	return false


## Ends motion when text finishes revealing, while leaving the active-speaker
## lighting in place until the next line selects another character.
func stop_dialogic_speaking(
	_info: Dictionary = {},
	immediate := false,
) -> bool:
	if not is_instance_valid(_speaking_slot):
		_speaking_slot = null
		return false
	_speaking_slot.stop_speaking(immediate)
	_speaking_slot = null
	return true


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


## Keep each authored layer in one fixed 1152x648 coordinate system. Scaling
## the layers themselves means animation tracks can continue writing authored
## positions without making actors drift when the window is wider or taller.
func _cache_composition_layers() -> void:
	_composition_layers.clear()
	for container_name in [&"Props", &"ActorSlots", &"Effects"]:
		var container := get_node_or_null(NodePath(container_name)) as Control
		if container != null:
			_composition_layers.append(container)
	_title_base_position = _title_label.position
	_title_base_scale = _title_label.scale
	_title_base_pivot = _title_label.pivot_offset


func _apply_responsive_layout() -> void:
	if _composition_layers.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var composition_scale := minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	var composition_size := REFERENCE_SIZE * composition_scale
	var composition_origin := (size - composition_size) * 0.5
	_layout_framed_background(_background_image, composition_origin, composition_size)
	for layer: Control in _composition_layers:
		_layout_composition_layer(layer, composition_origin, composition_scale)
	_title_label.scale = _title_base_scale * composition_scale
	_title_label.position = composition_origin \
		+ _title_base_position * composition_scale \
		+ _title_base_pivot * (Vector2.ONE - Vector2.ONE * composition_scale)


func _layout_composition_layer(
	layer: Control,
	composition_origin: Vector2,
	composition_scale: float,
) -> void:
	layer.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	layer.position = composition_origin
	layer.size = REFERENCE_SIZE
	layer.pivot_offset = Vector2.ZERO
	layer.scale = Vector2.ONE * composition_scale


func _layout_framed_background(
	background: TextureRect,
	composition_origin: Vector2,
	composition_size: Vector2,
) -> void:
	background.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	background.position = composition_origin
	background.size = composition_size


func _refresh_editor_label() -> void:
	if is_instance_valid(_title_label):
		_title_label.text = stage_title


func _on_animation_finished(animation_name: StringName) -> void:
	cue_finished.emit(animation_name)
