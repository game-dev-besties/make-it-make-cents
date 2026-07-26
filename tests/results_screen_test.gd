extends SceneTree

const RESULTS_SCENE := preload("res://ui/results/results_screen.tscn")
const GAME_STATE_SCRIPT := preload("res://game/runtime/game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := RESULTS_SCENE.instantiate() as ResultsScreen
	root.add_child(screen)
	await process_frame

	var state: GameStateStore = GAME_STATE_SCRIPT.new()
	state.money_total_spent = 37
	state.delivery_jingles_sung = 4
	state.delivery_grunts_said = 3
	state.delivery_nothings_said = 8

	var dad_face := screen.get_node_or_null("%DadFace") as TextureRect
	var grandma_face := screen.get_node_or_null("%GrandmaFace") as TextureRect
	var son_face := screen.get_node_or_null("%SonFace") as TextureRect
	var family_house := screen.get_node_or_null("%FamilyHouse") as TextureRect
	var pennybot_ending := (
		screen.get_node_or_null("%PennybotEnding") as MoneybotCompanion
	)
	var main_menu_button := screen.get_node_or_null("%MainMenuButton") as Button
	_check(
		dad_face != null
		and grandma_face != null
		and son_face != null
		and family_house != null
		and pennybot_ending != null
		and main_menu_button != null,
		(
			"The results panel should expose its house, ending prop, face row, "
			+ "and Main Menu action."
		),
	)
	_check(
		family_house.texture != null
		and family_house.texture.resource_path.ends_with("family_house.png")
		and family_house.modulate.v < 0.8,
		"The results screen should use a dimmed family-house background.",
	)
	_check(
		pennybot_ending.size.x >= 220.0
		and pennybot_ending.size.y >= 260.0,
		"The ending Pennybot should be substantially larger than its stage companion.",
	)
	_check(
		screen.find_children("*", "Button", true, false).size() == 1
		and main_menu_button.text == "Main Menu",
		"The sketch layout should have one Main Menu button.",
	)

	for outcome_mask: int in range(8):
		var dad_good := bool(outcome_mask & 1)
		var grandma_good := bool(outcome_mask & 2)
		var son_good := bool(outcome_mask & 4)
		var good_count := int(dad_good) + int(grandma_good) + int(son_good)
		state.set_story_flag(&"dad_got_job", dad_good)
		state.set_story_flag(
			&"dad_offended_interviewer",
			"none" if dad_good else "soda",
		)
		state.set_story_flag(&"got_prescription", grandma_good)
		state.set_story_flag(&"got_the_girl", "yes" if son_good else "no")
		state.set_story_flag(&"family_stays", good_count >= 2)
		screen.present(state)
		await process_frame

		_check(screen.visible, "Presenting results should reveal the screen.")
		_check(
			screen.dad_good_outcome == dad_good
			and screen.grandma_good_outcome == grandma_good
			and screen.son_good_outcome == son_good,
			"Outcome mask %d should select the matching three faces."
			% outcome_mask,
		)
		_check(
			_face_matches_outcome(dad_face, "dad", dad_good)
			and _face_matches_outcome(grandma_face, "grandma", grandma_good)
			and _face_matches_outcome(son_face, "son", son_good),
			"Outcome mask %d should put the expected textures in the face row."
			% outcome_mask,
		)
		var family_stays := good_count >= 2
		var expected_summary := (
			(
				"Good job, little robot! "
				+ "Looks like they’re here to stay because of you."
			)
			if family_stays
			else (
				"That robot is going straight to the garbage. "
				+ "You couldn’t even do better than Ohio."
			)
		)
		_check(
			(screen.get_node("%EndingTitle") as Label).text
			== ("PENNYBOT 4000" if family_stays else "SCRAP PARTS"),
			"Outcome mask %d should show the final ending name." % outcome_mask,
		)
		_check(
			screen.family_stays_outcome == family_stays
			and pennybot_ending.visible == family_stays,
			(
				"Outcome mask %d should show the corner Pennybot only when "
				+ "the family stays."
			)
			% outcome_mask,
		)
		_check(
			(screen.get_node("%SummaryLabel") as Label).text == expected_summary,
			(
				"Outcome mask %d should move the matching Chapter 6 ending "
				+ "description into the results card."
			)
			% outcome_mask,
		)

	state.set_story_flag(&"dad_got_job", false)
	state.set_story_flag(&"dad_offended_interviewer", "none")
	screen.present(state)
	await process_frame
	_check(
		not screen.dad_good_outcome,
		"Not offending the interviewer should not imply that Dad was hired.",
	)

	var all_label_text := ""
	for label: Label in screen.find_children("*", "Label", true, false):
		all_label_text += label.text + "\n"
	_check(
		not all_label_text.contains("GOOD OUTCOME")
		and not all_label_text.contains("SILLY OUTCOME"),
		"The face row should not enumerate good or silly outcomes.",
	)
	_check(
		(screen.get_node("%MoneySpentValue") as Label).text == "$37"
		and (screen.get_node("%JinglesSungValue") as Label).text == "4"
		and (screen.get_node("%GruntsSaidValue") as Label).text == "3"
		and (screen.get_node("%NothingsSaidValue") as Label).text == "8",
		"The stats list should display concrete campaign totals.",
	)

	screen.dismiss()
	_check(not screen.visible, "Dismissing results should hide the screen.")
	screen.queue_free()
	state.free()
	await process_frame
	_finish()


func _face_matches_outcome(
	face: TextureRect,
	character_name: String,
	good_outcome: bool,
) -> bool:
	var atlas := face.texture as AtlasTexture
	if atlas == null or atlas.atlas == null:
		return false
	var suffix := "good.png" if good_outcome else "silly.png"
	return atlas.atlas.resource_path.ends_with(
		"%s_%s" % [character_name, suffix],
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Results screen checks passed.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("FAIL: ", failure)
	quit(1)
