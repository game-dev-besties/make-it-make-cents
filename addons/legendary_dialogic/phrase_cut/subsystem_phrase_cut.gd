class_name DialogicPhraseCutSubsystem
extends DialogicSubsystem
## Loads phrase-cut metadata from a timeline's adjacent `.phrases.json` file.

var _current: Dictionary = {}
var _loaded_path: String = ""
var _loaded_timeline_path: String = ""


func _clear_state(_clear_flag: int = DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	# Do not clear metadata here. Dialogic can reset subsystems while the layout
	# is first becoming ready, after a PhraseCut event has resolved its sidecar.
	pass


func load_for(phrases_res_path: String, timeline_res_path: String = "") -> void:
	_loaded_path = phrases_res_path
	_loaded_timeline_path = timeline_res_path
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
	# CampaignPlayer may have explicitly selected a sidecar for this timeline.
	if timeline_path == _loaded_timeline_path and not _loaded_path.is_empty():
		return
	var sidecar_path := timeline_path.get_base_dir().path_join("phrases.json")
	if sidecar_path != _loaded_path or timeline_path != _loaded_timeline_path:
		load_for(sidecar_path, timeline_path)


func get_data(line_id: String) -> Dictionary:
	var data: Variant = _current.get(line_id, {})
	return data if data is Dictionary else {}
