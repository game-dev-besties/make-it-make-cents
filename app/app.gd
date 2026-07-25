extends Control
## Application shell. It only owns screen transitions; campaign logic lives in
## CampaignPlayer and visual content lives in episode stage scenes.

const CAMPAIGN := preload("res://content/campaign/campaign.tres")
const TITLE_PANEL_MAX_WIDTH := 600.0
const TITLE_PANEL_GUTTER := 16.0
const TITLE_COMPACT_WIDTH := 520.0
const TITLE_COMPACT_HEIGHT := 520.0
const HUD_STACK_WIDTH := 880.0
const DEPARTURE_MONO := preload("res://ui/theme/fonts/DepartureMono-Regular.ttf")
const INK_COLOR := Color(0.141176, 0.188235, 0.121569, 1)
const PAPER_COLOR := Color(0.992157, 0.984314, 0.956863, 1)

## The history modal (ui/dialogue/history_layer.tscn) is a separate scene
## mounted by Dialogic, not a child of this one -- these mirror its layout
## so the chapter title and "Return to Title" can align with its button row
## while it's open. Keep in sync with that file's HideHistory/HistoryBox rects.
const HISTORY_MODAL_LEFT_INSET := 74.0
const HISTORY_MODAL_RING_CLEARANCE := 20.0
const HISTORY_ROW_TOP := 85.0
const HISTORY_ROW_BOTTOM := 116.0
const HISTORY_RETURN_TO_GAME_LEFT_INSET := 313.0
const BACK_TO_TITLE_GAP := 10.0
const BACK_TO_TITLE_WIDTH := 150.0

@onready var title_screen: Control = %TitleScreen
@onready var start_button: Button = %StartButton
@onready var hud_status_panel: Panel = %HudStatusPanel
@onready var episode_label: Label = %EpisodeLabel
@onready var budget_label: Label = %BudgetLabel
@onready var back_to_title_button: Button = %BackToTitleButton
@onready var status_label: Label = %StatusLabel
@onready var campaign_player: CampaignPlayer = %CampaignPlayer
@onready var developer_tools: VBoxContainer = %DeveloperTools
@onready var episode_picker: OptionButton = %EpisodePicker
@onready var play_episode_button: Button = %PlayEpisodeButton
@onready var game_state: GameStateStore = get_node("/root/GameStats") as GameStateStore
@onready var dialogic_node: Node = get_node("/root/Dialogic")
@onready var title_panel: PanelContainer = $TitleScreen/Panel
@onready var title_margin: MarginContainer = $TitleScreen/Panel/Margin
@onready var title_vbox: VBoxContainer = $TitleScreen/Panel/Margin/VBox
@onready var title_label: Label = $TitleScreen/Panel/Margin/VBox/Title
@onready var subtitle_label: Label = $TitleScreen/Panel/Margin/VBox/Subtitle

var _history_box: Control = null


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
	start_button.grab_focus()


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
	episode_label.text = episode.title
	budget_label.show()
	hud_status_panel.show()
	_on_budget_changed(game_state.remaining_budget(), game_state.remaining_budget())


func _on_campaign_finished() -> void:
	episode_label.text = "The story is complete."
	budget_label.hide()
	hud_status_panel.hide()
	title_screen.hide()


func _on_campaign_aborted() -> void:
	episode_label.text = ""
	budget_label.hide()
	hud_status_panel.hide()
	title_screen.show()
	start_button.text = "Play again"
	start_button.grab_focus()


func _on_back_to_title_button_pressed() -> void:
	var history: Object = dialogic_node.call("get_subsystem", "History")
	if history != null and history.has_method("close_history"):
		history.call("close_history")
	await campaign_player.abort_campaign()


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


## The History layer's own "Show"/"Hide" buttons call their handlers directly
## rather than going through History.open_history()/close_history() (those
## are only emitted for programmatic callers) -- open_requested/close_requested
## never fire from an actual click, so watching HistoryBox's own visibility is
## the only hook that reliably reflects what the player sees.
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


func _on_history_box_visibility_changed() -> void:
	if _history_box.visible:
		_on_history_opened()
	else:
		_on_history_closed()


func _on_history_opened() -> void:
	episode_label.anchor_left = 0.0
	episode_label.anchor_right = 0.0
	episode_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	episode_label.offset_left = HISTORY_MODAL_LEFT_INSET + HISTORY_MODAL_RING_CLEARANCE
	episode_label.offset_right = episode_label.offset_left + 320.0
	episode_label.offset_top = HISTORY_ROW_TOP
	episode_label.offset_bottom = HISTORY_ROW_BOTTOM
	episode_label.show()

	var back_to_title_right := -(HISTORY_RETURN_TO_GAME_LEFT_INSET + BACK_TO_TITLE_GAP)
	back_to_title_button.anchor_left = 1.0
	back_to_title_button.anchor_right = 1.0
	back_to_title_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	back_to_title_button.offset_right = back_to_title_right
	back_to_title_button.offset_left = back_to_title_right - BACK_TO_TITLE_WIDTH
	back_to_title_button.offset_top = HISTORY_ROW_TOP
	back_to_title_button.offset_bottom = HISTORY_ROW_BOTTOM
	back_to_title_button.show()


func _on_history_closed() -> void:
	episode_label.hide()
	back_to_title_button.hide()


func _apply_responsive_layout() -> void:
	var panel_width := minf(TITLE_PANEL_MAX_WIDTH, maxf(0.0, size.x - TITLE_PANEL_GUTTER * 2.0))
	title_panel.custom_minimum_size.x = panel_width

	var compact_title := size.x < TITLE_COMPACT_WIDTH or size.y < TITLE_COMPACT_HEIGHT
	var horizontal_margin := 20 if compact_title else 44
	var vertical_margin := 16 if compact_title else 40
	title_margin.add_theme_constant_override(&"margin_left", horizontal_margin)
	title_margin.add_theme_constant_override(&"margin_top", vertical_margin)
	title_margin.add_theme_constant_override(&"margin_right", horizontal_margin)
	title_margin.add_theme_constant_override(&"margin_bottom", vertical_margin)
	title_vbox.add_theme_constant_override(&"separation", 10 if compact_title else 18)
	developer_tools.add_theme_constant_override(&"separation", 6 if compact_title else 8)
	title_label.add_theme_font_size_override(&"font_size", 32 if compact_title else 44)
	subtitle_label.add_theme_font_size_override(&"font_size", 16 if compact_title else 18)
	start_button.add_theme_font_size_override(&"font_size", 20 if compact_title else 22)

	if size.x < HUD_STACK_WIDTH:
		_layout_stacked_hud()
	else:
		_layout_inline_hud()


## Fixed-size chip, not proportional to window width: "Money Left: $NNN" only
## ever needs ~183px (DepartureMono, size 18), so a stretchy box just left a
## huge dead gap after the left-aligned text. The top offset (7) matches the
## History layer's ShowHistory button (ui/dialogue/history_layer.tscn) so the
## two line up in the same header row regardless of layout mode.
func _layout_stacked_hud() -> void:
	_layout_hud_status()


func _layout_inline_hud() -> void:
	_layout_hud_status()


func _layout_hud_status() -> void:
	hud_status_panel.anchor_left = 0.0
	hud_status_panel.anchor_right = 0.0
	hud_status_panel.offset_left = 20.0
	hud_status_panel.offset_top = 7.0
	hud_status_panel.offset_right = 236.0
	hud_status_panel.offset_bottom = 55.0

	budget_label.anchor_left = 0.0
	budget_label.anchor_right = 0.0
	budget_label.offset_left = 28.0
	budget_label.offset_top = 15.0
	budget_label.offset_right = 228.0
	budget_label.offset_bottom = 47.0
