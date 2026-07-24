extends SceneTree

const STYLE_PATH := "res://ui/dialogue/dialogue_style.tres"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(
		ProjectSettings.get_setting("dialogic/layout/default_style", "") == STYLE_PATH,
		"The project-owned Dialogic style should be the default.",
	)
	_check(
		bool(ProjectSettings.get_setting("dialogic/history/simple_history_enabled", false)),
		"Dialogic's simple history should be enabled.",
	)

	var style := ResourceLoader.load(STYLE_PATH) as DialogicStyle
	_check(style != null, "The project-owned Dialogic style should load.")
	if style != null:
		var layer_paths := PackedStringArray()
		for layer_id: String in style.get_layer_inherited_list():
			layer_paths.append(String(style.get_layer_inherited_info(layer_id).path))
		_check(
			_has_path_fragment(layer_paths, "Layer_Input"),
			"The style should retain Dialogic's advance-input layer.",
		)
		_check(
			_has_path_fragment(layer_paths, "Layer_VN_Textbox"),
			"The style should retain Dialogic's typed-text and sound layer.",
		)
		_check(
			_has_path_fragment(layer_paths, "Layer_VN_Choices"),
			"The style should retain Dialogic's choice layer.",
		)
		_check(
			_has_path_fragment(layer_paths, "Layer_History"),
			"The style should retain Dialogic's history layer.",
		)
		_check(
			_has_path_fragment(layer_paths, "background_state_layer"),
			"The style should retain native Dialogic background state for the stage bridge.",
		)
		_check(
			not _has_path_fragment(layer_paths, "Layer_FullBackground"),
			"The style should not place a full-screen background over StoryStage.",
		)
		_check(
			not _has_path_fragment(layer_paths, "Layer_VN_Portraits"),
			"The style should not duplicate StoryStage's portrait renderer.",
		)

	var dialogic := root.get_node_or_null("Dialogic") as DialogicGameHandler
	_check(dialogic != null, "The Dialogic autoload should be available.")
	if dialogic != null:
		_check(
			dialogic.History.simple_history_enabled,
			"The History subsystem should apply the project setting at runtime.",
		)

	_finish()


func _has_path_fragment(paths: PackedStringArray, fragment: String) -> bool:
	for path: String in paths:
		if fragment in path:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dialogic feature checks passed.")
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	quit(1)
