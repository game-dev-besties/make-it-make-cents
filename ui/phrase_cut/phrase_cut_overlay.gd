class_name PhraseCutOverlay
extends Control
## GUI-authored phrase-cut overlay. Edit phrase_cut_overlay.tscn in Godot to
## change its layout, theme, typography, and recovery choices.

signal resolved(kept_ids: Array[String], kept_text: String, delivery_mode: StringName, cost: int)

const DELIVERY_NORMAL := &"normal"
const DELIVERY_SILENCE := &"silence"
const DELIVERY_PITY := &"pity"
const DELIVERY_SPONSOR := &"sponsor"

const DEFAULT_PITY_TEXT := "hnf"
const DEFAULT_SPONSOR_TEXT := "Sam's Soda: pop open freedom."

## Kept for callers that prefer to inspect the result after awaiting `resolved`.
## The typed signal above is the public contract.
var result: Dictionary = {}

var _segments: Array = []
var _budget := 0
var _speaker := ""
var _can_use_pity := false
var _can_use_sponsor := false
var _pity_text := DEFAULT_PITY_TEXT
var _sponsor_text := DEFAULT_SPONSOR_TEXT
var _phrase_buttons: Array[Button] = []
var _is_resolved := false

@onready var _title_label: Label = %TitleLabel
@onready var _sentence_label: Label = %SentenceLabel
@onready var _chips: FlowContainer = %Chips
@onready var _budget_label: Label = %BudgetLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _recovery_box: VBoxContainer = %RecoveryBox
@onready var _recovery_label: Label = %RecoveryLabel
@onready var _silence_button: Button = %SilenceButton
@onready var _pity_button: Button = %PityButton
@onready var _sponsor_button: Button = %SponsorButton
@onready var _phrase_button_template: Button = %PhraseButtonTemplate


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm)
	_silence_button.pressed.connect(_on_silence)
	_pity_button.pressed.connect(_on_pity)
	_sponsor_button.pressed.connect(_on_sponsor)
	_rebuild()


func setup(segments: Array, budget: int, speaker: String, recovery: Dictionary = {}) -> void:
	_segments = segments
	_budget = maxi(0, budget)
	_speaker = speaker
	_can_use_pity = bool(recovery.get("can_use_pity", false))
	_can_use_sponsor = bool(recovery.get("can_use_sponsor", false))
	_pity_text = String(recovery.get("pity_text", DEFAULT_PITY_TEXT))
	_sponsor_text = String(recovery.get("sponsor_text", DEFAULT_SPONSOR_TEXT))
	_is_resolved = false
	result.clear()
	if is_node_ready():
		_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return

	_title_label.text = "Trim what %s will say (tap a phrase to cut it):" % (_speaker if not _speaker.is_empty() else "they")
	for child: Node in _chips.get_children():
		child.queue_free()
	_phrase_buttons.clear()

	for segment_index: int in _segments.size():
		var segment: Variant = _segments[segment_index]
		if not segment is Dictionary or String(segment.get("type", "phrase")) != "phrase":
			continue
		var chip: Button = _phrase_button_template.duplicate() as Button
		chip.visible = true
		chip.text = "%s  ($%d)" % [String(segment.get("text", "")), _segment_cost(segment)]
		chip.button_pressed = true
		chip.set_meta("segment_index", segment_index)
		chip.toggled.connect(_on_chip_toggled)
		_chips.add_child(chip)
		_phrase_buttons.append(chip)

	var is_out_of_budget := _budget <= 0
	for chip: Button in _phrase_buttons:
		if is_out_of_budget:
			var segment_index := int(chip.get_meta("segment_index", -1))
			var segment: Dictionary = _segments[segment_index]
			var is_free := _segment_cost(segment) == 0
			chip.set_pressed_no_signal(is_free)
			chip.disabled = not is_free
	_recovery_box.visible = is_out_of_budget
	_confirm_button.visible = (
		not is_out_of_budget
		or (_cost() == 0 and not _assemble().is_empty())
	)
	_pity_button.visible = _can_use_pity
	_sponsor_button.visible = _can_use_sponsor
	_recovery_label.text = _recovery_description()
	_recompute()


func _on_chip_toggled(_pressed: bool) -> void:
	_recompute()


func _assemble() -> String:
	var parts := PackedStringArray()
	for segment_index: int in _segments.size():
		var segment: Variant = _segments[segment_index]
		if not segment is Dictionary:
			continue
		match String(segment.get("type", "phrase")):
			"fixed":
				parts.append(String(segment.get("text", "")))
			"phrase":
				var chip: Button = _chip_for_segment(segment_index)
				if chip != null and chip.button_pressed:
					parts.append(String(segment.get("text", "")))
	return " ".join(parts).replace("  ", " ").strip_edges()


func _cost() -> int:
	var total := 0
	for segment_index: int in _segments.size():
		var segment: Variant = _segments[segment_index]
		if not segment is Dictionary:
			continue
		match String(segment.get("type", "phrase")):
			"fixed":
				total += maxi(0, int(segment.get("cost", 0)))
			"phrase":
				var chip: Button = _chip_for_segment(segment_index)
				if chip != null and chip.button_pressed:
					total += _segment_cost(segment)
	return total


func _segment_cost(segment: Dictionary) -> int:
	if segment.has("cost"):
		return maxi(0, int(segment["cost"]))
	var text := String(segment.get("text", "")).strip_edges()
	return 0 if text.is_empty() else text.split(" ", false).size()


func _chip_for_segment(segment_index: int) -> Button:
	for chip: Button in _phrase_buttons:
		if int(chip.get_meta("segment_index", -1)) == segment_index:
			return chip
	return null


func _kept_count() -> int:
	var total := 0
	for chip: Button in _phrase_buttons:
		if chip.button_pressed:
			total += 1
	return total


func _kept_ids() -> Array[String]:
	var kept_ids: Array[String] = []
	for chip: Button in _phrase_buttons:
		if not chip.button_pressed:
			continue
		var segment_index := int(chip.get_meta("segment_index", -1))
		if segment_index < 0 or segment_index >= _segments.size():
			continue
		var segment: Variant = _segments[segment_index]
		if segment is Dictionary and segment.has("id"):
			kept_ids.append(String(segment["id"]))
	return kept_ids


func _recompute() -> void:
	var cost := _cost()
	var kept_count := _kept_count()
	var over_budget := cost > _budget
	var kept_text := _assemble()
	_sentence_label.text = "\"%s\"" % kept_text if not kept_text.is_empty() else "(say nothing)"
	_budget_label.text = "Budget left: $%d   |   this line: $%d   |   kept %d/%d phrases" % [_budget, cost, kept_count, _phrase_buttons.size()]
	_budget_label.modulate = Color(1.0, 0.42, 0.42) if over_budget else Color.WHITE
	_confirm_button.disabled = over_budget
	_confirm_button.text = "Say nothing ($0)" if kept_text.is_empty() else "Say it ($%d)" % cost


func _recovery_description() -> String:
	var choices := PackedStringArray(["stay silent"])
	if _can_use_pity:
		choices.append("use your one pity grunt")
	if _can_use_sponsor:
		choices.append("read a sponsor message for $3")
	return "You are out of words. You can %s." % ", ".join(choices)


func _on_confirm() -> void:
	var kept_text := _assemble()
	var delivery_mode := DELIVERY_SILENCE if kept_text.is_empty() else DELIVERY_NORMAL
	_resolve(_kept_ids(), kept_text, delivery_mode, _cost())


func _on_silence() -> void:
	_resolve([], "", DELIVERY_SILENCE, 0)


func _on_pity() -> void:
	_resolve([], _pity_text, DELIVERY_PITY, 0)


func _on_sponsor() -> void:
	_resolve([], _sponsor_text, DELIVERY_SPONSOR, 0)


func _resolve(kept_ids: Array[String], kept_text: String, delivery_mode: StringName, cost: int) -> void:
	if _is_resolved:
		return
	_is_resolved = true
	result = {
		"kept_ids": kept_ids,
		"kept_text": kept_text,
		"delivery_mode": delivery_mode,
		"cost": cost,
	}
	resolved.emit(kept_ids, kept_text, delivery_mode, cost)
