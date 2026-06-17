extends Node3D

## Raíz del prop linterna: recogida / soltar.
## [b]F[/b] cicla: lejana → cercana → apagado.

enum LightMode {
	OFF,
	FAR,
	NEAR,
}

@export_group("UI")
@export var pickup_prompt: String = "[E] Recoger linterna"

@export_group("En la mano")
## Posición local respecto a HandRight (cámara FPS). Z negativo = adelante.
@export var hold_offset: Vector3 = Vector3(0.12, -0.08, -0.18)
## Rotación local al coger [grados]. Ajusta en el Inspector del nodo flashlight o aquí.
@export var hold_rotation_deg: Vector3 = Vector3(0.0, 180.0, 0.0)

@export_group("Luz")
@export var start_mode: LightMode = LightMode.FAR

var _rb: RigidBody3D
var _collision_shape: CollisionShape3D
var _beam_csg: CSGCylinder3D
var _saved_layer: int = 1
var _saved_mask: int = 1
var _spot_far: SpotLight3D
var _spot_near: SpotLight3D
var _mode: LightMode = LightMode.FAR


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
	_spot_far = find_child("SpotFar", true, false) as SpotLight3D
	_spot_near = find_child("SpotNear", true, false) as SpotLight3D
	_mode = start_mode
	_configure_flashlight_lights()
	_apply_light_state()


func _configure_flashlight_lights() -> void:
	for light in [_spot_far, _spot_near]:
		if light == null:
			continue
		light.shadow_enabled = true
		light.shadow_bias = 0.1
		light.shadow_normal_bias = 2.0
		light.shadow_opacity = 1.0
		light.light_indirect_energy = 0.0


func _apply_light_state() -> void:
	if _spot_far != null:
		_spot_far.visible = _mode == LightMode.FAR
	if _spot_near != null:
		_spot_near.visible = _mode == LightMode.NEAR


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
	match _mode:
		LightMode.FAR:
			_mode = LightMode.NEAR
		LightMode.NEAR:
			_mode = LightMode.OFF
		_:
			_mode = LightMode.FAR
	_apply_light_state()


func get_light_mode_label() -> String:
	match _mode:
		LightMode.FAR:
			return "Lejana"
		LightMode.NEAR:
			return "Cercana"
		_:
			return "Apagada"
