extends Node3D

## Raíz del prop linterna: recogida / soltar / pulsar F para encender-apagar foco.

@export_group("UI")
@export var pickup_prompt: String = "[E] Recoger linterna"

@export_group("En la mano")
## Posición local respecto a HandRight (cámara FPS). Z negativo = adelante.
@export var hold_offset: Vector3 = Vector3(0.12, -0.08, -0.18)
## Rotación local al coger [grados]. Ajusta en el Inspector del nodo flashlight o aquí.
## X = inclinar arriba/abajo, Y = girar izq/der, Z = balancear. Empieza en (0,0,0).
@export var hold_rotation_deg: Vector3 = Vector3(0.0, 180.0, 0.0)

var _rb: RigidBody3D
var _collision_shape: CollisionShape3D
var _beam_csg: CSGCylinder3D
var _saved_layer: int = 1
var _saved_mask: int = 1


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickup")
	_rb = find_child("RigidBody3D", true, false) as RigidBody3D
	if _rb:
		_saved_layer = _rb.collision_layer
		_saved_mask = _rb.collision_mask
	_collision_shape = find_child("CollisionShape3D", true, false) as CollisionShape3D
	_beam_csg = find_child("CSGCylinder3D", true, false) as CSGCylinder3D
	if _beam_csg:
		_beam_csg.visible = false
	_configure_flashlight_beam()


func _configure_flashlight_beam() -> void:
	var light := find_child("SpotLight3D", true, false) as SpotLight3D
	if light == null:
		return
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 0.55
	light.shadow_opacity = 1.0
	light.shadow_blur = 0.35
	light.light_energy = maxf(light.light_energy, 32.0)
	light.light_volumetric_fog_energy = 3.5
	light.light_indirect_energy = 0.15
	light.light_specular = 0.45


func get_interaction_prompt() -> String:
	return pickup_prompt


func pickup_to_hand(hand: Node3D) -> void:
	if _rb == null:
		return
	var p := get_parent()
	if p != null:
		p.remove_child(self)
	hand.add_child(self)
	var euler := Vector3(
		deg_to_rad(hold_rotation_deg.x),
		deg_to_rad(hold_rotation_deg.y),
		deg_to_rad(hold_rotation_deg.z)
	)
	transform = Transform3D(Basis.from_euler(euler), hold_offset)
	_rb.transform = Transform3D.IDENTITY
	_rb.freeze = true
	_rb.linear_velocity = Vector3.ZERO
	_rb.angular_velocity = Vector3.ZERO
	_rb.collision_layer = 0
	_rb.collision_mask = 0
	if _collision_shape:
		_collision_shape.disabled = true


func drop_soft(forward_dir: Vector3, drop_parent: Node) -> void:
	if _rb == null:
		return
	var gp := global_position
	var gb := global_basis
	var pr := get_parent()
	if pr != null:
		pr.remove_child(self)
	drop_parent.add_child(self)
	global_position = gp + forward_dir.normalized() * 0.35 + Vector3(0.0, 0.08, 0.0)
	global_basis = gb.orthonormalized()
	_rb.freeze = false
	_rb.collision_layer = _saved_layer
	_rb.collision_mask = _saved_mask
	if _collision_shape:
		_collision_shape.disabled = false
	if _beam_csg:
		_beam_csg.visible = false
	var toss := forward_dir.normalized() * 1.4 + Vector3(0.0, 0.35, 0.0)
	_rb.linear_velocity = toss
	_rb.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))


func toggle_spotlight() -> void:
	var light := find_child("SpotLight3D", true, false) as SpotLight3D
	if light == null:
		return
	light.visible = not light.visible
