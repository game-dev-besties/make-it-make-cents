class_name FastForwardButton
extends Button
## Toggles Dialogic's built-in Auto-Skip. Auto-Skip only fast-forwards event
## types that explicitly cooperate with it (plain text lines do); PhraseCut
## and Choice events never check it, so they still block on the player's
## actual decision -- this reads as "skip ahead to the next phrase cut."
##
## A choice or phrase-cut resolving doesn't go through Dialogic's normal
## advance input, so Auto-Skip's own disable_on_user_input never fires for
## them -- without this, fast-forward would carry on into whatever comes
## after the decision instead of requiring another press. We explicitly turn
## it off once a choice is made; the phrase-cut side is handled the same way
## in event_phrase_cut.gd, right after its overlay resolves.


func _ready() -> void:
	toggle_mode = true
	var dialogic: DialogicGameHandler = DialogicUtil.autoload()
	if dialogic == null:
		return
	button_pressed = dialogic.Inputs.auto_skip.enabled
	if not dialogic.Inputs.auto_skip.toggled.is_connected(_on_auto_skip_toggled):
		dialogic.Inputs.auto_skip.toggled.connect(_on_auto_skip_toggled)
	if dialogic.has_subsystem("Choices"):
		if not dialogic.Choices.choice_selected.is_connected(_on_choice_selected):
			dialogic.Choices.choice_selected.connect(_on_choice_selected)
	toggled.connect(_on_toggled)


func _on_toggled(pressed: bool) -> void:
	var dialogic: DialogicGameHandler = DialogicUtil.autoload()
	if dialogic != null:
		dialogic.Inputs.auto_skip.enabled = pressed


func _on_auto_skip_toggled(is_enabled: bool) -> void:
	if button_pressed != is_enabled:
		set_pressed_no_signal(is_enabled)


func _on_choice_selected(_info := {}) -> void:
	var dialogic: DialogicGameHandler = DialogicUtil.autoload()
	if dialogic != null:
		dialogic.Inputs.auto_skip.enabled = false
