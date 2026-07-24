extends RefCounted
## UI-independent runtime for the direct JSON dialogue format.
##
## submit_phrase() returns the matched response as a line. The following
## advance() enters that response's `next` node.

const FORMAT_VERSION := 1
const DELIVERY_MODES: Array[String] = ["speech", "silence", "pity", "sponsor"]
const CUE_FIELDS: Array[String] = ["expression", "background", "music", "sfx"]
const MATCH_FIELDS: Array[String] = ["exact", "all", "any", "none"]
const EFFECT_FIELDS: Array[String] = ["budget", "success", "silly"]
const RESPONSE_FIELDS: Array[String] = [
	"match", "speaker", "text", "next",
	"expression", "background", "music", "sfx",
	"budget", "success", "silly",
]

var _dialogue: Dictionary = {}
var _state: Dictionary = {}
var _node_id := ""
var _pending_next := ""
var _validation_errors: Array[String] = []
var _last_error := ""


func load_dialogue(path: String) -> Error:
	_reset()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error := FileAccess.get_open_error()
		_last_error = "Could not open dialogue file '%s' (error %d)." % [path, open_error]
		return open_error
	return load_json(file.get_as_text())


func load_json(json_text: String) -> Error:
	_reset()
	var parser := JSON.new()
	if parser.parse(json_text) != OK:
		_last_error = "Invalid dialogue JSON at line %d: %s" % [
			parser.get_error_line(),
			parser.get_error_message(),
		]
		return ERR_PARSE_ERROR
	if not parser.data is Dictionary:
		_last_error = "Dialogue JSON root must be an object."
		return ERR_INVALID_DATA

	var data: Dictionary = parser.data
	if not _validate(data):
		_last_error = "Invalid dialogue data:\n- " + "\n- ".join(_validation_errors)
		return ERR_INVALID_DATA
	_dialogue = data.duplicate(true)
	return OK


func start() -> Dictionary:
	if _dialogue.is_empty():
		return _fail("Load a valid dialogue before calling start().")
	var initial: Dictionary = _dialogue["initial_state"]
	_state = {
		"budget": int(initial["budget"]),
		"success": int(initial["success"]),
		"silly": int(initial["silly"]),
		"pity_used": false,
		"sponsor_used": false,
	}
	_pending_next = ""
	_last_error = ""
	return _enter(String(_dialogue["start"]))


func dialogue_id() -> String:
	return String(_dialogue.get("id", ""))


func state() -> Dictionary:
	return _state.duplicate(true)


func last_error() -> String:
	return _last_error


func advance() -> Dictionary:
	if _node_id.is_empty():
		return _fail("Call start() before advance().")
	if not _pending_next.is_empty():
		var next_id := _pending_next
		_pending_next = ""
		return _enter(next_id)

	var node := _source_node()
	match String(node["type"]):
		"line":
			return _enter(String(node["next"]))
		"phrase":
			return _fail("Submit the current phrase before advancing.")
		"end":
			return _enter(_node_id)
	return _fail("Current node has an unsupported type.")


func submit_phrase(kept_ids: Array[String], delivery_mode: String) -> Dictionary:
	if _node_id.is_empty():
		return _fail("Call start() before submitting a phrase.")
	if not _pending_next.is_empty():
		return _fail("Advance past the current response before submitting again.")
	var node := _source_node()
	if String(node.get("type", "")) != "phrase":
		return _fail("The current node is not a phrase node.")
	if not delivery_mode in DELIVERY_MODES:
		return _fail("Unknown delivery mode '%s'." % delivery_mode)
	if delivery_mode != "speech" and not kept_ids.is_empty():
		return _fail("Delivery mode '%s' cannot include kept phrase ids." % delivery_mode)
	if delivery_mode == "pity" and not can_use_pity():
		return _fail("The one-time pity delivery has already been used.")
	if delivery_mode == "sponsor" and not can_use_sponsor():
		return _fail("The one-time sponsor delivery has already been used.")

	var selected: Dictionary = {}
	for kept_id in kept_ids:
		if selected.has(kept_id):
			return _fail("Phrase id '%s' was submitted more than once." % kept_id)
		selected[kept_id] = true

	var cost := 0
	var known: Dictionary = {}
	for value: Variant in node["segments"]:
		var segment: Dictionary = value
		var segment_id := String(segment["id"])
		known[segment_id] = true
		if selected.has(segment_id):
			cost += _segment_cost(segment)
	for kept_id in kept_ids:
		if not known.has(kept_id):
			return _fail("Unknown phrase id '%s' for node '%s'." % [kept_id, _node_id])

	if cost > int(_state["budget"]):
		return _fail("Phrase costs %d, but only %d budget remains." % [
			cost,
			int(_state["budget"]),
		])

	var response: Dictionary = {}
	for value: Variant in node.get("responses", []):
		var candidate: Dictionary = value
		if _matches(candidate["match"], selected, delivery_mode):
			response = candidate
			break
	if response.is_empty():
		response = node["fallback"]

	_state["budget"] = int(_state["budget"]) - cost
	if delivery_mode == "pity":
		_state["pity_used"] = true
	elif delivery_mode == "sponsor":
		_state["sponsor_used"] = true
	_apply_effects(response)

	var display := response.duplicate(true)
	for field in ["match", "next", "budget", "success", "silly"]:
		display.erase(field)
	display["type"] = "line"
	_pending_next = String(response["next"])
	_last_error = ""
	return display


func can_use_pity() -> bool:
	return _can_use_recovery("pity_used")


func can_use_sponsor() -> bool:
	return _can_use_recovery("sponsor_used")


func _can_use_recovery(state_key: String) -> bool:
	return (
		not _node_id.is_empty()
		and _pending_next.is_empty()
		and String(_source_node().get("type", "")) == "phrase"
		and not bool(_state.get(state_key, false))
	)


func _enter(node_id: String) -> Dictionary:
	_node_id = node_id
	var nodes: Dictionary = _dialogue["nodes"]
	var node: Dictionary = nodes[node_id]
	var display := node.duplicate(true)
	display["id"] = node_id
	if String(display.get("type", "")) == "phrase":
		for value: Variant in display["segments"]:
			var segment: Dictionary = value
			segment["cost"] = _segment_cost(segment)
	_last_error = ""
	return display


func _source_node() -> Dictionary:
	if _node_id.is_empty():
		return {}
	var nodes: Dictionary = _dialogue["nodes"]
	return nodes.get(_node_id, {})


func _matches(match_data: Dictionary, selected: Dictionary, delivery: String) -> bool:
	if String(match_data.get("delivery", "speech")) != delivery:
		return false
	if match_data.has("exact"):
		var exact: Array = match_data["exact"]
		if exact.size() != selected.size() or not _has_all(selected, exact):
			return false
	if match_data.has("all") and not _has_all(selected, match_data["all"]):
		return false
	if match_data.has("any"):
		var found := false
		for phrase_id: Variant in match_data["any"]:
			if selected.has(String(phrase_id)):
				found = true
				break
		if not found:
			return false
	if match_data.has("none"):
		for phrase_id: Variant in match_data["none"]:
			if selected.has(String(phrase_id)):
				return false
	return true


func _has_all(selected: Dictionary, required: Array) -> bool:
	for phrase_id: Variant in required:
		if not selected.has(String(phrase_id)):
			return false
	return true


func _segment_cost(segment: Dictionary) -> int:
	if segment.has("cost"):
		return int(segment["cost"])
	return String(segment["text"]).split(" ", false).size()


func _apply_effects(response: Dictionary) -> void:
	_state["budget"] = maxi(0, int(_state["budget"]) + int(response.get("budget", 0)))
	_state["success"] = clampi(int(_state["success"]) + int(response.get("success", 0)), 1, 10)
	_state["silly"] = clampi(int(_state["silly"]) + int(response.get("silly", 0)), 0, 10)


func _reset() -> void:
	_dialogue.clear()
	_state.clear()
	_node_id = ""
	_pending_next = ""
	_validation_errors.clear()
	_last_error = ""


func _fail(message: String) -> Dictionary:
	_last_error = message
	return {}


# Validation stays here (rather than in a compiler) so a bad JSON file fails
# immediately with a writer-readable path.
func _validate(data: Dictionary) -> bool:
	_validation_errors.clear()
	_require_string(data, "id", "root")
	_require_string(data, "start", "root")
	if not data.has("format_version") or not _is_integer(data["format_version"]):
		_error("root.format_version must be an integer.")
	elif int(data["format_version"]) != FORMAT_VERSION:
		_error("root.format_version must be %d." % FORMAT_VERSION)

	if not data.get("initial_state") is Dictionary:
		_error("root.initial_state must be an object.")
	else:
		_validate_initial_state(data["initial_state"])
	if not data.get("nodes") is Dictionary:
		_error("root.nodes must be an object.")
		return false

	var nodes: Dictionary = data["nodes"]
	if nodes.is_empty():
		_error("root.nodes cannot be empty.")
	if data.get("start") is String and not nodes.has(data["start"]):
		_error("root.start references missing node '%s'." % data["start"])
	for key: Variant in nodes:
		if String(key).is_empty():
			_error("Every node key must be a non-empty string.")
		elif not nodes[key] is Dictionary:
			_error("nodes.%s must be an object." % key)
		else:
			_validate_node(String(key), nodes[key], nodes)
	return _validation_errors.is_empty()


func _validate_initial_state(initial: Dictionary) -> void:
	for field in ["budget", "success", "silly"]:
		if not initial.has(field) or not _is_integer(initial[field]):
			_error("root.initial_state.%s must be an integer." % field)
	if initial.has("budget") and _is_integer(initial["budget"]) and int(initial["budget"]) < 0:
		_error("root.initial_state.budget cannot be negative.")
	if initial.has("success") and _is_integer(initial["success"]):
		if int(initial["success"]) < 1 or int(initial["success"]) > 10:
			_error("root.initial_state.success must be between 1 and 10.")
	if initial.has("silly") and _is_integer(initial["silly"]):
		if int(initial["silly"]) < 0 or int(initial["silly"]) > 10:
			_error("root.initial_state.silly must be between 0 and 10.")


func _validate_node(node_id: String, node: Dictionary, nodes: Dictionary) -> void:
	var path := "nodes.%s" % node_id
	if not _require_string(node, "type", path):
		return
	match String(node["type"]):
		"line":
			_validate_line(node, path)
			_validate_next(node, path, nodes)
		"phrase":
			_validate_phrase(node, path, nodes)
		"end":
			pass
		_:
			_error("%s.type must be line, phrase, or end." % path)


func _validate_line(line: Dictionary, path: String) -> void:
	_require_string(line, "speaker", path, true)
	_require_string(line, "text", path, true)
	for cue in CUE_FIELDS:
		if line.has(cue) and not line[cue] is String:
			_error("%s.%s must be a string." % [path, cue])


func _validate_phrase(node: Dictionary, path: String, nodes: Dictionary) -> void:
	_require_string(node, "speaker", path, true)
	for cue in CUE_FIELDS:
		if node.has(cue) and not node[cue] is String:
			_error("%s.%s must be a string." % [path, cue])
	if not node.get("segments") is Array:
		_error("%s.segments must be an array." % path)
		return

	var ids: Dictionary = {}
	var segments: Array = node["segments"]
	if segments.is_empty():
		_error("%s.segments cannot be empty." % path)
	for index in range(segments.size()):
		var segment_path := "%s.segments[%d]" % [path, index]
		if not segments[index] is Dictionary:
			_error("%s must be an object." % segment_path)
			continue
		var segment: Dictionary = segments[index]
		if _require_string(segment, "id", segment_path):
			var segment_id := String(segment["id"])
			if ids.has(segment_id):
				_error("%s.id '%s' is duplicated." % [segment_path, segment_id])
			ids[segment_id] = true
		_require_string(segment, "text", segment_path)
		if segment.has("cost"):
			if not _is_integer(segment["cost"]):
				_error("%s.cost must be an integer." % segment_path)
			elif int(segment["cost"]) < 0:
				_error("%s.cost cannot be negative." % segment_path)

	if node.has("responses"):
		if not node["responses"] is Array:
			_error("%s.responses must be an array." % path)
		else:
			for index in range(node["responses"].size()):
				_validate_response(
					node["responses"][index],
					"%s.responses[%d]" % [path, index],
					nodes,
					ids,
					true,
				)
	if not node.has("fallback"):
		_error("%s.fallback is required." % path)
	else:
		_validate_response(node["fallback"], "%s.fallback" % path, nodes, ids, false)


func _validate_response(
	value: Variant,
	path: String,
	nodes: Dictionary,
	ids: Dictionary,
	require_match: bool,
) -> void:
	if not value is Dictionary:
		_error("%s must be an object." % path)
		return
	var response: Dictionary = value
	if require_match:
		if not response.get("match") is Dictionary:
			_error("%s.match must be an object." % path)
		else:
			_validate_match(response["match"], "%s.match" % path, ids)
	for field: Variant in response:
		if not field in RESPONSE_FIELDS:
			_error("%s.%s is not a supported response field." % [path, field])
	_validate_line(response, path)
	for effect in EFFECT_FIELDS:
		if response.has(effect) and not _is_integer(response[effect]):
			_error("%s.%s must be an integer." % [path, effect])
	_validate_next(response, path, nodes)


func _validate_match(match_data: Dictionary, path: String, ids: Dictionary) -> void:
	for key: Variant in match_data:
		if not key in MATCH_FIELDS and key != "delivery":
			_error("%s.%s is not a supported matcher." % [path, key])
	for field in MATCH_FIELDS:
		if not match_data.has(field):
			continue
		if not match_data[field] is Array:
			_error("%s.%s must be an array." % [path, field])
			continue
		for value: Variant in match_data[field]:
			if not value is String or not ids.has(value):
				_error("%s.%s references unknown phrase id '%s'." % [path, field, value])
	if match_data.has("delivery"):
		if not match_data["delivery"] is String or not match_data["delivery"] in DELIVERY_MODES:
			_error("%s.delivery must be speech, silence, pity, or sponsor." % path)


func _validate_next(value: Dictionary, path: String, nodes: Dictionary) -> void:
	if _require_string(value, "next", path) and not nodes.has(value["next"]):
		_error("%s.next references missing node '%s'." % [path, value["next"]])


func _require_string(
	value: Dictionary,
	field: String,
	path: String,
	allow_empty: bool = false,
) -> bool:
	if not value.has(field) or not value[field] is String:
		_error("%s.%s must be a string." % [path, field])
		return false
	if not allow_empty and String(value[field]).is_empty():
		_error("%s.%s cannot be empty." % [path, field])
		return false
	return true


func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and value == floorf(value))


func _error(message: String) -> void:
	_validation_errors.append(message)
