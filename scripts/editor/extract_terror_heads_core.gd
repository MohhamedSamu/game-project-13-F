class_name ExtractTerrorHeadsCore
extends RefCounted

const DAE_PATH := "res://assets/characters/Personajes_terror/Pesonajes 2.dae"
const OUT_DIR := "res://scenes/props/terror_heads/"

const HEADS: Array[Dictionary] = [
	{"scene": "terror_head_01", "dae_label": "Cube.015", "node_names": ["Cube_015", "Cube.015"]},
	{"scene": "terror_head_02", "dae_label": "Cube.016", "node_names": ["Cube_016", "Cube.016"]},
	{"scene": "terror_head_03", "dae_label": "Cube.034", "node_names": ["Cube_034", "Cube.034"]},
	{"scene": "terror_head_04", "dae_label": "Cube.035", "node_names": ["Cube_035", "Cube.035"]},
	{"scene": "terror_head_05", "dae_label": "Cube.036", "node_names": ["Cube_036", "Cube.036"]},
	{"scene": "terror_head_06", "dae_label": "Cube.037", "node_names": ["Cube_037", "Cube.037"]},
	{"scene": "terror_head_07", "dae_label": "Cube.038", "node_names": ["Cube_038", "Cube.038"]},
	{"scene": "terror_head_08", "dae_label": "Cube.039", "node_names": ["Cube_039", "Cube.039"]},
	{"scene": "terror_head_09", "dae_label": "Cube.041", "node_names": ["Cube_041", "Cube.041"]},
	{"scene": "terror_head_10", "dae_label": "Cube.044", "node_names": ["Cube_044", "Cube.044"]},
]


static func extract_all() -> int:
	var packed: PackedScene = load(DAE_PATH)
	if packed == null:
		push_error("ExtractTerrorHeads: no se pudo cargar %s" % DAE_PATH)
		return 0

	var source := packed.instantiate()
	if source == null:
		push_error("ExtractTerrorHeads: no se pudo instanciar el DAE.")
		return 0

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var saved := 0
	for head in HEADS:
		var mesh_instance := _find_mesh_instance(source, head["node_names"])
		if mesh_instance == null:
			push_error("ExtractTerrorHeads: mesh no encontrado %s" % str(head["node_names"]))
			continue
		if _save_head_scene(head, mesh_instance):
			saved += 1

	source.free()
	return saved


static func _find_mesh_instance(root: Node, names: Array) -> MeshInstance3D:
	for node_name in names:
		var found := root.find_child(str(node_name), true, false)
		if found is MeshInstance3D:
			return found
	return null


static func _save_head_scene(head: Dictionary, source_mesh: MeshInstance3D) -> bool:
	var scene_name: String = head["scene"]
	var root_name := scene_name.replace("_", " ").capitalize().replace(" ", "")

	var root := Node3D.new()
	root.name = root_name

	var model := MeshInstance3D.new()
	model.name = "Model"

	if source_mesh.mesh != null:
		model.mesh = _build_centered_mesh(source_mesh)

	var surface_count := model.mesh.get_surface_count() if model.mesh else 0
	for surface_idx in surface_count:
		var mat := source_mesh.get_surface_override_material(surface_idx)
		if mat == null:
			mat = source_mesh.get_active_material(surface_idx)
		if mat != null:
			model.set_surface_override_material(surface_idx, mat.duplicate(true))

	root.add_child(model)
	model.owner = root

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		push_error("ExtractTerrorHeads: error al empaquetar %s (%s)" % [scene_name, pack_err])
		root.free()
		return false

	var out_path := OUT_DIR + scene_name + ".tscn"
	var err := ResourceSaver.save(packed, out_path)
	root.free()

	if err != OK:
		push_error("ExtractTerrorHeads: error guardando %s (%s)" % [out_path, err])
		return false

	print("  %s <- %s" % [scene_name, head["dae_label"]])
	return true


static func _build_centered_mesh(source_mesh: MeshInstance3D) -> ArrayMesh:
	var src: Mesh = source_mesh.mesh
	var xform := _accumulated_transform(source_mesh)
	var baked := ArrayMesh.new()

	for surface_idx in src.get_surface_count():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(src, surface_idx, xform)
		st.commit(baked)

	var aabb := baked.get_aabb()
	var centered := ArrayMesh.new()
	var center_offset := Transform3D(Basis.IDENTITY, -aabb.get_center())
	for surface_idx in baked.get_surface_count():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(baked, surface_idx, center_offset)
		st.commit(centered)

	return centered


static func _accumulated_transform(node: Node3D) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent()
	while parent is Node3D:
		xform = parent.transform * xform
		parent = parent.get_parent()
	return xform
