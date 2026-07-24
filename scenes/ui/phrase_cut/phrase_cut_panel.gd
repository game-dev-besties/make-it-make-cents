extends Control
## Editor-authored phrase selection overlay.

signal resolved(kept_ids: Array[String], kept_text: String, delivery_mode: String)

const PHRASE_CHIP_SCENE := preload("res://scenes/ui/phrase_cut/phrase_chip.tscn")
const MAX_PANEL_WIDTH := 760.0
const MIN_PANEL_WIDTH := 220.0
const HORIZONTAL_GUTTER := 32.0

@export_group("Recovery Copy")
@export var pity_text := "hnf"
@export_multiline var sponsor_text := "Sam's Soda: pop open freedom."

var _segments: Array = []
var _budget: int = 0
var _speaker: String = ""
var _chips: Array[Button] = []
var _is_configured := false
var _can_use_pity := true
var _can_use_sponsor := true

@onready var _dialog_panel: PanelContainer = %DialogPanel
@onready var _title_label: Label = %TitleLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _preview_panel: PanelContainer = %PreviewPanel
@onready var _preview_label: Label = %PreviewLabel
@onready var _chips_flow: HFlowContainer = %ChipsFlow
@onready var _status_label: Label = %StatusLabel
@onready var _budget_label: Label = %BudgetLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _broke_prompt: Label = %BrokePrompt
@onready var _broke_actions: HFlowContainer = %BrokeActions
@onready var _pity_button: Button = %PityButton
@onready var _sponsor_button: Button = %SponsorButton


func _ready() -> void:
	_update_panel_width()
	if _is_configured:
		_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_panel_width()


func setup(
	segments: Array,
	budget: int,
	speaker: String,
	can_use_pity: bool,
	can_use_sponsor: bool,
) -> void:
	_segments = segments.duplicate(true)
	_budget = budget
	_speaker = speaker
	_can_use_pity = can_use_pity
	_can_use_sponsor = can_use_sponsor
	_is_configured = true

	if is_node_ready():
		_rebuild()


func _rebuild() -> void:
	_clear_chips()

	for segment_index in range(_segments.size()):
		var segment: Dictionary = _segments[segment_index]
		var chip := PHRASE_CHIP_SCENE.instantiate() as Button
		var phrase_text := String(segment.get("text", ""))
		var phrase_cost := int(segment.get("cost", 0))

		chip.text = "%s  ·  $%d" % [phrase_text, phrase_cost]
		chip.tooltip_text = "Selected: Penny will say this phrase. Click to cut it."
		chip.button_pressed = true
		chip.toggled.connect(_on_chip_toggled.bind(segment_index))
		_chips_flow.add_child(chip)
		_chips.append(chip)

	_title_label.text = (
		"Choose what %s says" % _speaker.capitalize()
		if not _speaker.is_empty()
		else "Choose what Penny says"
	)
	_set_out_of_words_mode(_budget <= 0)
	_recompute()

	if _budget <= 0:
		%SilenceButton.grab_focus()
	elif not _chips.is_empty():
		_chips.front().grab_focus()
	else:
		_confirm_button.grab_focus()


func _clear_chips() -> void:
	for child in _chips_flow.get_children():
		_chips_flow.remove_child(child)
		child.queue_free()
	_chips.clear()


func _on_chip_toggled(is_kept: bool, segment_index: int) -> void:
	if segment_index < 0 or segment_index >= _chips.size():
		return

	var chip := _chips[segment_index]
	chip.tooltip_text = (
		"Selected: Penny will say this phrase. Click to cut it."
		if is_kept
		else "Cut: Penny will omit this phrase. Click to restore it."
	)
	_recompute()


func _assemble() -> String:
	var parts: PackedStringArray = []
	for segment_index in range(_segments.size()):
		if _chips[segment_index].button_pressed:
			var segment: Dictionary = _segments[segment_index]
			parts.append(String(segment.get("text", "")))

	var assembled := " ".join(parts).strip_edges()
	while assembled.contains("  "):
		assembled = assembled.replace("  ", " ")
	return assembled


func _cost() -> int:
	var total := 0
	for segment_index in range(_segments.size()):
		if not _chips[segment_index].button_pressed:
			continue
		var segment: Dictionary = _segments[segment_index]
		total += int(segment.get("cost", 0))
	return total


func _kept_count() -> int:
	var count := 0
	for chip in _chips:
		if chip.button_pressed:
			count += 1
	return count


func _kept_ids() -> Array[String]:
	var ids: Array[String] = []
	for segment_index in range(_segments.size()):
		if not _chips[segment_index].button_pressed:
			continue
		var segment: Dictionary = _segments[segment_index]
		ids.append(String(segment["id"]))
	return ids


func _recompute() -> void:
	if _budget <= 0:
		return

	var kept_text := _assemble()
	var cost := _cost()
	var kept_count := _kept_count()
	var over_budget := cost > _budget
	var is_silent := kept_text.is_empty()

	_preview_label.text = (
		"Penny will stay silent."
		if is_silent
		else "“%s”" % kept_text
	)
	_budget_label.text = "This line: $%d    Budget after: $%d" % [cost, _budget - cost]
	_confirm_button.text = "Say nothing" if is_silent else "Say selected phrases"
	_confirm_button.disabled = over_budget

	if over_budget:
		_status_label.text = "Cut at least $%d more to afford this line." % (cost - _budget)
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
	elif is_silent:
		_status_label.text = "Silence is free."
		_status_label.add_theme_color_override("font_color", Color(0.65, 0.82, 0.7))
	else:
		_status_label.text = "%d of %d phrases kept." % [kept_count, _chips.size()]
		_status_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))


func _set_out_of_words_mode(enabled: bool) -> void:
	_instruction_label.visible = not enabled
	_preview_panel.visible = not enabled
	_chips_flow.visible = not enabled
	_status_label.visible = not enabled
	_budget_label.visible = not enabled
	_confirm_button.visible = not enabled
	_broke_prompt.visible = enabled
	_broke_actions.visible = enabled

	if not enabled:
		return

	_pity_button.text = 'Use pity word: "%s"' % pity_text
	_pity_button.disabled = not _can_use_pity
	_pity_button.tooltip_text = (
		"Your one free emergency word."
		if _can_use_pity
		else "The pity word was already used in this conversation."
	)
	_sponsor_button.text = "Shill sponsor (refill)"
	_sponsor_button.disabled = not _can_use_sponsor
	_sponsor_button.tooltip_text = (
		"Refill a few words, but hurt this conversation's score."
		if _can_use_sponsor
		else "The sponsor refill was already used in this conversation."
	)


func _on_confirm_button_pressed() -> void:
	if _confirm_button.disabled:
		return

	var kept_text := _assemble()
	resolved.emit(
		_kept_ids(),
		kept_text,
		"silence" if kept_text.is_empty() else "speech",
	)


func _on_pity_button_pressed() -> void:
	_resolve_recovery(pity_text, "pity")


func _on_silence_button_pressed() -> void:
	_resolve_recovery("", "silence")


func _on_sponsor_button_pressed() -> void:
	_resolve_recovery(sponsor_text, "sponsor")


func _resolve_recovery(text: String, delivery_mode: String) -> void:
	var no_ids: Array[String] = []
	resolved.emit(no_ids, text, delivery_mode)


func _update_panel_width() -> void:
	var available_width := maxf(size.x - HORIZONTAL_GUTTER, MIN_PANEL_WIDTH)
	_dialog_panel.custom_minimum_size.x = minf(available_width, MAX_PANEL_WIDTH)
