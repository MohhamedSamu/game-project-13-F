extends Node3D
## Gasolinera: emisión en paneles + focos (cono) opcionales + aire bajo toldo.
## Omni desactivado por defecto; usar focos para sensación de farol.

@export var gas_station_path: NodePath = ^"../Gas_station"
@export var fixture_surface_name: String = "Light"

@export_group("Emisión paneles cuadrados")
@export_range(0.0, 10.0, 0.1) var fixture_emission_boost_night: float = 3.2
@export_range(0.0, 1.0, 0.05) var fixture_emission_boost_day: float = 0.3

@export_group("Focos automáticos (cono, estilo farol)")
@export var spawn_fixture_spots: bool = true
@export var fixture_spot_energy: float = 16.0
@export_range(8.0, 35.0, 0.5) var fixture_spot_range: float = 18.0
@export_range(15.0, 70.0, 1.0) var fixture_spot_angle: float = 36.0
@export var fixture_spot_volumetric: float = 3.0
@export var fixture_spot_color: Color = Color(1.0, 0.93, 0.8, 1.0)
@export var fixture_spot_cast_shadows: bool = true
## Solo lámparas dentro de esta caja (evita focos dentro del edificio).
@export var limit_spawns_to_exterior_box: bool = true
@export var exterior_box_center: Vector3 = Vector3(-2.0, 6.0, 30.0)
@export var exterior_box_half_extents: Vector3 = Vector3(20.0, 8.0, 22.0)
@export_range(-20.0, 30.0, 0.5) var exterior_y_min: float = 4.0
@export_range(-20.0, 40.0, 0.5) var exterior_y_max: float = 12.0

@export_group("Omni (habitaciones / pruebas; desactivado en gasolinera)")
@export var spawn_fixture_omnis: bool = false
@export var omni_energy_night: float = 7.5
@export_range(4.0, 30.0, 0.5) var omni_range_night: float = 13.0
@export var omni_volumetric_night: float = 0.6
@export var omni_light_color: Color = Color(1.0, 0.93, 0.8, 1.0)

@export_group("Aire más claro bajo el toldo (FogVolume)")
@export var canopy_clear_volume_enabled: bool = true
@export var canopy_volume_size: Vector3 = Vector3(30.0, 8.0, 26.0)
@export var canopy_volume_position: Vector3 = Vector3(-2.0, 4.0, 30.0)
@export_range(-0.15, 0.15, 0.005) var canopy_volume_density: float = -0.08
@export var canopy_volume_albedo: Color = Color(0.1, 0.11, 0.15, 1.0)

const SPOT_SCRIPT := preload("res://scripts/lights/security_spot_light.gd")

var _fixture_materials: Array[StandardMaterial3D] = []
var _fixture_base_emission: Array[Color] = []
var _fixture_omnis: Array[OmniLight3D] = []
var _fixture_spots: Array[SpotLight3D] = []
var _canopy_fog: FogVolume

func _ready() -> void:
	add_to_group("security_lighting_zones")
	_cache_fixture_materials()
	if spawn_fixture_spots:
		_spawn_fixture_spots()
	if spawn_fixture_omnis:
		_spawn_fixture_omnis()
	if canopy_clear_volume_enabled:
		_setup_canopy_fog_volume()
	for child in get_children():
		if child is SpotLight3D and child.get_script() == null:
			child.set_script(SPOT_SCRIPT)

func apply_time_of_day(day_factor: float, night_factor: float) -> void:
	var night_blend := clampf(night_factor, 0.0, 1.0)
	for light in get_children():
		if light is SpotLight3D and light.has_method("apply_time_profile"):
			light.apply_time_profile(day_factor, night_factor)
	for spot in _fixture_spots:
		if not is_instance_valid(spot):
			continue
		if spot.has_method("apply_time_profile"):
			spot.apply_time_profile(day_factor, night_factor)
		else:
			spot.light_energy = fixture_spot_energy * night_blend
			spot.light_volumetric_fog_energy = fixture_spot_volumetric * night_blend
			spot.visible = night_blend > 0.05
	for omni in _fixture_omnis:
		if not is_instance_valid(omni):
			continue
		omni.light_energy = omni_energy_night * night_blend
		omni.omni_range = omni_range_night
		omni.light_volumetric_fog_energy = omni_volumetric_night * night_blend
		omni.visible = night_blend > 0.05
	_apply_fixture_emission(lerpf(fixture_emission_boost_day, fixture_emission_boost_night, night_blend))
	if _canopy_fog != null:
		_canopy_fog.visible = night_blend > 0.05

func _is_exterior_fixture(world_pos: Vector3) -> bool:
	if world_pos.y < exterior_y_min or world_pos.y > exterior_y_max:
		return false
	if not limit_spawns_to_exterior_box:
		return true
	var offset := world_pos - exterior_box_center
	return (
		absf(offset.x) <= exterior_box_half_extents.x
		and absf(offset.y) <= exterior_box_half_extents.y
		and absf(offset.z) <= exterior_box_half_extents.z
	)

func _setup_canopy_fog_volume() -> void:
	_canopy_fog = FogVolume.new()
	_canopy_fog.name = "CanopyClearAir"
	_canopy_fog.position = canopy_volume_position
	_canopy_fog.size = canopy_volume_size
	_canopy_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	var fog_mat := FogMaterial.new()
	fog_mat.density = canopy_volume_density
	fog_mat.albedo = canopy_volume_albedo
	_canopy_fog.material = fog_mat
	add_child(_canopy_fog)

func _spawn_fixture_spots() -> void:
	_clear_fixture_spots()
	var station: Node = get_node_or_null(gas_station_path)
	if station == null:
		return
	_collect_fixture_spots(station)

func _clear_fixture_spots() -> void:
	for spot in _fixture_spots:
		if is_instance_valid(spot):
			spot.queue_free()
	_fixture_spots.clear()

func _collect_fixture_spots(node: Node) -> void:
	if node is MeshInstance3D:
		_try_spawn_spot_at_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_collect_fixture_spots(child)

func _try_spawn_spot_at_mesh(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	for surf_i in mesh.mesh.get_surface_count():
		if mesh.mesh.surface_get_name(surf_i) != fixture_surface_name:
			continue
		var local_center := mesh.get_aabb().get_center()
		var world_pos := mesh.global_transform * local_center
		if not _is_exterior_fixture(world_pos):
			continue
		var spot := SpotLight3D.new()
		spot.name = "FixtureSpot_%s_%d" % [mesh.name, surf_i]
		spot.set_script(SPOT_SCRIPT)
		spot.light_color = fixture_spot_color
		spot.light_energy = fixture_spot_energy
		spot.spot_range = fixture_spot_range
		spot.spot_angle = fixture_spot_angle
		spot.spot_attenuation = 0.85
		spot.light_volumetric_fog_energy = fixture_spot_volumetric
		spot.set("cast_shadows", fixture_spot_cast_shadows)
		add_child(spot)
		spot.global_position = world_pos
		var beam_dir := -mesh.global_transform.basis.y.normalized()
		if beam_dir.length_squared() < 0.01:
			beam_dir = Vector3.DOWN
		if beam_dir.dot(Vector3.DOWN) < 0.25:
			beam_dir = Vector3.DOWN
		var up_hint := Vector3.UP
		if absf(beam_dir.dot(up_hint)) > 0.92:
			up_hint = Vector3.FORWARD
		spot.global_basis = Basis.looking_at(beam_dir, up_hint)
		_fixture_spots.append(spot)

func _spawn_fixture_omnis() -> void:
	for omni in _fixture_omnis:
		if is_instance_valid(omni):
			omni.queue_free()
	_fixture_omnis.clear()
	var station: Node = get_node_or_null(gas_station_path)
	if station == null:
		return
	_collect_fixture_omnis(station)

func _collect_fixture_omnis(node: Node) -> void:
	if node is MeshInstance3D:
		_try_spawn_omni_at_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_collect_fixture_omnis(child)

func _try_spawn_omni_at_mesh(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	for surf_i in mesh.mesh.get_surface_count():
		if mesh.mesh.surface_get_name(surf_i) != fixture_surface_name:
			continue
		var local_center := mesh.get_aabb().get_center()
		var world_pos := mesh.global_transform * local_center
		if not _is_exterior_fixture(world_pos):
			continue
		var omni := OmniLight3D.new()
		omni.name = "FixtureOmni_%s_%d" % [mesh.name, surf_i]
		omni.shadow_enabled = false
		omni.distance_fade_enabled = false
		omni.light_indirect_energy = 0.0
		omni.light_specular = 0.2
		omni.omni_attenuation = 0.75
		omni.light_color = omni_light_color
		omni.light_energy = omni_energy_night
		omni.omni_range = omni_range_night
		omni.light_volumetric_fog_energy = omni_volumetric_night
		add_child(omni)
		omni.global_position = world_pos
		_fixture_omnis.append(omni)

func _cache_fixture_materials() -> void:
	_fixture_materials.clear()
	_fixture_base_emission.clear()
	var station: Node = get_node_or_null(gas_station_path)
	if station == null:
		return
	_collect_fixture_materials(station)

func _collect_fixture_materials(node: Node) -> void:
	if node is MeshInstance3D:
		_extract_light_surfaces(node as MeshInstance3D)
	for child in node.get_children():
		_collect_fixture_materials(child)

func _extract_light_surfaces(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	for i in mesh.mesh.get_surface_count():
		if mesh.mesh.surface_get_name(i) != fixture_surface_name:
			continue
		var mat: Material = mesh.get_surface_override_material(i)
		if mat == null:
			mat = mesh.mesh.surface_get_material(i)
		if mat == null or not (mat is StandardMaterial3D):
			continue
		var std := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		std.emission_enabled = true
		mesh.set_surface_override_material(i, std)
		_fixture_materials.append(std)
		_fixture_base_emission.append(std.emission)

func _apply_fixture_emission(boost: float) -> void:
	for i in _fixture_materials.size():
		var base: Color = _fixture_base_emission[i]
		var mat := _fixture_materials[i]
		mat.emission = base * boost
		mat.emission_energy_multiplier = clampf(boost * 0.55, 0.5, 4.0)
