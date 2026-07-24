class_name DialogicPhraseCutSubsystem
extends DialogicSubsystem
## Loads phrase-cut metadata from a timeline's adjacent `.phrases.json` file.
##
## Legacy compiled timelines use `phrase_cut <speaker> <line_id>` events and
## keep their editable phrase segments in a sidecar JSON file. Keeping the
## sidecar beside the timeline makes those files portable to an episode folder
## and removes the old CutsceneRunner loading dependency.

var _current: Dictionary = {}
var _loaded_path: String = ""


func _clear_state(_clear_flag: int = DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	# Do not clear metadata here. Dialogic can reset subsystems while the layout
	# is first becoming ready, after a PhraseCut event has resolved its sidecar.
	pass


func load_for(phrases_res_path: String) -> void:
	_loaded_path = phrases_res_path
	_current.clear()
	if phrases_res_path.is_empty() or not FileAccess.file_exists(phrases_res_path):
		return

	var phrase_file: FileAccess = FileAccess.open(phrases_res_path, FileAccess.READ)
	if phrase_file == null:
		return
	var parsed: Variant = JSON.parse_string(phrase_file.get_as_text())
	if parsed is Dictionary:
		_current = parsed


func ensure_loaded_for_timeline(timeline_path: String) -> void:
	if timeline_path.is_empty():
		return
	# The old compiler wrote `dad.dtl` + `dad.phrases.json`. The native
	# episode port keeps the resource simply as `phrases.json` beside
	# `dialogue.dtl`; support both without requiring runtime coordination.
	var legacy_sidecar_path: String = "%s.phrases.json" % timeline_path.get_basename()
	var episode_sidecar_path: String = timeline_path.get_base_dir().path_join("phrases.json")
	var sidecar_path: String = legacy_sidecar_path if FileAccess.file_exists(legacy_sidecar_path) else episode_sidecar_path
	if sidecar_path != _loaded_path:
		load_for(sidecar_path)


func get_data(line_id: String) -> Dictionary:
	var data: Variant = _current.get(line_id, {})
	return data if data is Dictionary else {}
