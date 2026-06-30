extends Node3D

## Raiz del prop linterna: recogida / soltar.
## [b]F[/b] cicla: lejana -> cercana -> apagado.

enum LightMode {
	OFF,
	FAR,
	NEAR,
}

@export_group("UI")
@export var pickup_prompt: String = "[E] Recoger linterna"

@export_group("Identity")
@export var item_id: StringName = &"flashlight"

@export_group("En la mano")
@export var hold_offset: Vector3 = Vector3(0.12, -0.08, -0.18)
@export var hold_rotation_deg: Vector3 = Vector3(0.0, 180.0, 0.0)
## Offset local respecto a la camara para el origen real del haz en mano.
## En cero, el centro del haz coincide con el centro de la camara/reticulo.
@export var held_light_camera_offset: Vector3 = Vector3.ZERO
## Inclinacion local del haz en mano. En 0 apunta exactamente hacia el centro de camara.
@export_range(-45.0, 45.0, 0.1) var held_light_pitch_deg: float = 0.0

@export_group("Al soltar")
@export var drop_forward_speed: float = 1.2
@export var drop_up_speed: float = 0.25
@export var drop_spawn_forward: float = 0.35
@export var drop_spawn_lift: float = 0.08

@export_group("Luz")
@export var start_mode: LightMode = LightMode.FAR

var _rb: RigidBody3D
var _collision_shape: CollisionShape3D
var _beam_csg: CSGCylinder3D
var _saved_layer: int = 1
var _saved_mask: int = 1
var _spot_far: SpotLight3D
var _spot_near: SpotLight3D
var _visual: Node3D
var _visual_default_transform: Transform3D
var _lights: Node3D
var _lights_ground_transform: Transform3D
var _mode: LightMode = LightMode.FAR
var _held_in_hand: bool = false


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
	_visual = find_child("Visual", true, false) as Node3D
	if _visual != null:
		_visual_default_transform = _visual.transform
	_lights = find_child("Lights", true, false) as Node3D
	if _lights != null:
		_lights_ground_transform = _lights.transform
	_mode = start_mode
	_fix_negative_rb_scale()
	_disable_mesh_shadow_casting()
	_apply_lights_ground_transform()
	_apply_light_state()
	InteractableHighlight.ensure_on(self)


func _process(_delta: float) -> void:
	if not _held_in_hand or _lights == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# En mano: forzar que el haz use la base de la camara (-Z = adelante).
	# Evita que un eje local del prop invierta sombras respecto a la iluminacion.
	var light_basis := cam.global_basis.orthonormalized()
	if not is_zero_approx(held_light_pitch_deg):
		var pitch_basis := Basis.from_euler(Vector3(deg_to_rad(held_light_pitch_deg), 0.0, 0.0))
		light_basis = (light_basis * pitch_basis).orthonormalized()
	var light_pos := cam.global_transform * held_light_camera_offset
	_lights.global_transform = Transform3D(light_basis, light_pos)


func _fix_negative_rb_scale() -> void:
	if _rb == null:
		return
	var rb_t: Transform3D = _rb.transform
	if rb_t.basis.determinant() < 0.0:
		_rb.transform = Transform3D(rb_t.basis.orthonormalized(), rb_t.origin)


func _disable_mesh_shadow_casting() -> void:
	var mesh := find_child("Flashlight", true, false) as MeshInstance3D
	if mesh != null:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _apply_lights_ground_transform() -> void:
	if _lights != null:
		_lights.transform = _lights_ground_transform


func _apply_lights_hold_transform() -> void:
	if _lights != null:
		_lights.transform = Transform3D.IDENTITY


func _apply_light_state() -> void:
	if _spot_far != null:
		_spot_far.visible = _mode == LightMode.FAR
	if _spot_near != null:
		_spot_near.visible = _mode == LightMode.NEAR


func get_interaction_prompt() -> String:
	return pickup_prompt


func get_item_id() -> StringName:
	return item_id


func pickup_to_hand(hand: Node3D) -> void:
	_set_interaction_highlight(false)
	if _rb == null:
		return
	var p := get_parent()
	if p != null:
		p.remove_child(self)
	hand.add_child(self)
	transform = Transform3D(Basis.IDENTITY, hold_offset)
	_apply_hold_visual_rotation()
	_apply_lights_hold_transform()
	_rb.transform = Transform3D.IDENTITY
	_rb.freeze = true
	_rb.linear_velocity = Vector3.ZERO
	_rb.angular_velocity = Vector3.ZERO
	_rb.collision_layer = 0
	_rb.collision_mask = 0
	if _collision_shape:
		_collision_shape.disabled = true
	_held_in_hand = true


func _apply_hold_visual_rotation() -> void:
	if _visual == null:
		return
	var hold_basis := Basis.from_euler(Vector3(
		deg_to_rad(hold_rotation_deg.x),
		deg_to_rad(hold_rotation_deg.y),
		deg_to_rad(hold_rotation_deg.z)
	))
	_visual.transform = Transform3D(
		hold_basis * _visual_default_transform.basis,
		_visual_default_transform.origin
	)


func _reset_visual_transform() -> void:
	if _visual != null:
		_visual.transform = _visual_default_transform
	_apply_lights_ground_transform()


func drop_soft(forward_dir: Vector3, drop_parent: Node) -> void:
	if _rb == null:
		return
	_held_in_hand = false
	var fwd := forward_dir.normalized()
	var gp := global_position
	var pr := get_parent()
	if pr != null:
		pr.remove_child(self)
	drop_parent.add_child(self)
	global_position = gp + fwd * drop_spawn_forward + Vector3(0.0, drop_spawn_lift, 0.0)
	global_basis = _basis_beam_along_forward(fwd)
	_reset_visual_transform()
	_rb.transform = Transform3D.IDENTITY
	_rb.linear_velocity = Vector3.ZERO
	_rb.angular_velocity = Vector3.ZERO
	_rb.freeze = false
	_rb.collision_layer = _saved_layer
	_rb.collision_mask = _saved_mask
	if _collision_shape:
		_collision_shape.disabled = false
	if _beam_csg:
		_beam_csg.visible = false
	_rb.linear_velocity = fwd * drop_forward_speed + Vector3(0.0, drop_up_speed, 0.0)


func _basis_beam_along_forward(fwd: Vector3) -> Basis:
	var up_ref := Vector3.UP
	if absf(fwd.dot(up_ref)) > 0.95:
		up_ref = Vector3.FORWARD
	var right := up_ref.cross(fwd).normalized()
	var up := fwd.cross(right).normalized()
	# El haz de la linterna sale por +Z local del RigidBody.
	return Basis(right, up, fwd).orthonormalized()


func set_light_mode(mode: LightMode) -> void:
	_mode = mode
	_apply_light_state()


func force_near_light() -> void:
	set_light_mode(LightMode.NEAR)


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


func _set_interaction_highlight(active: bool) -> void:
	var highlight := find_child("InteractableHighlight", true, false)
	if highlight != null and highlight.has_method("set_highlight"):
		highlight.set_highlight(active)
