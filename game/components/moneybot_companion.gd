@tool
class_name MoneybotCompanion
extends Control

## A reusable, stage-sized Moneybot prop. The outer control owns authored
## placement and responsive stage scaling; only the inner visual moves so the
## idle animation cannot fight StoryStage's layout pass.

@export_category("Idle Motion")
@export var idle_motion_enabled := true:
	set(value):
		idle_motion_enabled = value
		if is_node_ready():
			_apply_idle_pose()

@export_range(0.0, 12.0, 0.25) var bob_distance := 3.0
@export_range(1.0, 8.0, 0.1) var cycle_duration := 3.2
@export_range(0.0, 0.03, 0.001) var breathe_amount := 0.006
@export_range(0.0, 0.03, 0.001) var tilt_amount := 0.006
@export_range(0.0, 1.0, 0.01) var idle_phase := 0.0

@onready var _motion_root: Control = %MotionRoot

var _elapsed := 0.0


func _ready() -> void:
	_elapsed = maxf(cycle_duration, 0.001) * idle_phase
	_update_motion_pivot()
	resized.connect(_update_motion_pivot)
	_apply_idle_pose()


func _process(delta: float) -> void:
	if not idle_motion_enabled or not is_instance_valid(_motion_root):
		return
	_elapsed = fposmod(_elapsed + delta, maxf(cycle_duration, 0.001))
	_apply_idle_pose()


func _update_motion_pivot() -> void:
	if not is_instance_valid(_motion_root):
		return
	_motion_root.pivot_offset = size * 0.5


func _apply_idle_pose() -> void:
	if not is_instance_valid(_motion_root):
		return
	if not idle_motion_enabled:
		_motion_root.position = Vector2.ZERO
		_motion_root.rotation = 0.0
		_motion_root.scale = Vector2.ONE
		return

	var cycle := maxf(cycle_duration, 0.001)
	var phase := TAU * _elapsed / cycle
	var bob_wave := sin(phase)
	var breath_wave := sin(phase - PI * 0.5)
	_motion_root.position = Vector2(0.0, bob_wave * bob_distance)
	_motion_root.rotation = sin(phase + PI * 0.35) * tilt_amount
	_motion_root.scale = Vector2.ONE * (1.0 + breath_wave * breathe_amount)
