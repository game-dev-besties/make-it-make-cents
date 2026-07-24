class_name DialogicPhraseCutSubsystem
extends DialogicSubsystem
## Loads phrase-cut metadata from a timeline's adjacent `.phrases.json` file.

var _current: Dictionary = {}
var _loaded_path: String = ""
var _loaded_timeline_path: String = ""
var _pending_recovery_policy: StringName = &""


func _clear_state(_clear_flag: int = DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	# Do not clear metadata here. Dialogic can reset subsystems while the layout
	# is first becoming ready, after a PhraseCut event has resolved its sidecar.
	clear_recovery_policy()


func load_for(phrases_res_path: String, timeline_res_path: String = "") -> void:
	_loaded_path = phrases_res_path
	_loaded_timeline_path = timeline_res_path
	_current.clear()
	clear_recovery_policy()
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


func set_recovery_policy(policy: StringName) -> bool:
	if policy == &"both":
		policy = &"pity,sponsor"
	if policy not in [&"pity", &"sponsor", &"pity,sponsor", &"none"]:
		return false
	_pending_recovery_policy = policy
	return true


func consume_recovery_policy() -> Dictionary:
	if _pending_recovery_policy.is_empty():
		return {}
	var policy := _pending_recovery_policy
	clear_recovery_policy()
	return {
		"allow_pity": policy == &"pity" or policy == &"pity,sponsor",
		"allow_sponsor": policy == &"sponsor" or policy == &"pity,sponsor",
	}


func clear_recovery_policy() -> void:
	_pending_recovery_policy = &""
