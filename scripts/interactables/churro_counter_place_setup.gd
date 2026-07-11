extends Node3D

@export var counter_item_rotation_deg: Vector3 = Vector3(-90.0, 0.0, 0.0)
@export_range(0.1, 3.0, 0.01) var counter_item_scale: float = 1.0
## Velocidad de giro de cámara al dejar el churro (menor = más lento; default jugador ≈ 2.5).
@export var place_camera_focus_speed: float = 1.15

@onready var _place_point: Marker3D = $ChurroCounterPlacePoint
@onready var _cashier_focus: Marker3D = $CashierFocusPoint
@onready var _interact: InteractableDialogueComponent = $CounterInteractArea

var _counter_churro: Node3D


func _ready() -> void:
	add_to_group("churro_counter_place")
	sync_interact_area()


func sync_interact_area() -> void:
	if _interact == null:
		return
	var active := can_handle_interaction()
	_interact.monitorable = active


func get_cashier_focus() -> Node3D:
	return _cashier_focus


func place_counter_churro(item: Node3D) -> void:
	if _counter_churro != null and is_instance_valid(_counter_churro):
		item.queue_free()
		return
	if _place_point == null or item == null:
		item.queue_free()
		return
	_place_point.add_child(item)
	var euler := Vector3(
		deg_to_rad(counter_item_rotation_deg.x),
		deg_to_rad(counter_item_rotation_deg.y),
		deg_to_rad(counter_item_rotation_deg.z)
	)
	var display_scale: float = item.get_meta("held_display_scale", 1.0)
	var basis := Basis.from_euler(euler).scaled(Vector3.ONE * display_scale * counter_item_scale)
	item.transform = Transform3D(basis, Vector3.ZERO)
	for child in item.get_children():
		if child is MeshInstance3D:
			child.transform = Transform3D.IDENTITY
	item.add_to_group(&"supermarket_counter_items")
	item.add_to_group(&"supermarket_counter_churro")
	HeldViewModel.restore_for_world_display(item)
	HeldViewModel.freeze_as_static_prop(item)
	_counter_churro = item


func can_handle_interaction() -> bool:
	return ChurroCounterFlow.can_place_churro()


func get_interaction_prompt() -> String:
	if ChurroCounterFlow.can_place_churro():
		return ChurroCounterFlow.PROMPT_PLACE
	return ""


func handle_interaction() -> void:
	if not ChurroCounterFlow.can_place_churro():
		return
	ChurroCounterFlow.place_churro_from_counter(self)
