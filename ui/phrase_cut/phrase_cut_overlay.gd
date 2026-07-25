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

const MAX_PANEL_WIDTH := 780.0
const MIN_PANEL_WIDTH := 220.0
const HORIZONTAL_GUTTER := 48.0
const MONEYBOT_COMPANION_MIN_WIDTH := 1080.0
const MONEYBOT_COMPANION_MIN_HEIGHT := 540.0
const COMPACT_SAFE_MARGIN := 16
const COMPANION_SAFE_MARGIN_RIGHT := 180
const PANEL_CONTENT_MARGIN_RIGHT := 38
const COMPANION_CONTENT_MARGIN_RIGHT := 128
const COMPANION_PANEL_OVERLAP := 90.0
const COMPANION_SIZE := Vector2(286.0, 342.0)

const FIXED_WORD_FONT := preload("res://ui/theme/fonts/DepartureMono-Regular.ttf")
const FIXED_WORD_COLOR := Color(0.992157, 0.984314, 0.956863, 1)

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

@onready var _panel: PanelContainer = %Panel
@onready var _panel_scroll: ScrollContainer = %PanelScroll
@onready var _panel_margin: MarginContainer = %Margin
@onready var _safe_margin: MarginContainer = %SafeMargin
@onready var _moneybot_companion: TextureRect = %MoneybotCompanion
@onready var _moneybot_icon: TextureRect = %MoneybotIcon
@onready var _title_label: Label = %TitleLabel
@onready var _budget_label: Label = %BudgetLabel
@onready var _chips: FlowContainer = %Chips
@onready var _confirm_button: Button = %ConfirmButton
@onready var _recovery_box: VBoxContainer = %RecoveryBox
@onready var _recovery_label: Label = %RecoveryLabel
@onready var _silence_button: Button = %SilenceButton
@onready var _pity_button: Button = %PityButton
@onready var _sponsor_button: Button = %SponsorButton
@onready var _phrase_button_template: Button = %PhraseButtonTemplate


func _ready() -> void:
	_update_panel_width()
	_confirm_button.pressed.connect(_on_confirm)
	_silence_button.pressed.connect(_on_silence)
	_pity_button.pressed.connect(_on_pity)
	_sponsor_button.pressed.connect(_on_sponsor)
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_panel_width()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key_event := event as InputEventKey
	if (
		key_event != null
		and key_event.pressed
		and not key_event.echo
		and (
			key_event.keycode == KEY_SPACE
			or key_event.physical_keycode == KEY_SPACE
		)
	):
		# Phrase chips receive focus for keyboard navigation, but Space is also
		# Dialogic's advance key. Swallow it before BaseButton can toggle a chip.
		get_viewport().set_input_as_handled()


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

	_title_label.text = _speaker.to_upper()
	_title_label.visible = not _speaker.is_empty()
	_budget_label.text = "AVAILABLE: $%d" % _budget
	for child: Node in _chips.get_children():
		child.queue_free()
	_phrase_buttons.clear()

	for segment_index: int in _segments.size():
		var segment: Variant = _segments[segment_index]
		if not segment is Dictionary:
			continue
		if String(segment.get("type", "phrase")) == "fixed":
			var fixed_text := String(segment.get("text", ""))
			if fixed_text.is_empty():
				continue
			var fixed_word := Label.new()
			fixed_word.text = fixed_text
			fixed_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fixed_word.add_theme_color_override("font_color", FIXED_WORD_COLOR)
			fixed_word.add_theme_font_override("font", FIXED_WORD_FONT)
			fixed_word.add_theme_font_size_override("font_size", 29)
			fixed_word.add_theme_constant_override("outline_size", 0)
			_chips.add_child(fixed_word)
			continue
		if String(segment.get("type", "phrase")) != "phrase":
			continue
		var chip: Button = _phrase_button_template.duplicate() as Button
		chip.visible = true
		chip.text = String(segment.get("text", ""))
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
	_pity_button.text = '"%s"  /  $0' % _pity_text
	_pity_button.tooltip_text = 'Deliver the one free pity word: "%s".' % _pity_text
	_sponsor_button.tooltip_text = "Read the sponsor message for +$3, at a score cost."
	_recovery_label.text = _recovery_description()
	_recompute()
	_focus_initial_control(is_out_of_budget)
	call_deferred("_position_companion")


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
	var over_budget := cost > _budget
	var kept_text := _assemble()
	_confirm_button.disabled = over_budget
	if over_budget:
		_confirm_button.text = "Cut $%d more  /  $%d" % [cost - _budget, cost]
	elif kept_text.is_empty():
		_confirm_button.text = "Say nothing  /  $0"
	else:
		_confirm_button.text = "Say it  /  $%d" % cost
	_refresh_chip_presentation()

func _refresh_chip_presentation() -> void:
	for chip: Button in _phrase_buttons:
		var segment_index := int(chip.get_meta("segment_index", -1))
		if segment_index < 0 or segment_index >= _segments.size():
			continue
		var segment: Dictionary = _segments[segment_index]
		var phrase_text := String(segment.get("text", ""))
		var phrase_cost := _segment_cost(segment)
		if chip.disabled:
			chip.text = phrase_text
			chip.tooltip_text = "Your budget is empty."
		elif chip.button_pressed:
			chip.text = phrase_text
			chip.tooltip_text = (
				"%s costs $%d. Click to cut."
				% [phrase_text, phrase_cost]
			)
		else:
			chip.text = phrase_text
			chip.tooltip_text = (
				'Cut: "%s" will be omitted, saving $%d. Click to restore it.'
				% [phrase_text, phrase_cost]
			)


func _focus_initial_control(is_out_of_budget: bool) -> void:
	var focus_target: Control
	if is_out_of_budget:
		focus_target = _silence_button
	elif not _phrase_buttons.is_empty():
		focus_target = _phrase_buttons.front()
	else:
		focus_target = _confirm_button
	focus_target.grab_focus()
	_panel_scroll.call_deferred("ensure_control_visible", focus_target)


func _update_panel_width() -> void:
	var available_width := maxf(size.x - HORIZONTAL_GUTTER, MIN_PANEL_WIDTH)
	_panel.custom_minimum_size.x = minf(available_width, MAX_PANEL_WIDTH)
	var show_companion := (
		size.x >= MONEYBOT_COMPANION_MIN_WIDTH
		and size.y >= MONEYBOT_COMPANION_MIN_HEIGHT
	)
	_moneybot_companion.visible = show_companion
	_moneybot_icon.visible = not show_companion
	_panel_margin.add_theme_constant_override(
		"margin_right",
		COMPANION_CONTENT_MARGIN_RIGHT if show_companion else PANEL_CONTENT_MARGIN_RIGHT,
	)
	_safe_margin.add_theme_constant_override(
		"margin_right",
		COMPANION_SAFE_MARGIN_RIGHT if show_companion else COMPACT_SAFE_MARGIN,
	)
	call_deferred("_position_companion")


func _position_companion() -> void:
	if not _moneybot_companion.visible or not is_instance_valid(_panel):
		return
	var panel_rect := _panel.get_global_rect()
	_moneybot_companion.size = COMPANION_SIZE
	_moneybot_companion.global_position = Vector2(
		panel_rect.end.x - COMPANION_PANEL_OVERLAP,
		panel_rect.get_center().y - COMPANION_SIZE.y * 0.5,
	)


func _recovery_description() -> String:
	var choices := PackedStringArray(["stay silent"])
	if _can_use_pity:
		choices.append("use your one pity grunt")
	if _can_use_sponsor:
		choices.append("read a sponsor message for $3")
	return "No budget. %s." % ", ".join(choices)


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
