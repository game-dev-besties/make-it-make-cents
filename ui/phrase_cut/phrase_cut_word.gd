class_name PhraseCutWord
extends Button
## A text-first toggle. Pressed words are spoken; unpressed words are struck out.
## Hovering a kept word previews the cut before a click commits it; hovering an
## already-cut word previews the restore by fading its strike. Words that are
## unaffordable are disabled and struck out in the same colour as their text.

var _is_hovering := false


func _ready() -> void:
	toggled.connect(func(_is_kept: bool) -> void: queue_redraw())
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))


func _on_hover_changed(hovering: bool) -> void:
	_is_hovering = hovering
	queue_redraw()


func _draw() -> void:
	if text.is_empty():
		return

	if disabled:
		# Unaffordable: struck out in the disabled font colour, no hover preview.
		_draw_strike(get_theme_color("font_disabled_color"))
		return

	var strike_color := get_theme_color("font_color")
	if button_pressed and _is_hovering:
		# Kept, hovered: preview the cut that a click would commit.
		strike_color.a *= 0.55
	elif not button_pressed and _is_hovering:
		# Cut, hovered: preview the restore by fading the committed strike.
		strike_color.a *= 0.35
	elif not button_pressed:
		# Cut, committed.
		strike_color.a = minf(1.0, strike_color.a + 0.2)
	else:
		return

	_draw_strike(strike_color)


func _draw_strike(strike_color: Color) -> void:
	var line_y := size.y * 0.54
	draw_line(Vector2(3.0, line_y), Vector2(size.x - 3.0, line_y), strike_color, 2.0, true)
