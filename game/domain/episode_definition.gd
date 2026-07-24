class_name EpisodeDefinition
extends Resource
## Inspector-authored content required to play one episode.

@export var id: StringName
@export var title := ""
@export_multiline var description := ""
@export var presentation_scene: PackedScene
@export_file("*.dtl") var dialogue_timeline_path := ""
@export_file("*.json") var phrase_data_path := ""
@export_range(0, 100000, 1, "or_greater") var word_budget := 0
@export var state_changes: Dictionary = {}
@export var routes: Array[CampaignRoute] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Episode has no ID.")
	if presentation_scene == null:
		errors.append("Episode '%s' has no presentation scene." % id)
	if dialogue_timeline_path.is_empty():
		errors.append("Episode '%s' has no Dialogic timeline path." % id)
	elif not ResourceLoader.exists(dialogue_timeline_path):
		errors.append("Episode '%s' references a missing timeline: %s" % [id, dialogue_timeline_path])
	if not phrase_data_path.is_empty() and not FileAccess.file_exists(phrase_data_path):
		errors.append("Episode '%s' references missing phrase data: %s" % [id, phrase_data_path])
	var exit_ids: Dictionary = {}
	var automatic_route_count := 0
	for route in routes:
		if route == null:
			errors.append("Episode '%s' has an empty route entry." % id)
			continue
		for route_error in route.validate():
			errors.append("Episode '%s': %s" % [id, route_error])
		if route.exit_id.is_empty():
			automatic_route_count += 1
		elif exit_ids.has(route.exit_id):
			errors.append("Episode '%s' has duplicate exit ID '%s'." % [id, route.exit_id])
		else:
			exit_ids[route.exit_id] = true
	if automatic_route_count > 1:
		errors.append("Episode '%s' has more than one automatic route." % id)
	return errors
