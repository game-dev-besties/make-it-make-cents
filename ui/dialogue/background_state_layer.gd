@tool
extends DialogicLayoutLayer
## Gives Dialogic's Backgrounds subsystem a nonvisual state holder.
##
## CampaignPlayer mirrors `background_changed` into StoryStage, so this layer
## must retain Dialogic's state without drawing over the editor-authored stage.
