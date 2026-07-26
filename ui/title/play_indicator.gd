extends Label
## A restrained idle nudge that points at the primary title action without
## making the button itself look permanently hovered or focused.

@export var travel := 5.0
@export var cycles_per_second := 1.15

var _resting_x := 0.0


func _ready() -> void:
	_resting_x = position.x


func _process(_delta: float) -> void:
	var phase := Time.get_ticks_msec() * 0.001 * cycles_per_second * TAU
	var offset := (sin(phase) * 0.5 + 0.5) * travel
	position.x = _resting_x + roundf(offset)
