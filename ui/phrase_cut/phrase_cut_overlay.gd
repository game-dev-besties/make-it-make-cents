class_name PhraseCutOverlay
extends Control
## GUI-authored phrase-cut overlay. Edit phrase_cut_overlay.tscn in Godot to
## change its layout, theme, typography, and button states.

signal resolved

var result: Dictionary = {}

var _segments: Array = []
var _min_keep := 1
var _budget := 0
var _speaker := ""
var _kept: Array = []
var _phrase_indices: Array = []

@onready var _title_label: Label = %TitleLabel
@onready var _sentence_label: Label = %SentenceLabel
@onready var _chips: FlowContainer = %Chips
@onready var _budget_label: Label = %BudgetLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _phrase_button_template: Button = %PhraseButtonTemplate


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm)
	_rebuild()


func setup(segments: Array, min_keep: int, budget: int, speaker: String) -> void:
	_segments = segments
	_min_keep = min_keep
	_budget = budget
	_speaker = speaker
	_phrase_indices.clear()
	_kept.clear()
	for index: int in _segments.size():
		var segment: Variant = _segments[index]
		if segment is Dictionary and segment.get("type") == "phrase":
			_phrase_indices.append(index)
			_kept.append(true)
	if is_node_ready():
		_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	_title_label.text = "Trim what %s will say (tap a phrase to cut it):" % (_speaker if not _speaker.is_empty() else "they")
	for child: Node in _chips.get_children():
		child.queue_free()
	for phrase_index: int in _phrase_indices.size():
		var segment_index: int = int(_phrase_indices[phrase_index])
		var segment: Variant = _segments[segment_index]
		if not segment is Dictionary:
			continue
		var chip: Button = _phrase_button_template.duplicate() as Button
		chip.visible = true
		chip.text = "%s  ($%d)" % [String(segment.get("text", "")), int(segment.get("cost", 0))]
		chip.button_pressed = true
		chip.toggled.connect(_on_chip_toggled.bind(phrase_index))
		_chips.add_child(chip)
	_recompute()


func _on_chip_toggled(pressed: bool, phrase_index: int) -> void:
	_kept[phrase_index] = pressed
	_recompute()


func _assemble() -> String:
	var parts := PackedStringArray()
	for index: int in _segments.size():
		var segment: Variant = _segments[index]
		if not segment is Dictionary:
			continue
		if segment.get("type") == "fixed":
			parts.append(String(segment.get("text", "")))
		else:
			var phrase_index: int = _phrase_indices.find(index)
			if phrase_index >= 0 and bool(_kept[phrase_index]):
				parts.append(String(segment.get("text", "")))
	return " ".join(parts).replace("  ", " ").strip_edges()


func _cost() -> int:
	var total := 0
	for phrase_index: int in _phrase_indices.size():
		if bool(_kept[phrase_index]):
			var segment_index: int = int(_phrase_indices[phrase_index])
			var segment: Variant = _segments[segment_index]
			if segment is Dictionary:
				total += int(segment.get("cost", 0))
	return total


func _kept_count() -> int:
	var total := 0
	for is_kept: Variant in _kept:
		if bool(is_kept):
			total += 1
	return total


func _recompute() -> void:
	var cost: int = _cost()
	var kept_count: int = _kept_count()
	var invalid_selection := cost > _budget or kept_count < _min_keep
	_sentence_label.text = "\"%s\"" % _assemble()
	_budget_label.text = "Budget left: $%d   |   this line: $%d   |   kept %d/%d phrases" % [_budget, cost, kept_count, _phrase_indices.size()]
	_budget_label.modulate = Color(1.0, 0.42, 0.42) if invalid_selection else Color.WHITE
	_confirm_button.disabled = invalid_selection


func _on_confirm() -> void:
	var kept_ids: Array = []
	for phrase_index: int in _phrase_indices.size():
		if not bool(_kept[phrase_index]):
			continue
		var segment_index: int = int(_phrase_indices[phrase_index])
		var segment: Variant = _segments[segment_index]
		if segment is Dictionary and segment.has("id"):
			kept_ids.append(String(segment["id"]))
	result = {"kept_text": _assemble(), "cost": _cost(), "kept_ids": kept_ids}
	resolved.emit()
