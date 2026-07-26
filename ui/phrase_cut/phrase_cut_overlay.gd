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
const COMPANION_EDGE_PADDING := 4.0
const COMPANION_CURSOR_RADIUS_X := 260.0
const COMPANION_CURSOR_RADIUS_Y := 225.0
const COMPANION_FOLLOW_SPEED := 7.0
const COMPANION_RETURN_SPEED := 4.5
const COMPANION_RETURN_DELAY := 0.3
const COMPANION_HOVER_AMPLITUDE := 6.0
const COMPANION_HOVER_FREQUENCY := 1.15
const COMPANION_MAX_TILT := 0.0872665
const COMPANION_TILT_PER_SPEED := 0.00016
const COMPANION_TILT_SPRING := 46.0
const COMPANION_TILT_DAMPING := 7.0
const STORY_FRAME_SIZE := Vector2(1152.0, 648.0)

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
var _companion_target_position := Vector2.ZERO
var _companion_follow_position := Vector2.ZERO
var _has_companion_target := false
var _companion_angular_velocity := 0.0
var _companion_hover_time := 0.0
var _companion_return_delay_remaining := 0.0

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


func _process(delta: float) -> void:
	if not _moneybot_companion.visible:
		return
	var cursor_position := get_global_mouse_position()
	if not _has_companion_target:
		_companion_follow_position = _companion_home_position()
		_moneybot_companion.global_position = _companion_follow_position
		_has_companion_target = true
	var is_over_word := _cursor_is_over_word(cursor_position)
	var movement_speed := COMPANION_FOLLOW_SPEED
	if is_over_word:
		_companion_return_delay_remaining = COMPANION_RETURN_DELAY
		_companion_target_position = _companion_target_for_cursor(
			cursor_position,
			_companion_follow_position,
		)
	elif _companion_return_delay_remaining > 0.0:
		_companion_return_delay_remaining = maxf(
			0.0,
			_companion_return_delay_remaining - delta,
		)
		_companion_target_position = _companion_follow_position
	else:
		movement_speed = COMPANION_RETURN_SPEED
		_companion_target_position = _companion_home_position()
	var follow_weight := 1.0 - exp(-movement_speed * delta)
	var previous_follow_position := _companion_follow_position
	_companion_follow_position = _clamped_companion_position(
		_companion_follow_position.lerp(
			_companion_target_position,
			follow_weight,
		),
	)
	_companion_hover_time += delta
	_moneybot_companion.global_position = _clamped_companion_position(
		_companion_follow_position + _companion_hover_offset_at(_companion_hover_time),
	)
	var safe_delta := maxf(delta, 0.001)
	var velocity := (
		(_companion_follow_position - previous_follow_position)
		/ safe_delta
	)
	var target_tilt := clampf(
		velocity.x * COMPANION_TILT_PER_SPEED,
		-COMPANION_MAX_TILT,
		COMPANION_MAX_TILT,
	)
	var spring_delta := minf(delta, 0.05)
	var angular_acceleration := (
		(target_tilt - _moneybot_companion.rotation) * COMPANION_TILT_SPRING
		- _companion_angular_velocity * COMPANION_TILT_DAMPING
	)
	_companion_angular_velocity += angular_acceleration * spring_delta
	_moneybot_companion.rotation = clampf(
		_moneybot_companion.rotation + _companion_angular_velocity * spring_delta,
		-COMPANION_MAX_TILT * 1.35,
		COMPANION_MAX_TILT * 1.35,
	)


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

	_title_label.text = "User: %s" % _speaker
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
	var frame := _story_frame_rect()
	_safe_margin.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_safe_margin.position = frame.position
	_safe_margin.size = frame.size
	var available_width := maxf(frame.size.x - HORIZONTAL_GUTTER, MIN_PANEL_WIDTH)
	_panel.custom_minimum_size.x = minf(available_width, MAX_PANEL_WIDTH)
	var show_companion := (
		frame.size.x >= MONEYBOT_COMPANION_MIN_WIDTH
		and frame.size.y >= MONEYBOT_COMPANION_MIN_HEIGHT
	)
	_moneybot_companion.visible = show_companion
	_moneybot_icon.visible = not show_companion
	if not show_companion:
		_has_companion_target = false
		_companion_angular_velocity = 0.0
		_companion_hover_time = 0.0
		_companion_return_delay_remaining = 0.0
		_moneybot_companion.rotation = 0.0
	_panel_margin.add_theme_constant_override(
		"margin_right",
		COMPANION_CONTENT_MARGIN_RIGHT if show_companion else PANEL_CONTENT_MARGIN_RIGHT,
	)
	_safe_margin.add_theme_constant_override(
		"margin_right",
		COMPANION_SAFE_MARGIN_RIGHT if show_companion else COMPACT_SAFE_MARGIN,
	)
	call_deferred("_position_companion")


func _story_frame_rect() -> Rect2:
	var frame_scale := minf(size.x / STORY_FRAME_SIZE.x, size.y / STORY_FRAME_SIZE.y)
	var frame_size := STORY_FRAME_SIZE * frame_scale
	return Rect2((size - frame_size) * 0.5, frame_size)


func _position_companion() -> void:
	if not _moneybot_companion.visible or not is_instance_valid(_panel):
		return
	_moneybot_companion.size = COMPANION_SIZE
	_moneybot_companion.pivot_offset = COMPANION_SIZE * 0.5
	var companion_modulate := _moneybot_companion.self_modulate
	companion_modulate.a = 1.0
	_moneybot_companion.self_modulate = companion_modulate
	if not _has_companion_target:
		_companion_follow_position = _companion_home_position()
		_moneybot_companion.global_position = _companion_follow_position
		_has_companion_target = true
	_companion_target_position = _companion_home_position()


func _companion_home_position() -> Vector2:
	var panel_rect := _panel.get_global_rect()
	return _clamped_companion_position(
		Vector2(
			panel_rect.end.x - COMPANION_PANEL_OVERLAP,
			panel_rect.get_center().y - COMPANION_SIZE.y * 0.5,
		),
	)


func _cursor_is_over_word(cursor_position: Vector2) -> bool:
	for child: Node in _chips.get_children():
		var word := child as Control
		if (
			word != null
			and word.visible
			and word.is_visible_in_tree()
			and word.get_global_rect().has_point(cursor_position)
		):
			return true
	return false


func _companion_target_for_cursor(
	cursor_position: Vector2,
	current_position: Vector2,
) -> Vector2:
	var current_center := current_position + COMPANION_SIZE * 0.5
	var away_from_cursor := current_center - cursor_position
	var target_offset := Vector2(COMPANION_CURSOR_RADIUS_X, 0.0)
	if not away_from_cursor.is_zero_approx():
		var ellipse_distance := Vector2(
			away_from_cursor.x / COMPANION_CURSOR_RADIUS_X,
			away_from_cursor.y / COMPANION_CURSOR_RADIUS_Y,
		).length()
		target_offset = away_from_cursor / ellipse_distance
	var target_center := cursor_position + target_offset
	return _clamped_companion_position(target_center - COMPANION_SIZE * 0.5)


func _companion_hover_offset_at(hover_time: float) -> Vector2:
	var hover_phase := hover_time * TAU * COMPANION_HOVER_FREQUENCY
	var primary_bob := sin(hover_phase) * COMPANION_HOVER_AMPLITUDE
	var secondary_bob := sin(hover_phase * 2.0 + 0.7) * COMPANION_HOVER_AMPLITUDE * 0.2
	return Vector2(0.0, primary_bob + secondary_bob)


func _clamped_companion_position(desired_position: Vector2) -> Vector2:
	var frame := _story_frame_rect()
	var movement_bounds := Rect2(
		get_global_rect().position + frame.position + Vector2.ONE * COMPANION_EDGE_PADDING,
		frame.size - Vector2.ONE * COMPANION_EDGE_PADDING * 2.0,
	)
	return _clamp_companion_to_bounds(desired_position, movement_bounds)


func _clamp_companion_to_bounds(companion_position: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(
		clampf(
			companion_position.x,
			bounds.position.x,
			maxf(bounds.position.x, bounds.end.x - COMPANION_SIZE.x),
		),
		clampf(
			companion_position.y,
			bounds.position.y,
			maxf(bounds.position.y, bounds.end.y - COMPANION_SIZE.y),
		),
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
