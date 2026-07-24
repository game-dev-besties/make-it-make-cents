extends SceneTree

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_happy_path_and_first_match()
	_test_match_combinations_and_fallback()
	_test_delivery_modes_are_one_time()
	_test_validation_errors()
	_test_repository_dialogues_validate()
	if _failures.is_empty():
		print("DialogueRunner: all tests passed")
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	quit(1)


func _test_happy_path_and_first_match() -> void:
	var runner: Variant = RunnerScript.new()
	_check(runner.load_json(_valid_dialogue_json()) == OK, runner.last_error())
	var display: Dictionary = runner.start()
	_check(display.get("id") == "intro", "start() should display the start node")
	_check(runner.state()["budget"] == 5, "start() should restore initial budget")

	display = runner.advance()
	_check(display.get("id") == "offer", "advance() should move line nodes forward")
	var segments: Array = display["segments"]
	_check(segments[0]["cost"] == 1, "single-word phrase cost should be inferred")
	_check(segments[1]["cost"] == 2, "multi-word phrase cost should be inferred")
	var hello_ids: Array[String] = ["hello"]
	display = runner.submit_phrase(hello_ids, "speech")
	_check(display.get("type") == "line", "phrase submission should display a line")
	_check(display.get("text") == "First match.", "first matching response should win")
	var after_submit: Dictionary = runner.state()
	_check(after_submit["budget"] == 4, "kept phrase costs should be deducted")
	_check(after_submit["success"] == 10, "success should clamp to 10")
	_check(after_submit["silly"] == 0, "silly should clamp to 0")

	display = runner.advance()
	_check(display.get("id") == "done", "advance() should leave reply for response.next")
	_check(display.get("type") == "end", "response.next should be able to finish the dialogue")


func _test_delivery_modes_are_one_time() -> void:
	var runner: Variant = RunnerScript.new()
	_check(runner.load_json(_valid_dialogue_json()) == OK, runner.last_error())
	runner.start()
	runner.advance()
	_check(runner.can_use_pity(), "pity should initially be available on a phrase")
	var no_ids: Array[String] = []
	var reply: Dictionary = runner.submit_phrase(no_ids, "pity")
	_check(reply.get("text") == "Hnf.", "pity delivery should use its matching response")
	_check(runner.state()["pity_used"] == true, "pity use should be recorded in state")
	runner.advance()
	_check(not runner.can_use_pity(), "pity should not be available after one use")
	var rejected: Dictionary = runner.submit_phrase(no_ids, "pity")
	_check(rejected.is_empty(), "a second pity delivery should be rejected")
	_check("already been used" in runner.last_error(), "rejected pity should explain why")

	runner.start()
	runner.advance()
	var sponsor_reply: Dictionary = runner.submit_phrase(no_ids, "sponsor")
	_check(sponsor_reply.get("text") == "Buy Sam's.", "sponsor should match by delivery")
	_check(runner.state()["sponsor_used"] == true, "sponsor use should be recorded")
	_check(runner.state()["budget"] == 8, "sponsor effects should replenish budget")


func _test_match_combinations_and_fallback() -> void:
	var runner: Variant = RunnerScript.new()
	_check(runner.load_json(_valid_dialogue_json()) == OK, runner.last_error())
	runner.start()
	runner.advance()
	var country_ids: Array[String] = ["country"]
	var reply: Dictionary = runner.submit_phrase(country_ids, "speech")
	_check(reply.get("text") == "Country only.", "any and none matchers should combine")

	runner.start()
	runner.advance()
	var no_ids: Array[String] = []
	reply = runner.submit_phrase(no_ids, "silence")
	_check(reply.get("text") == "Fallback.", "unmatched selections should use fallback")


func _test_validation_errors() -> void:
	var runner: Variant = RunnerScript.new()
	var invalid := """{
		"format_version": 1,
		"id": "broken",
		"start": "missing",
		"initial_state": {"budget": 1, "success": 5, "silly": 0},
		"nodes": {"end": {"type": "end"}}
	}"""
	_check(runner.load_json(invalid) == ERR_INVALID_DATA, "missing start target should fail validation")
	_check("missing node" in runner.last_error(), "validation failure should name the bad reference")


func _test_repository_dialogues_validate() -> void:
	var directory := "res://story/dialogues"
	if not DirAccess.dir_exists_absolute(directory):
		return
	for file_name in DirAccess.get_files_at(directory):
		if not file_name.ends_with(".json"):
			continue
		var runner: Variant = RunnerScript.new()
		var path := directory.path_join(file_name)
		_check(runner.load_dialogue(path) == OK, "%s: %s" % [path, runner.last_error()])


func _valid_dialogue_json() -> String:
	return """{
		"format_version": 1,
		"id": "test",
		"start": "intro",
		"initial_state": {"budget": 5, "success": 9, "silly": 1},
		"nodes": {
			"intro": {
				"type": "line",
				"speaker": "Dad",
				"text": "Try this.",
				"expression": "cheerful",
				"next": "offer"
			},
			"offer": {
				"type": "phrase",
				"speaker": "Son",
				"segments": [
					{"id": "hello", "text": "Hello"},
					{"id": "country", "text": "beautiful country"}
				],
				"responses": [
					{
						"match": {"all": ["hello"]},
						"speaker": "Dad",
						"text": "First match.",
						"success": 5,
						"silly": -5,
						"next": "done"
					},
					{
						"match": {"exact": ["hello"]},
						"speaker": "Dad",
						"text": "Second match.",
						"next": "done"
					},
					{
						"match": {
							"any": ["country"],
							"none": ["hello"]
						},
						"speaker": "Dad",
						"text": "Country only.",
						"next": "done"
					},
					{
						"match": {"delivery": "pity"},
						"speaker": "Penny",
						"text": "Hnf.",
						"next": "offer"
					},
					{
						"match": {"delivery": "sponsor"},
						"speaker": "Penny",
						"text": "Buy Sam's.",
						"budget": 3,
						"success": -20,
						"next": "done"
					}
				],
				"fallback": {
					"speaker": "Dad",
					"text": "Fallback.",
					"success": -1,
					"next": "done"
				}
			},
			"done": {"type": "end"}
		}
	}"""


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message if not message.is_empty() else "unnamed assertion")
