extends Control
## Application shell. It only owns screen transitions; campaign logic lives in
## CampaignPlayer and visual content lives in episode stage scenes.

const CAMPAIGN := preload("res://content/campaign/campaign.tres")
const TITLE_PANEL_MAX_WIDTH := 600.0
const TITLE_PANEL_GUTTER := 16.0
const TITLE_COMPACT_WIDTH := 520.0
const TITLE_COMPACT_HEIGHT := 520.0
const HUD_STACK_WIDTH := 880.0

@onready var title_screen: Control = %TitleScreen
@onready var start_button: Button = %StartButton
@onready var episode_label: Label = %EpisodeLabel
@onready var budget_label: Label = %BudgetLabel
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


func _ready() -> void:
	campaign_player.set_stage_host(%StageHost as StageHost)
	campaign_player.set_game_state(game_state)
	campaign_player.set_dialogic(dialogic_node)
	campaign_player.episode_started.connect(_on_episode_started)
	campaign_player.campaign_finished.connect(_on_campaign_finished)
	campaign_player.validation_failed.connect(_on_validation_failed)
	campaign_player.integration_warning.connect(_on_integration_warning)
	game_state.budget_changed.connect(_on_budget_changed)
	_configure_developer_tools()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	start_button.grab_focus()


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
	_on_budget_changed(game_state.remaining_budget(), game_state.remaining_budget())


func _on_campaign_finished() -> void:
	episode_label.text = "The story is complete."
	budget_label.hide()
	title_screen.show()
	start_button.text = "Play again"
	start_button.grab_focus()


func _on_validation_failed(errors: PackedStringArray) -> void:
	status_label.text = "Cannot start:\n" + "\n".join(errors)


func _on_integration_warning(message: String) -> void:
	status_label.text = message


func _on_budget_changed(current_budget: int, _previous_budget: int) -> void:
	budget_label.text = "Words left: $%d" % current_budget


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


func _layout_stacked_hud() -> void:
	episode_label.anchor_right = 1.0
	episode_label.offset_left = 20.0
	episode_label.offset_top = 16.0
	episode_label.offset_right = -20.0
	episode_label.offset_bottom = 48.0

	budget_label.anchor_left = 0.0
	budget_label.anchor_right = 1.0
	budget_label.offset_left = 20.0
	budget_label.offset_top = 52.0
	budget_label.offset_right = -20.0
	budget_label.offset_bottom = 84.0


func _layout_inline_hud() -> void:
	episode_label.anchor_right = 1.0
	episode_label.offset_left = 28.0
	episode_label.offset_top = 24.0
	episode_label.offset_right = -340.0
	episode_label.offset_bottom = 56.0

	budget_label.anchor_left = 1.0
	budget_label.anchor_right = 1.0
	budget_label.offset_left = -320.0
	budget_label.offset_top = 24.0
	budget_label.offset_right = -92.0
	budget_label.offset_bottom = 56.0
