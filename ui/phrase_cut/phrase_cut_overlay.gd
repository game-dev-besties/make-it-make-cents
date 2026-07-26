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
const PHRASE_TEXT_FORMATTER := preload("res://ui/phrase_cut/phrase_text_formatter.gd")
const TUTORIAL_STATE_KEY := &"phrase_cut_tutorial_seen"

const MAX_PANEL_WIDTH := 780.0
const MIN_PANEL_WIDTH := 220.0
const MIN_PHRASE_BUTTON_HEIGHT := 46.0
const HORIZONTAL_GUTTER := 48.0
const MONEYBOT_COMPANION_MIN_WIDTH := 1080.0
const MONEYBOT_COMPANION_MIN_HEIGHT := 540.0
const COMPACT_SAFE_MARGIN := 16
const COMPANION_SAFE_MARGIN_RIGHT := 150
const PANEL_CONTENT_MARGIN_RIGHT := 38
const COMPANION_CONTENT_MARGIN_RIGHT := 38
const COMPANION_HOME_GAP := 8.0
const COMPANION_SIZE := Vector2(228.0, 273.0)
const COMPANION_BODY_OFFSET := Vector2(0.0, 136.5)
const COMPANION_BODY_SIZE := Vector2(228.0, 136.5)
const COMPANION_EDGE_PADDING := 4.0
const COMPANION_CURSOR_RADIUS_X := 185.0
const COMPANION_CURSOR_RADIUS_Y := 160.0
const COMPANION_CURSOR_OFFSET := Vector2(130.0, 105.0)
const COMPANION_OBSTACLE_PADDING := 12.0
const COMPANION_OVERLAP_ALPHA := 1.0
const COMPANION_ALPHA_SPEED := 12.0
const COMPANION_PANEL_EXIT_BUFFER := 16.0
const COMPANION_WORD_RECOIL_CLEARANCE := 30.0
const COMPANION_MIN_LUNGE_TRAVEL := 36.0
const COMPANION_FOLLOW_SPRING := 68.0
const COMPANION_FOLLOW_DAMPING := 13.5
const COMPANION_RETURN_SPRING := 34.0
const COMPANION_RETURN_DAMPING := 11.0
const COMPANION_RETURN_DELAY := 0.22
const COMPANION_HOVER_AMPLITUDE := 6.0
const COMPANION_HOVER_FREQUENCY := 1.15
const COMPANION_ACTIVE_SCALE := 0.5
const COMPANION_SCALE_SPEED := 11.0
const COMPANION_PULSE_AMOUNT := 0.012
const COMPANION_PULSE_FREQUENCY := 0.72
const TUTORIAL_COMPANION_SCALE := 0.58
const TUTORIAL_FLIGHT_TIME := 0.55
const TUTORIAL_BUBBLE_GAP := 14.0
const COMPANION_MAX_TILT := 0.0872665
const COMPANION_TILT_PER_SPEED := 0.00016
const COMPANION_TILT_SPRING := 46.0
const COMPANION_TILT_DAMPING := 7.0
const COMPANION_IMPACT_OVERLAP := 36.0
const COMPANION_PEAK_ALIGN_TIME := 0.08
const COMPANION_LUNGE_TIME := 0.13
const COMPANION_RECOIL_TIME := 0.22
const COMPANION_PEAK_HOLD_TIME := 0.07
const STORY_FRAME_SIZE := Vector2(1152.0, 648.0)

const FIXED_WORD_FONT := preload("res://ui/theme/fonts/DepartureMono-Regular.ttf")
const FIXED_WORD_COLOR := Color(1.0, 0.964706, 0.898039, 1)
const PHRASE_TEXT_OUTLINE_COLOR := Color(0.258824, 0.243137, 0.266667, 1)
const PHRASE_TEXT_OUTLINE_SIZE := 4

enum TutorialStep {
	NONE,
	BUDGET,
	WORD,
	SUBMIT,
}

## Kept for callers that prefer to inspect the result after awaiting `resolved`.
## The typed signal above is the public contract.
var result: Dictionary = {}

var _segments: Array = []
var _budget := 0
var _speaker := ""
var _can_use_pity := false
var _can_use_sponsor := false
var _required_delivery := &""
var _pity_text := DEFAULT_PITY_TEXT
var _sponsor_text := DEFAULT_SPONSOR_TEXT
var _phrase_buttons: Array[Button] = []
var _is_resolved := false
var _companion_target_position := Vector2.ZERO
var _companion_follow_position := Vector2.ZERO
var _companion_follow_velocity := Vector2.ZERO
var _has_companion_target := false
var _companion_angular_velocity := 0.0
var _companion_hover_time := 0.0
var _companion_visual_scale := 1.0
var _companion_visual_alpha := 1.0
var _companion_cursor_active := false
var _companion_return_delay_remaining := 0.0
var _companion_velocity_sample_position := Vector2.ZERO
var _is_companion_acting := false
var _companion_action_tween: Tween
var _pending_action_chip: Button
var _tutorial_requested := false
var _tutorial_step := TutorialStep.NONE
var _tutorial_target_chip: Button
var _tutorial_waiting_for_word_action := false
var _tutorial_move_tween: Tween

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
@onready var _tutorial_click_catcher: Button = %TutorialClickCatcher
@onready var _tutorial_bubble: PanelContainer = %TutorialBubble
@onready var _tutorial_label: Label = %TutorialLabel
@onready var _tutorial_hint_label: Label = %TutorialHintLabel
@onready var _tutorial_tail_outline: Polygon2D = %TutorialTailOutline
@onready var _tutorial_tail_fill: Polygon2D = %TutorialTailFill


func _ready() -> void:
	_update_panel_width()
	_confirm_button.pressed.connect(_on_confirm)
	_silence_button.pressed.connect(_on_silence)
	_pity_button.pressed.connect(_on_pity)
	_sponsor_button.pressed.connect(_on_sponsor)
	_tutorial_click_catcher.pressed.connect(_on_tutorial_continue)
	_rebuild()


func _process(delta: float) -> void:
	if not _moneybot_companion.visible:
		return
	var cursor_position := get_global_mouse_position()
	if not _has_companion_target:
		_companion_follow_position = _companion_home_position()
		_moneybot_companion.global_position = _companion_follow_position
		_companion_velocity_sample_position = _companion_follow_position
		_companion_follow_velocity = Vector2.ZERO
		_has_companion_target = true
	var tutorial_active := _tutorial_step != TutorialStep.NONE
	var cursor_is_active := (
		false
		if tutorial_active
		else _update_companion_cursor_active(cursor_position)
	)
	if not _is_companion_acting and not tutorial_active:
		var follow_spring := COMPANION_FOLLOW_SPRING
		var follow_damping := COMPANION_FOLLOW_DAMPING
		if cursor_is_active:
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
			follow_spring = COMPANION_RETURN_SPRING
			follow_damping = COMPANION_RETURN_DAMPING
			_companion_target_position = _companion_home_position()
		var motion_delta := minf(delta, 1.0 / 30.0)
		var follow_acceleration := (
			(_companion_target_position - _companion_follow_position) * follow_spring
			- _companion_follow_velocity * follow_damping
		)
		_companion_follow_velocity += follow_acceleration * motion_delta
		_companion_follow_position += _companion_follow_velocity * motion_delta
		var unclamped_position := _companion_follow_position
		_companion_follow_position = _clamped_companion_position(
			unclamped_position,
			_companion_visual_scale,
		)
		if not _companion_follow_position.is_equal_approx(unclamped_position):
			_companion_follow_velocity *= 0.35
	else:
		_companion_follow_velocity = Vector2.ZERO
	_companion_hover_time += delta
	var companion_is_engaged := (
		cursor_is_active
		or _companion_return_delay_remaining > 0.0
		or _is_companion_acting
		or tutorial_active
	)
	var target_visual_scale := (
		TUTORIAL_COMPANION_SCALE
		if tutorial_active
		else (
			COMPANION_ACTIVE_SCALE
			if companion_is_engaged
			else 1.0
		)
	)
	_companion_visual_scale = lerpf(
		_companion_visual_scale,
		target_visual_scale,
		1.0 - exp(-COMPANION_SCALE_SPEED * delta),
	)
	_moneybot_companion.scale = (
		_companion_pulse_scale_at(_companion_hover_time)
		* _companion_visual_scale
	)
	_moneybot_companion.global_position = _clamped_companion_position(
		_companion_follow_position + _companion_hover_offset_at(_companion_hover_time),
		_companion_visual_scale,
	)
	var target_alpha := 1.0
	if (
		companion_is_engaged
		and _companion_obstacle_overlap_area(
			_companion_follow_position,
			_companion_visual_scale,
		) > 0.0
	):
		target_alpha = COMPANION_OVERLAP_ALPHA
	_companion_visual_alpha = lerpf(
		_companion_visual_alpha,
		target_alpha,
		1.0 - exp(-COMPANION_ALPHA_SPEED * delta),
	)
	var companion_modulate := _moneybot_companion.self_modulate
	companion_modulate.a = _companion_visual_alpha
	_moneybot_companion.self_modulate = companion_modulate
	var safe_delta := maxf(delta, 0.001)
	var velocity := (
		(_companion_follow_position - _companion_velocity_sample_position)
		/ safe_delta
	)
	_companion_velocity_sample_position = _companion_follow_position
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
		if _tutorial_step != TutorialStep.NONE:
			call_deferred("_refresh_tutorial_layout")


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _tutorial_step == TutorialStep.BUDGET:
		var mouse_event := event as InputEventMouseButton
		if (
			mouse_event != null
			and mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
		):
			_on_tutorial_continue()
			get_viewport().set_input_as_handled()
			return
		var touch_event := event as InputEventScreenTouch
		if touch_event != null and touch_event.pressed:
			_on_tutorial_continue()
			get_viewport().set_input_as_handled()
			return
	if _tutorial_step == TutorialStep.SUBMIT:
		var dismiss_mouse_event := event as InputEventMouseButton
		var dismiss_touch_event := event as InputEventScreenTouch
		if (
			(
				dismiss_mouse_event != null
				and dismiss_mouse_event.pressed
				and dismiss_mouse_event.button_index == MOUSE_BUTTON_LEFT
			)
			or (
				dismiss_touch_event != null
				and dismiss_touch_event.pressed
			)
		):
			# Defer so a click on an actual modal control can still perform that
			# control's action while also dismissing the coachmark.
			call_deferred("_finish_tutorial")
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
	_required_delivery = StringName(recovery.get("required_delivery", ""))
	if _required_delivery not in [
		&"",
		DELIVERY_NORMAL,
		DELIVERY_SILENCE,
		DELIVERY_PITY,
		DELIVERY_SPONSOR,
	]:
		_required_delivery = &""
	_pity_text = String(recovery.get("pity_text", DEFAULT_PITY_TEXT))
	_sponsor_text = String(recovery.get("sponsor_text", DEFAULT_SPONSOR_TEXT))
	_tutorial_requested = bool(recovery.get("show_tutorial", false))
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
			fixed_word.add_theme_color_override(
				"font_outline_color",
				PHRASE_TEXT_OUTLINE_COLOR,
			)
			fixed_word.add_theme_font_override("font", FIXED_WORD_FONT)
			fixed_word.add_theme_font_size_override("font_size", 29)
			fixed_word.add_theme_constant_override(
				"outline_size",
				PHRASE_TEXT_OUTLINE_SIZE,
			)
			fixed_word.set_meta("segment_index", segment_index)
			_chips.add_child(fixed_word)
			continue
		if String(segment.get("type", "phrase")) != "phrase":
			continue
		var chip: Button = _phrase_button_template.duplicate() as Button
		chip.visible = true
		chip.text = String(segment.get("text", ""))
		chip.button_pressed = true
		chip.set_meta("segment_index", segment_index)
		chip.toggled.connect(_on_chip_toggled.bind(chip))
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
		if not _delivery_is_allowed(DELIVERY_NORMAL):
			chip.set_pressed_no_signal(false)
			chip.disabled = true
	_pity_button.visible = _can_use_pity
	_sponsor_button.visible = _can_use_sponsor
	_silence_button.disabled = not _delivery_is_allowed(DELIVERY_SILENCE)
	_pity_button.disabled = not _delivery_is_allowed(DELIVERY_PITY)
	_sponsor_button.disabled = not _delivery_is_allowed(DELIVERY_SPONSOR)
	_pity_button.text = '"%s"  /  $0' % _pity_text
	_pity_button.tooltip_text = 'Deliver the free grunt: "%s".' % _pity_text
	_sponsor_button.tooltip_text = "Read the sponsor message for +$3, at a score cost."
	_recovery_label.visible = is_out_of_budget
	_recovery_label.text = (
		"Only the sponsor response can continue."
		if _required_delivery == DELIVERY_SPONSOR
		else "No budget — choose a fallback."
	)
	_recompute()
	_focus_initial_control(is_out_of_budget)
	call_deferred("_position_companion")
	call_deferred("_maybe_start_tutorial")


func _on_chip_toggled(pressed: bool, chip: Button) -> void:
	_recompute()
	if _tutorial_step == TutorialStep.WORD and not pressed:
		_tutorial_waiting_for_word_action = true
		_tutorial_bubble.hide()
	_play_chip_action(chip, not pressed)
	if _tutorial_waiting_for_word_action and not _moneybot_companion.visible:
		_show_tutorial_submit()


func _play_chip_action(chip: Button, is_cut: bool) -> void:
	if not is_instance_valid(chip):
		return
	if is_instance_valid(_companion_action_tween):
		_companion_action_tween.kill()
		if is_instance_valid(_pending_action_chip):
			_play_prepared_chip_strike(_pending_action_chip)
		_companion_action_tween = null
		_pending_action_chip = null
		_is_companion_acting = false
	var word_rect := chip.get_global_rect()
	var word_center := word_rect.get_center()
	var start_position := _companion_follow_position
	var recoil_peak_position := _closest_recoil_peak(word_rect, start_position)
	var recoil_body_center := _companion_body_rect(
		recoil_peak_position,
	).get_center()
	var travel_direction := recoil_body_center.direction_to(word_center)
	if travel_direction.is_zero_approx():
		travel_direction = Vector2.LEFT
	var left_to_right := travel_direction.x >= 0.0
	chip.call("prepare_strike_animation", is_cut, left_to_right)
	chip.set_meta(&"strike_is_cut", is_cut)

	if not _moneybot_companion.visible:
		_play_prepared_chip_strike(chip)
		_spawn_impact_sparks(
			_word_impact_point(word_rect, travel_direction),
			travel_direction,
		)
		return

	_is_companion_acting = true
	_pending_action_chip = chip
	var impact_position := _companion_impact_position(word_rect, travel_direction)
	var impact_point := _word_impact_point(word_rect, travel_direction)

	_companion_action_tween = create_tween()
	_companion_action_tween.tween_method(
		_set_companion_follow_position,
		start_position,
		recoil_peak_position,
		COMPANION_PEAK_ALIGN_TIME,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_companion_action_tween.tween_method(
		_set_companion_follow_position,
		recoil_peak_position,
		impact_position,
		COMPANION_LUNGE_TIME,
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_companion_action_tween.tween_callback(
		_on_chip_impact.bind(chip, impact_point, travel_direction),
	)
	_companion_action_tween.tween_method(
		_set_companion_follow_position,
		impact_position,
		recoil_peak_position,
		COMPANION_RECOIL_TIME,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_companion_action_tween.tween_interval(COMPANION_PEAK_HOLD_TIME)
	_companion_action_tween.tween_callback(_finish_companion_action)


func _set_companion_follow_position(companion_position: Vector2) -> void:
	_companion_follow_position = companion_position


func _companion_impact_position(word_rect: Rect2, travel_direction: Vector2) -> Vector2:
	var scaled_body_size := COMPANION_BODY_SIZE * COMPANION_ACTIVE_SCALE
	var expanded_half_size := (
		word_rect.size * 0.5
		+ scaled_body_size * 0.5
		- Vector2.ONE * COMPANION_IMPACT_OVERLAP * COMPANION_ACTIVE_SCALE
	)
	var distance_x := (
		INF
		if is_zero_approx(travel_direction.x)
		else expanded_half_size.x / absf(travel_direction.x)
	)
	var distance_y := (
		INF
		if is_zero_approx(travel_direction.y)
		else expanded_half_size.y / absf(travel_direction.y)
	)
	var impact_body_center := (
		word_rect.get_center()
		- travel_direction * minf(distance_x, distance_y)
	)
	return _clamped_companion_position(
		impact_body_center - _companion_body_center_offset(COMPANION_ACTIVE_SCALE),
		COMPANION_ACTIVE_SCALE,
	)


func _companion_body_center_offset(visual_scale: float) -> Vector2:
	var pivot := COMPANION_SIZE * 0.5
	var unscaled_body_center := COMPANION_BODY_OFFSET + COMPANION_BODY_SIZE * 0.5
	return pivot + (unscaled_body_center - pivot) * visual_scale


func _companion_body_rect(
	companion_position: Vector2,
	visual_scale: float = COMPANION_ACTIVE_SCALE,
) -> Rect2:
	var pivot := COMPANION_SIZE * 0.5
	var visual_body_origin := (
		companion_position
		+ pivot
		+ (COMPANION_BODY_OFFSET - pivot) * visual_scale
	)
	return Rect2(
		visual_body_origin,
		COMPANION_BODY_SIZE * visual_scale,
	)


func _closest_recoil_peak(word_rect: Rect2, current_position: Vector2) -> Vector2:
	var recoil_radii := _word_recoil_radii(word_rect)
	var word_center := word_rect.get_center()
	var current_center := current_position + COMPANION_SIZE * 0.5
	var preferred_direction := word_center.direction_to(current_center)
	if preferred_direction.is_zero_approx():
		preferred_direction = Vector2.RIGHT

	var best_position := _clamped_companion_position(
		word_center
		+ _ellipse_offset(preferred_direction, recoil_radii)
		- COMPANION_SIZE * 0.5,
		COMPANION_ACTIVE_SCALE,
	)
	var best_distance := INF
	var fallback_position := best_position
	var fallback_attack_travel := 0.0
	for sample_index: int in 33:
		var recoil_direction := (
			preferred_direction
			if sample_index == 0
			else Vector2.RIGHT.rotated(TAU * float(sample_index - 1) / 32.0)
		)
		var target_center := (
			word_center
			+ _ellipse_offset(recoil_direction, recoil_radii)
		)
		var candidate := _clamped_companion_position(
			target_center - COMPANION_SIZE * 0.5,
			COMPANION_ACTIVE_SCALE,
		)
		var candidate_center := candidate + COMPANION_SIZE * 0.5
		var distance_to_current := candidate.distance_to(current_position)
		var achieved_radius := Vector2(
			(candidate_center.x - word_center.x) / recoil_radii.x,
			(candidate_center.y - word_center.y) / recoil_radii.y,
		).length()
		var candidate_body_center := _companion_body_rect(candidate).get_center()
		var attack_direction := candidate_body_center.direction_to(word_center)
		if attack_direction.is_zero_approx():
			attack_direction = Vector2.LEFT
		var candidate_impact := _companion_impact_position(word_rect, attack_direction)
		var attack_travel := candidate.distance_to(candidate_impact)
		if attack_travel > fallback_attack_travel:
			fallback_attack_travel = attack_travel
			fallback_position = candidate
		if (
			achieved_radius >= 0.8
			and attack_travel >= COMPANION_MIN_LUNGE_TRAVEL
			and distance_to_current < best_distance
		):
			best_distance = distance_to_current
			best_position = candidate
	return fallback_position if is_inf(best_distance) else best_position


func _word_recoil_radii(word_rect: Rect2) -> Vector2:
	return Vector2(
		maxf(
			COMPANION_CURSOR_RADIUS_X,
			word_rect.size.x * 0.5
			+ COMPANION_SIZE.x * COMPANION_ACTIVE_SCALE * 0.5
			+ COMPANION_WORD_RECOIL_CLEARANCE,
		),
		maxf(
			COMPANION_CURSOR_RADIUS_Y,
			word_rect.size.y * 0.5
			+ COMPANION_SIZE.y * COMPANION_ACTIVE_SCALE * 0.5
			+ COMPANION_WORD_RECOIL_CLEARANCE,
		),
	)


func _word_impact_point(word_rect: Rect2, travel_direction: Vector2) -> Vector2:
	var half_size := word_rect.size * 0.5
	var distance_x := (
		INF
		if is_zero_approx(travel_direction.x)
		else half_size.x / absf(travel_direction.x)
	)
	var distance_y := (
		INF
		if is_zero_approx(travel_direction.y)
		else half_size.y / absf(travel_direction.y)
	)
	return word_rect.get_center() - travel_direction * minf(distance_x, distance_y)


func _on_chip_impact(
	chip: Button,
	impact_point: Vector2,
	travel_direction: Vector2,
) -> void:
	if is_instance_valid(chip):
		_play_prepared_chip_strike(chip)
	if chip == _pending_action_chip:
		_pending_action_chip = null
	_spawn_impact_sparks(impact_point, travel_direction)


func _play_prepared_chip_strike(chip: Button) -> void:
	chip.call("play_prepared_strike")
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.call("play_word_action", bool(chip.get_meta(&"strike_is_cut", true)))


func _spawn_impact_sparks(impact_point: Vector2, travel_direction: Vector2) -> void:
	var spark_directions: Array[Vector2] = [
		-travel_direction.rotated(-0.9),
		-travel_direction.rotated(-0.45),
		-travel_direction,
		-travel_direction.rotated(0.45),
		-travel_direction.rotated(0.9),
	]
	var spark_sizes: Array[float] = [8.0, 10.0, 12.0, 10.0, 8.0]
	var spark_colors: Array[Color] = [
		Color(1.0, 0.72549, 0.411765, 1.0),
		Color(0.992157, 0.584314, 0.352941, 1.0),
		Color(1.0, 0.839216, 0.568627, 1.0),
		Color(0.992157, 0.584314, 0.352941, 1.0),
		Color(1.0, 0.72549, 0.411765, 1.0),
	]
	for spark_index: int in spark_directions.size():
		var spark := ColorRect.new()
		spark.z_index = 6
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.color = spark_colors[spark_index]
		spark.size = Vector2.ONE * spark_sizes[spark_index]
		spark.pivot_offset = spark.size * 0.5
		spark.rotation = deg_to_rad(45.0)
		spark.scale = Vector2.ONE * 0.6
		add_child(spark)
		spark.global_position = impact_point - spark.size * 0.5
		var spark_distance := 38.0 + float(2 - absi(spark_index - 2)) * 8.0
		var spark_duration := 0.24
		var spark_tween := create_tween()
		spark_tween.tween_property(
			spark,
			"global_position",
			spark.global_position + spark_directions[spark_index] * spark_distance,
			spark_duration,
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var transparent := spark.modulate
		transparent.a = 0.0
		spark_tween.parallel().tween_property(
			spark,
			"modulate",
			transparent,
			spark_duration,
		)
		spark_tween.parallel().tween_property(
			spark,
			"scale",
			Vector2.ONE * 1.35,
			spark_duration,
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		spark_tween.parallel().tween_property(
			spark,
			"rotation",
			spark.rotation + deg_to_rad(90.0),
			spark_duration,
		)
		spark_tween.tween_callback(spark.queue_free)


func _finish_companion_action() -> void:
	_is_companion_acting = false
	_companion_follow_velocity = Vector2.ZERO
	_companion_action_tween = null
	_pending_action_chip = null
	if _tutorial_waiting_for_word_action:
		_show_tutorial_submit()


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
	return PHRASE_TEXT_FORMATTER.format_parts(parts)


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
	# Keep fallbacks in a stable location so editing the phrase does not make
	# the layout jump. Their low-emphasis styling keeps "Say it" primary.
	_recovery_box.visible = true
	_confirm_button.visible = (
		_budget > 0
		or (cost == 0 and not kept_text.is_empty())
	)
	var confirm_delivery := (
		DELIVERY_SILENCE
		if kept_text.is_empty()
		else DELIVERY_NORMAL
	)
	_confirm_button.disabled = (
		over_budget
		or not _delivery_is_allowed(confirm_delivery)
	)
	if over_budget:
		_confirm_button.text = "Cut $%d more  /  $%d" % [cost - _budget, cost]
	elif kept_text.is_empty():
		_confirm_button.text = "Say nothing  /  $0"
	else:
		_confirm_button.text = "Say it  /  $%d" % cost
	_refresh_chip_presentation()


func _has_cut_phrase() -> bool:
	for chip: Button in _phrase_buttons:
		if not chip.button_pressed:
			return true
	return false


func _refresh_chip_presentation() -> void:
	var formatted_texts := _formatted_segment_texts()
	for child: Node in _chips.get_children():
		var fixed_word := child as Label
		if fixed_word == null or not fixed_word.has_meta("segment_index"):
			continue
		var fixed_index := int(fixed_word.get_meta("segment_index", -1))
		if fixed_index < 0 or fixed_index >= _segments.size():
			continue
		var fixed_segment: Dictionary = _segments[fixed_index]
		fixed_word.text = String(
			formatted_texts.get(
				fixed_index,
				fixed_segment.get("text", ""),
			)
		)

	for chip: Button in _phrase_buttons:
		var segment_index := int(chip.get_meta("segment_index", -1))
		if segment_index < 0 or segment_index >= _segments.size():
			continue
		var segment: Dictionary = _segments[segment_index]
		var phrase_text := String(segment.get("text", ""))
		var display_text := String(formatted_texts.get(segment_index, phrase_text))
		var phrase_cost := _segment_cost(segment)
		if chip.disabled:
			chip.text = phrase_text
			chip.tooltip_text = "Your budget is empty."
		elif chip.button_pressed:
			chip.text = display_text
			chip.tooltip_text = (
				"%s costs $%d. Click to cut."
				% [display_text, phrase_cost]
			)
		else:
			chip.text = phrase_text
			chip.tooltip_text = (
				'Cut: "%s" will be omitted, saving $%d. Click to restore it.'
				% [phrase_text, phrase_cost]
			)
	_fit_phrase_buttons_to_row()
	_refresh_strike_connections()
	call_deferred("_refresh_strike_connections")


func _refresh_strike_connections() -> void:
	for chip: Button in _phrase_buttons:
		chip.call("clear_strike_connections")

	var children := _chips.get_children()
	if children.size() < 2:
		return
	for child_index: int in children.size() - 1:
		var left_word := children[child_index] as PhraseCutWord
		var right_word := children[child_index + 1] as PhraseCutWord
		if (
			left_word == null
			or right_word == null
			or left_word.button_pressed
			or right_word.button_pressed
			or not left_word.can_connect_strike()
			or not right_word.can_connect_strike()
		):
			continue
		var left_rect := left_word.get_global_rect()
		var right_rect := right_word.get_global_rect()
		if absf(left_rect.position.y - right_rect.position.y) > 1.5:
			continue
		var gap := maxf(0.0, right_rect.position.x - left_rect.end.x)
		var extension := gap * 0.5 + PhraseCutWord.STRIKE_EDGE_INSET
		left_word.set_strike_connection_right(extension)
		right_word.set_strike_connection_left(extension)


func _fit_phrase_buttons_to_row() -> void:
	var maximum_width := _phrase_button_row_width()
	if maximum_width <= 0.0:
		return
	for chip: Button in _phrase_buttons:
		chip.autowrap_mode = TextServer.AUTOWRAP_OFF
		chip.custom_minimum_size = Vector2(0.0, MIN_PHRASE_BUTTON_HEIGHT)
		if _natural_phrase_button_width(chip) <= maximum_width:
			continue
		chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chip.custom_minimum_size.x = maximum_width


func _phrase_button_row_width() -> float:
	var width := _panel.custom_minimum_size.x
	var panel_style := _panel.get_theme_stylebox("panel")
	if panel_style != null:
		width -= (
			panel_style.get_margin(SIDE_LEFT)
			+ panel_style.get_margin(SIDE_RIGHT)
		)
	width -= (
		_panel_margin.get_theme_constant("margin_left")
		+ _panel_margin.get_theme_constant("margin_right")
	)
	return maxf(1.0, width)


func _natural_phrase_button_width(chip: Button) -> float:
	var font := chip.get_theme_font("font")
	var font_size := chip.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		chip.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
	).x
	var style_name := "disabled" if chip.disabled else (
		"pressed" if chip.button_pressed else "normal"
	)
	var style := chip.get_theme_stylebox(style_name)
	var style_width := 0.0 if style == null else style.get_minimum_size().x
	return ceilf(text_width + style_width)


func _formatted_segment_texts() -> Dictionary:
	var segment_indices: Array[int] = []
	var parts := PackedStringArray()
	for segment_index: int in _segments.size():
		var segment: Variant = _segments[segment_index]
		if not segment is Dictionary:
			continue
		var segment_type := String(segment.get("type", "phrase"))
		if segment_type == "phrase":
			var chip := _chip_for_segment(segment_index)
			if chip == null or not chip.button_pressed:
				continue
		elif segment_type != "fixed":
			continue
		var text := String(segment.get("text", ""))
		if text.strip_edges().is_empty():
			continue
		segment_indices.append(segment_index)
		parts.append(text)

	var formatted_parts: PackedStringArray = PHRASE_TEXT_FORMATTER.format_part_labels(parts)
	var formatted_texts := {}
	for output_index: int in mini(segment_indices.size(), formatted_parts.size()):
		formatted_texts[segment_indices[output_index]] = formatted_parts[output_index]
	return formatted_texts


func _focus_initial_control(is_out_of_budget: bool) -> void:
	var focus_target: Control
	if (
		_required_delivery == DELIVERY_SPONSOR
		and _sponsor_button.visible
		and not _sponsor_button.disabled
	):
		focus_target = _sponsor_button
	elif (
		_required_delivery == DELIVERY_PITY
		and _pity_button.visible
		and not _pity_button.disabled
	):
		focus_target = _pity_button
	elif _required_delivery == DELIVERY_SILENCE:
		focus_target = _silence_button
	elif is_out_of_budget:
		focus_target = _silence_button
	elif not _phrase_buttons.is_empty():
		focus_target = _phrase_buttons.front()
	else:
		focus_target = _confirm_button
	focus_target.grab_focus()
	_panel_scroll.call_deferred("ensure_control_visible", focus_target)


func _maybe_start_tutorial() -> void:
	if (
		not _tutorial_requested
		or _tutorial_step != TutorialStep.NONE
		or _phrase_buttons.is_empty()
		or not is_visible_in_tree()
	):
		return
	_tutorial_requested = false
	_tutorial_target_chip = _first_tutorial_word()
	_tutorial_step = TutorialStep.BUDGET
	_tutorial_click_catcher.show()
	_update_panel_width()
	_position_companion()
	_fly_tutorial_companion(
		_tutorial_budget_position(),
		"This is your budget.",
		_budget_label,
		"Click anywhere to move on.",
	)


func _first_tutorial_word() -> Button:
	for chip: Button in _phrase_buttons:
		if not chip.disabled and chip.button_pressed:
			return chip
	return null


func _on_tutorial_continue() -> void:
	if _tutorial_step != TutorialStep.BUDGET:
		return
	_tutorial_click_catcher.hide()
	_tutorial_step = TutorialStep.WORD
	if not is_instance_valid(_tutorial_target_chip):
		_show_tutorial_submit()
		return
	_tutorial_target_chip.grab_focus()
	_panel_scroll.ensure_control_visible(_tutorial_target_chip)
	_fly_tutorial_companion(
		_tutorial_word_position(),
		"Click on a phrase.",
		_tutorial_target_chip,
	)


func _show_tutorial_submit() -> void:
	if _tutorial_step != TutorialStep.WORD:
		return
	_tutorial_waiting_for_word_action = false
	_tutorial_step = TutorialStep.SUBMIT
	_mark_tutorial_seen()
	_confirm_button.grab_focus()
	_panel_scroll.ensure_control_visible(_confirm_button)
	_fly_tutorial_companion(
		_tutorial_submit_position(),
		"Submit words here and pay!",
		_confirm_button,
	)


func _finish_tutorial() -> void:
	if _tutorial_step == TutorialStep.NONE:
		return
	if _tutorial_step == TutorialStep.SUBMIT:
		_mark_tutorial_seen()
	if is_instance_valid(_tutorial_move_tween):
		_tutorial_move_tween.kill()
	_tutorial_move_tween = null
	_tutorial_step = TutorialStep.NONE
	_tutorial_waiting_for_word_action = false
	_tutorial_click_catcher.hide()
	_tutorial_bubble.hide()
	_tutorial_tail_outline.hide()
	_tutorial_tail_fill.hide()
	_update_panel_width()


func _mark_tutorial_seen() -> void:
	var game_stats := get_node_or_null("/root/GameStats")
	if game_stats != null and game_stats.has_method("set_value"):
		game_stats.call("set_value", TUTORIAL_STATE_KEY, true)


func _fly_tutorial_companion(
	target_position: Vector2,
	message: String,
	focus_control: Control,
	hint: String = "",
) -> void:
	if is_instance_valid(_tutorial_move_tween):
		_tutorial_move_tween.kill()
	_tutorial_move_tween = null
	_tutorial_label.text = message
	_tutorial_hint_label.text = hint
	_tutorial_hint_label.visible = not hint.is_empty()
	_tutorial_bubble.hide()
	_tutorial_tail_outline.hide()
	_tutorial_tail_fill.hide()
	_tutorial_click_catcher.show()
	_moneybot_companion.show()
	_moneybot_companion.size = COMPANION_SIZE
	_moneybot_companion.pivot_offset = COMPANION_SIZE * 0.5
	_has_companion_target = true
	_is_companion_acting = true
	_companion_follow_velocity = Vector2.ZERO
	var clamped_target := _clamped_companion_position(
		target_position,
		TUTORIAL_COMPANION_SCALE,
	)
	_tutorial_move_tween = create_tween()
	_tutorial_move_tween.tween_method(
		_set_companion_follow_position,
		_companion_follow_position,
		clamped_target,
		TUTORIAL_FLIGHT_TIME,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tutorial_move_tween.tween_callback(
		_finish_tutorial_flight.bind(focus_control)
	)


func _finish_tutorial_flight(focus_control: Control) -> void:
	_tutorial_move_tween = null
	_is_companion_acting = false
	_companion_follow_velocity = Vector2.ZERO
	if _tutorial_step == TutorialStep.NONE:
		return
	_tutorial_bubble.show()
	_position_tutorial_bubble(focus_control)
	_position_tutorial_tail()
	_tutorial_tail_outline.show()
	_tutorial_tail_fill.show()
	call_deferred("_settle_tutorial_bubble", focus_control)


func _settle_tutorial_bubble(focus_control: Control) -> void:
	if _tutorial_step == TutorialStep.NONE or not is_instance_valid(focus_control):
		return
	_position_tutorial_bubble(focus_control)
	_position_tutorial_tail()
	if _tutorial_step != TutorialStep.BUDGET:
		_tutorial_click_catcher.hide()


func _refresh_tutorial_layout() -> void:
	if _tutorial_step == TutorialStep.NONE:
		return
	var focus_control: Control = _budget_label
	var target_position := _tutorial_budget_position()
	match _tutorial_step:
		TutorialStep.WORD:
			if not is_instance_valid(_tutorial_target_chip):
				return
			focus_control = _tutorial_target_chip
			target_position = _tutorial_word_position()
		TutorialStep.SUBMIT:
			focus_control = _confirm_button
			target_position = _tutorial_submit_position()
	_companion_follow_position = _clamped_companion_position(
		target_position,
		TUTORIAL_COMPANION_SCALE,
	)
	_position_tutorial_bubble(focus_control)
	_position_tutorial_tail()


func _tutorial_budget_position() -> Vector2:
	var budget_rect := _budget_label.get_global_rect()
	var scaled_body_size := COMPANION_BODY_SIZE * TUTORIAL_COMPANION_SCALE
	var desired_body_center := Vector2(
		budget_rect.end.x + scaled_body_size.x * 0.5 + 10.0,
		budget_rect.get_center().y + 15.0,
	)
	return _clamped_companion_position(
		desired_body_center
		- _companion_body_center_offset(TUTORIAL_COMPANION_SCALE),
		TUTORIAL_COMPANION_SCALE,
	)


func _tutorial_word_position() -> Vector2:
	if not is_instance_valid(_tutorial_target_chip):
		return _companion_follow_position
	return _clamped_companion_position(
		_closest_recoil_peak(
			_tutorial_target_chip.get_global_rect(),
			_companion_follow_position,
		)
		+ Vector2.UP * 40.0,
		TUTORIAL_COMPANION_SCALE,
	)


func _tutorial_submit_position() -> Vector2:
	var confirm_rect := _confirm_button.get_global_rect()
	var target_center := Vector2(
		confirm_rect.end.x
		+ COMPANION_SIZE.x * TUTORIAL_COMPANION_SCALE * 0.35
		+ 40.0,
		confirm_rect.get_center().y
		+ COMPANION_SIZE.y * TUTORIAL_COMPANION_SCALE * 0.3,
	)
	return target_center - COMPANION_SIZE * 0.5


func _position_tutorial_bubble(focus_control: Control) -> void:
	if not is_instance_valid(focus_control):
		return
	_tutorial_bubble.reset_size()
	var bubble_size := _tutorial_bubble.get_combined_minimum_size()
	_tutorial_bubble.size = bubble_size
	var focus_rect := focus_control.get_global_rect()
	var frame := _story_frame_rect()
	var bubble_position := Vector2(
		focus_rect.get_center().x - bubble_size.x * 0.5,
		focus_rect.position.y - bubble_size.y - TUTORIAL_BUBBLE_GAP,
	)
	if _tutorial_step == TutorialStep.BUDGET:
		var companion_rect := _companion_visual_rect(
			_companion_follow_position,
			TUTORIAL_COMPANION_SCALE,
		)
		bubble_position.x = companion_rect.end.x + TUTORIAL_BUBBLE_GAP
		bubble_position.y = (
			companion_rect.get_center().y - bubble_size.y * 0.5 - 15.0
		)
	elif _tutorial_step == TutorialStep.SUBMIT:
		bubble_position.y = focus_rect.position.y - bubble_size.y - TUTORIAL_BUBBLE_GAP
	bubble_position.x = clampf(
		bubble_position.x,
		frame.position.x + COMPACT_SAFE_MARGIN,
		frame.end.x - bubble_size.x - COMPACT_SAFE_MARGIN,
	)
	bubble_position.y = clampf(
		bubble_position.y,
		frame.position.y + COMPACT_SAFE_MARGIN,
		frame.end.y - bubble_size.y - COMPACT_SAFE_MARGIN,
	)
	_tutorial_bubble.global_position = bubble_position


func _position_tutorial_tail() -> void:
	var bubble_rect := _tutorial_bubble.get_global_rect()
	var companion_center := _companion_body_rect(
		_companion_follow_position,
		TUTORIAL_COMPANION_SCALE,
	).get_center()
	var bubble_center := bubble_rect.get_center()
	var toward_companion := bubble_center.direction_to(companion_center)
	if toward_companion.is_zero_approx():
		toward_companion = Vector2.RIGHT

	var base_center := bubble_center
	if absf(toward_companion.x) > absf(toward_companion.y):
		base_center.x = (
			bubble_rect.end.x
			if toward_companion.x > 0.0
			else bubble_rect.position.x
		)
		base_center.y = clampf(
			companion_center.y,
			bubble_rect.position.y + 14.0,
			bubble_rect.end.y - 14.0,
		)
	else:
		base_center.y = (
			bubble_rect.end.y
			if toward_companion.y > 0.0
			else bubble_rect.position.y
		)
		base_center.x = clampf(
			companion_center.x,
			bubble_rect.position.x + 14.0,
			bubble_rect.end.x - 14.0,
		)

	# Tuck the base beneath the panel so the tail and rounded box read as one
	# continuous speech bubble instead of two shapes touching at their edges.
	base_center -= toward_companion * 7.0
	var perpendicular := toward_companion.orthogonal()
	_tutorial_tail_outline.global_position = base_center
	_tutorial_tail_outline.polygon = PackedVector2Array(
		[
			perpendicular * -11.0,
			perpendicular * 11.0,
			toward_companion * 24.0,
		]
	)
	_tutorial_tail_fill.global_position = base_center
	_tutorial_tail_fill.polygon = PackedVector2Array(
		[
			perpendicular * -7.0 + toward_companion * 3.0,
			perpendicular * 7.0 + toward_companion * 3.0,
			toward_companion * 18.0,
		]
	)


func _update_panel_width() -> void:
	var frame := _story_frame_rect()
	_safe_margin.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_safe_margin.position = frame.position
	_safe_margin.size = frame.size
	var available_width := maxf(frame.size.x - HORIZONTAL_GUTTER, MIN_PANEL_WIDTH)
	_panel.custom_minimum_size.x = minf(available_width, MAX_PANEL_WIDTH)
	var show_companion := (
		_tutorial_step != TutorialStep.NONE
		or (
			frame.size.x >= MONEYBOT_COMPANION_MIN_WIDTH
			and frame.size.y >= MONEYBOT_COMPANION_MIN_HEIGHT
		)
	)
	_moneybot_companion.visible = show_companion
	_moneybot_icon.visible = not show_companion
	if not show_companion:
		if is_instance_valid(_companion_action_tween):
			_companion_action_tween.kill()
		if is_instance_valid(_pending_action_chip):
			_play_prepared_chip_strike(_pending_action_chip)
		_companion_action_tween = null
		_pending_action_chip = null
		_is_companion_acting = false
		_has_companion_target = false
		_companion_angular_velocity = 0.0
		_companion_follow_velocity = Vector2.ZERO
		_companion_hover_time = 0.0
		_companion_visual_scale = 1.0
		_companion_visual_alpha = 1.0
		_companion_cursor_active = false
		_companion_return_delay_remaining = 0.0
		_moneybot_companion.rotation = 0.0
		_moneybot_companion.scale = Vector2.ONE
	_panel_margin.add_theme_constant_override(
		"margin_right",
		COMPANION_CONTENT_MARGIN_RIGHT if show_companion else PANEL_CONTENT_MARGIN_RIGHT,
	)
	_safe_margin.add_theme_constant_override(
		"margin_right",
		COMPANION_SAFE_MARGIN_RIGHT if show_companion else COMPACT_SAFE_MARGIN,
	)
	_fit_phrase_buttons_to_row()
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
	_companion_visual_alpha = 1.0
	if not _has_companion_target:
		_companion_follow_position = _companion_home_position()
		_moneybot_companion.global_position = _companion_follow_position
		_companion_follow_velocity = Vector2.ZERO
		_companion_visual_scale = 1.0
		_moneybot_companion.scale = Vector2.ONE
		_has_companion_target = true
	_companion_target_position = _companion_home_position()


func _companion_home_position() -> Vector2:
	var panel_rect := _panel.get_global_rect()
	return _clamped_companion_position(
		Vector2(
			panel_rect.end.x + COMPANION_HOME_GAP,
			panel_rect.get_center().y - COMPANION_SIZE.y * 0.5,
		),
	)


func _update_companion_cursor_active(cursor_position: Vector2) -> bool:
	var panel_rect := _panel.get_global_rect()
	if panel_rect.has_point(cursor_position):
		_companion_cursor_active = true
	elif not panel_rect.grow(COMPANION_PANEL_EXIT_BUFFER).has_point(cursor_position):
		_companion_cursor_active = false
	return _companion_cursor_active


func _companion_target_for_cursor(
	cursor_position: Vector2,
	_current_position: Vector2,
) -> Vector2:
	# Follow like a physical cursor companion. Keep one predictable offset and
	# only flip it when the active-size sprite would leave the story frame.
	var movement_bounds := _companion_movement_bounds()
	var visual_half_size := COMPANION_SIZE * COMPANION_ACTIVE_SCALE * 0.5
	var cursor_offset := COMPANION_CURSOR_OFFSET
	if cursor_position.x + cursor_offset.x + visual_half_size.x > movement_bounds.end.x:
		cursor_offset.x *= -1.0
	if cursor_position.y + cursor_offset.y + visual_half_size.y > movement_bounds.end.y:
		cursor_offset.y *= -1.0
	var target_center := cursor_position + cursor_offset
	return _clamped_companion_position(
		target_center - COMPANION_SIZE * 0.5,
		COMPANION_ACTIVE_SCALE,
	)


func _companion_obstacle_overlap_area(
	companion_position: Vector2,
	visual_scale: float,
) -> float:
	var companion_rect := _companion_visual_rect(
		companion_position,
		visual_scale,
	)
	var total_overlap := 0.0
	for obstacle: Rect2 in _companion_obstacle_rects():
		var overlap := companion_rect.intersection(obstacle)
		if overlap.has_area():
			total_overlap += overlap.get_area()
	return total_overlap


func _companion_visual_rect(
	companion_position: Vector2,
	visual_scale: float,
) -> Rect2:
	var visual_size := COMPANION_SIZE * visual_scale
	var visual_center := companion_position + COMPANION_SIZE * 0.5
	return Rect2(visual_center - visual_size * 0.5, visual_size)


func _companion_obstacle_rects() -> Array[Rect2]:
	var obstacle_rects: Array[Rect2] = []
	for child: Node in _chips.get_children():
		var word := child as Control
		if word != null and word.visible and word.is_visible_in_tree():
			obstacle_rects.append(
				word.get_global_rect().grow(COMPANION_OBSTACLE_PADDING),
			)
	var controls: Array[Control] = [
		_title_label,
		_budget_label,
		_recovery_label,
		_silence_button,
		_pity_button,
		_sponsor_button,
		_confirm_button,
	]
	for control: Control in controls:
		if control.visible and control.is_visible_in_tree():
			obstacle_rects.append(
				control.get_global_rect().grow(COMPANION_OBSTACLE_PADDING),
			)
	return obstacle_rects


func _ellipse_offset(direction: Vector2, radii: Vector2) -> Vector2:
	if direction.is_zero_approx():
		return Vector2(radii.x, 0.0)
	var ellipse_distance := Vector2(
		direction.x / radii.x,
		direction.y / radii.y,
	).length()
	return direction / ellipse_distance


func _companion_hover_offset_at(hover_time: float) -> Vector2:
	var hover_phase := hover_time * TAU * COMPANION_HOVER_FREQUENCY
	var primary_bob := sin(hover_phase) * COMPANION_HOVER_AMPLITUDE
	var secondary_bob := sin(hover_phase * 2.0 + 0.7) * COMPANION_HOVER_AMPLITUDE * 0.2
	return Vector2(0.0, primary_bob + secondary_bob)


func _companion_pulse_scale_at(hover_time: float) -> Vector2:
	var pulse_phase := hover_time * TAU * COMPANION_PULSE_FREQUENCY
	return Vector2.ONE * (1.0 + sin(pulse_phase) * COMPANION_PULSE_AMOUNT)


func _companion_movement_bounds() -> Rect2:
	var frame := _story_frame_rect()
	return Rect2(
		get_global_rect().position + frame.position + Vector2.ONE * COMPANION_EDGE_PADDING,
		frame.size - Vector2.ONE * COMPANION_EDGE_PADDING * 2.0,
	)


func _clamped_companion_position(
	desired_position: Vector2,
	visual_scale: float = 1.0,
) -> Vector2:
	return _clamp_companion_to_bounds(
		desired_position,
		_companion_movement_bounds(),
		visual_scale,
	)


func _clamp_companion_to_bounds(
	companion_position: Vector2,
	bounds: Rect2,
	visual_scale: float = 1.0,
) -> Vector2:
	var pivot_offset := COMPANION_SIZE * 0.5
	var scaled_size := COMPANION_SIZE * visual_scale
	var visual_origin_offset := pivot_offset * (1.0 - visual_scale)
	return Vector2(
		clampf(
			companion_position.x,
			bounds.position.x - visual_origin_offset.x,
			maxf(
				bounds.position.x - visual_origin_offset.x,
				bounds.end.x - visual_origin_offset.x - scaled_size.x,
			),
		),
		clampf(
			companion_position.y,
			bounds.position.y - visual_origin_offset.y,
			maxf(
				bounds.position.y - visual_origin_offset.y,
				bounds.end.y - visual_origin_offset.y - scaled_size.y,
			),
		),
	)


func _on_confirm() -> void:
	if _tutorial_step in [TutorialStep.BUDGET, TutorialStep.WORD]:
		return
	var kept_text := _assemble()
	var delivery_mode := DELIVERY_SILENCE if kept_text.is_empty() else DELIVERY_NORMAL
	if not _delivery_is_allowed(delivery_mode):
		return
	_finish_tutorial()
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.call("play", &"ui_confirm", -5.0)
	_resolve(_kept_ids(), kept_text, delivery_mode, _cost())


func _on_silence() -> void:
	if _tutorial_step in [TutorialStep.BUDGET, TutorialStep.WORD]:
		return
	if not _delivery_is_allowed(DELIVERY_SILENCE):
		return
	_finish_tutorial()
	_resolve([], "", DELIVERY_SILENCE, 0)


func _on_pity() -> void:
	if _tutorial_step in [TutorialStep.BUDGET, TutorialStep.WORD]:
		return
	if not _delivery_is_allowed(DELIVERY_PITY):
		return
	_finish_tutorial()
	_resolve([], _pity_text, DELIVERY_PITY, 0)


func _on_sponsor() -> void:
	if _tutorial_step in [TutorialStep.BUDGET, TutorialStep.WORD]:
		return
	if not _delivery_is_allowed(DELIVERY_SPONSOR):
		return
	_finish_tutorial()
	_resolve([], _sponsor_text, DELIVERY_SPONSOR, 0)


func _delivery_is_allowed(delivery_mode: StringName) -> bool:
	return _required_delivery.is_empty() or _required_delivery == delivery_mode


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
