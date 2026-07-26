extends Control
## Application shell. It only owns screen transitions; campaign logic lives in
## CampaignPlayer and visual content lives in episode stage scenes.

const CAMPAIGN := preload("res://content/campaign/campaign.tres")
const TITLE_CANVAS_SIZE := Vector2(1152.0, 648.0)
const HUD_STACK_WIDTH := 880.0
const STORY_FRAME_SIZE := Vector2(1152.0, 648.0)
const DEPARTURE_MONO := preload("res://ui/theme/fonts/DepartureMono-Regular.ttf")
const INK_COLOR := Color(0.141176, 0.188235, 0.121569, 1)
const PAPER_COLOR := Color(0.992157, 0.984314, 0.956863, 1)

## The history modal (ui/dialogue/history_layer.tscn) is a separate scene
## mounted by Dialogic, not a child of this one -- these mirror its layout
## so the chapter title can align with the transcript while its actions remain
## in the persistent top header.
const HISTORY_MODAL_LEFT_INSET := 74.0
const HISTORY_MODAL_RING_CLEARANCE := 20.0
const HISTORY_ROW_TOP := 82.0
const HISTORY_ROW_BOTTOM := 122.0
const HISTORY_CHAPTER_GAP := 16.0
const BACK_TO_TITLE_WIDTH := 180.0
const COMPACT_BACK_TO_TITLE_WIDTH := 150.0
const COMPACT_HISTORY_CHAPTER_TOP := 48.0
const COMPACT_HISTORY_CHAPTER_BOTTOM := 88.0
const HUD_BUTTON_TOP := 7.0
const COMPACT_RETURN_BUTTON_TOP := 55.0
const HUD_CONTROL_HEIGHT := 40.0
const HISTORY_BUTTON_WIDTH := 96.0
const RETURN_TO_GAME_WIDTH := 175.0
const HUD_RIGHT_MARGIN := 20.0
const HUD_CONTROL_GAP := 10.0

@onready var title_screen: Control = %TitleScreen
@onready var start_button: TextureButton = %StartButton
@onready var play_indicator: Label = %PlayIndicator
@onready var credits_button: TextureButton = %CreditsButton
@onready var credits_back_button: Button = %CreditsBackButton
@onready var hud_status_panel: Panel = %HudStatusPanel
@onready var episode_label: Label = %EpisodeLabel
@onready var budget_label: Label = %BudgetLabel
@onready var back_to_title_button: Button = %BackToTitleButton
@onready var history_button: Button = %HistoryButton
@onready var return_to_game_button: Button = %ReturnToGameButton
@onready var status_label: Label = %StatusLabel
@onready var campaign_player: CampaignPlayer = %CampaignPlayer
@onready var developer_tools: VBoxContainer = %DeveloperTools
@onready var episode_picker: OptionButton = %EpisodePicker
@onready var play_episode_button: Button = %PlayEpisodeButton
@onready var game_state: GameStateStore = get_node("/root/GameStats") as GameStateStore
@onready var dialogic_node: Node = get_node("/root/Dialogic")
@onready var title_canvas: Control = %TitleCanvas
@onready var title_art: TextureRect = %TitleArt
@onready var pennybot_credits: Control = %PennybotCredits
@onready var credits_heading: TextureRect = %CreditsHeading
@onready var credits_body: Control = %CreditsBody

var _history_box: Control = null
var _budget_visible_before_history := false
var _hud_visible_before_history := false
var _credits_active := false


func _ready() -> void:
	campaign_player.set_stage_host(%StageHost as StageHost)
	campaign_player.set_game_state(game_state)
	campaign_player.set_dialogic(dialogic_node)
	campaign_player.episode_started.connect(_on_episode_started)
	campaign_player.campaign_finished.connect(_on_campaign_finished)
	campaign_player.campaign_aborted.connect(_on_campaign_aborted)
	campaign_player.validation_failed.connect(_on_validation_failed)
	campaign_player.integration_warning.connect(_on_integration_warning)
	game_state.budget_changed.connect(_on_budget_changed)
	_configure_developer_tools()
	_style_episode_picker_popup()
	_ensure_history_box_connection()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


## episode_started fires before Dialogic actually mounts the style layout
## (the layout only appears once the timeline starts advancing text), so a
## one-shot connection attempt at episode start can silently miss it. This
## keeps retrying every frame until it succeeds, then becomes a no-op.
func _process(_delta: float) -> void:
	if _history_box == null or not is_instance_valid(_history_box):
		_ensure_history_box_connection()


func _on_start_button_pressed() -> void:
	status_label.text = ""
	if campaign_player.start_campaign(CAMPAIGN):
		title_screen.hide()


func _on_credits_button_pressed() -> void:
	_credits_active = true
	title_art.hide()
	start_button.hide()
	play_indicator.hide()
	credits_button.hide()
	credits_heading.show()
	credits_body.show()
	credits_back_button.show()


func _show_main_title() -> void:
	_credits_active = false
	title_art.show()
	start_button.show()
	play_indicator.show()
	credits_button.show()
	credits_heading.hide()
	credits_body.hide()
	credits_back_button.hide()


func _on_credits_back_button_pressed() -> void:
	_show_main_title()


func _unhandled_input(event: InputEvent) -> void:
	if _credits_active and event.is_action_pressed(&"ui_cancel"):
		_show_main_title()
		get_viewport().set_input_as_handled()


func _on_play_episode_button_pressed() -> void:
	status_label.text = ""
	var selected_index := episode_picker.selected
	if selected_index < 0:
		status_label.text = "Choose an episode to playtest."
		return
	var episode_id := StringName(String(episode_picker.get_item_metadata(selected_index)))
	if campaign_player.start_campaign_at(CAMPAIGN, episode_id):
		title_screen.hide()


func _on_episode_started(episode: EpisodeDefinition) -> void:
	episode_label.text = "CURRENT CHAPTER  /  %s" % episode.title
	budget_label.show()
	hud_status_panel.show()
	back_to_title_button.show()
	# The Dialogic history layer mounts just after this signal. Its opener is
	# enabled by _ensure_history_box_connection() once it has a live target.
	history_button.visible = _history_box != null and is_instance_valid(_history_box)
	_on_budget_changed(game_state.remaining_budget(), game_state.remaining_budget())
	_layout_active_cutscene_header()


func _on_campaign_finished() -> void:
	episode_label.text = "The story is complete."
	budget_label.hide()
	hud_status_panel.hide()
	back_to_title_button.hide()
	history_button.hide()
	return_to_game_button.hide()
	title_screen.hide()


func _on_campaign_aborted() -> void:
	episode_label.text = ""
	budget_label.hide()
	hud_status_panel.hide()
	back_to_title_button.hide()
	history_button.hide()
	return_to_game_button.hide()
	title_screen.show()
	_show_main_title()


func _on_back_to_title_button_pressed() -> void:
	var history: Object = dialogic_node.call("get_subsystem", "History")
	if history != null and history.has_method("close_history"):
		history.call("close_history")
	await campaign_player.abort_campaign()


func _on_history_button_pressed() -> void:
	var history: Object = dialogic_node.call("get_subsystem", "History")
	if history != null and history.has_method("open_history"):
		history.call("open_history")


func _on_return_to_game_button_pressed() -> void:
	var history: Object = dialogic_node.call("get_subsystem", "History")
	if history != null and history.has_method("close_history"):
		history.call("close_history")


func _on_validation_failed(errors: PackedStringArray) -> void:
	status_label.text = "Cannot start:\n" + "\n".join(errors)


func _on_integration_warning(message: String) -> void:
	status_label.text = message


func _on_budget_changed(current_budget: int, _previous_budget: int) -> void:
	budget_label.text = "Money Left: $%d" % current_budget


func _configure_developer_tools() -> void:
	developer_tools.visible = OS.is_debug_build()
	episode_picker.clear()
	if not developer_tools.visible:
		return
	for episode in CAMPAIGN.episodes:
		if episode == null:
			continue
		var label := episode.title if not episode.title.is_empty() else String(episode.id)
		episode_picker.add_item(label)
		episode_picker.set_item_metadata(
			episode_picker.item_count - 1,
			String(episode.id),
		)
	play_episode_button.disabled = episode_picker.item_count == 0


func _style_episode_picker_popup() -> void:
	var popup := episode_picker.get_popup()
	popup.add_theme_font_override(&"font", DEPARTURE_MONO)
	popup.add_theme_font_size_override(&"font_size", 16)
	popup.add_theme_color_override(&"font_color", INK_COLOR)
	popup.add_theme_color_override(&"font_hover_color", PAPER_COLOR)
	popup.add_theme_color_override(&"font_focus_color", INK_COLOR)
	popup.add_theme_stylebox_override(&"panel", load("res://ui/dialogue/choice_button_normal.tres"))
	popup.add_theme_stylebox_override(&"hover", load("res://ui/dialogue/choice_button_hover.tres"))


## The app header requests open/close through Dialogic, while HistoryBox
## visibility remains the source of truth for keeping both layouts in sync.
func _ensure_history_box_connection() -> void:
	if _history_box != null and is_instance_valid(_history_box):
		return
	if not dialogic_node.call("has_subsystem", "Styles"):
		return
	var styles: Object = dialogic_node.call("get_subsystem", "Styles")
	if styles == null or not styles.call("has_active_layout_node"):
		return
	var layout: Node = styles.call("get_layout_node")
	if layout == null:
		return
	var history_box := layout.find_child("HistoryBox", true, false) as Control
	if history_box == null:
		return
	_history_box = history_box
	if not _history_box.visibility_changed.is_connected(_on_history_box_visibility_changed):
		_history_box.visibility_changed.connect(_on_history_box_visibility_changed)
	if _history_box.visible:
		_on_history_opened()
	elif campaign_player.current_episode != null:
		history_button.show()
		_layout_active_cutscene_header()


func _on_history_box_visibility_changed() -> void:
	if _history_box.visible:
		_on_history_opened()
	else:
		_on_history_closed()


func _on_history_opened() -> void:
	history_button.hide()
	return_to_game_button.show()
	var frame := _story_frame_rect()
	var compact_history := frame.size.x < 680.0 or frame.size.y < 460.0
	_layout_history_actions(frame, compact_history)
	if compact_history:
		# Stack chapter identity below the two actions so every control remains
		# readable on a phone-sized story frame.
		_budget_visible_before_history = _budget_visible_before_history or budget_label.visible
		_hud_visible_before_history = _hud_visible_before_history or hud_status_panel.visible
		budget_label.hide()
		hud_status_panel.hide()
		episode_label.anchor_left = 0.0
		episode_label.anchor_right = 0.0
		episode_label.grow_horizontal = Control.GROW_DIRECTION_END
		episode_label.offset_left = frame.position.x + 16.0
		episode_label.offset_right = frame.end.x - 16.0
		episode_label.offset_top = frame.position.y + COMPACT_HISTORY_CHAPTER_TOP
		episode_label.offset_bottom = frame.position.y + COMPACT_HISTORY_CHAPTER_BOTTOM
		episode_label.show()
		return

	if _budget_visible_before_history:
		budget_label.show()
		_budget_visible_before_history = false
	if _hud_visible_before_history:
		hud_status_panel.show()
		_hud_visible_before_history = false
	var back_to_title_left := back_to_title_button.position.x
	episode_label.anchor_left = 0.0
	episode_label.anchor_right = 0.0
	episode_label.grow_horizontal = Control.GROW_DIRECTION_END
	episode_label.offset_left = frame.position.x + HISTORY_MODAL_LEFT_INSET + HISTORY_MODAL_RING_CLEARANCE
	episode_label.offset_right = back_to_title_left - HISTORY_CHAPTER_GAP
	episode_label.offset_top = frame.position.y + HISTORY_ROW_TOP
	episode_label.offset_bottom = frame.position.y + HISTORY_ROW_BOTTOM
	episode_label.show()

func _on_history_closed() -> void:
	episode_label.hide()
	return_to_game_button.hide()
	if _budget_visible_before_history:
		budget_label.show()
	_budget_visible_before_history = false
	if _hud_visible_before_history:
		hud_status_panel.show()
	_hud_visible_before_history = false
	if campaign_player.current_episode != null:
		back_to_title_button.show()
		history_button.show()
		_layout_active_cutscene_header()
	else:
		back_to_title_button.hide()
		history_button.hide()
		return_to_game_button.hide()


func _apply_responsive_layout() -> void:
	var title_scale := minf(
		size.x / TITLE_CANVAS_SIZE.x,
		size.y / TITLE_CANVAS_SIZE.y,
	)
	var scaled_title_size := TITLE_CANVAS_SIZE * title_scale
	title_canvas.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	title_canvas.position = (size - scaled_title_size) * 0.5
	title_canvas.size = TITLE_CANVAS_SIZE
	title_canvas.scale = Vector2.ONE * title_scale
	pennybot_credits.pivot_offset = pennybot_credits.size * 0.5

	if size.x < HUD_STACK_WIDTH:
		_layout_stacked_hud()
	else:
		_layout_inline_hud()
	if _history_box != null and is_instance_valid(_history_box) and _history_box.visible:
		_on_history_opened()
	elif campaign_player.current_episode != null:
		_layout_active_cutscene_header()


## Fixed-size chip, not proportional to window width: "Money Left: $NNN" only
## ever needs ~183px (DepartureMono, size 18), so a stretchy box would leave a
## large dead gap after the text. All persistent HUD controls share this row.
func _layout_stacked_hud() -> void:
	_layout_hud_status()


func _layout_inline_hud() -> void:
	_layout_hud_status()


func _layout_hud_status() -> void:
	var frame := _story_frame_rect()
	hud_status_panel.anchor_left = 0.0
	hud_status_panel.anchor_right = 0.0
	hud_status_panel.offset_left = frame.position.x + 20.0
	hud_status_panel.offset_top = frame.position.y + HUD_BUTTON_TOP
	hud_status_panel.offset_right = frame.position.x + 236.0
	hud_status_panel.offset_bottom = (
		frame.position.y + HUD_BUTTON_TOP + HUD_CONTROL_HEIGHT
	)

	budget_label.anchor_left = 0.0
	budget_label.anchor_right = 0.0
	budget_label.offset_left = frame.position.x + 28.0
	budget_label.offset_top = frame.position.y + HUD_BUTTON_TOP
	budget_label.offset_right = frame.position.x + 228.0
	budget_label.offset_bottom = (
		frame.position.y + HUD_BUTTON_TOP + HUD_CONTROL_HEIGHT
	)


func _layout_active_cutscene_header() -> void:
	var frame := _story_frame_rect()
	var compact := frame.size.x < 680.0 or frame.size.y < 460.0
	var top := COMPACT_RETURN_BUTTON_TOP if compact else HUD_BUTTON_TOP
	var width := COMPACT_BACK_TO_TITLE_WIDTH if compact else BACK_TO_TITLE_WIDTH
	var history_right := frame.end.x - HUD_RIGHT_MARGIN
	var history_left := history_right - HISTORY_BUTTON_WIDTH
	var right := history_left - HUD_CONTROL_GAP

	history_button.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	history_button.position = Vector2(history_left, frame.position.y + HUD_BUTTON_TOP)
	history_button.size = Vector2(HISTORY_BUTTON_WIDTH, HUD_CONTROL_HEIGHT)
	return_to_game_button.hide()

	back_to_title_button.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	back_to_title_button.position = Vector2(
		right - width,
		frame.position.y + top,
	)
	back_to_title_button.size = Vector2(width, HUD_CONTROL_HEIGHT)


func _layout_history_actions(frame: Rect2, compact: bool) -> void:
	var return_right := frame.end.x - (16.0 if compact else HUD_RIGHT_MARGIN)
	var return_left := return_right - RETURN_TO_GAME_WIDTH
	return_to_game_button.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	return_to_game_button.position = Vector2(
		return_left,
		frame.position.y + HUD_BUTTON_TOP,
	)
	return_to_game_button.size = Vector2(RETURN_TO_GAME_WIDTH, HUD_CONTROL_HEIGHT)

	var back_width := COMPACT_BACK_TO_TITLE_WIDTH if compact else BACK_TO_TITLE_WIDTH
	var back_left := (
		frame.position.x + 16.0
		if compact
		else return_left - HUD_CONTROL_GAP - back_width
	)
	back_to_title_button.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	back_to_title_button.position = Vector2(
		back_left,
		frame.position.y + HUD_BUTTON_TOP,
	)
	back_to_title_button.size = Vector2(back_width, HUD_CONTROL_HEIGHT)
	back_to_title_button.show()


func _story_frame_rect() -> Rect2:
	var frame_scale := minf(size.x / STORY_FRAME_SIZE.x, size.y / STORY_FRAME_SIZE.y)
	var frame_size := STORY_FRAME_SIZE * frame_scale
	return Rect2((size - frame_size) * 0.5, frame_size)
