class_name HeldViewModel
extends RefCounted
## Convierte un objeto en mano en "viewmodel": sin colisión y dibujado encima del mundo 3D.
## La UI (diálogo, etc.) sigue por encima porque usa CanvasLayer.

const VIEWMODEL_SHADER := preload("res://assets/shaders/held_viewmodel.gdshader")


static func apply(root: Node) -> void:
	_disable_physics(root)
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		_apply_viewmodel_mesh(mesh)


static func freeze_as_static_prop(root: Node) -> void:
	_disable_physics(root)


static func _disable_physics(node: Node) -> void:
	if node is RigidBody3D:
		var rb := node as RigidBody3D
		rb.freeze = true
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.collision_layer = 0
		rb.collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_disable_physics(child)


static func _apply_viewmodel_mesh(mesh: MeshInstance3D) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tex := _resolve_albedo_texture(mesh)
	var mat := ShaderMaterial.new()
	mat.shader = VIEWMODEL_SHADER
	if tex != null:
		mat.set_shader_parameter("albedo_texture", tex)
	mat.render_priority = 128
	mesh.material_override = mat


static func _resolve_albedo_texture(mesh: MeshInstance3D) -> Texture2D:
	var mat: Material = mesh.material_override
	if mat == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		mat = mesh.mesh.surface_get_material(0)
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_texture
	if mat is ShaderMaterial:
		var tex: Variant = (mat as ShaderMaterial).get_shader_parameter("albedo_texture")
		if tex is Texture2D:
			return tex
	return null
