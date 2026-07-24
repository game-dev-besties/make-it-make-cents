extends Node
## Remembers labelled choices from the latest phrase-cut line so Dialogic
## conditions such as `kept("calm")` retain their original behaviour.

var _known: Dictionary = {}
var _kept: Dictionary = {}


func set_line(known_ids: Array, kept_ids: Array) -> void:
	_known.clear()
	_kept.clear()
	for raw_id: Variant in known_ids:
		_known[String(raw_id)] = true
	for raw_id: Variant in kept_ids:
		_kept[String(raw_id)] = true


func kept(id: String) -> bool:
	return bool(_kept.get(id, false))


func removed(id: String) -> bool:
	return bool(_known.get(id, false)) and not bool(_kept.get(id, false))


func kept_count() -> int:
	return _kept.size()
