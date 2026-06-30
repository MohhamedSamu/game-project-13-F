class_name JumpscareDelayedPickupTrigger
extends Node
## Dispara un [SoftJumpscareSetup] tras recoger un prop (p. ej. linterna) y esperar unos segundos.

@export var jumpscare_path: NodePath
@export var pickup_item_id: StringName = &"flashlight"
@export_range(0.0, 30.0, 0.1) var delay_seconds: float = 2.0
@export var trigger_once: bool = true
## Si no está vacío, no repite tras activarse (persistente en GameManager).
@export var trigger_flag: String = ""

var _jumpscare: SoftJumpscareSetup
var _armed: bool = false
var _triggered: bool = false


func _ready() -> void:
	_jumpscare = get_node_or_null(jumpscare_path) as SoftJumpscareSetup
	if _jumpscare == null:
		push_warning("JumpscareDelayedPickupTrigger: asigna jumpscare_path.")
		return
	if not trigger_flag.is_empty() and GameManager.get_flag(trigger_flag):
		_triggered = true
		return
	call_deferred("_connect_player")


func _connect_player() -> void:
	var player := GameManager.get_player()
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("JumpscareDelayedPickupTrigger: no se encontró al jugador.")
		return
	if player.has_signal("pickup_acquired"):
		player.pickup_acquired.connect(_on_pickup_acquired)


func _on_pickup_acquired(_pickup: Node3D, item_id: StringName) -> void:
	if _triggered or _armed:
		return
	if pickup_item_id != StringName() and item_id != pickup_item_id:
		return
	if trigger_once and not trigger_flag.is_empty() and GameManager.get_flag(trigger_flag):
		_triggered = true
		return
	_armed = true
	_run_delayed_trigger()


func _run_delayed_trigger() -> void:
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout
	_armed = false
	if not is_inside_tree() or _jumpscare == null:
		return
	if _triggered and trigger_once:
		return
	if GameManager.dialogue_active or GameManager.minigame_active or GameManager.level_intro_active:
		return
	if GameManager.instructions_overlay_active:
		return
	_triggered = true
	_jumpscare.trigger_jumpscare(GameManager.get_player() as Node3D)
