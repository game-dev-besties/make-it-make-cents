@tool
extends "res://addons/dialogic/Modules/DefaultLayoutParts/Layer_VN_Textbox/vn_textbox_layer.gd"
## Keeps Dialogic's editable textbox scene readable when the viewport is not
## the 16:9 desktop size it was originally composed for.

const MAX_WIDTH := 900.0
const MIN_WIDTH := 248.0
const WIDE_GUTTER := 56.0
const COMPACT_GUTTER := 24.0
const DESKTOP_HEIGHT := 210.0
const COMPACT_MIN_HEIGHT := 144.0
const DESKTOP_BOTTOM_MARGIN := 34.0
const COMPACT_BOTTOM_MARGIN := 16.0
const REFERENCE_SIZE := Vector2(1152.0, 648.0)


func _ready() -> void:
	super()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var composition_scale := minf(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y)
	var composition_size := REFERENCE_SIZE * composition_scale
	var composition_origin := (viewport_size - composition_size) * 0.5
	var compact := composition_size.x < 620.0 or composition_size.y < 500.0
	var gutter := COMPACT_GUTTER if compact else WIDE_GUTTER
	var box_width := clampf(composition_size.x - gutter * 2.0, MIN_WIDTH, MAX_WIDTH)
	var box_height := clampf(composition_size.y * 0.31, COMPACT_MIN_HEIGHT, DESKTOP_HEIGHT)
	var bottom_margin := COMPACT_BOTTOM_MARGIN if compact else DESKTOP_BOTTOM_MARGIN
	var font_size := 18 if compact else 22
	var name_font_size := 17 if compact else 20

	box_size = Vector2(box_width, box_height)
	box_margin_bottom = roundi(bottom_margin)
	text_size = font_size
	name_label_custom_font_size = name_font_size

	var sizer := %Sizer as Control
	sizer.size = box_size
	sizer.position = Vector2(
		composition_origin.x + (composition_size.x - box_width) * 0.5 - viewport_size.x * 0.5,
		composition_origin.y + composition_size.y - box_height - bottom_margin - viewport_size.y,
	)

	var dialog_text := %DialogicNode_DialogText as RichTextLabel
	dialog_text.add_theme_font_size_override(&"normal_font_size", font_size)
	dialog_text.add_theme_font_size_override(&"bold_font_size", font_size)
	dialog_text.add_theme_font_size_override(&"italics_font_size", font_size)
	dialog_text.add_theme_font_size_override(&"bold_italics_font_size", font_size)
	(%DialogicNode_NameLabel as Label).add_theme_font_size_override(&"font_size", name_font_size)
