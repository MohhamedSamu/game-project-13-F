@tool
class_name FlashlightJumpscareSetup
extends SoftJumpscareSetup
## Soft jumpscare que se dispara al recoger la linterna (con retardo).
## Hereda todas las opciones de [SoftJumpscareSetup] en el nodo raíz del inspector.

@export_group("Trigger linterna")
@export var pickup_item_id: StringName = &"flashlight"
@export_range(0.0, 30.0, 0.1) var pickup_delay_seconds: float = 1.0
## Flag persistente; si está vacío usa [member trigger_flag].
@export var pickup_trigger_flag: String = ""

var _pickup_armed: bool = false
var _pickup_triggered: bool = false


func _ready() -> void:
	use_trigger_zone = false
	if trigger_flag.is_empty() and not pickup_trigger_flag.is_empty():
		trigger_flag = pickup_trigger_flag
	super._ready()
	if Engine.is_editor_hint():
		return
	var flag := _resolved_pickup_flag()
	if not flag.is_empty() and GameManager.get_flag(flag):
		_pickup_triggered = true
		return
	call_deferred("_connect_pickup_player")


func _connect_pickup_player() -> void:
	var player := GameManager.get_player()
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("FlashlightJumpscareSetup: no se encontró al jugador.")
		return
	if player.has_signal("pickup_acquired"):
		player.pickup_acquired.connect(_on_pickup_acquired)


func _on_pickup_acquired(_pickup: Node3D, item_id: StringName) -> void:
	if _pickup_triggered or _pickup_armed:
		return
	if pickup_item_id != StringName() and item_id != pickup_item_id:
		return
	var flag := _resolved_pickup_flag()
	if trigger_once and not flag.is_empty() and GameManager.get_flag(flag):
		_pickup_triggered = true
		return
	_pickup_armed = true
	_run_pickup_delayed_trigger()


func _run_pickup_delayed_trigger() -> void:
	if pickup_delay_seconds > 0.0:
		await get_tree().create_timer(pickup_delay_seconds).timeout
	_pickup_armed = false
	if not is_inside_tree():
		return
	if _pickup_triggered and trigger_once:
		return
	if GameManager.dialogue_active or GameManager.minigame_active or GameManager.level_intro_active:
		return
	if GameManager.instructions_overlay_active:
		return
	_pickup_triggered = true
	trigger_jumpscare(GameManager.get_player() as Node3D)


func _resolved_pickup_flag() -> String:
	if not pickup_trigger_flag.is_empty():
		return pickup_trigger_flag
	return trigger_flag
