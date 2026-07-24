@tool
extends DialogicIndexer
## Registers our custom phrase-cut event + subsystem with Dialogic.
## Dialogic auto-discovers addons/dialogic_additions/*/index.gd.

func _get_events() -> Array:
	return [this_folder.path_join('event_phrase_cut.gd')]

func _get_subsystems() -> Array:
	return [{'name': 'PhraseCut', 'script': this_folder.path_join('subsystem_phrase_cut.gd')}]
