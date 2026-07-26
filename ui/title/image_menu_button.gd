extends TextureButton
## Keeps the interaction treatment attached to the visible pixels of a menu
## overlay. Mouse clicks release focus so a clicked item never looks selected
## forever; keyboard focus remains visible for accessible navigation.

const MENU_OVERLAY_SHADER := preload("res://ui/title/menu_overlay.gdshader")
const RESPONSE_SPEED := 12.0

var _hovered := false
var _focused := false
var _pressed := false
var _hover_amount := 0.0
var _focus_amount := 0.0
var _pressed_amount := 0.0
var _visual_scale := 1.0
var _shader_material: ShaderMaterial


func _ready() -> void:
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = MENU_OVERLAY_SHADER
	material = _shader_material
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	resized.connect(_update_pivot)
	_update_pivot()
	set_process(true)


func _process(delta: float) -> void:
	var weight := clampf(delta * RESPONSE_SPEED, 0.0, 1.0)
	_hover_amount = lerpf(_hover_amount, 1.0 if _hovered else 0.0, weight)
	_focus_amount = lerpf(
		_focus_amount,
		1.0 if _focused and not _hovered else 0.0,
		weight,
	)
	_pressed_amount = lerpf(
		_pressed_amount,
		1.0 if _pressed else 0.0,
		weight,
	)
	var target_scale := 0.94 if _pressed else (1.07 if _hovered else 1.0)
	_visual_scale = lerpf(_visual_scale, target_scale, weight)
	scale = Vector2.ONE * _visual_scale
	_shader_material.set_shader_parameter(&"hover_amount", _hover_amount)
	_shader_material.set_shader_parameter(&"focus_amount", _focus_amount)
	_shader_material.set_shader_parameter(&"pressed_amount", _pressed_amount)


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		call_deferred("release_focus")


func _on_mouse_entered() -> void:
	_hovered = true


func _on_mouse_exited() -> void:
	_hovered = false
	_pressed = false


func _on_focus_entered() -> void:
	_focused = true


func _on_focus_exited() -> void:
	_focused = false


func _on_button_down() -> void:
	_pressed = true


func _on_button_up() -> void:
	_pressed = false


func _update_pivot() -> void:
	pivot_offset = size * 0.5
