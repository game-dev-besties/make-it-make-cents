extends Node
## Transient record of which (id'd) phrases the player KEPT on the last
## PhraseCut line. Lets subsequent lines branch on the kept/removed combo:
##
##     son (nervous): [Don't panic|2|calm] [I didn't|2|deny] [to your car|3|guilty]
##     if kept("guilty"):
##         crush (nervous): Wait, you DID something to my car?!
##
## The compiler rewrites kept()/removed()/kept_count() into PhraseMemory.* calls
## (Dialogic's Expression engine sees autoloads, so this resolves at runtime).
##
## Not persisted; only the LAST phrase-cut line's result is held, cleared on
## the next one. Phrases without an explicit id are not queryable.

var _known: Dictionary = {}  # id -> true (ids that existed on the last line)
var _kept: Dictionary = {}   # id -> true (ids the player kept)


func set_line(known_ids: Array, kept_ids: Array) -> void:
	_known.clear()
	_kept.clear()
	for id in known_ids:
		_known[String(id)] = true
	for id in kept_ids:
		_kept[String(id)] = true


func kept(id: String) -> bool:
	return _kept.get(id, false)


func removed(id: String) -> bool:
	return _known.get(id, false) and not _kept.get(id, false)


func kept_count() -> int:
	return _kept.size()
