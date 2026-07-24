# Shared character assets

Create one folder per character, for example `mara/`. Keep portraits,
expression resources, and voice clips together in that folder. Episode stage
scenes should reference these shared assets through the Godot Inspector rather
than duplicating image files into each episode.

A character can have a `.dch` resource before portrait art is ready. This keeps
speaker names and colors stable; expressions begin showing art as portraits are
added to that resource in Dialogic.
