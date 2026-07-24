extends Node
## Drives the sequence of cutscenes from timelines/index.json.
##
## Flow:
##   start_game() → reset stats, play cutscene[0]
##   on each timeline end → bank unspent budget, play next cutscene
##   after the last → game over (prints total saved for now)
##
## Dialogic is accessed dynamically via /root/Dialogic so this script still
## parses even before the Dialogic addon is installed/enabled.

const INDEX_PATH := "res://generated/timelines/index.json"

var _index: Array = []
var _current: int = -1


func _ready() -> void:
	_load_index()


func _load_index() -> void:
	if not ResourceLoader.exists(INDEX_PATH):
		push_warning("CutsceneRunner: timelines/index.json missing — run `python3 tools/compile_scenes.py`")
		return
	var f := FileAccess.open(INDEX_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		_index = data.get("cutscenes", [])


func _dialogic() -> Node:
	return get_node_or_null("/root/Dialogic")


func start_game() -> void:
	GameStats.reset_for_new_game()
	_current = -1
	_advance()


func start(cutscene_id: String) -> void:
	for i in range(len(_index)):
		if _index[i].get("id") == cutscene_id:
			_current = i
			_play_current()
			return
	push_warning("CutsceneRunner: unknown cutscene '%s'" % cutscene_id)


func _advance() -> void:
	_current += 1
	if _current >= len(_index):
		_on_all_done()
		return
	_play_current()


func _play_current() -> void:
	if _current < 0 or _current >= len(_index):
		return
	var d := _dialogic()
	if d == null:
		push_warning("CutsceneRunner: Dialogic not installed — run ./scripts/install_dialogic.sh and enable the plugin")
		return
	var entry: Dictionary = _index[_current]
	GameStats.begin_cutscene(int(entry.get("budget", 0)))
	# `d.PhraseCut` isn't available: that shortcut property is normally added to
	# DialogicGameHandler.gd by editor codegen when a custom subsystem is
	# registered, which never ran for this addon. get_subsystem() works unconditionally.
	d.get_subsystem("PhraseCut").load_for(String(entry.get("phrases", "")))
	if d.has_signal("timeline_ended"):
		d.timeline_ended.connect(_on_timeline_ended, CONNECT_ONE_SHOT)
	d.start(String(entry.get("timeline", "")))


func _on_timeline_ended() -> void:
	GameStats.end_cutscene()
	_advance()


func _on_all_done() -> void:
	print("Game complete. Total saved: $%d" % GameStats.money_total_saved)
	# TODO: show an ending screen instead of a log line.
