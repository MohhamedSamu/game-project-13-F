extends Node3D
## Instancia IGLESIA 2, oculta meshes no deseados y genera colisiones trimesh.

const UNWANTED_NODE_NAMES: PackedStringArray = [
	"Cube_001",
	"Cube.001",
	"Plane",
	"Paladin_J_Nordstrom_Helmet",
	"Paladin_J_Nordstrom_Helmet_001",
	"Paladin_J_Nordstrom_Helmet.001",
]

const COLLISION_MESH_NAMES: PackedStringArray = [
	"1_Columnas exteriores",
	"1_SideBuildings_001",
	"COLLIDER OMG",
	"COLLIDER OMG_001",
	"Circle_002",
	"Cube_002",
	"Cube_003",
	"Cube_004",
	"Cube_009",
	"Entrance_roof",
	"Entrance_tower",
	"MAIN_BASE",
	"MAIN_BUILDING",
	"Techo",
	"Techo_001",
	"chinese_sofa",
]


func _ready() -> void:
	_remove_unwanted_nodes()
	_setup_mesh_collisions()


func _remove_unwanted_nodes() -> void:
	var to_remove: Array[Node] = []
	for node_name in UNWANTED_NODE_NAMES:
		var node := _find_node_by_name(node_name)
		if node != null and not to_remove.has(node):
			to_remove.append(node)
	for node in to_remove:
		node.queue_free()


func _setup_mesh_collisions() -> void:
	for mesh_name in COLLISION_MESH_NAMES:
		var mesh_instance := _find_mesh_instance(mesh_name)
		if mesh_instance == null:
			push_warning("IglesiaSetup: mesh '%s' no encontrado para colisión." % mesh_name)
			continue
		if _has_static_body(mesh_instance):
			continue
		if mesh_instance.mesh == null:
			push_warning("IglesiaSetup: mesh '%s' no tiene geometría." % mesh_name)
			continue
		mesh_instance.create_trimesh_collision()


func _has_static_body(mesh_instance: MeshInstance3D) -> bool:
	for child in mesh_instance.get_children():
		if child is StaticBody3D:
			return true
	return false


func _find_mesh_instance(mesh_name: String) -> MeshInstance3D:
	var node := _find_node_by_name(mesh_name)
	if node is MeshInstance3D:
		return node
	return null


func _find_node_by_name(node_name: String) -> Node:
	var candidates: Array[String] = [node_name]
	if "." in node_name:
		candidates.append(node_name.replace(".", "_"))
	if "_" in node_name:
		candidates.append(node_name.replace("_", "."))
	for candidate in candidates:
		var found := _find_node_recursive(self, candidate)
		if found != null:
			return found
	return null


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_recursive(child, target_name)
		if found != null:
			return found
	return null


func _find_mesh_instance_recursive(node: Node, mesh_name: String) -> MeshInstance3D:
	if node.name == mesh_name and node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance_recursive(child, mesh_name)
		if found != null:
			return found
	return null
