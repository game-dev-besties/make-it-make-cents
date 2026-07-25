class_name PhraseCutWord
extends Button
## A text-first toggle. Pressed words are spoken; unpressed words are struck out.


func _ready() -> void:
	toggled.connect(func(_is_kept: bool) -> void: queue_redraw())


func _draw() -> void:
	if button_pressed or disabled or text.is_empty():
		return

	var strike_color := get_theme_color("font_color")
	strike_color.a = minf(1.0, strike_color.a + 0.2)
	var line_y := size.y * 0.54
	draw_line(Vector2(3.0, line_y), Vector2(size.x - 3.0, line_y), strike_color, 2.0, true)
