extends Node
## Conecta el trigger de la escena final con Scene6FinalChaseDirector.

@export var setup_path: NodePath = ^"../FinalScene"
@export var require_flag: String = ""
@export var block_if_flag: String = "scene6_final_chase_started"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_connect_trigger")


func _connect_trigger() -> void:
	var setup := get_node_or_null(setup_path)
	if setup == null or not setup.has_method("get_trigger_zone"):
		push_warning("Scene6FinalChaseConnector: no se encontró Scene6FinalSceneSetup.")
		return

	var trigger := setup.call("get_trigger_zone") as JumpscareTriggerZone
	if trigger == null:
		push_warning("Scene6FinalChaseConnector: asigna ChaseTrigger en FinalScene.")
		return

	if not trigger.player_entered.is_connected(_on_player_entered):
		trigger.player_entered.connect(_on_player_entered)


func _on_player_entered(player: Node3D) -> void:
	if not require_flag.is_empty() and not GameManager.get_flag(require_flag):
		return
	if not block_if_flag.is_empty() and GameManager.get_flag(block_if_flag):
		return

	var setup := get_node_or_null(setup_path)
	if setup == null:
		return

	await Scene6FinalChaseDirector.start_sequence(setup, player)
