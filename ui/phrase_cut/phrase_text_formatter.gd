class_name PhraseTextFormatter
extends RefCounted
## Applies conservative surface cleanup to the phrase chunks the player kept.
##
## This formatter never adds, removes, reorders, or lowercases authored words.
## Phrase IDs, costs, and response branching remain independent from the
## delivered display text.

const SENTENCE_TERMINATORS := ".?!…"
const CLOSING_PUNCTUATION := "\"'”’)]}"
const WORD_BOUNDARIES := " \t\r\n.,!?…;:\"'“”‘’()[]{}"


static func format_parts(parts: PackedStringArray) -> String:
	return " ".join(format_part_labels(parts)).replace("  ", " ").strip_edges()


static func format_part_labels(parts: PackedStringArray) -> PackedStringArray:
	var formatted_parts := PackedStringArray()
	var capitalize_next := true

	for raw_part: String in parts:
		var part := raw_part.strip_edges()
		if part.is_empty():
			continue
		if capitalize_next:
			part = _uppercase_first_cased_character(part)
		formatted_parts.append(part)
		capitalize_next = _ends_sentence(part)

	if not formatted_parts.is_empty():
		formatted_parts[-1] = _replace_terminal_comma(formatted_parts[-1])
	return formatted_parts


static func _uppercase_first_cased_character(text: String) -> String:
	for index: int in text.length():
		var character := text.substr(index, 1)
		var lower := character.to_lower()
		var upper := character.to_upper()
		if lower == upper:
			if character.is_valid_int():
				return text
			continue
		if character == lower and not _word_has_internal_uppercase(text, index):
			return text.substr(0, index) + upper + text.substr(index + 1)
		return text
	return text


static func _word_has_internal_uppercase(text: String, first_index: int) -> bool:
	for index: int in range(first_index + 1, text.length()):
		var character := text.substr(index, 1)
		if WORD_BOUNDARIES.contains(character):
			return false
		var lower := character.to_lower()
		var upper := character.to_upper()
		if lower != upper and character == upper:
			return true
	return false


static func _ends_sentence(text: String) -> bool:
	var index := text.length() - 1
	while index >= 0 and CLOSING_PUNCTUATION.contains(text.substr(index, 1)):
		index -= 1
	return index >= 0 and SENTENCE_TERMINATORS.contains(text.substr(index, 1))


static func _replace_terminal_comma(text: String) -> String:
	var index := text.length() - 1
	while index >= 0 and CLOSING_PUNCTUATION.contains(text.substr(index, 1)):
		index -= 1
	if index < 0 or text.substr(index, 1) != ",":
		return text
	return text.substr(0, index) + "." + text.substr(index + 1)
