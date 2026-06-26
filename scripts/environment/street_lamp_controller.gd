class_name StreetLampController
extends Node3D
## Farola autocontenida: luces hijas + foco visual + modos OFF / STABLE / FLICKERING.

enum LampMode {
	OFF,
	STABLE,
	FLICKERING,
}

const _BULB_MATERIAL_NAME := &"Light"
const _BULB_NODE_HINTS: Array[StringName] = [&"LampHead", &"Light"]
const _FLICKER_GROUP := &"flicker_managed"

@export_group("Mode")
@export var initial_mode: LampMode = LampMode.STABLE
@export var apply_initial_mode_on_ready: bool = true
@export var randomize_on_start: bool = true

@export_group("Lights")
@export var spot_light_path: NodePath = ^"Lights/SpotLight3D"
@export var omni_light_path: NodePath = ^"Lights/OmniLight3D"
@export var street_lamp_model_path: NodePath = ^"StreetLamp/Model/StreetLampModel"
@export var light_socket_path: NodePath = ^"StreetLamp/LightSocket"
@export var lights_parent_path: NodePath = ^"Lights"
@export var align_lights_to_socket_on_ready: bool = true

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

@export_group("Flicker Audio")
@export var flicker_sound_enabled: bool = true
@export var flicker_sound_player_path: NodePath = ^"FlickerSFX"
## Solo en la fase principal encendida (no en micro-parpadeos).
@export_range(0.0, 1.0) var flicker_sfx_play_chance: float = 1.0
## Duración mínima de la fase ON para disparar SFX (los micro-parpadeos no llaman esto).
@export var flicker_sfx_min_on_duration: float = 0.4
@export_range(0.5, 2.0) var flicker_sfx_pitch_min: float = 0.92
@export_range(0.5, 2.0) var flicker_sfx_pitch_max: float = 1.08

var _current_mode: LampMode = LampMode.STABLE
var _controlled_lights: Array[Light3D] = []
var _original_energies: Dictionary = {}
var _flicker_running: bool = false
var _initialized: bool = false
var _bulb_mesh_targets: Array[MeshInstance3D] = []
var _bulb_surface_targets: Array[int] = []
var _bulb_materials: Array[StandardMaterial3D] = []
var _flicker_audio: AudioStreamPlayer3D


func _ready() -> void:
	if randomize_on_start:
		randomize()
	call_deferred("_begin")


func _begin() -> void:
	_resolve_flicker_audio()
	_align_lights_to_socket()
	_resolve_controlled_lights()
	_resolve_bulb_targets()
	_prepare_bulb_materials()

	if not _has_valid_lights():
		push_warning(
			"StreetLampController sin luces en %s. Revisa spot_light_path / omni_light_path."
			% get_path()
		)
		return

	await get_tree().process_frame
	await get_tree().process_frame
	_cache_original_energies()
	_initialized = true

	if apply_initial_mode_on_ready:
		set_mode(initial_mode)
	else:
		_current_mode = initial_mode


func set_mode(mode: LampMode) -> void:
	_current_mode = mode
	if not _initialized:
		return
	_flicker_running = false
	match mode:
		LampMode.OFF:
			_stop_flicker_audio()
			_unmark_lights_flicker_managed()
			_set_light_off()
		LampMode.STABLE:
			_stop_flicker_audio()
			_unmark_lights_flicker_managed()
			_restore_lights()
		LampMode.FLICKERING:
			_mark_lights_flicker_managed()
			start_flicker()


func set_stable() -> void:
	set_mode(LampMode.STABLE)


func set_off() -> void:
	set_mode(LampMode.OFF)


func set_flickering() -> void:
	set_mode(LampMode.FLICKERING)


func set_flicker_enabled(value: bool) -> void:
	if value:
		set_flickering()
	elif _initialized:
		stop_flicker(true)
		if _current_mode == LampMode.FLICKERING:
			_current_mode = LampMode.STABLE


func start_flicker() -> void:
	if not _has_valid_lights():
		return
	_mark_lights_flicker_managed()
	if _flicker_running:
		return
	_flicker_running = true
	_flicker_loop()


func stop_flicker(restore_lights: bool = true) -> void:
	_flicker_running = false
	_stop_flicker_audio()
	if restore_lights:
		_restore_lights()
	elif _current_mode == LampMode.FLICKERING:
		_set_light_off()


func force_on() -> void:
	if not _has_valid_lights():
		return
	for light in _controlled_lights:
		if light == null:
			continue
		light.visible = true
		light.light_energy = _get_original_energy(light)
	_set_bulb_visual_on(1.0)


func force_off() -> void:
	_set_light_off()


func get_mode() -> LampMode:
	return _current_mode


func _resolve_flicker_audio() -> void:
	_flicker_audio = get_node_or_null(flicker_sound_player_path) as AudioStreamPlayer3D
	if not flicker_sound_enabled:
		return
	if _flicker_audio == null:
		push_warning(
			"StreetLampController: no se encontró AudioStreamPlayer3D en %s (%s)."
			% [get_path(), flicker_sound_player_path]
		)


func _play_flicker_sfx_for_on_phase(on_duration: float) -> void:
	if not flicker_sound_enabled or _flicker_audio == null:
		return
	if _flicker_audio.stream == null:
		return
	if _current_mode != LampMode.FLICKERING or not _flicker_running:
		return
	if on_duration < flicker_sfx_min_on_duration:
		return
	if randf() > flicker_sfx_play_chance:
		return

	_flicker_audio.pitch_scale = randf_range(
		minf(flicker_sfx_pitch_min, flicker_sfx_pitch_max),
		maxf(flicker_sfx_pitch_min, flicker_sfx_pitch_max)
	)
	if _flicker_audio.playing:
		_flicker_audio.stop()
	_flicker_audio.play()


func _stop_flicker_audio() -> void:
	if _flicker_audio != null and _flicker_audio.playing:
		_flicker_audio.stop()


func _align_lights_to_socket() -> void:
	if not align_lights_to_socket_on_ready:
		return
	var socket := get_node_or_null(light_socket_path) as Node3D
	var lights_parent := get_node_or_null(lights_parent_path) as Node3D
	if socket == null or lights_parent == null:
		return
	lights_parent.position = socket.position
	lights_parent.rotation = socket.rotation
	if _flicker_audio != null and _flicker_audio.get_parent() == self:
		_flicker_audio.position = socket.position
		_flicker_audio.rotation = socket.rotation


func _resolve_controlled_lights() -> void:
	_controlled_lights.clear()
	var spot := get_node_or_null(spot_light_path)
	if spot is Light3D:
		_controlled_lights.append(spot as Light3D)
	var omni := get_node_or_null(omni_light_path)
	if omni is Light3D:
		_controlled_lights.append(omni as Light3D)


func _mark_lights_flicker_managed() -> void:
	for light in _controlled_lights:
		if light != null:
			light.add_to_group(_FLICKER_GROUP)


func _unmark_lights_flicker_managed() -> void:
	for light in _controlled_lights:
		if light != null:
			light.remove_from_group(_FLICKER_GROUP)


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
		model_root = _find_descendant_by_name(self, &"StreetLampModel")
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

	if _bulb_materials.is_empty() and control_bulb_material:
		push_warning(
			"StreetLampController: no se encontró material de foco en %s."
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
	for light in _controlled_lights:
		if light != null:
			return true
	return false


func _cache_original_energies() -> void:
	_original_energies.clear()
	for light in _controlled_lights:
		if light == null:
			continue
		_original_energies[light.get_instance_id()] = light.light_energy


func _get_original_energy(light: Light3D) -> float:
	var id := light.get_instance_id()
	if not _original_energies.has(id):
		_original_energies[id] = light.light_energy
	return _original_energies[id]


func _restore_lights() -> void:
	for light in _controlled_lights:
		if light == null:
			continue
		var id := light.get_instance_id()
		if _original_energies.has(id):
			light.light_energy = _original_energies[id]
		light.visible = true
	_set_bulb_visual_on(1.0)


func _set_light_on_random_strength() -> void:
	var strength := randf_range(min_energy_multiplier, max_energy_multiplier)
	for light in _controlled_lights:
		if light == null:
			continue
		light.visible = true
		light.light_energy = _get_original_energy(light) * strength
	_set_bulb_visual_on(strength)


func _set_light_off() -> void:
	for light in _controlled_lights:
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
	return _flicker_running and _current_mode == LampMode.FLICKERING


func _flicker_loop() -> void:
	while _flicker_running and _current_mode == LampMode.FLICKERING:
		var on_duration := randf_range(min_on_time, max_on_time)
		_set_light_on_random_strength()
		_play_flicker_sfx_for_on_phase(on_duration)
		if not await _wait_while_running(on_duration):
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
