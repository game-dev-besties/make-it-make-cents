extends RefCounted
## Shared parsing and history formatting for compiler-owned story flag events.

const DEBUG_COLOR := Color("#8c5f2f")


static func parse_payload(text: String, prefix: String) -> Dictionary:
	if not text.begins_with(prefix):
		return {}
	var parsed: Variant = JSON.parse_string(text.trim_prefix(prefix).strip_edges())
	return parsed if parsed is Dictionary else {}


static func store_debug_history(
	dialogic: DialogicGameHandler,
	text: String,
	extra_info: Dictionary,
) -> void:
	if not OS.is_debug_build():
		return
	if not is_instance_valid(dialogic) or not dialogic.has_subsystem("History"):
		return
	var history := dialogic.get_subsystem("History")
	if history == null or not history.has_method("store_simple_history_entry"):
		return
	var info := {
		"character": "DEBUG",
		"character_color": DEBUG_COLOR,
		"debug": true,
	}
	info.merge(extra_info, true)
	history.call("store_simple_history_entry", text, "Text", info)


static func value_text(value: Variant) -> String:
	return JSON.stringify(value)


static func branch_sentence(branch: String) -> String:
	if branch.is_empty() or not branch.is_valid_identifier():
		return ""
	var sentence := branch.replace("_", " ")
	sentence = sentence.left(1).to_upper() + sentence.substr(1)
	return sentence + "."
