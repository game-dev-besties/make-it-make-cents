class_name CampaignDefinition
extends Resource
## Ordered, routable collection of episodes. Routes refer to episode IDs, not scene paths.

@export var id: StringName
@export var title := ""
@export var first_episode_id: StringName
@export var episodes: Array[EpisodeDefinition] = []


func get_episode(episode_id: StringName) -> EpisodeDefinition:
	for episode in episodes:
		if episode != null and episode.id == episode_id:
			return episode
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Campaign has no ID.")
	if first_episode_id.is_empty():
		errors.append("Campaign '%s' has no first episode ID." % id)
	var episode_ids: Dictionary = {}
	for episode in episodes:
		if episode == null:
			errors.append("Campaign '%s' has an empty episode entry." % id)
			continue
		if not episode.id.is_empty() and episode_ids.has(episode.id):
			errors.append("Campaign '%s' has duplicate episode ID '%s'." % [id, episode.id])
		else:
			episode_ids[episode.id] = true
		for episode_error in episode.validate():
			errors.append(episode_error)
	if not first_episode_id.is_empty() and not episode_ids.has(first_episode_id):
		errors.append("Campaign '%s' first episode '%s' does not exist." % [id, first_episode_id])
	for episode in episodes:
		if episode == null:
			continue
		for route in episode.routes:
			if route != null and not route.next_episode_id.is_empty() and not episode_ids.has(route.next_episode_id):
				errors.append("Episode '%s' route '%s' points to missing episode '%s'." % [episode.id, route.exit_id, route.next_episode_id])
	return errors
