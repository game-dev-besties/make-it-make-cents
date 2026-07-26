class_name ChapterTransition
extends CanvasLayer
## Reusable full-screen chapter card. The black field stays opaque while the
## title fades in, rests briefly, and fades out.

signal finished

@export_range(0.0, 5.0, 0.05, "or_greater") var fade_in_seconds := 0.35
@export_range(0.0, 10.0, 0.05, "or_greater") var hold_seconds := 1.8
@export_range(0.0, 5.0, 0.05, "or_greater") var fade_out_seconds := 0.35

@onready var title_label: Label = %TitleLabel

var _active_tween: Tween


func _ready() -> void:
	hide()


func present(chapter_title: String) -> void:
	if is_instance_valid(_active_tween):
		_active_tween.kill()

	title_label.text = chapter_title
	title_label.modulate.a = 0.0
	show()

	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.tween_property(
		title_label,
		"modulate:a",
		1.0,
		fade_in_seconds,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_interval(hold_seconds)
	_active_tween.tween_property(
		title_label,
		"modulate:a",
		0.0,
		fade_out_seconds,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _active_tween.finished

	_active_tween = null
	hide()
	finished.emit()


## Lets players advance the card without waiting through the full animation.
func skip() -> void:
	if is_instance_valid(_active_tween):
		_active_tween.custom_step(
			fade_in_seconds + hold_seconds + fade_out_seconds + 1.0,
		)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event.is_action_pressed(&"ui_accept")
		or event.is_action_pressed(&"ui_cancel")
	):
		skip()
		get_viewport().set_input_as_handled()


func _on_black_background_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton and event.pressed
		or event is InputEventScreenTouch and event.pressed
	):
		skip()
		get_viewport().set_input_as_handled()
