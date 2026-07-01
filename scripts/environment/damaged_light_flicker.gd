class_name DamagedLightFlicker
extends Node
## Parpadeo intermitente para luces bajo `iluminacion` + foco visual de lámpara dañada.

const _BULB_MATERIAL_NAME := &"Light"
const _BULB_NODE_HINTS: Array[StringName] = [&"LampHead", &"Light"]

@export_group("Mode")
@export var flicker_enabled: bool = true
@export var start_on_ready: bool = true
@export var randomize_on_start: bool = true

@export_group("Lights")
@export var controlled_lights: Array[Light3D] = []

@export_group("Auto Find (Level Setup)")
@export var auto_find_lights: bool = true
@export var controlled_light_paths: Array[NodePath] = []
@export var iluminacion_path: NodePath = ^"../../../iluminacion"
@export var spot_light_name: StringName = &"SpotLight3DStreetLampDamaged1"
@export var omni_light_name: StringName = &"OmniLight3DStreetLampDamaged1"
@export var street_lamp_model_path: NodePath = ^"../StreetLamp/Model/StreetLampModel"

@export_group("Terror Flicker Timing")
@export var min_on_time: float = 0.45
@export var max_on_time: float = 0.75
@export var min_off_time: float = 0.35
@export var max_off_time: float = 0.65
@export var long_off_chance: float = 0.18
@export var min_long_off_time: float = 1.0
@export var max_long_off_time: float = 2.0
@export var micro_flicker_chance: float = 0.38
@export var micro_flicker_count_min: int = 2
@export var micro_flicker_count_max: int = 5
@export var micro_flicker_min_time: float = 0.025
@export var micro_flicker_max_time: float = 0.08

@export_group("Light Intensity")
@export var min_energy_multiplier: float = 0.2
@export var max_energy_multiplier: float = 1.0
@export var off_energy_multiplier: float = 0.0
@export var use_hard_off: bool = true

@export_group("Visual Bulb")
@export var control_bulb_material: bool = true
@export var bulb_meshes: Array[MeshInstance3D] = []
@export var bulb_surface_indices: Array[int] = []
@export var auto_find_bulb_meshes: bool = true
@export var bulb_on_color: Color = Color(1.0, 1.0, 0.85, 1.0)
@export var bulb_off_color: Color = Color(0.03, 0.03, 0.035, 1.0)
@export var bulb_on_emission_energy: float = 1.0
@export var bulb_off_emission_energy: float = 0.0

var _original_energies: Dictionary = {}
var _flicker_running: bool = false
var _initialized: bool = false
var _bulb_mesh_targets: Array[MeshInstance3D] = []
var _bulb_surface_targets: Array[int] = []
var _bulb_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	if randomize_on_start:
		randomize()
	call_deferred("_begin")


func _begin() -> void:
	_resolve_controlled_lights()
	_resolve_bulb_targets()
	_prepare_bulb_materials()

	if not _has_valid_lights():
		push_warning(
			"DamagedLightFlicker sin luces en %s. Asigna controlled_lights o Auto Find."
			% get_path()
		)
		return

	await get_tree().process_frame
	await get_tree().process_frame
	_cache_original_energies()
	_mark_lights_flicker_managed()
	_initialized = true

	if start_on_ready and flicker_enabled:
		start_flicker()


func set_flicker_enabled(value: bool) -> void:
	flicker_enabled = value
	if not _initialized:
		return
	if flicker_enabled:
		start_flicker()
	else:
		stop_flicker(true)


func start_flicker() -> void:
	if not flicker_enabled:
		return
	if not ensure_ready():
		push_warning("DamagedLightFlicker: no hay luces válidas en %s." % get_path())
		return
	if _flicker_running:
		return
	_flicker_running = true
	_flicker_loop()


func ensure_ready() -> bool:
	_resolve_controlled_lights()
	if not _has_valid_lights():
		if auto_find_lights:
			_resolve_scene_root_lights()
	if not _has_valid_lights():
		return false
	if not _initialized:
		_cache_original_energies()
		_mark_lights_flicker_managed()
		_initialized = true
	return true


func stop_flicker(restore_lights := true) -> void:
	_flicker_running = false
	if restore_lights:
		_restore_lights()


func force_on() -> void:
	if not _has_valid_lights():
		return
	for light in controlled_lights:
		if light == null:
			continue
		light.visible = true
		light.light_energy = _get_original_energy(light)
	_set_bulb_visual_on(1.0)


func force_off() -> void:
	_set_light_off()


func _mark_lights_flicker_managed() -> void:
	for light in controlled_lights:
		if light != null:
			light.add_to_group(&"flicker_managed")


func _resolve_controlled_lights() -> void:
	if not controlled_lights.is_empty() and _has_valid_lights():
		return

	controlled_lights.clear()

	for path in controlled_light_paths:
		var light := _find_light_at_path(path)
		if light != null:
			controlled_lights.append(light)

	if _has_valid_lights() or not auto_find_lights:
		return

	var folder := get_node_or_null(iluminacion_path) as Node
	if folder == null:
		var root := get_tree().current_scene
		if root != null:
			folder = root.get_node_or_null(NodePath("iluminacion"))

	if folder == null:
		return

	for light_name: StringName in [spot_light_name, omni_light_name]:
		if light_name.is_empty():
			continue
		var node := folder.get_node_or_null(String(light_name))
		if node is Light3D:
			controlled_lights.append(node as Light3D)


func _resolve_bulb_targets() -> void:
	_bulb_mesh_targets.clear()
	_bulb_surface_targets.clear()

	if not control_bulb_material:
		return

	if not bulb_meshes.is_empty():
		for i in bulb_meshes.size():
			var mesh := bulb_meshes[i]
			if mesh == null:
				continue
			var surface_index := _surface_index_for_manual_entry(i, mesh)
			if surface_index < 0:
				continue
			_bulb_mesh_targets.append(mesh)
			_bulb_surface_targets.append(surface_index)
		return

	if not auto_find_bulb_meshes:
		return

	var model_root := get_node_or_null(street_lamp_model_path) as Node
	if model_root == null:
		model_root = _find_descendant_by_name(get_parent(), &"StreetLampModel")

	if model_root == null:
		return

	_collect_bulb_surfaces_recursive(model_root)


func _surface_index_for_manual_entry(index: int, mesh: MeshInstance3D) -> int:
	if index < bulb_surface_indices.size():
		return bulb_surface_indices[index]
	return _find_emissive_surface_index(mesh)


func _collect_bulb_surfaces_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var surface_index := _find_emissive_surface_index(mesh)
		if surface_index >= 0:
			_bulb_mesh_targets.append(mesh)
			_bulb_surface_targets.append(surface_index)

	for child in node.get_children():
		_collect_bulb_surfaces_recursive(child)


func _find_emissive_surface_index(mesh: MeshInstance3D) -> int:
	if mesh.mesh == null:
		return -1

	var named_light_surface := -1
	var emissive_surface := -1

	for surface_index in mesh.mesh.get_surface_count():
		var mat := mesh.get_active_material(surface_index)
		if mat == null:
			continue
		if mat.resource_name == String(_BULB_MATERIAL_NAME):
			named_light_surface = surface_index
		if mat is StandardMaterial3D:
			var std := mat as StandardMaterial3D
			if std.emission_enabled and std.emission.get_luminance() > 0.05:
				emissive_surface = surface_index

	if named_light_surface >= 0:
		return named_light_surface
	if emissive_surface >= 0:
		return emissive_surface

	for hint in _BULB_NODE_HINTS:
		if String(hint) in mesh.name and mesh.mesh.get_surface_count() > 0:
			return mini(1, mesh.mesh.get_surface_count() - 1)

	return -1


func _prepare_bulb_materials() -> void:
	_bulb_materials.clear()
	if not control_bulb_material:
		return

	for i in _bulb_mesh_targets.size():
		var mesh := _bulb_mesh_targets[i]
		if mesh == null:
			_bulb_materials.append(null)
			continue

		var surface_index := _bulb_surface_targets[i]
		var source := mesh.get_active_material(surface_index)
		if source == null:
			_bulb_materials.append(null)
			continue

		var local_mat := source.duplicate(true) as StandardMaterial3D
		mesh.set_surface_override_material(surface_index, local_mat)
		_bulb_materials.append(local_mat)

	if _bulb_materials.is_empty():
		push_warning(
			"DamagedLightFlicker: no se encontró material de foco en %s."
			% get_path()
		)


func _set_bulb_visual_on(strength: float) -> void:
	if not control_bulb_material:
		return

	var blend := clampf(strength, 0.0, 1.0)
	for mat in _bulb_materials:
		if mat == null:
			continue
		mat.albedo_color = bulb_off_color.lerp(bulb_on_color, blend)
		mat.emission_enabled = blend > 0.04
		mat.emission = bulb_on_color * blend
		mat.emission_energy_multiplier = lerpf(
			bulb_off_emission_energy,
			bulb_on_emission_energy,
			blend
		)


func _set_bulb_visual_off() -> void:
	if not control_bulb_material:
		return

	for mat in _bulb_materials:
		if mat == null:
			continue
		mat.albedo_color = bulb_off_color
		mat.emission_enabled = false
		mat.emission = Color.BLACK
		mat.emission_energy_multiplier = bulb_off_emission_energy


func _find_light_at_path(path: NodePath) -> Light3D:
	if path.is_empty():
		return null
	var node := get_node_or_null(path)
	if node is Light3D:
		return node as Light3D
	var root := get_tree().current_scene
	if root != null:
		node = root.get_node_or_null(path)
		if node is Light3D:
			return node as Light3D
	return null


func _resolve_scene_root_lights() -> void:
	_try_append_bathroom_lights(get_parent())

	var root := get_tree().current_scene
	if root == null:
		return
	for path in controlled_light_paths:
		var sub := String(path)
		if sub.begins_with("../"):
			sub = sub.trim_prefix("../")
			while sub.begins_with("../"):
				sub = sub.trim_prefix("../")
		var node := root.get_node_or_null(NodePath(sub))
		if node is Light3D and not controlled_lights.has(node):
			controlled_lights.append(node)
	_try_append_bathroom_lights(root.get_node_or_null(NodePath("iluminacion")))
	_try_append_bathroom_lights(root.get_node_or_null(NodePath("Jumpscares/BathroomSinkHorror")))


func _try_append_bathroom_lights(container: Node) -> void:
	if container == null:
		return
	for light_name: StringName in [&"OmniLight3DBath1", &"OmniLight3DBath2"]:
		var node := container.get_node_or_null(NodePath(String(light_name)))
		if node is Light3D and not controlled_lights.has(node):
			controlled_lights.append(node)


func _find_descendant_by_name(root: Node, target_name: StringName) -> Node:
	if root == null:
		return null
	if root.name == String(target_name):
		return root
	for child in root.get_children():
		var found := _find_descendant_by_name(child, target_name)
		if found != null:
			return found
	return null


func _has_valid_lights() -> bool:
	for light in controlled_lights:
		if light != null:
			return true
	return false


func _cache_original_energies() -> void:
	_original_energies.clear()
	for light in controlled_lights:
		if light == null:
			continue
		_original_energies[light.get_instance_id()] = light.light_energy


func _get_original_energy(light: Light3D) -> float:
	var id := light.get_instance_id()
	if not _original_energies.has(id):
		_original_energies[id] = light.light_energy
	return _original_energies[id]


func _restore_lights() -> void:
	for light in controlled_lights:
		if light == null:
			continue
		var id := light.get_instance_id()
		if _original_energies.has(id):
			light.light_energy = _original_energies[id]
		light.visible = true
	_set_bulb_visual_on(1.0)


func _set_light_on_random_strength() -> void:
	var strength := randf_range(min_energy_multiplier, max_energy_multiplier)
	for light in controlled_lights:
		if light == null:
			continue
		light.visible = true
		light.light_energy = _get_original_energy(light) * strength
	_set_bulb_visual_on(strength)


func _set_light_off() -> void:
	for light in controlled_lights:
		if light == null:
			continue
		light.light_energy = _get_original_energy(light) * off_energy_multiplier
		if use_hard_off:
			light.visible = false
	_set_bulb_visual_off()


func _run_micro_flicker_burst() -> void:
	var burst_count := randi_range(micro_flicker_count_min, micro_flicker_count_max)
	for _i in burst_count:
		_set_light_off()
		if not await _wait_while_running(randf_range(micro_flicker_min_time, micro_flicker_max_time)):
			return
		_set_light_on_random_strength()
		if not await _wait_while_running(randf_range(micro_flicker_min_time, micro_flicker_max_time)):
			return


func _wait_while_running(duration: float) -> bool:
	await get_tree().create_timer(duration).timeout
	return _flicker_running


func _flicker_loop() -> void:
	while _flicker_running and flicker_enabled:
		_set_light_on_random_strength()
		if not await _wait_while_running(randf_range(min_on_time, max_on_time)):
			break

		if randf() < micro_flicker_chance:
			await _run_micro_flicker_burst()
			if not _flicker_running:
				break

		_set_light_off()
		var off_duration := randf_range(min_off_time, max_off_time)
		if randf() < long_off_chance:
			off_duration = randf_range(min_long_off_time, max_long_off_time)
		if not await _wait_while_running(off_duration):
			break

	_flicker_running = false
