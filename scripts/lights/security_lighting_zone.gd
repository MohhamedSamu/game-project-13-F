extends Node3D
## Zona de iluminación: emisión en paneles "Light", FogVolume bajo toldo,
## y ciclo día/noche para luces hijas que coloques a mano (Spot u Omni con script).

@export var gas_station_path: NodePath = ^"../Gas_station"
@export var fixture_surface_name: String = "Light"

@export_group("Emisión paneles cuadrados")
@export_range(0.0, 10.0, 0.1) var fixture_emission_boost_night: float = 3.2
@export_range(0.0, 1.0, 0.05) var fixture_emission_boost_day: float = 0.3

@export_group("Aire más claro bajo el toldo (FogVolume)")
@export var canopy_clear_volume_enabled: bool = true
@export var canopy_volume_size: Vector3 = Vector3(30.0, 8.0, 26.0)
@export var canopy_volume_position: Vector3 = Vector3(-2.0, 4.0, 30.0)
@export_range(-0.15, 0.15, 0.005) var canopy_volume_density: float = -0.08
@export var canopy_volume_albedo: Color = Color(0.1, 0.11, 0.15, 1.0)

const SPOT_SCRIPT := preload("res://scripts/lights/security_spot_light.gd")
const CEILING_OMNI_SCRIPT := preload("res://scripts/lights/ceiling_omni_light.gd")

var _fixture_materials: Array[StandardMaterial3D] = []
var _fixture_base_emission: Array[Color] = []
var _canopy_fog: FogVolume

func _ready() -> void:
	add_to_group("security_lighting_zones")
	_cache_fixture_materials()
	if canopy_clear_volume_enabled:
		_setup_canopy_fog_volume()
	_attach_scripts_to_manual_lights()

func _attach_scripts_to_manual_lights() -> void:
	for child in get_children():
		if child is SpotLight3D and child.get_script() == null:
			child.set_script(SPOT_SCRIPT)
		elif child is OmniLight3D and child.get_script() == null:
			child.set_script(CEILING_OMNI_SCRIPT)

func apply_time_of_day(day_factor: float, night_factor: float) -> void:
	var night_blend := clampf(night_factor, 0.0, 1.0)
	for child in get_children():
		if child.has_method("apply_time_profile"):
			child.apply_time_profile(day_factor, night_factor)
	_apply_fixture_emission(lerpf(fixture_emission_boost_day, fixture_emission_boost_night, night_blend))
	if _canopy_fog != null:
		_canopy_fog.visible = night_blend > 0.05

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
