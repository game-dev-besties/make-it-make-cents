@tool
class_name DialogicStoryFlagSetEvent
extends DialogicEvent
## Sets a persistent story flag and records the change in simple history.

const FlagEventUtil = preload("res://addons/legendary_dialogic/phrase_cut/story_flag_event_util.gd")
const PREFIX := "story_flag_set "

@export var flag_name := ""
@export var flag_value: Variant


func _init() -> void:
	event_name = "Set Story Flag"
	event_description = "Sets a persistent story flag and adds a debug history entry."
	set_default_color("Color6")
	event_category = "Gameplay"
	disable_editor_button = true


func to_text() -> String:
	return PREFIX + JSON.stringify(
		{
			"name": flag_name,
			"value": flag_value,
		}
	)


func from_text(text: String) -> void:
	var payload := FlagEventUtil.parse_payload(text.strip_edges(), PREFIX)
	flag_name = String(payload.get("name", ""))
	flag_value = payload.get("value")


func is_valid_event(text: String) -> bool:
	var payload := FlagEventUtil.parse_payload(text.strip_edges(), PREFIX)
	return (
		not payload.is_empty()
		and payload.get("name") is String
		and payload.has("value")
	)


func _execute() -> void:
	var game_stats := dialogic.get_node_or_null("/root/GameStats")
	if (
		game_stats == null
		or not game_stats.has_method("set_story_flag")
		or not bool(game_stats.call("set_story_flag", StringName(flag_name), flag_value))
	):
		push_error("StoryFlagSet could not set '%s'." % flag_name)
		finish()
		return

	var message := "SET %s to %s." % [
		flag_name,
		FlagEventUtil.value_text(flag_value),
	]
	if game_stats.has_method("describe_story_flag"):
		var description := String(
			game_stats.call(
				"describe_story_flag",
				StringName(flag_name),
				flag_value,
			)
		)
		if not description.is_empty():
			message += "\n[i]%s[/i]" % description
	FlagEventUtil.store_debug_history(
		dialogic,
		message,
		{
			"debug_kind": "SET",
			"flag_name": flag_name,
			"flag_value": flag_value,
		},
	)
	finish()
