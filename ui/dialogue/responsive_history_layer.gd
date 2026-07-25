@tool
extends "res://addons/dialogic/Modules/DefaultLayoutParts/Layer_History/history_layer.gd"
## Keeps history actions and its scrollable log inside the letterboxed story
## frame rather than the browser's unused black-bar area.

const STORY_FRAME_SIZE := Vector2(1152.0, 648.0)


func _ready() -> void:
	super()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var frame_scale := minf(viewport_size.x / STORY_FRAME_SIZE.x, viewport_size.y / STORY_FRAME_SIZE.y)
	var frame_size := STORY_FRAME_SIZE * frame_scale
	var frame := Rect2((viewport_size - frame_size) * 0.5, frame_size)
	var compact := frame.size.x < 680.0 or frame.size.y < 460.0
	var inset := 16.0 if compact else 74.0
	var history_top := 48.0 if compact else 65.0
	var history_bottom := 16.0 if compact else 57.0

	var history_box := get_history_box()
	history_box.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	history_box.position = frame.position + Vector2(inset, history_top)
	history_box.size = Vector2(
		maxf(0.0, frame.size.x - inset * 2.0),
		maxf(0.0, frame.size.y - history_top - history_bottom),
	)

	var show_button := get_show_history_button()
	show_button.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	# Keep the button's styled edge clear of the letterbox/frame boundary.
	show_button.position = frame.position + Vector2(frame.size.x - 104.0, 7.0)
	show_button.size = Vector2(64.0, 31.0)

	var hide_button := get_hide_history_button()
	hide_button.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	if compact:
		hide_button.position = frame.position + Vector2(frame.size.x - 191.0, 8.0)
	else:
		hide_button.position = frame.position + Vector2(frame.size.x - 313.0, 85.0)
	hide_button.size = Vector2(175.0, 31.0)
