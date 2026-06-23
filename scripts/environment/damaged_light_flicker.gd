class_name DamagedLightFlicker
extends Node
## Parpadeo intermitente para luces asignadas manualmente (p. ej. bajo `iluminacion` en el nivel).

@export_group("Lights")
@export var controlled_lights: Array[Light3D] = []
@export var controlled_light_paths: Array[NodePath] = []
@export var start_enabled: bool = true

@export_group("Auto Find")
@export var auto_find_lights: bool = true
@export var iluminacion_path: NodePath = ^"../../iluminacion"
@export var spot_light_name: StringName = &"SpotLight3DStreetLampDamaged1"
@export var omni_light_name: StringName = &"OmniLight3DStreetLampDamaged1"

@export_group("Flicker Timing")
@export var min_on_time: float = 0.45
@export var max_on_time: float = 0.75
@export var min_off_time: float = 0.35
@export var max_off_time: float = 0.65
@export var long_off_chance: float = 0.18
@export var min_long_off_time: float = 1.0
@export var max_long_off_time: float = 2.0

@export_group("Light Intensity")
@export var min_energy_multiplier: float = 0.2
@export var max_energy_multiplier: float = 1.0
@export var off_energy_multiplier: float = 0.0
@export var use_hard_off: bool = true

@export_group("Randomness")
@export var randomize_on_start: bool = true

@export_group("Optional Visual")
@export var emissive_meshes: Array[MeshInstance3D] = []
@export var control_emission: bool = false
@export var emission_on_multiplier: float = 1.0
@export var emission_off_multiplier: float = 0.12

var _original_energies: Dictionary = {}
var _emission_base: Dictionary = {}
var _flicker_running: bool = false


func _ready() -> void:
	if randomize_on_start:
		randomize()
	call_deferred("_begin")


func _begin() -> void:
	_resolve_controlled_lights()
	if not _has_valid_lights():
		push_warning(
			"DamagedLightFlicker sin luces en %s. Revisa Auto Find o controlled_light_paths."
			% get_path()
		)
		return

	# Esperar perfil nocturno / boost de luces del nivel antes de cachear energías.
	await get_tree().process_frame
	await get_tree().process_frame
	_cache_original_energies()
	_cache_emission_base()
	_mark_lights_flicker_managed()
	if start_enabled:
		start_flicker()


func _mark_lights_flicker_managed() -> void:
	for light in controlled_lights:
		if light != null:
			light.add_to_group(&"flicker_managed")


func _resolve_controlled_lights() -> void:
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


func start_flicker() -> void:
	if _flicker_running or not _has_valid_lights():
		return
	_flicker_running = true
	_flicker_loop()


func stop_flicker(restore := true) -> void:
	_flicker_running = false
	if restore:
		_restore_lights()


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


func _cache_emission_base() -> void:
	_emission_base.clear()
	if not control_emission:
		return
	for mesh in emissive_meshes:
		if mesh == null:
			continue
		var mat := mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			_emission_base[mesh.get_instance_id()] = (mat as StandardMaterial3D).emission


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
	if control_emission:
		_apply_emission_multiplier(emission_on_multiplier)


func _set_light_on_random_strength() -> void:
	var strength := randf_range(min_energy_multiplier, max_energy_multiplier)
	for light in controlled_lights:
		if light == null:
			continue
		light.visible = true
		light.light_energy = _get_original_energy(light) * strength
	if control_emission:
		var emission_blend := inverse_lerp(
			min_energy_multiplier,
			max_energy_multiplier,
			strength
		)
		var emission_mult := lerpf(
			emission_off_multiplier,
			emission_on_multiplier,
			emission_blend
		)
		_apply_emission_multiplier(emission_mult)


func _set_light_off() -> void:
	for light in controlled_lights:
		if light == null:
			continue
		light.light_energy = _get_original_energy(light) * off_energy_multiplier
		if use_hard_off:
			light.visible = false
	if control_emission:
		_apply_emission_multiplier(emission_off_multiplier)


func _apply_emission_multiplier(multiplier: float) -> void:
	for mesh in emissive_meshes:
		if mesh == null:
			continue
		var mat := mesh.get_active_material(0)
		if not (mat is StandardMaterial3D):
			continue
		var std := mat as StandardMaterial3D
		var id := mesh.get_instance_id()
		var base: Color = _emission_base.get(id, std.emission)
		if not _emission_base.has(id):
			_emission_base[id] = base
		std.emission = base * multiplier
		std.emission_enabled = multiplier > 0.01


func _flicker_loop() -> void:
	while _flicker_running:
		_set_light_on_random_strength()
		await get_tree().create_timer(randf_range(min_on_time, max_on_time)).timeout
		if not _flicker_running:
			break

		if randf() < 0.38:
			_set_light_off()
			await get_tree().create_timer(randf_range(0.04, 0.12)).timeout
			if not _flicker_running:
				break
			_set_light_on_random_strength()
			await get_tree().create_timer(randf_range(0.03, 0.09)).timeout
			if not _flicker_running:
				break

		_set_light_off()
		var off_duration := randf_range(min_off_time, max_off_time)
		if randf() < long_off_chance:
			off_duration = randf_range(min_long_off_time, max_long_off_time)
		await get_tree().create_timer(off_duration).timeout
