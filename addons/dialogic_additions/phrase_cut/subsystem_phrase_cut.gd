class_name DialogicPhraseCutSubsystem
extends DialogicSubsystem
## Caches the current cutscene's phrase-cut metadata (generated/timelines/*.phrases.json)
## so PhraseCut events can look up their segments by line id.
##
## CutsceneRunner calls Dialogic.get_subsystem("PhraseCut").load_for(...)
## before starting a cutscene.

var _current: Dictionary = {}


func _clear_state(_clear_flag := DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	# Deliberately NOT clearing _current here. Dialogic calls _clear_state() as
	# part of its generic subsystem-reset cycle — notably once, bound to the
	# layout scene's one-time `ready` signal on the very first Dialogic.start()
	# call (see DialogicGameHandler.start()/ClearFlags.KEEP_VARIABLES). On a
	# slow load (observed on web export) that deferred signal can fire AFTER
	# CutsceneRunner has already called load_for() for the real cutscene,
	# wiping the just-loaded phrase data before the first phrase_cut event
	# reads it. This subsystem's data lifecycle is owned entirely by
	# CutsceneRunner's explicit load_for() calls, once per cutscene — it
	# doesn't need or want Dialogic's generic clear to touch it.
	pass


func load_for(phrases_res_path: String) -> void:
	if not phrases_res_path.is_empty() and ResourceLoader.exists(phrases_res_path):
		var f := FileAccess.open(phrases_res_path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_current = parsed
				return
	_current.clear()


func get_data(line_id: String) -> Dictionary:
	return _current.get(line_id, {})
