class_name InteractableHighlight
extends Node3D

## Contorno blanco al apuntar un prop interactuable (mismo momento que el prompt [E]).

@export_group("Apariencia")
@export var outline_color: Color = Color(1.0, 1.0, 1.0, 0.82)
@export_range(0.0005, 0.08, 0.0005) var outline_width: float = 0.012
@export_range(0.0005, 0.12, 0.0005) var aura_width: float = 0.028
@export var aura_color: Color = Color(1.0, 1.0, 1.0, 0.28)

@export_group("Escaneo")
@export var scan_root: NodePath
@export var exclude_node_names: PackedStringArray = PackedStringArray(["Outline", "Aura"])

var _outline_meshes: Array[MeshInstance3D] = []
var _aura_meshes: Array[MeshInstance3D] = []
var _active: bool = false
var _outline_material: ShaderMaterial
var _aura_material: ShaderMaterial


static func ensure_on(prop_root: Node3D) -> InteractableHighlight:
	if prop_root == null:
		return null
	var existing := prop_root.find_child("InteractableHighlight", true, false) as InteractableHighlight
	if existing != null:
		return existing
	var highlight := InteractableHighlight.new()
	highlight.name = "InteractableHighlight"
	prop_root.add_child(highlight)
	return highlight


func _ready() -> void:
	_build_materials()
	_build_outlines()


func set_highlight(active: bool) -> void:
	if _active == active:
		return
	_active = active
	for mesh in _outline_meshes:
		if is_instance_valid(mesh):
			mesh.visible = active
	for mesh in _aura_meshes:
		if is_instance_valid(mesh):
			mesh.visible = active


func is_highlighted() -> bool:
	return _active


func _build_materials() -> void:
	var shader := load("res://assets/shaders/interactable_outline.gdshader") as Shader
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = shader
	_outline_material.set_shader_parameter("outline_color", outline_color)
	_outline_material.set_shader_parameter("outline_width", outline_width)

	_aura_material = ShaderMaterial.new()
	_aura_material.shader = shader
	_aura_material.set_shader_parameter("outline_color", aura_color)
	_aura_material.set_shader_parameter("outline_width", aura_width)


func _build_outlines() -> void:
	var root := _resolve_scan_root()
	if root == null:
		return

	var sources: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, sources)
	for source in sources:
		_add_outline_pair(source)


func _resolve_scan_root() -> Node3D:
	if not scan_root.is_empty():
		return get_node_or_null(scan_root) as Node3D
	var parent := get_parent()
	return parent as Node3D


func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if _should_skip_mesh_node(node):
		return
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.visible:
			out.append(mesh_instance)
	for child in node.get_children():
		_collect_mesh_instances(child, out)


func _should_skip_mesh_node(node: Node) -> bool:
	if node == self:
		return true
	for excluded in exclude_node_names:
		if node.name.begins_with(excluded):
			return true
	return false


func _add_outline_pair(source: MeshInstance3D) -> void:
	var parent := source.get_parent()
	if parent == null:
		return

	var outline := MeshInstance3D.new()
	outline.name = "Outline_%s" % source.name
	outline.mesh = source.mesh
	outline.skin = source.skin
	outline.transform = source.transform
	outline.material_override = _outline_material
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.visible = false
	parent.add_child(outline)
	_outline_meshes.append(outline)

	var aura := MeshInstance3D.new()
	aura.name = "Aura_%s" % source.name
	aura.mesh = source.mesh
	aura.skin = source.skin
	aura.transform = source.transform
	aura.material_override = _aura_material
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.visible = false
	parent.add_child(aura)
	_aura_meshes.append(aura)
