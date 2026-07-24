class_name PhraseCutUI
extends Control
## Overlay shown by DialogicPhraseCutEvent. Lets the player toggle phrases off
## to save budget, shows the assembled sentence + running cost live, and emits
## `resolved` (with `result = {kept_text, cost}`) on confirm.
##
## Built in code so there's no .tscn to author. Replace with a styled scene later.

signal resolved

var result: Dictionary = {}

var _segments: Array = []
var _min_keep: int = 1
var _budget: int = 0
var _speaker: String = ""

var _kept: Array = []          # bool per phrase index
var _phrase_idx: Array = []    # segment index of each phrase
var _chips: Array = []         # Buttons
var _sentence_label: Label
var _budget_label: Label
var _confirm_button: Button


func setup(segments: Array, min_keep: int, budget: int, speaker: String) -> void:
	_segments = segments
	_min_keep = min_keep
	_budget = budget
	_speaker = speaker
	_phrase_idx.clear()
	_kept.clear()
	for i in range(len(segments)):
		if segments[i].get("type") == "phrase":
			_phrase_idx.append(i)
			_kept.append(true)
	_build_ui()
	_recompute()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 260)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Trim what %s will say (tap a phrase to cut it):" % (_speaker if _speaker else "they")
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_sentence_label = Label.new()
	_sentence_label.text = ""
	_sentence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sentence_label.custom_minimum_size = Vector2(0, 64)
	_sentence_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_sentence_label)

	var chips_row := HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 8)
	chips_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(chips_row)
	_chips.clear()
	for k in range(len(_phrase_idx)):
		var seg: Dictionary = _segments[_phrase_idx[k]]
		var btn := Button.new()
		btn.text = "%s  ($%d)" % [seg.get("text", ""), int(seg.get("cost", 0))]
		btn.toggle_mode = true
		btn.button_pressed = true   # kept
		btn.add_theme_font_size_override("font_size", 18)
		btn.toggled.connect(_on_chip_toggled.bind(k))
		chips_row.add_child(btn)
		_chips.append(btn)

	_budget_label = Label.new()
	_budget_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_budget_label)

	_confirm_button = Button.new()
	_confirm_button.text = "Confirm"
	_confirm_button.add_theme_font_size_override("font_size", 20)
	_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_button.pressed.connect(_on_confirm)
	vbox.add_child(_confirm_button)


func _on_chip_toggled(pressed: bool, k: int) -> void:
	_kept[k] = pressed
	_recompute()


func _assemble() -> String:
	var parts: PackedStringArray = []
	for i in range(len(_segments)):
		var seg: Dictionary = _segments[i]
		if seg.get("type") == "fixed":
			parts.append(String(seg.get("text", "")))
		else:  # phrase
			var k := _phrase_idx.find(i)
			if k >= 0 and _kept[k]:
				parts.append(String(seg.get("text", "")))
	return " ".join(parts).replace("  ", " ").strip_edges()


func _cost() -> int:
	var total := 0
	for k in range(len(_phrase_idx)):
		if _kept[k]:
			total += int(_segments[_phrase_idx[k]].get("cost", 0))
	return total


func _kept_count() -> int:
	var n := 0
	for k in _kept:
		if k: n += 1
	return n


func _recompute() -> void:
	var cost := _cost()
	var kept := _kept_count()
	var over := cost > _budget
	var too_few := kept < _min_keep
	_sentence_label.text = "\"%s\"" % _assemble()
	_budget_label.text = "Budget left: $%d   |   this line: $%d   |   kept %d/%d phrases" % [_budget, cost, kept, len(_phrase_idx)]
	_budget_label.add_theme_color_override("font_color", Color.RED if (over or too_few) else Color.WHITE)
	_confirm_button.disabled = over or too_few


func _on_confirm() -> void:
	# collect ids of kept phrases that have one, for PhraseMemory branching
	var kept_ids: Array = []
	for k in range(len(_phrase_idx)):
		if _kept[k]:
			var seg: Dictionary = _segments[_phrase_idx[k]]
			if seg.has("id"):
				kept_ids.append(String(seg["id"]))
	result = {"kept_text": _assemble(), "cost": _cost(), "kept_ids": kept_ids}
	resolved.emit()
