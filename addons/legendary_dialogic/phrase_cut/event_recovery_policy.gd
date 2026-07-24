@tool
class_name DialogicRecoveryPolicyEvent
extends DialogicEvent
## Limits which paid-word recovery choices appear on the next phrase-cut line.

@export_enum("pity", "sponsor", "both", "none") var policy := "both"

var _pattern := RegEx.create_from_string(
	r"^recovery_policy\s+(?<policy>pity,sponsor|pity|sponsor|both|none)\s*$"
)


func _init() -> void:
	event_name = "Recovery Policy"
	event_description = "Limits pity and sponsor choices on the next phrase-cut line."
	set_default_color("Color3")
	event_category = "Gameplay"
	disable_editor_button = true


func to_text() -> String:
	var timeline_policy := "pity,sponsor" if policy == "both" else policy
	return "recovery_policy %s" % timeline_policy


func from_text(text: String) -> void:
	var match := _pattern.search(text.strip_edges())
	if match != null:
		policy = match.get_string("policy")
		if policy == "pity,sponsor":
			policy = "both"


func is_valid_event(text: String) -> bool:
	return _pattern.search(text.strip_edges()) != null


func _execute() -> void:
	var phrase_cut := dialogic.get_subsystem("PhraseCut") as DialogicPhraseCutSubsystem
	if phrase_cut == null:
		push_error("RecoveryPolicy requires the PhraseCut Dialogic subsystem.")
	else:
		phrase_cut.set_recovery_policy(StringName(policy))
	finish()
