@tool
extends DialogicIndexer
## Dialogic extension index for phrase cutting and editor-authored stage cues.
##
## Configure Dialogic's `dialogic/extensions_folder` setting to
## `res://addons/legendary_dialogic` so it discovers this folder.


func _get_events() -> Array:
	return [
		this_folder.path_join("event_phrase_cut.gd"),
		this_folder.path_join("event_presentation_cue.gd"),
		this_folder.path_join("event_budget_set.gd"),
		this_folder.path_join("event_recovery_policy.gd"),
		this_folder.path_join("event_goto_label.gd"),
		this_folder.path_join("event_story_flag_set.gd"),
		this_folder.path_join("event_story_flag_check.gd"),
	]


func _get_subsystems() -> Array[Dictionary]:
	return [{"name": "PhraseCut", "script": this_folder.path_join("subsystem_phrase_cut.gd")}]
