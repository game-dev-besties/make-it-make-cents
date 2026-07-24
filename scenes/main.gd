extends Control
## Main scene navigation. All visible layout remains editable in main.tscn.

@export_file("*.json") var opening_dialogue := "res://story/dialogues/border_tutorial.json"
@export_file("*.json") var dad_interview := "res://story/dialogues/dad_job_interview.json"

@onready var _title_screen: Control = %TitleScreen
@onready var _dialogue_screen := %DialogueScreen


func _on_start_button_pressed() -> void:
	_start_dialogue(opening_dialogue)


func _on_dad_interview_button_pressed() -> void:
	_start_dialogue(dad_interview)


func _start_dialogue(path: String) -> void:
	_title_screen.hide()
	_dialogue_screen.start_dialogue(path)


func _on_dialogue_screen_finished(_dialogue_id: String) -> void:
	_title_screen.show()
