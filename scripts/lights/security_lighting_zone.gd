extends Node3D
## Zona de iluminación: focos colocados a mano + aire bajo toldo (FogVolume).

@export_group("Aire más claro bajo el toldo (FogVolume)")
@export var canopy_clear_volume_enabled: bool = true
@export var canopy_volume_size: Vector3 = Vector3(30.0, 8.0, 26.0)
@export var canopy_volume_position: Vector3 = Vector3(-2.0, 4.0, 30.0)
@export_range(-0.15, 0.15, 0.005) var canopy_volume_density: float = -0.08
@export var canopy_volume_albedo: Color = Color(0.1, 0.11, 0.15, 1.0)

const SPOT_SCRIPT := preload("res://scripts/lights/security_spot_light.gd")
const OMNI_SCRIPT := preload("res://scripts/lights/ceiling_omni_light.gd")

var _canopy_fog: FogVolume


func _ready() -> void:
	add_to_group("security_lighting_zones")
	for child in get_children():
		if child is SpotLight3D and child.get_script() == null:
			child.set_script(SPOT_SCRIPT)
		elif child is OmniLight3D and child.get_script() == null:
			_attach_omni_script(child as OmniLight3D)
	if canopy_clear_volume_enabled:
		_setup_canopy_fog_volume()


func apply_time_of_day(day_factor: float, night_factor: float) -> void:
	var night_blend := clampf(night_factor, 0.0, 1.0)
	for child in get_children():
		if child is SpotLight3D and child.has_method("apply_time_profile"):
			child.apply_time_profile(day_factor, night_factor)
		elif child is OmniLight3D:
			if child.has_method("apply_time_profile"):
				child.apply_time_profile(day_factor, night_factor)
			else:
				child.visible = night_blend > 0.05
	if _canopy_fog != null:
		_canopy_fog.visible = night_blend > 0.05


func _attach_omni_script(omni: OmniLight3D) -> void:
	var saved_energy := omni.light_energy
	var saved_range := omni.omni_range
	omni.set_script(OMNI_SCRIPT)
	if saved_energy > 0.01:
		omni.set("night_light_energy", saved_energy)
	if saved_range > 0.01:
		omni.set("night_omni_range", saved_range)
	omni.set("day_light_energy", 0.0)
	omni.set("light_specular_amount", 0.0)
	if omni.name.begins_with("OmniLight3DSuper"):
		omni.set("night_light_size", 0.0)
	if omni.has_method("apply_time_profile"):
		omni.apply_time_profile(1.0, 1.0)


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
