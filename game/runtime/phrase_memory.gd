extends Node
## Remembers the latest phrase-cut delivery so Dialogic conditions can branch
## on both selected phrases and recovery choices.

var _known: Dictionary = {}
var _kept: Dictionary = {}
var _delivery_mode: StringName = &""
var _could_afford_speech := false


func set_line(
	known_ids: Array,
	kept_ids: Array,
	delivery_mode: StringName = &"normal",
	could_afford_speech: bool = false,
) -> void:
	_known.clear()
	_kept.clear()
	_delivery_mode = delivery_mode
	_could_afford_speech = could_afford_speech
	for raw_id: Variant in known_ids:
		_known[String(raw_id)] = true
	for raw_id: Variant in kept_ids:
		_kept[String(raw_id)] = true


func kept(id: String) -> bool:
	return bool(_kept.get(id, false))


func removed(id: String) -> bool:
	return bool(_known.get(id, false)) and not bool(_kept.get(id, false))


func delivery_is(mode: String) -> bool:
	return _delivery_mode == StringName(mode)


func get_delivery_mode() -> StringName:
	return _delivery_mode


func kept_count() -> int:
	return _kept.size()


func known_count() -> int:
	return _known.size()


func could_afford_speech() -> bool:
	return _could_afford_speech
