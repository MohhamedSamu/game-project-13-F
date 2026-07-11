class_name HeldViewModel
extends RefCounted
## Convierte un objeto en mano en "viewmodel": sin colisión y dibujado encima del mundo 3D.
## La UI (diálogo, etc.) sigue por encima porque usa CanvasLayer.

const VIEWMODEL_SHADER := preload("res://assets/shaders/held_viewmodel.gdshader")
const VIEWMODEL_BRIGHTNESS := 0.82
const VIEWMODEL_SATURATION := 0.88


static func apply(root: Node) -> void:
	_disable_physics(root)
	_for_each_mesh_instance(root, _apply_viewmodel_mesh)


static func freeze_as_static_prop(root: Node) -> void:
	_disable_physics(root)


static func restore_for_world_display(root: Node) -> void:
	_for_each_mesh_instance(root, _restore_world_mesh)


static func _for_each_mesh_instance(root: Node, callback: Callable) -> void:
	if root is MeshInstance3D:
		callback.call(root)
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		callback.call(mesh)


static func _restore_world_mesh(mesh: MeshInstance3D) -> void:
	mesh.material_override = null
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


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
	mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var tex := _resolve_albedo_texture(mesh)
	var color := _resolve_albedo_color(mesh)
	var mat := ShaderMaterial.new()
	mat.shader = VIEWMODEL_SHADER
	mat.render_priority = BaseMaterial3D.RENDER_PRIORITY_MAX
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("albedo_alpha", color.a)
	mat.set_shader_parameter("brightness", VIEWMODEL_BRIGHTNESS)
	mat.set_shader_parameter("saturation", VIEWMODEL_SATURATION)
	if tex != null:
		mat.set_shader_parameter("use_albedo_texture", true)
		mat.set_shader_parameter("albedo_texture", tex)
	else:
		mat.set_shader_parameter("use_albedo_texture", false)
	mesh.material_override = mat


static func _resolve_albedo_color(mesh: MeshInstance3D) -> Color:
	var mat: Material = mesh.material_override
	if mat == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		mat = mesh.mesh.surface_get_material(0)
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_color
	return Color.WHITE


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
