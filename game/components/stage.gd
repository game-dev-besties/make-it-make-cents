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
var _responsive_controls: Array[Dictionary] = []
var _framed_prop_backgrounds: Array[TextureRect] = []


func _ready() -> void:
	_refresh_editor_label()
	_background.color = Color.BLACK
	if animation_player.animation_finished.is_connected(_on_animation_finished) == false:
		animation_player.animation_finished.connect(_on_animation_finished)
	_cache_responsive_controls()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func play_cue(cue_name: StringName, custom_blend := -1.0) -> bool:
	if cue_name.is_empty() or not animation_player.has_animation(cue_name):
		push_warning("Stage cue '%s' does not exist on %s." % [cue_name, name])
		return false

	_finish_active_cue()
	animation_player.play(cue_name, custom_blend)
	cue_started.emit(cue_name)
	return true


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


## A Control whose anchors are all zero is an authored, fixed-coordinate story
## element.  Its parent containers are deliberately not transformed: this
## lets blackout overlays keep their edge-to-edge anchors while positioned
## siblings scale as a single scene composition. Background textures are
## explicitly framed below so they share that composition too.
func _cache_responsive_controls() -> void:
	_responsive_controls.clear()
	_framed_prop_backgrounds.clear()
	for container_name in [&"Props", &"ActorSlots", &"Effects"]:
		var container := get_node_or_null(NodePath(container_name)) as Control
		if container != null:
			_collect_responsive_controls(container, false)


func _collect_responsive_controls(parent: Control, inside_framed_background: bool) -> void:
	for child: Node in parent.get_children():
		var control := child as Control
		if control == null:
			continue
		var is_framed_background := (
			parent.name == &"Props"
			and control is TextureRect
			and not _has_absolute_anchors(control)
		)
		if is_framed_background:
			_framed_prop_backgrounds.append(control as TextureRect)
			_collect_responsive_controls(control, true)
			continue
		if _has_absolute_anchors(control):
			_responsive_controls.append(
				{
					"control": control,
					"position": control.position,
					"scale": control.scale,
					"pivot": control.pivot_offset,
					"relative_to_frame": inside_framed_background,
				}
			)
			# Descendants inherit their parent's transform, so transforming them
			# too would apply the viewport scale twice.
			continue
		_collect_responsive_controls(control, inside_framed_background)


func _has_absolute_anchors(control: Control) -> bool:
	return (
		is_zero_approx(control.anchor_left)
		and is_zero_approx(control.anchor_top)
		and is_zero_approx(control.anchor_right)
		and is_zero_approx(control.anchor_bottom)
	)


func _apply_responsive_layout() -> void:
	if _responsive_controls.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var composition_scale := minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	var composition_size := REFERENCE_SIZE * composition_scale
	var composition_origin := (size - composition_size) * 0.5
	_layout_framed_background(_background_image, composition_origin, composition_size)
	for prop_background: TextureRect in _framed_prop_backgrounds:
		_layout_framed_background(prop_background, composition_origin, composition_size)
	for entry: Dictionary in _responsive_controls:
		var control := entry["control"] as Control
		if not is_instance_valid(control):
			continue
		var base_position := entry["position"] as Vector2
		var base_scale := entry["scale"] as Vector2
		var base_pivot := entry["pivot"] as Vector2
		control.scale = base_scale * composition_scale
		# Control scale is applied around its pivot. Offset that pivot so an
		# authored top-left coordinate remains on the reference composition.
		var origin := Vector2.ZERO if bool(entry["relative_to_frame"]) else composition_origin
		control.position = origin + base_position * composition_scale \
			+ base_pivot * (Vector2.ONE - Vector2.ONE * composition_scale)


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
