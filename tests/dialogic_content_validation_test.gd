extends SceneTree
## Static integration check for writer-compiled Dialogic content.
##
## Run with:
##   godot --headless --path . \
##     --script res://tests/dialogic_content_validation_test.gd

const CAMPAIGN_PATH := "res://content/campaign/campaign.tres"
const CHARACTER_ROOT := "res://content/characters"
const EPISODE_ROOT := "res://content/episodes"
const SPONSOR_JINGLE_PATH := "res://audio/sfx/sams_soda_jingle.mp3"

var _failures: Array[String] = []
var _character_count := 0
var _timeline_count := 0
var _phrase_count := 0
var _cue_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Building the cache first ensures project-owned event indexers are present
	# before any timeline is parsed.
	DialogicResourceUtil.get_event_cache()
	_validate_custom_event_registration()
	_validate_registered_characters()
	_validate_sponsor_jingle_asset()

	var campaign := load(CAMPAIGN_PATH) as CampaignDefinition
	_check(
		campaign != null,
		"%s did not load as CampaignDefinition." % CAMPAIGN_PATH,
	)
	if campaign != null:
		for error: String in campaign.validate():
			_failures.append("Campaign validation: %s" % error)
		_validate_compiled_timelines(campaign)

	if _failures.is_empty():
		print(
			(
				"Dialogic content validation passed: %d characters, %d timelines, "
				+ "%d phrase lines, %d presentation cues."
			)
			% [_character_count, _timeline_count, _phrase_count, _cue_count]
		)
		quit(0)
		return

	for failure: String in _failures:
		printerr("FAIL: ", failure)
	quit(1)


func _validate_custom_event_registration() -> void:
	var has_phrase_cut := false
	var has_presentation_cue := false
	var has_budget_set := false
	var has_recovery_policy := false
	var has_goto_label := false
	var has_story_flag_set := false
	var has_story_flag_check := false
	for event: DialogicEvent in DialogicResourceUtil.get_event_cache():
		has_phrase_cut = has_phrase_cut or event is DialogicPhraseCutEvent
		has_presentation_cue = has_presentation_cue or event is DialogicPresentationCueEvent
		has_budget_set = has_budget_set or event is DialogicBudgetSetEvent
		has_recovery_policy = has_recovery_policy or event is DialogicRecoveryPolicyEvent
		has_goto_label = has_goto_label or event is DialogicGotoLabelEvent
		has_story_flag_set = has_story_flag_set or event is DialogicStoryFlagSetEvent
		has_story_flag_check = has_story_flag_check or event is DialogicStoryFlagCheckEvent
		if (
			event is DialogicPhraseCutEvent
			or event is DialogicPresentationCueEvent
			or event is DialogicBudgetSetEvent
			or event is DialogicRecoveryPolicyEvent
			or event is DialogicGotoLabelEvent
			or event is DialogicStoryFlagSetEvent
			or event is DialogicStoryFlagCheckEvent
		):
			_check(
				event.disable_editor_button,
				"%s should be hidden from Dialogic's add-event menu because it is compiler-owned."
				% _event_type_name(event),
			)

	_check(
		has_phrase_cut,
		"Dialogic did not register DialogicPhraseCutEvent. Check "
		+ "`dialogic/extensions_folder` and the Legendary Dialogic indexer.",
	)
	_check(
		has_presentation_cue,
		"Dialogic did not register DialogicPresentationCueEvent. Check "
		+ "`dialogic/extensions_folder` and the Legendary Dialogic indexer.",
	)
	_check(
		has_budget_set,
		"Dialogic did not register DialogicBudgetSetEvent. Check "
		+ "`dialogic/extensions_folder` and the Legendary Dialogic indexer.",
	)
	_check(
		has_recovery_policy,
		"Dialogic did not register DialogicRecoveryPolicyEvent. Check "
		+ "`dialogic/extensions_folder` and the Legendary Dialogic indexer.",
	)
	_check(
		has_goto_label,
		"Dialogic did not register DialogicGotoLabelEvent. Check "
		+ "`dialogic/extensions_folder` and the Legendary Dialogic indexer.",
	)
	_check(
		has_story_flag_set,
		"Dialogic did not register DialogicStoryFlagSetEvent. Check "
		+ "`dialogic/extensions_folder` and the Legendary Dialogic indexer.",
	)
	_check(
		has_story_flag_check,
		"Dialogic did not register DialogicStoryFlagCheckEvent. Check "
		+ "`dialogic/extensions_folder` and the Legendary Dialogic indexer.",
	)


func _validate_registered_characters() -> void:
	var character_paths: Array[String] = []
	if not _collect_files(CHARACTER_ROOT, ".dch", character_paths):
		return
	character_paths.sort()

	var directory: Dictionary = DialogicResourceUtil.get_character_directory()
	for character_path: String in character_paths:
		var identifier_value: Variant = directory.find_key(character_path)
		if identifier_value == null:
			_failures.append(
				(
					"%s is not in Dialogic's character directory. Open Dialogic "
					+ "once or add it under `dialogic/directories/dch_directory`."
				)
				% character_path
			)
			continue

		var identifier := String(identifier_value)
		var character := DialogicResourceUtil.get_character_resource(identifier)
		if character == null:
			_failures.append(
				"%s registers speaker `%s`, but that resource does not load."
				% [character_path, identifier]
			)
			continue

		_character_count += 1
		if not character.default_portrait.is_empty():
			_check(
				character.portraits.has(character.default_portrait),
				(
					"%s (`%s`) declares default expression `%s`, but its portrait "
					+ "dictionary does not contain that key."
				)
				% [character_path, identifier, character.default_portrait],
			)

	for identifier: Variant in directory:
		var registered_path := String(directory[identifier])
		if (
			registered_path.begins_with(CHARACTER_ROOT + "/")
			and not character_paths.has(registered_path)
		):
			_failures.append(
				"Dialogic speaker `%s` points to missing project character %s."
				% [identifier, registered_path]
			)


func _validate_compiled_timelines(campaign: CampaignDefinition) -> void:
	var episodes_by_timeline: Dictionary = {}
	for episode: EpisodeDefinition in campaign.episodes:
		if episode == null or episode.dialogue_timeline_path.is_empty():
			continue
		if episodes_by_timeline.has(episode.dialogue_timeline_path):
			_failures.append(
				"Episodes `%s` and `%s` both use %s."
				% [
					episodes_by_timeline[episode.dialogue_timeline_path].id,
					episode.id,
					episode.dialogue_timeline_path,
				]
			)
		else:
			episodes_by_timeline[episode.dialogue_timeline_path] = episode

	var timeline_paths: Array[String] = []
	if not _collect_files(EPISODE_ROOT, ".dtl", timeline_paths):
		return
	timeline_paths.sort()
	var registered_paths: Array = DialogicResourceUtil.get_timeline_directory().values()

	for timeline_path: String in timeline_paths:
		_check(
			timeline_path in registered_paths,
			(
				"%s is compiled content but is absent from "
				+ "`dialogic/directories/dtl_directory`."
			)
			% timeline_path,
		)
		var episode := episodes_by_timeline.get(timeline_path) as EpisodeDefinition
		_check(
			episode != null,
			(
				"%s has no matching episode in %s; add an EpisodeDefinition so its "
				+ "phrase data and presentation stage can be validated."
			)
			% [timeline_path, CAMPAIGN_PATH],
		)
		_validate_timeline(timeline_path, episode)

	for episode_timeline: String in episodes_by_timeline:
		_check(
			timeline_paths.has(episode_timeline),
			"Episode `%s` references %s, but no compiled timeline exists there."
			% [episodes_by_timeline[episode_timeline].id, episode_timeline],
		)


func _validate_timeline(
	timeline_path: String,
	episode: EpisodeDefinition,
) -> void:
	var timeline := load(timeline_path) as DialogicTimeline
	if timeline == null:
		_failures.append(
			(
				"%s did not load as DialogicTimeline. Run an editor import and check "
				+ "the DTL importer output."
			)
			% timeline_path
		)
		return

	timeline.process()
	_check(
		timeline.events_processed,
		"%s did not finish Dialogic timeline processing." % timeline_path,
	)
	_check(
		not timeline.events.is_empty(),
		"%s processed to zero events." % timeline_path,
	)
	_timeline_count += 1

	var phrase_data: Dictionary = _load_phrase_data(episode, timeline_path)
	var referenced_phrase_ids: Dictionary = {}
	var stage: Node = null
	var animation_player: AnimationPlayer = null
	if episode != null and episode.presentation_scene != null:
		stage = episode.presentation_scene.instantiate()
		root.add_child(stage)
		animation_player = stage.get_node_or_null("AnimationPlayer") as AnimationPlayer
		_validate_stage_slots(stage, episode)
		_validate_authored_stage_choreography(stage, animation_player, episode)

	for event_index: int in timeline.events.size():
		var event: Variant = timeline.events[event_index]
		var context := _event_context(timeline, timeline_path, event_index, event)
		if not event is DialogicEvent:
			_failures.append(
				"%s processed into `%s` instead of a DialogicEvent."
				% [context, type_string(typeof(event))]
			)
			continue

		var source := String(event.event_node_as_text).strip_edges()
		_validate_compiled_event_type(event, source, context)

		if event is DialogicTextEvent:
			_validate_text_event(event as DialogicTextEvent, context)
		elif event is DialogicPhraseCutEvent:
			var phrase_event := event as DialogicPhraseCutEvent
			_validate_phrase_event(
				phrase_event,
				phrase_data,
				referenced_phrase_ids,
				context,
			)
		elif event is DialogicPresentationCueEvent:
			_validate_presentation_cue(
				event as DialogicPresentationCueEvent,
				animation_player,
				episode,
				context,
			)
		elif event is DialogicAudioEvent:
			_validate_audio_event(
				event as DialogicAudioEvent,
				context,
			)

	for metadata_id: Variant in phrase_data:
		_check(
			referenced_phrase_ids.has(String(metadata_id)),
			(
				"%s contains unused phrase metadata `%s`; regenerate the sidecar or "
				+ "restore the matching `phrase_cut` event."
			)
			% [episode.phrase_data_path, metadata_id],
		)

	if episode != null and String(episode.id) == "son":
		_validate_son_bully_entrance_order(timeline.events, timeline_path)

	if stage != null:
		stage.free()


func _validate_son_bully_entrance_order(
	events: Array,
	timeline_path: String,
) -> void:
	var entrance_index := -1
	var first_bully_line_index := -1
	for event_index: int in events.size():
		var event: Variant = events[event_index]
		if (
			event is DialogicPresentationCueEvent
			and (event as DialogicPresentationCueEvent).cue_id == "bully_enters"
		):
			entrance_index = event_index
		elif (
			first_bully_line_index < 0
			and event is DialogicTextEvent
			and (event as DialogicTextEvent).character_identifier == "bully"
		):
			first_bully_line_index = event_index

	_check(
		entrance_index >= 0,
		"%s must cue `bully_enters` before the bully speaks." % timeline_path,
	)
	_check(
		first_bully_line_index >= 0,
		"%s must contain the bully’s opening line." % timeline_path,
	)
	_check(
		entrance_index + 1 == first_bully_line_index,
		(
			"%s must place `bully_enters` immediately before the bully’s first "
			+ "line."
		)
		% timeline_path,
	)


func _validate_authored_stage_choreography(
	stage: Node,
	animation_player: AnimationPlayer,
	episode: EpisodeDefinition,
) -> void:
	if animation_player == null:
		return

	match String(episode.id):
		"son":
			_finish_stage_animation(animation_player, &"RESET")
			_check_visible_cast(
				stage,
				["son"],
				"Chapter 3 should begin with Percy alone; the bully must be off-screen.",
			)
			_finish_stage_animation(animation_player, &"bully_enters")
			_check_visible_cast(
				stage,
				["bully", "son"],
				"Chapter 3 should reveal the bully only at `bully_enters`.",
			)
		"crush":
			_finish_stage_animation(animation_player, &"RESET")
			_check_visible_cast(
				stage,
				["son"],
				"Chapter 4 should begin with Percy alone; Clem must be off-screen.",
			)
			_finish_stage_animation(animation_player, &"clem_walks_over")
			_check_visible_cast(
				stage,
				["crush", "son"],
				"Chapter 4 should reveal Clem only after `clem_walks_over`.",
			)
		"neighbors":
			_finish_stage_animation(animation_player, &"RESET")
			_check_visible_cast(
				stage,
				["dad", "grandma", "son"],
				"Chapter 6 should open on the Leiton family at home.",
			)
			_check_background_flip(
				stage,
				true,
				"The Leiton home should use the mirrored dining-room layout.",
			)

			_finish_stage_animation(animation_player, &"neighbors_transition_out")
			_finish_stage_animation(animation_player, &"neighbors_transition_in")
			_check_visible_cast(
				stage,
				["crush", "son"],
				"The neighbor reveal should focus only on Percy and Clementine.",
			)
			_check_background_flip(
				stage,
				false,
				"The Reeds’ home should use the unmirrored dining-room layout.",
			)

			_finish_stage_animation(animation_player, &"hosts_enter")
			_check_visible_cast(
				stage,
				["dad", "doctor", "interviewer"],
				"The adult introduction should show Dad and the two hosts.",
			)

			_finish_stage_animation(animation_player, &"grandma_returns")
			_check_visible_cast(
				stage,
				["doctor", "grandma", "interviewer"],
				"The doctor callback should replace Dad with Grandma.",
			)

			_finish_stage_animation(animation_player, &"dinner_fade")
			_finish_stage_animation(animation_player, &"back_at_home")
			_check_visible_cast(
				stage,
				["dad", "grandma", "son"],
				"The post-dinner scene should return to the Leiton family.",
			)
			_check_background_flip(
				stage,
				true,
				"Returning home should restore the mirrored Leiton layout.",
			)

			_finish_stage_animation(animation_player, &"pennybot_reveal")
			_check_visible_cast(
				stage,
				["penny"],
				"The final ending card should isolate Pennybot.",
			)


func _finish_stage_animation(
	animation_player: AnimationPlayer,
	animation_name: StringName,
) -> void:
	_check(
		animation_player.has_animation(animation_name),
		"Stage choreography requires missing animation `%s`." % animation_name,
	)
	if not animation_player.has_animation(animation_name):
		return
	var animation := animation_player.get_animation(animation_name)
	animation_player.play(animation_name)
	animation_player.seek(animation.length, true)
	animation_player.stop(true)


func _check_visible_cast(
	stage: Node,
	expected_ids: Array,
	message: String,
) -> void:
	var actual_ids: Array[String] = []
	var actor_slots := stage.get_node_or_null("ActorSlots")
	if actor_slots != null:
		for child: Node in actor_slots.get_children():
			var slot := child as StageActorSlot
			if (
				slot != null
				and slot.visible
				and slot.self_modulate.a > 0.01
				and not slot.character_id.is_empty()
			):
				actual_ids.append(String(slot.character_id))
	actual_ids.sort()

	var normalized_expected: Array[String] = []
	for identifier: Variant in expected_ids:
		normalized_expected.append(String(identifier))
	normalized_expected.sort()
	_check(
		actual_ids == normalized_expected,
		"%s Expected %s, got %s."
		% [message, normalized_expected, actual_ids],
	)


func _check_background_flip(
	stage: Node,
	expected: bool,
	message: String,
) -> void:
	var background := stage.get_node_or_null("Background/BackgroundImage") as TextureRect
	_check(
		background != null and background.flip_h == expected,
		message,
	)


func _validate_stage_slots(stage: Node, episode: EpisodeDefinition) -> void:
	var actor_slots := stage.get_node_or_null("ActorSlots")
	if actor_slots == null:
		return
	for child: Node in actor_slots.get_children():
		var slot := child as StageActorSlot
		if slot == null or slot.character_id.is_empty():
			continue
		var identifier := String(slot.character_id)
		var character := DialogicResourceUtil.get_character_resource(identifier)
		if character == null:
			_failures.append(
				"%s stage slot `%s` references unregistered speaker `%s`."
				% [episode.id, slot.name, identifier]
			)
			continue
		if not slot.expression.is_empty():
			_check(
				character.portraits.has(slot.expression),
				(
					"%s stage slot `%s` previews expression `%s`, but speaker `%s` "
					+ "has no portrait with that key."
				)
				% [episode.id, slot.name, slot.expression, identifier],
			)


func _validate_text_event(event: DialogicTextEvent, context: String) -> void:
	var identifier := String(event.character_identifier)
	if identifier.is_empty() or identifier == "_" or "{" in identifier:
		return
	_validate_speaker_and_expression(identifier, event.portrait, context)


func _validate_phrase_event(
	event: DialogicPhraseCutEvent,
	phrase_data: Dictionary,
	referenced_phrase_ids: Dictionary,
	context: String,
) -> void:
	_phrase_count += 1
	_validate_speaker_and_expression(event.speaker, event.portrait, context)

	_check(
		not event.line_id.is_empty(),
		"%s has an empty phrase line ID." % context,
	)
	if event.line_id.is_empty():
		return
	_check(
		not referenced_phrase_ids.has(event.line_id),
		"%s reuses phrase line ID `%s` in the same timeline."
		% [context, event.line_id],
	)
	referenced_phrase_ids[event.line_id] = true

	var metadata_value: Variant = phrase_data.get(event.line_id)
	if not metadata_value is Dictionary:
		_failures.append(
			(
				"%s references `%s`, but that key is missing or not an object in the "
				+ "episode phrase sidecar."
			)
			% [context, event.line_id]
		)
		return
	var metadata := metadata_value as Dictionary

	_check(
		String(metadata.get("speaker", "")) == event.speaker,
		"%s speaker `%s` disagrees with phrase metadata speaker `%s`."
		% [context, event.speaker, metadata.get("speaker", "")],
	)
	_check(
		String(metadata.get("expr", "")) == event.portrait,
		"%s expression `%s` disagrees with phrase metadata expression `%s`."
		% [context, event.portrait, metadata.get("expr", "")],
	)

	var segments_value: Variant = metadata.get("segments")
	if not segments_value is Array or segments_value.is_empty():
		_failures.append(
			"%s phrase metadata `%s` needs a nonempty `segments` array."
			% [context, event.line_id]
		)
		return

	var seen_segment_ids: Dictionary = {}
	for segment_index: int in segments_value.size():
		var segment_value: Variant = segments_value[segment_index]
		if not segment_value is Dictionary:
			_failures.append(
				"%s phrase metadata `%s` segment %d is not an object."
				% [context, event.line_id, segment_index + 1]
			)
			continue
		var segment := segment_value as Dictionary
		_check(
			String(segment.get("type", "")) == "phrase",
			"%s phrase metadata `%s` segment %d has unsupported type `%s`."
			% [
				context,
				event.line_id,
				segment_index + 1,
				segment.get("type", ""),
			],
		)
		_check(
			not String(segment.get("text", "")).strip_edges().is_empty(),
			"%s phrase metadata `%s` segment %d has empty text."
			% [context, event.line_id, segment_index + 1],
		)
		_check(
			int(segment.get("cost", -1)) >= 0,
			"%s phrase metadata `%s` segment %d has a missing or negative cost."
			% [context, event.line_id, segment_index + 1],
		)
		var segment_id := String(segment.get("id", ""))
		if not segment_id.is_empty():
			_check(
				not seen_segment_ids.has(segment_id),
				"%s phrase metadata `%s` repeats segment ID `%s`."
				% [context, event.line_id, segment_id],
			)
			seen_segment_ids[segment_id] = true


func _validate_presentation_cue(
	event: DialogicPresentationCueEvent,
	animation_player: AnimationPlayer,
	episode: EpisodeDefinition,
	context: String,
) -> void:
	_cue_count += 1
	if episode == null:
		return
	if animation_player == null:
		_failures.append(
			(
				"%s requests stage cue `%s`, but episode `%s` has no root "
				+ "AnimationPlayer."
			)
			% [context, event.cue_id, episode.id]
		)
		return
	_check(
		animation_player.has_animation(StringName(event.cue_id)),
		"%s requests stage cue `%s`, but %s does not define that animation."
		% [
			context,
			event.cue_id,
			episode.presentation_scene.resource_path,
		],
	)


func _validate_sponsor_jingle_asset() -> void:
	_check(
		DialogicPhraseCutEvent.SPONSOR_JINGLE_PATH == SPONSOR_JINGLE_PATH,
		"Every sponsor delivery should use the project sponsor jingle.",
	)
	_check(
		is_equal_approx(
			DialogicPhraseCutEvent.SPONSOR_JINGLE_AUDIBLE_SECONDS,
			2.4,
		),
		"Sponsor delivery should hold through the jingle's audible duration.",
	)
	var stream := load(SPONSOR_JINGLE_PATH) as AudioStreamMP3
	_check(
		stream != null,
		"%s should import as an AudioStreamMP3." % SPONSOR_JINGLE_PATH,
	)
	if stream == null:
		return
	_check(
		not stream.loop,
		"The sponsor jingle import must not loop.",
	)
	_check(
		stream.get_length() > 3.7 and stream.get_length() < 3.72,
		"The sponsor jingle should retain the advert v3 duration.",
	)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	_check(
		is_equal_approx(player.pitch_scale, 1.0),
		"The sponsor jingle should play at normal speed and pitch.",
	)
	player.free()


func _validate_audio_event(
	event: DialogicAudioEvent,
	context: String,
) -> void:
	_check(
		ResourceLoader.exists(event.file_path),
		"%s references missing audio `%s`." % [context, event.file_path],
	)


func _validate_speaker_and_expression(
	identifier: String,
	expression: String,
	context: String,
) -> void:
	if identifier.is_empty() or identifier == "_" or "{" in identifier:
		return
	var character := DialogicResourceUtil.get_character_resource(identifier)
	if character == null:
		_failures.append(
			(
				"%s references unregistered speaker `%s`. Add a `.dch` resource and "
				+ "register the same identifier in Dialogic."
			)
			% [context, identifier]
		)
		return
	if not expression.is_empty():
		_check(
			character.portraits.has(expression),
			(
				"%s uses expression `%s`, but speaker `%s` has no portrait with "
				+ "that key."
			)
			% [context, expression, identifier],
		)


func _validate_compiled_event_type(
	event: DialogicEvent,
	source: String,
	context: String,
) -> void:
	var valid := true
	var expected := ""
	if source.begins_with("\\"):
		valid = event is DialogicTextEvent
		expected = "DialogicTextEvent"
	elif event is DialogicCallEvent:
		valid = false
		expected = "DialogicTextEvent (writer scripts do not expose Call events)"
	elif source.begins_with("phrase_cut "):
		valid = event is DialogicPhraseCutEvent
		expected = "DialogicPhraseCutEvent"
	elif source.begins_with("presentation_cue "):
		valid = event is DialogicPresentationCueEvent
		expected = "DialogicPresentationCueEvent"
	elif source.begins_with("budget_set "):
		valid = event is DialogicBudgetSetEvent
		expected = "DialogicBudgetSetEvent"
	elif source.begins_with("recovery_policy "):
		valid = event is DialogicRecoveryPolicyEvent
		expected = "DialogicRecoveryPolicyEvent"
	elif source.begins_with("goto_label "):
		valid = event is DialogicGotoLabelEvent
		expected = "DialogicGotoLabelEvent"
	elif source.begins_with("story_flag_set "):
		valid = event is DialogicStoryFlagSetEvent
		expected = "DialogicStoryFlagSetEvent"
	elif source.begins_with("story_flag_check "):
		valid = event is DialogicStoryFlagCheckEvent
		expected = "DialogicStoryFlagCheckEvent"
	elif source.begins_with("label "):
		valid = event is DialogicLabelEvent
		expected = "DialogicLabelEvent"
	elif (
		source.begins_with("if ")
		or source.begins_with("elif ")
		or source == "else:"
	):
		valid = event is DialogicConditionEvent
		expected = "DialogicConditionEvent"
	elif source.begins_with("set "):
		valid = event is DialogicVariableEvent
		expected = "DialogicVariableEvent"
	elif source.begins_with("- "):
		valid = event is DialogicChoiceEvent
		expected = "DialogicChoiceEvent"
	elif source.begins_with("[wait "):
		valid = event is DialogicWaitEvent
		expected = "DialogicWaitEvent"
	elif source.begins_with("[background "):
		valid = event is DialogicBackgroundEvent
		expected = "DialogicBackgroundEvent"
	elif source.begins_with("audio "):
		valid = event is DialogicAudioEvent
		expected = "DialogicAudioEvent"
	elif source == "[end_timeline]":
		valid = event is DialogicEndTimelineEvent
		expected = "DialogicEndTimelineEvent"

	if not valid:
		_failures.append(
			(
				"%s should compile as %s, but Dialogic parsed it as %s. Check the "
				+ "event indexer and DTL syntax."
			)
			% [context, expected, _event_type_name(event)]
		)


func _load_phrase_data(
	episode: EpisodeDefinition,
	timeline_path: String,
) -> Dictionary:
	if episode == null:
		return {}
	if episode.phrase_data_path.is_empty():
		return {}
	var file := FileAccess.open(episode.phrase_data_path, FileAccess.READ)
	if file == null:
		_failures.append(
			"%s cannot read phrase sidecar %s."
			% [timeline_path, episode.phrase_data_path]
		)
		return {}

	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	if error != OK:
		_failures.append(
			"%s has invalid JSON at line %d: %s"
			% [
				episode.phrase_data_path,
				parser.get_error_line(),
				parser.get_error_message(),
			]
		)
		return {}
	if not parser.data is Dictionary:
		_failures.append(
			"%s must contain a JSON object keyed by phrase line ID."
			% episode.phrase_data_path
		)
		return {}
	return parser.data as Dictionary


func _collect_files(
	directory_path: String,
	extension: String,
	output: Array[String],
) -> bool:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_failures.append(
			"Cannot scan %s: %s."
			% [directory_path, error_string(DirAccess.get_open_error())]
		)
		return false

	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_files(path, extension, output)
			elif entry.ends_with(extension):
				output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
	return true


func _event_context(
	timeline: DialogicTimeline,
	timeline_path: String,
	event_index: int,
	event: Variant,
) -> String:
	# Alpha 20's get_text_line_from_index() can return Nil for synthetic
	# EndBranch events despite its `int` return annotation, so read the public
	# index map directly and fall back to the processed event index.
	var source_line_value: Variant = timeline.text_lines_indexed.find_key(event_index)
	var source_line := int(source_line_value) if typeof(source_line_value) == TYPE_INT else -1
	var location := (
		"%s:%d" % [timeline_path, source_line + 1]
		if source_line >= 0
		else "%s event %d" % [timeline_path, event_index + 1]
	)
	if event is DialogicEvent:
		var source := String(event.event_node_as_text).strip_edges()
		if not source.is_empty():
			return "%s (`%s`)" % [location, source.replace("\n", "\\n")]
	return location


func _event_type_name(event: DialogicEvent) -> String:
	var script := event.get_script() as Script
	if script != null:
		var global_name := script.get_global_name()
		if not global_name.is_empty():
			return global_name
	return event.get_class()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
