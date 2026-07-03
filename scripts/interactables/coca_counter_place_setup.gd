extends Node3D

@export var coca_scene: PackedScene = preload("res://scenes/interactables/coca_bottle/coca_bottle.tscn")
@export var counter_bottle_rotation_deg: Vector3 = Vector3(-90.0, 0.0, 0.0)
@export var counter_bottle_scale: float = 1.0
## Velocidad de giro de cámara al dejar la coca (menor = más lento; default jugador ≈ 2.5).
@export var place_camera_focus_speed: float = 1.35

@onready var _place_point: Marker3D = $CocaCounterPlacePoint
@onready var _cashier_focus: Marker3D = $CashierFocusPoint
@onready var _interact: InteractableDialogueComponent = $CounterInteractArea

var _counter_coca: Node3D


func _ready() -> void:
	add_to_group("coca_counter_place")
	sync_interact_area()


func sync_interact_area() -> void:
	if _interact == null:
		return
	var active := can_handle_interaction()
	_interact.monitorable = active


func get_cashier_focus() -> Node3D:
	return _cashier_focus


func spawn_counter_coca() -> void:
	if _counter_coca != null and is_instance_valid(_counter_coca):
		return
	if _place_point == null or coca_scene == null:
		return
	var bottle := coca_scene.instantiate() as Node3D
	if bottle == null:
		return
	_place_point.add_child(bottle)
	var euler := Vector3(
		deg_to_rad(counter_bottle_rotation_deg.x),
		deg_to_rad(counter_bottle_rotation_deg.y),
		deg_to_rad(counter_bottle_rotation_deg.z)
	)
	var basis := Basis.from_euler(euler).scaled(Vector3.ONE * counter_bottle_scale)
	bottle.transform = Transform3D(basis, Vector3.ZERO)
	HeldViewModel.freeze_as_static_prop(bottle)
	_counter_coca = bottle


func can_handle_interaction() -> bool:
	return CocaCounterFlow.can_place_coca()


func get_interaction_prompt() -> String:
	if CocaCounterFlow.can_place_coca():
		return CocaCounterFlow.PROMPT_PLACE
	return ""


func handle_interaction() -> void:
	if not CocaCounterFlow.can_place_coca():
		return
	CocaCounterFlow.place_coca_from_counter(self)
