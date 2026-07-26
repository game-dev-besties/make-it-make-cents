class_name PhraseCutWord
extends Button
## A text-first toggle. Pressed words are spoken; unpressed words are struck out.
## Hovering a kept word previews the cut before a click commits it; hovering an
## already-cut word previews the restore by fading its strike. Words that are
## unaffordable are disabled and struck out in the same colour as their text.

const TEXT_COLOR_STATES: Array[StringName] = [
	&"font_color",
	&"font_hover_color",
	&"font_pressed_color",
	&"font_hover_pressed_color",
	&"font_focus_color",
]
const STRIKE_COLOR := Color(0.917647, 0.498039, 0.345098, 1)
const STRIKE_OUTLINE_COLOR := Color(0.258824, 0.243137, 0.266667, 1)
const STRIKE_OUTLINE_WIDTH := 5.0
const STRIKE_WIDTH := 3.0
const STRIKE_EDGE_INSET := 3.0

var _is_hovering := false
var _strike_progress := 1.0
var _strike_left_to_right := true
var _strike_animation_active := false
var _prepared_is_cut := true
var _strike_draw_color := STRIKE_COLOR
var _strike_connection_left := 0.0
var _strike_connection_right := 0.0
var _text_color_held := false
var _press_text_color_held := false
var _held_text_colors: Dictionary = {}
var _held_color_was_overridden: Dictionary = {}
var _strike_tween: Tween
var _pulse_tween: Tween


func _ready() -> void:
	toggled.connect(func(_is_kept: bool) -> void: queue_redraw())
	if not button_down.is_connected(_on_button_down):
		button_down.connect(_on_button_down)
	if not button_up.is_connected(_on_button_up):
		button_up.connect(_on_button_up)
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))


func _on_hover_changed(hovering: bool) -> void:
	_is_hovering = hovering
	queue_redraw()


func _on_button_down() -> void:
	if disabled or _text_color_held:
		return
	# Latch before BaseButton toggles so its new state never gets one frame to
	# draw with the post-click color while the companion is still approaching.
	_hold_text_color(_current_text_color())
	_press_text_color_held = true


func _on_button_up() -> void:
	if _press_text_color_held:
		call_deferred("_release_unclaimed_press_text_color")


func _release_unclaimed_press_text_color() -> void:
	if not _press_text_color_held:
		return
	_press_text_color_held = false
	_release_text_color_hold()


func _current_text_color() -> Color:
	if button_pressed:
		return get_theme_color(
			"font_hover_pressed_color" if _is_hovering else "font_pressed_color",
		)
	return get_theme_color("font_hover_color" if _is_hovering else "font_color")


func set_strike_connection_left(extension: float) -> void:
	var next_extension := maxf(0.0, extension)
	if is_equal_approx(_strike_connection_left, next_extension):
		return
	_strike_connection_left = next_extension
	queue_redraw()


func set_strike_connection_right(extension: float) -> void:
	var next_extension := maxf(0.0, extension)
	if is_equal_approx(_strike_connection_right, next_extension):
		return
	_strike_connection_right = next_extension
	queue_redraw()


func clear_strike_connections() -> void:
	set_strike_connection_left(0.0)
	set_strike_connection_right(0.0)


func get_strike_connections() -> Vector2:
	return Vector2(_strike_connection_left, _strike_connection_right)


func can_connect_strike() -> bool:
	return _strike_line_rects().size() == 1


func _draw() -> void:
	if text.is_empty():
		return

	if disabled:
		# Unaffordable: struck out in the disabled font colour, no hover preview.
		_draw_strike(get_theme_color("font_disabled_color"))
		return

	var strike_color := STRIKE_COLOR
	if _strike_animation_active:
		strike_color = _strike_draw_color
		_draw_strike(strike_color, _strike_progress, _strike_left_to_right)
		return
	elif button_pressed and _is_hovering:
		# Kept, hovered: preview the cut that a click would commit.
		strike_color.a *= 0.55
	elif not button_pressed and _is_hovering:
		# Cut, hovered: preview the restore by fading the committed strike.
		strike_color.a *= 0.35
	elif not button_pressed:
		# Cut, committed.
		strike_color = STRIKE_COLOR
	else:
		return

	_draw_strike(strike_color)


func prepare_strike_animation(is_cut: bool, left_to_right: bool) -> void:
	if is_instance_valid(_strike_tween):
		_strike_tween.kill()
	var has_press_color_hold := _press_text_color_held and _text_color_held
	if has_press_color_hold:
		# Claim the pre-toggle latch so button_up's deferred cleanup leaves it
		# in place until play_prepared_strike() runs at impact.
		_press_text_color_held = false
	else:
		_release_text_color_hold()
	_prepared_is_cut = is_cut
	_strike_left_to_right = left_to_right
	_strike_draw_color = STRIKE_COLOR
	_strike_progress = 0.0 if is_cut else 1.0
	_strike_animation_active = true
	if not has_press_color_hold:
		_hold_previous_text_color()
	queue_redraw()


func play_prepared_strike() -> void:
	if not _strike_animation_active:
		return
	_release_text_color_hold()
	_play_impact_pulse()
	_strike_tween = create_tween()
	_strike_tween.tween_method(
		_set_strike_progress,
		_strike_progress,
		1.0 if _prepared_is_cut else 0.0,
		0.11,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_strike_tween.tween_callback(_finish_strike_animation)


func _set_strike_progress(progress: float) -> void:
	_strike_progress = progress
	queue_redraw()


func _finish_strike_animation() -> void:
	_release_text_color_hold()
	_strike_animation_active = false
	_strike_progress = 1.0 if not button_pressed else 0.0
	queue_redraw()


func _hold_previous_text_color() -> void:
	# The button has already toggled, so explicitly keep the color from its
	# previous state until the companion reaches the word.
	var held_color := (
		get_theme_color("font_pressed_color")
		if _prepared_is_cut
		else get_theme_color("font_color")
	)
	_hold_text_color(held_color)


func _hold_text_color(held_color: Color) -> void:
	_held_text_colors.clear()
	_held_color_was_overridden.clear()
	for color_name: StringName in TEXT_COLOR_STATES:
		_held_text_colors[color_name] = get_theme_color(color_name)
		_held_color_was_overridden[color_name] = has_theme_color_override(color_name)
		add_theme_color_override(color_name, held_color)
	_text_color_held = true


func _release_text_color_hold() -> void:
	if not _text_color_held:
		return
	for color_name: StringName in TEXT_COLOR_STATES:
		if bool(_held_color_was_overridden.get(color_name, false)):
			var original_color: Color = _held_text_colors.get(color_name, Color.WHITE)
			add_theme_color_override(color_name, original_color)
		else:
			remove_theme_color_override(color_name)
	_held_text_colors.clear()
	_held_color_was_overridden.clear()
	_text_color_held = false
	_press_text_color_held = false


func _play_impact_pulse() -> void:
	if is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2(1.04, 0.94) if _prepared_is_cut else Vector2(0.97, 1.03)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(
		Tween.TRANS_BACK,
	).set_ease(Tween.EASE_OUT)


func _draw_strike(
	strike_color: Color,
	progress: float = 1.0,
	left_to_right: bool = true,
) -> void:
	var line_rects := _strike_line_rects()
	var can_extend := line_rects.size() == 1
	for line_rect: Rect2 in line_rects:
		var left := Vector2(line_rect.position.x, line_rect.get_center().y)
		var right := Vector2(line_rect.end.x, line_rect.get_center().y)
		if can_extend:
			left.x -= _strike_connection_left
			right.x += _strike_connection_right
		var line_start := left if left_to_right else right
		var line_end := line_start.lerp(right if left_to_right else left, progress)
		draw_line(
			line_start,
			line_end,
			STRIKE_OUTLINE_COLOR,
			STRIKE_OUTLINE_WIDTH,
			true,
		)
		draw_line(line_start, line_end, strike_color, STRIKE_WIDTH, true)


func _strike_line_rects() -> Array[Rect2]:
	var style := _strike_stylebox()
	var left_margin := 0.0 if style == null else style.get_margin(SIDE_LEFT)
	var top_margin := 0.0 if style == null else style.get_margin(SIDE_TOP)
	var right_margin := 0.0 if style == null else style.get_margin(SIDE_RIGHT)
	var bottom_margin := 0.0 if style == null else style.get_margin(SIDE_BOTTOM)
	var content_size := Vector2(
		maxf(1.0, size.x - left_margin - right_margin),
		maxf(1.0, size.y - top_margin - bottom_margin),
	)

	var paragraph := TextParagraph.new()
	paragraph.alignment = alignment
	paragraph.break_flags = _strike_break_flags()
	paragraph.width = (
		-1.0
		if autowrap_mode == TextServer.AUTOWRAP_OFF
		else content_size.x
	)
	paragraph.add_string(
		text,
		get_theme_font("font"),
		get_theme_font_size("font_size"),
		language,
	)

	var paragraph_size := paragraph.get_size()
	var line_top := top_margin + maxf(0.0, (content_size.y - paragraph_size.y) * 0.5)
	var line_rects: Array[Rect2] = []
	for line_index: int in paragraph.get_line_count():
		var line_size := paragraph.get_line_size(line_index)
		var line_width := minf(content_size.x, paragraph.get_line_width(line_index))
		var line_left := left_margin
		match alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				line_left += (content_size.x - line_width) * 0.5
			HORIZONTAL_ALIGNMENT_RIGHT:
				line_left += content_size.x - line_width
		var strike_left := maxf(STRIKE_EDGE_INSET, line_left - 1.0)
		var strike_right := minf(
			size.x - STRIKE_EDGE_INSET,
			line_left + line_width + 1.0,
		)
		line_rects.append(
			Rect2(
				strike_left,
				line_top + line_size.y * 0.04,
				maxf(0.0, strike_right - strike_left),
				line_size.y,
			)
		)
		line_top += line_size.y
	paragraph = null
	return line_rects


func _strike_stylebox() -> StyleBox:
	var style_name := &"normal"
	if disabled:
		style_name = &"disabled"
	elif _is_hovering:
		style_name = &"hover_pressed" if button_pressed else &"hover"
	elif button_pressed:
		style_name = &"pressed"
	var style := get_theme_stylebox(style_name)
	return style if style != null else get_theme_stylebox("normal")


func _strike_break_flags() -> int:
	var flags := TextServer.BREAK_MANDATORY | autowrap_trim_flags
	match autowrap_mode:
		TextServer.AUTOWRAP_ARBITRARY:
			flags |= TextServer.BREAK_GRAPHEME_BOUND
		TextServer.AUTOWRAP_WORD:
			flags |= TextServer.BREAK_WORD_BOUND
		TextServer.AUTOWRAP_WORD_SMART:
			flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return flags
