@tool
class_name JumpscareTriggerZone
extends Area3D
## Trigger sin colisión física: solo detecta al jugador. Vista previa en el editor.

signal player_entered(player: Node3D)

@export_group("Tamaño")
@export var zone_length: float = 4.0:
	set(value):
		zone_length = maxf(value, 0.1)
		_request_rebuild()

@export var zone_height: float = 2.5:
	set(value):
		zone_height = maxf(value, 0.1)
		_request_rebuild()

@export var zone_thickness: float = 0.2:
	set(value):
		zone_thickness = maxf(value, 0.05)
		_request_rebuild()

@export_group("Editor")
@export var show_editor_preview: bool = true:
	set(value):
		show_editor_preview = value
		_update_preview_visibility()

const _PREVIEW_COLOR := Color(0.95, 0.25, 0.55, 0.38)

var _shape_node: CollisionShape3D
var _preview: MeshInstance3D
var _preview_material: StandardMaterial3D
var _owns_shape: bool = false
var _owns_preview_mesh: bool = false


func _enter_tree() -> void:
	_cache_nodes()
	call_deferred("_rebuild")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _notification(what: int) -> void:
	if Engine.is_editor_hint() and what == NOTIFICATION_TRANSFORM_CHANGED:
		call_deferred("_rebuild")


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
	box.size = Vector3(zone_length, zone_height, zone_thickness)
	_shape_node.transform = Transform3D.IDENTITY
	_shape_node.position = Vector3(0.0, zone_height * 0.5, 0.0)
	_sync_editor_preview()
	_update_preview_visibility()


func _sync_editor_preview() -> void:
	if _preview == null:
		return
	var mesh := _unique_preview_mesh()
	mesh.size = Vector3(zone_length, zone_height, zone_thickness)
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
	if not _owns_shape:
		var shared := _shape_node.shape as BoxShape3D
		var box := shared.duplicate() if shared else BoxShape3D.new()
		_shape_node.shape = box
		_owns_shape = true
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


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_entered.emit(body)
