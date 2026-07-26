class_name ResultsScreen
extends Control

signal title_requested

const CANVAS_SIZE := Vector2(1152.0, 648.0)
const DAD_GOOD := preload("res://ui/results/portraits/dad_good.png")
const DAD_SILLY := preload("res://ui/results/portraits/dad_silly.png")
const GRANDMA_GOOD := preload("res://ui/results/portraits/grandma_good.png")
const GRANDMA_SILLY := preload("res://ui/results/portraits/grandma_silly.png")
const SON_GOOD := preload("res://ui/results/portraits/son_good.png")
const SON_SILLY := preload("res://ui/results/portraits/son_silly.png")
const DAD_GOOD_REGION := Rect2(39.0, 44.0, 216.0, 204.0)
const DAD_SILLY_REGION := Rect2(43.0, 44.0, 216.0, 203.0)
const GRANDMA_GOOD_REGION := Rect2(47.0, 45.0, 199.0, 203.0)
const GRANDMA_SILLY_REGION := Rect2(51.0, 45.0, 189.0, 203.0)
const SON_GOOD_REGION := Rect2(44.0, 49.0, 206.0, 196.0)
const SON_SILLY_REGION := Rect2(44.0, 46.0, 206.0, 202.0)

@onready var results_canvas: Control = %ResultsCanvas
@onready var ending_title: Label = %EndingTitle
@onready var summary_label: Label = %SummaryLabel
@onready var dad_face: TextureRect = %DadFace
@onready var grandma_face: TextureRect = %GrandmaFace
@onready var son_face: TextureRect = %SonFace
@onready var money_spent_value: Label = %MoneySpentValue
@onready var jingles_sung_value: Label = %JinglesSungValue
@onready var grunts_said_value: Label = %GruntsSaidValue
@onready var nothings_said_value: Label = %NothingsSaidValue
@onready var main_menu_button: Button = %MainMenuButton

var dad_good_outcome := false
var grandma_good_outcome := false
var son_good_outcome := false
var _entrance_tween: Tween


func _ready() -> void:
	main_menu_button.pressed.connect(title_requested.emit)
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func present(game_state: GameStateStore) -> void:
	if game_state == null:
		return

	dad_good_outcome = game_state.story_flag_equals(
		&"dad_offended_interviewer",
		"none",
	)
	grandma_good_outcome = game_state.story_flag_equals(
		&"got_prescription",
		true,
	)
	son_good_outcome = game_state.story_flag_equals(&"got_the_girl", "yes")

	dad_face.texture = _cropped_portrait(
		DAD_GOOD if dad_good_outcome else DAD_SILLY,
		DAD_GOOD_REGION if dad_good_outcome else DAD_SILLY_REGION,
	)
	grandma_face.texture = _cropped_portrait(
		GRANDMA_GOOD if grandma_good_outcome else GRANDMA_SILLY,
		GRANDMA_GOOD_REGION if grandma_good_outcome else GRANDMA_SILLY_REGION,
	)
	son_face.texture = _cropped_portrait(
		SON_GOOD if son_good_outcome else SON_SILLY,
		SON_GOOD_REGION if son_good_outcome else SON_SILLY_REGION,
	)

	var happy_count := (
		int(dad_good_outcome)
		+ int(grandma_good_outcome)
		+ int(son_good_outcome)
	)
	var family_stays := game_state.story_flag_equals(&"family_stays", true)
	ending_title.text = "PENNYBOT 4000" if family_stays else "SCRAP PARTS"
	if happy_count == 3:
		summary_label.text = "You made everyone happy. Wow, congrats!"
	elif family_stays:
		summary_label.text = "A little chaos, but they are making it work."
	else:
		summary_label.text = "It did not quite go to plan this time."

	money_spent_value.text = "$%d" % game_state.money_total_spent
	jingles_sung_value.text = str(game_state.delivery_jingles_sung)
	grunts_said_value.text = str(game_state.delivery_grunts_said)
	nothings_said_value.text = str(game_state.delivery_nothings_said)
	show()
	_play_entrance()


func dismiss() -> void:
	if is_instance_valid(_entrance_tween):
		_entrance_tween.kill()
	hide()


func _cropped_portrait(
	source_texture: Texture2D,
	region: Rect2,
) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = source_texture
	result.region = region
	return result


func _play_entrance() -> void:
	if is_instance_valid(_entrance_tween):
		_entrance_tween.kill()
	results_canvas.modulate.a = 0.0
	_entrance_tween = create_tween()
	_entrance_tween.set_trans(Tween.TRANS_QUAD)
	_entrance_tween.set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(results_canvas, "modulate:a", 1.0, 0.22)
	_entrance_tween.finished.connect(_on_entrance_finished)


func _on_entrance_finished() -> void:
	_entrance_tween = null
	main_menu_button.grab_focus()


func _apply_responsive_layout() -> void:
	var results_scale := minf(
		size.x / CANVAS_SIZE.x,
		size.y / CANVAS_SIZE.y,
	)
	var scaled_results_size := CANVAS_SIZE * results_scale
	results_canvas.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	results_canvas.position = (size - scaled_results_size) * 0.5
	results_canvas.size = CANVAS_SIZE
	results_canvas.scale = Vector2.ONE * results_scale
