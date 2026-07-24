extends Control
## Application shell. It only owns screen transitions; campaign logic lives in
## CampaignPlayer and visual content lives in episode stage scenes.

const CAMPAIGN := preload("res://content/campaign/campaign.tres")

@onready var title_screen: Control = %TitleScreen
@onready var start_button: Button = %StartButton
@onready var episode_label: Label = %EpisodeLabel
@onready var status_label: Label = %StatusLabel
@onready var campaign_player: CampaignPlayer = %CampaignPlayer


func _ready() -> void:
	campaign_player.set_stage_host($StageHost as StageHost)
	campaign_player.set_game_state(get_node_or_null("/root/GameStats") as GameStateStore)
	campaign_player.set_dialogic(get_node_or_null("/root/Dialogic"))
	campaign_player.episode_started.connect(_on_episode_started)
	campaign_player.campaign_finished.connect(_on_campaign_finished)
	campaign_player.validation_failed.connect(_on_validation_failed)
	campaign_player.integration_warning.connect(_on_integration_warning)
	start_button.grab_focus()


func _on_start_button_pressed() -> void:
	status_label.text = ""
	if campaign_player.start_campaign(CAMPAIGN):
		title_screen.hide()


func _on_episode_started(episode: EpisodeDefinition) -> void:
	episode_label.text = episode.title


func _on_campaign_finished() -> void:
	episode_label.text = "The story is complete."
	title_screen.show()
	start_button.text = "Play again"
	start_button.grab_focus()


func _on_validation_failed(errors: PackedStringArray) -> void:
	status_label.text = "Cannot start:\n" + "\n".join(errors)


func _on_integration_warning(message: String) -> void:
	status_label.text = message
