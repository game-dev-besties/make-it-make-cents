@tool
class_name DialogicStoryFlagCheckEvent
extends DialogicEvent
## Records the selected persistent-story-flag branch in simple history.

const FlagEventUtil = preload("res://addons/legendary_dialogic/phrase_cut/story_flag_event_util.gd")
const PREFIX := "story_flag_check "

@export var flag_name := ""
@export_enum("==", "!=") var operator := "=="
@export var expected_value: Variant
@export var branch := ""


func _init() -> void:
	event_name = "Check Story Flag"
	event_description = "Records a selected story flag branch in debug history."
	set_default_color("Color3")
	event_category = "Gameplay"
	disable_editor_button = true


func to_text() -> String:
	return PREFIX + JSON.stringify(
		{
			"name": flag_name,
			"operator": operator,
			"expected": expected_value,
			"branch": branch,
		}
	)


func from_text(text: String) -> void:
	var payload := FlagEventUtil.parse_payload(text.strip_edges(), PREFIX)
	flag_name = String(payload.get("name", ""))
	operator = String(payload.get("operator", "=="))
	expected_value = payload.get("expected")
	branch = String(payload.get("branch", ""))


func is_valid_event(text: String) -> bool:
	var payload := FlagEventUtil.parse_payload(text.strip_edges(), PREFIX)
	return (
		not payload.is_empty()
		and payload.get("name") is String
		and payload.get("operator") in ["==", "!="]
		and payload.has("expected")
		and payload.get("branch") is String
	)


func _execute() -> void:
	var game_stats := dialogic.get_node_or_null("/root/GameStats")
	if game_stats == null or not game_stats.has_method("get_story_flag"):
		push_error("StoryFlagCheck requires the GameStats story flag API.")
		finish()
		return
	var actual: Variant = game_stats.call(
		"get_story_flag",
		StringName(flag_name),
	)
	var matched: bool = actual == expected_value
	if operator == "!=":
		matched = not matched
	if not matched:
		push_warning(
			"StoryFlagCheck '%s %s %s' executed for a non-matching value %s."
			% [
				flag_name,
				operator,
				FlagEventUtil.value_text(expected_value),
				FlagEventUtil.value_text(actual),
			]
		)

	var message := "CHECK %s was %s; taking the %s branch." % [
		flag_name,
		FlagEventUtil.value_text(actual),
		branch,
	]
	if game_stats.has_method("describe_story_flag"):
		var description := String(
			game_stats.call(
				"describe_story_flag",
				StringName(flag_name),
				actual,
			)
		)
		if not description.is_empty():
			message += "\n[i]%s[/i]" % description
	var branch_description := FlagEventUtil.branch_sentence(branch)
	if not branch_description.is_empty():
		message += " [i]%s[/i]" % branch_description
	FlagEventUtil.store_debug_history(
		dialogic,
		message,
		{
			"debug_kind": "CHECK",
			"flag_name": flag_name,
			"flag_value": actual,
			"expected_value": expected_value,
			"operator": operator,
			"branch": branch,
		},
	)
	finish()
