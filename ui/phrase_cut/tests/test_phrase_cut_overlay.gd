extends SceneTree

const OVERLAY_SCENE := preload("res://ui/phrase_cut/phrase_cut_overlay.tscn")
const PHRASE_MEMORY_SCRIPT := preload("res://game/runtime/phrase_memory.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var normal: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(normal)
	normal.setup(
		[
			{"type": "phrase", "id": "intro", "text": "I have", "cost": 2},
			{"type": "phrase", "id": "learner", "text": "learn very fast"},
		],
		5,
		"Dad",
	)
	await process_frame

	var normal_chips: Array[Node] = normal.get_node("%Chips").get_children()
	_assert(normal_chips.size() == 2, "expected two phrase chips")
	(normal_chips[0] as Button).button_pressed = false
	normal.call("_on_confirm")
	_assert(normal.result.delivery_mode == &"normal", "kept text should be a normal delivery")
	_assert(normal.result.kept_text == "learn very fast", "chip state should determine assembled text")
	_assert(normal.result.cost == 3, "missing phrase cost should be counted from words")
	_assert(normal.result.kept_ids == ["learner"], "only pressed chip IDs should be kept")
	normal.queue_free()

	var silence: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(silence)
	silence.setup([{"type": "phrase", "id": "only", "text": "Anything", "cost": 1}], 4, "Dad")
	await process_frame
	(silence.get_node("%Chips").get_child(0) as Button).button_pressed = false
	silence.call("_on_confirm")
	_assert(silence.result.delivery_mode == &"silence", "all removed phrases should resolve as silence")
	_assert(silence.result.cost == 0, "silence should be free")
	silence.queue_free()

	var recovery: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(recovery)
	recovery.setup(
		[{"type": "phrase", "id": "only", "text": "Anything", "cost": 1}],
		0,
		"Dad",
		{"can_use_pity": true, "can_use_sponsor": false},
	)
	await process_frame
	_assert(recovery.get_node("%RecoveryBox").visible, "zero budget should reveal recovery choices")
	_assert((recovery.get_node("%Chips").get_child(0) as Button).disabled, "zero budget should disable phrase delivery")
	_assert(recovery.get_node("%PityButton").visible, "available pity choice should be visible")
	_assert(not recovery.get_node("%SponsorButton").visible, "unavailable sponsor choice should be hidden")
	recovery.call("_on_pity")
	_assert(recovery.result.delivery_mode == &"pity", "pity button should report pity delivery")
	_assert(recovery.result.kept_text == "hnf", "default pity line should be the grunt")
	recovery.queue_free()

	var free_phrase: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(free_phrase)
	free_phrase.setup(
		[
			{"type": "phrase", "id": "free", "text": "Free word", "cost": 0},
			{"type": "phrase", "id": "taxed", "text": "Taxed word", "cost": 1},
		],
		0,
		"Dad",
	)
	await process_frame
	var free_chips: Array[Node] = free_phrase.get_node("%Chips").get_children()
	_assert(not (free_chips[0] as Button).disabled, "a free phrase should remain usable at zero budget")
	_assert((free_chips[1] as Button).disabled, "a taxed phrase should remain unavailable at zero budget")
	_assert(free_phrase.get_node("%ConfirmButton").visible, "free delivery should remain confirmable")
	free_phrase.call("_on_confirm")
	_assert(free_phrase.result.delivery_mode == &"normal", "kept free text should be a normal delivery")
	_assert(free_phrase.result.cost == 0, "a free phrase should cost zero")
	free_phrase.queue_free()

	var free_fixed: PhraseCutOverlay = OVERLAY_SCENE.instantiate()
	root.add_child(free_fixed)
	free_fixed.setup(
		[{"type": "fixed", "text": "Untaxed sound", "cost": 0}],
		0,
		"Dad",
	)
	await process_frame
	_assert(free_fixed.get_node("%ConfirmButton").visible, "free fixed text should remain confirmable")
	free_fixed.call("_on_confirm")
	_assert(free_fixed.result.kept_text == "Untaxed sound", "free fixed text should be delivered")
	_assert(free_fixed.result.cost == 0, "free fixed text should cost zero")
	free_fixed.queue_free()

	var memory: Node = PHRASE_MEMORY_SCRIPT.new()
	memory.call("set_line", ["intro", "learner"], ["learner"], &"sponsor")
	_assert(memory.call("kept", "learner"), "phrase memory should retain kept IDs")
	_assert(memory.call("removed", "intro"), "phrase memory should retain removed IDs")
	_assert(memory.call("delivery_is", "sponsor"), "phrase memory should retain delivery mode")
	memory.free()

	var stats := GameStateStore.new()
	var phrase_event := DialogicPhraseCutEvent.new()
	phrase_event.from_text("phrase_cut teen-son (nervous) test_L001")
	_assert(phrase_event.speaker == "teen-son", "phrase events should accept compiler-valid hyphenated speakers")
	phrase_event.speaker = "dad"
	stats.begin_cutscene(5)
	phrase_event.call(
		"_apply_delivery",
		stats,
		{"delivery_mode": &"normal", "kept_text": "three taxed words", "cost": 3},
	)
	_assert(stats.remaining_budget() == 2, "normal delivery should spend its phrase cost")
	stats.spend(2)
	var sponsor_result := {"delivery_mode": &"sponsor", "kept_text": "Sponsor", "cost": 0}
	phrase_event.call("_apply_delivery", stats, sponsor_result)
	_assert(stats.remaining_budget() == 3, "sponsor delivery should grant three budget")
	_assert(stats.sponsor_used, "sponsor recovery should be one-time state")
	_assert(stats.dad_success == 2, "sponsor delivery should tank the speaker's success score")
	stats.free()

	if not _failures.is_empty():
		for failure in _failures:
			printerr("FAIL: ", failure)
		quit(1)
		return
	print("Phrase-cut focused checks passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
