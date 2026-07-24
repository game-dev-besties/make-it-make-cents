extends Control
## Title screen. Builds itself in code so main.tscn stays minimal.
## Pressing Start hands off to CutsceneRunner, which plays the cutscenes.

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Money Where Your Mouth Is"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "A family. A new country. A chatbot that charges per word."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var hint := Label.new()
	hint.text = "(You are the chatbot. Cut phrases to save money — but stay understandable.)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	vbox.add_child(hint)

	var btn := Button.new()
	btn.text = "Start"
	btn.add_theme_font_size_override("font_size", 24)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_start)
	vbox.add_child(btn)


func _on_start() -> void:
	hide()
	CutsceneRunner.start_game()
