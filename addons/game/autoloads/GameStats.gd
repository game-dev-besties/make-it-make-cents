extends Node
# AUTO-GENERATED from story/stats.yaml by tools/gen_game_stats.py — do not edit by hand.
# Dotted script path `group.stat` maps to property `group_stat`.

# Persisted game stats (see story/stats.yaml):
# ── crush ──
var crush_fondness: int = 0
var crush_creeped_out: int = 0

# ── interviewer ──
var interviewer_impression: int = 0
var interviewer_weirded_out: int = 0

# ── doctor ──
var doctor_patience: int = 0
var doctor_concern: int = 0

# ── son ──
var son_success: int = 5
var son_silly: int = 0

# ── dad ──
var dad_success: int = 5
var dad_silly: int = 0

# ── grandma ──
var grandma_success: int = 5
var grandma_silly: int = 0

# ── money ──
var money_total_saved: int = 0

# Per-cutscene word budget. Set by CutsceneRunner from the manifest; resets per cutscene.
var cutscene_budget: int = 0
var cutscene_spent: int = 0


func reset_for_new_game() -> void:
	crush_fondness = 0
	crush_creeped_out = 0
	interviewer_impression = 0
	interviewer_weirded_out = 0
	doctor_patience = 0
	doctor_concern = 0
	son_success = 5
	son_silly = 0
	dad_success = 5
	dad_silly = 0
	grandma_success = 5
	grandma_silly = 0
	money_total_saved = 0
	cutscene_budget = 0
	cutscene_spent = 0


func begin_cutscene(budget: int) -> void:
	cutscene_budget = budget
	cutscene_spent = 0

func spend(amount: int) -> void:
	cutscene_spent += amount

func remaining_budget() -> int:
	return cutscene_budget - cutscene_spent

# Bank unspent budget as lifetime savings. Call at cutscene end.
func end_cutscene() -> void:
	money_total_saved += max(0, cutscene_budget - cutscene_spent)


func snapshot() -> Dictionary:
	return {
		"crush_fondness": crush_fondness,
		"crush_creeped_out": crush_creeped_out,
		"interviewer_impression": interviewer_impression,
		"interviewer_weirded_out": interviewer_weirded_out,
		"doctor_patience": doctor_patience,
		"doctor_concern": doctor_concern,
		"son_success": son_success,
		"son_silly": son_silly,
		"dad_success": dad_success,
		"dad_silly": dad_silly,
		"grandma_success": grandma_success,
		"grandma_silly": grandma_silly,
		"money_total_saved": money_total_saved,
		"cutscene_budget": cutscene_budget,
		"cutscene_spent": cutscene_spent,
	}

func restore(data: Dictionary) -> void:
	crush_fondness = data.get("crush_fondness", 0)
	crush_creeped_out = data.get("crush_creeped_out", 0)
	interviewer_impression = data.get("interviewer_impression", 0)
	interviewer_weirded_out = data.get("interviewer_weirded_out", 0)
	doctor_patience = data.get("doctor_patience", 0)
	doctor_concern = data.get("doctor_concern", 0)
	son_success = data.get("son_success", 5)
	son_silly = data.get("son_silly", 0)
	dad_success = data.get("dad_success", 5)
	dad_silly = data.get("dad_silly", 0)
	grandma_success = data.get("grandma_success", 5)
	grandma_silly = data.get("grandma_silly", 0)
	money_total_saved = data.get("money_total_saved", 0)
	cutscene_budget = data.get("cutscene_budget", 0)
	cutscene_spent = data.get("cutscene_spent", 0)

