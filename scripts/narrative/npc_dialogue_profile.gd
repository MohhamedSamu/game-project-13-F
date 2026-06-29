class_name NpcDialogueProfile
extends Resource
## Lista ordenada de beats para un NPC. El primero que cumpla condiciones define el diálogo.

@export var npc_id: String = ""
@export var fallback_title: String = "start"
@export var beats: Array[NpcDialogueBeat] = []
