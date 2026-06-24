@tool
extends StaticBody3D
## Pared de colisión invisible. Vista previa solo en el editor.

@export_group("Tamaño")
## Longitud horizontal de la pared (eje X local).
@export var wall_length: float = 4.0:
	set(value):
		wall_length = maxf(value, 0.1)
		_request_rebuild()

## Altura de la pared (eje Y local).
@export var wall_height: float = 2.5:
	set(value):
		wall_height = maxf(value, 0.1)
		_request_rebuild()

## Grosor de la pared (eje Z local). Mantener fino (0.1–0.3).
@export var wall_thickness: float = 0.2:
	set(value):
		wall_thickness = maxf(value, 0.05)
		_request_rebuild()

@export_group("Editor")
## Malla semitransparente en el editor (no aparece al jugar).
@export var show_editor_preview: bool = true:
	set(value):
		show_editor_preview = value
		_update_preview_visibility()

const _PREVIEW_COLOR := Color(1.0, 0.45, 0.35, 0.4)

var _shape_node: CollisionShape3D
var _preview: MeshInstance3D
var _preview_material: StandardMaterial3D
var _owns_collision_shape: bool = false
var _owns_preview_mesh: bool = false


func _enter_tree() -> void:
	_cache_nodes()
	_rebuild()


func _request_rebuild() -> void:
	if is_inside_tree():
		_rebuild()
	elif Engine.is_editor_hint():
		call_deferred("_rebuild")


func _cache_nodes() -> void:
	_shape_node = get_node_or_null("CollisionShape3D") as CollisionShape3D
	_preview = get_node_or_null("EditorPreview") as MeshInstance3D
	if _preview != null:
		_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape_node == null:
		_cache_nodes()
	if _shape_node == null:
		return

	var box := _unique_box_shape()
	box.size = Vector3(wall_length, wall_height, wall_thickness)
	_shape_node.transform = Transform3D.IDENTITY
	_shape_node.position = Vector3(0.0, wall_height * 0.5, 0.0)

	_sync_editor_preview()
	_update_preview_visibility()


func _sync_editor_preview() -> void:
	if _preview == null:
		return
	var mesh := _unique_preview_mesh()
	mesh.size = Vector3(wall_length, wall_height, wall_thickness)
	_preview.transform = _shape_node.transform
	if _preview_material == null:
		_preview_material = StandardMaterial3D.new()
		_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_preview_material.albedo_color = _PREVIEW_COLOR
		_preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_preview.material_override = _preview_material
	else:
		_preview_material.albedo_color = _PREVIEW_COLOR


func _update_preview_visibility() -> void:
	if _preview == null:
		return
	_preview.visible = Engine.is_editor_hint() and show_editor_preview


func _unique_box_shape() -> BoxShape3D:
	if not _owns_collision_shape:
		var shared := _shape_node.shape as BoxShape3D
		var box := shared.duplicate() if shared else BoxShape3D.new()
		_shape_node.shape = box
		_owns_collision_shape = true
		return box
	return _shape_node.shape as BoxShape3D


func _unique_preview_mesh() -> BoxMesh:
	if not _owns_preview_mesh:
		var shared := _preview.mesh as BoxMesh
		var mesh := shared.duplicate() if shared else BoxMesh.new()
		_preview.mesh = mesh
		_owns_preview_mesh = true
		return mesh
	return _preview.mesh as BoxMesh


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_update_preview_visibility()
	elif what == NOTIFICATION_READY:
		_update_preview_visibility()
