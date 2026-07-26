@tool
class_name SpeakingMotionProfile
extends Resource

## Reusable tuning for the subtle procedural motion used while dialogue text
## reveals. Expressions and punctuation adjust these base values, keeping the
## result expressive without requiring a bespoke animation for every line.

@export_category("Base Motion")
@export_range(0.0, 12.0, 0.1) var vertical_travel := 3.0
@export_range(0.0, 12.0, 0.1) var horizontal_travel := 1.5
@export_range(0.0, 5.0, 0.05) var rotation_degrees := 0.45
@export_range(0.0, 0.1, 0.001) var scale_amount := 0.012
@export_range(0.1, 1.5, 0.01) var cycle_duration := 0.42

@export_category("Opening Gesture")
@export_range(0.0, 16.0, 0.1) var entrance_lift := 3.5
@export_range(0.0, 0.15, 0.001) var entrance_scale := 0.018
@export_range(0.05, 0.5, 0.01) var entrance_duration := 0.11
@export_range(0.05, 0.5, 0.01) var return_duration := 0.14
@export_range(1, 30, 1) var short_line_threshold := 10


func motion_for(
	expression: String,
	text: String,
	strength: float,
	direction: float,
) -> Dictionary:
	var expression_key := expression.strip_edges().to_lower()
	var style := &"neutral"
	var amplitude_multiplier := 1.0
	var tempo_multiplier := 1.0
	var entrance_multiplier := 1.0

	match expression_key:
		"happy", "excited", "joy":
			style = &"happy"
			amplitude_multiplier = 1.35
			tempo_multiplier = 0.85
			entrance_multiplier = 1.3
		"nervous", "shy", "worried", "afraid":
			style = &"nervous"
			amplitude_multiplier = 0.72
			tempo_multiplier = 0.7
			entrance_multiplier = 0.75
		"sad", "tired", "disappointed":
			style = &"sad"
			amplitude_multiplier = 0.58
			tempo_multiplier = 1.45
			entrance_multiplier = 0.45
		"surprised", "shocked", "confused":
			style = &"surprised"
			amplitude_multiplier = 1.1
			tempo_multiplier = 0.9
			entrance_multiplier = 1.75

	var plain_text := _plain_text(text)
	if plain_text.ends_with("!"):
		entrance_multiplier *= 1.3
	elif plain_text.ends_with("?"):
		entrance_multiplier *= 1.1
	elif plain_text.ends_with("...") or plain_text.ends_with("…"):
		amplitude_multiplier *= 0.55
		tempo_multiplier *= 1.35
		entrance_multiplier *= 0.5

	var clamped_strength := maxf(0.0, strength)
	var signed_direction := -1.0 if direction < 0.0 else 1.0
	return {
		"style": style,
		"vertical": vertical_travel * amplitude_multiplier * clamped_strength,
		"horizontal": (
			horizontal_travel
			* amplitude_multiplier
			* clamped_strength
			* signed_direction
		),
		"rotation": deg_to_rad(
			rotation_degrees * amplitude_multiplier * clamped_strength * signed_direction
		),
		"scale": scale_amount * amplitude_multiplier * clamped_strength,
		"cycle_duration": cycle_duration * tempo_multiplier,
		"entrance_lift": (
			entrance_lift * entrance_multiplier * clamped_strength
		),
		"entrance_scale": (
			entrance_scale * entrance_multiplier * clamped_strength
		),
		"entrance_duration": entrance_duration,
		"return_duration": return_duration,
		"loop": plain_text.length() > short_line_threshold,
	}


func _plain_text(text: String) -> String:
	var plain := text.strip_edges()
	var bbcode := RegEx.create_from_string("\\[[^\\]]*\\]")
	if bbcode != null:
		plain = bbcode.sub(plain, "", true)
	return plain.strip_edges()
