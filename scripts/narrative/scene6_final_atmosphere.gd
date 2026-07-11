extends Node3D
class_name Scene6FinalAtmosphere
## Niebla baja, farola final y luces de la escena 6.

@export_group("Farolas")
@export var end_road_lamp_path: NodePath
@export var street_lamps_root_path: NodePath = NodePath("../../../StreetLamps")

@export_group("Niebla baja (FogVolume)")
@export var fog_region_position: Vector3 = Vector3(-24.0, 0.0, 30.0)
@export var fog_region_size: Vector3 = Vector3(110.0, 2.2, 52.0)
## Capa densa ~30 cm sobre el suelo.
@export_range(0.15, 0.6, 0.01) var dense_layer_height: float = 0.32
@export_range(0.02, 0.35, 0.01) var dense_layer_density: float = 0.14
@export_range(0.4, 2.5, 0.05) var upper_layer_height: float = 1.55
@export_range(0.01, 0.12, 0.005) var upper_layer_density: float = 0.045
@export var fog_volume_albedo: Color = Color(0.48, 0.5, 0.54, 1.0)
@export_range(0.0, 0.08, 0.005) var volumetric_fog_baseline: float = 0.016

@export_group("Niebla de distancia (Environment)")
## El depth fog del Environment tiñe objetos lejanos de gris plano contra cielo negro (siluetas).
## Mejor dejarlo off y usar la niebla atmosférica de Sky3D.
@export var use_depth_fog: bool = false
@export_range(4.0, 80.0, 1.0) var depth_fog_begin: float = 14.0
@export_range(12.0, 120.0, 1.0) var depth_fog_end: float = 58.0
@export_range(0.5, 3.0, 0.05) var depth_fog_curve: float = 1.1
@export var depth_fog_color: Color = Color(0.38, 0.4, 0.44, 1.0)

@export_group("Niebla atmosférica (Sky3D)")
@export var tune_sky3d_fog: bool = true
@export_range(0.00005, 0.001, 0.00001) var sky_fog_density: float = 0.00038
@export_range(10.0, 120.0, 1.0) var sky_fog_start: float = 28.0
@export_range(40.0, 400.0, 1.0) var sky_fog_end: float = 190.0
@export_range(0.5, 4.0, 0.05) var sky_fog_falloff: float = 1.85

@export_group("Presentación")
@export var presentation_path: NodePath = ^"../Scene6Presentation"

@export_group("Cruce de pared")
@export var wall_crossing_size: Vector3 = Vector3(26.0, 4.0, 0.8)

var _ground_fog_dense: FogVolume
var _ground_fog_upper: FogVolume
var _wall_crossing_area: Area3D
var _wall_crossing_shape: CollisionShape3D
var _end_lamp: StreetLampController
var _scene_zone_active: bool = false
var _chase_presentation_active: bool = false
var _wall_crossing_armed: bool = false
var _wall_crossing_triggered: bool = false
var _saved_environment: Dictionary = {}
var _saved_sky_fog: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_ground_fog()
	_build_wall_crossing_area()
	_hide_ground_fog()


## Fin escena 5: niebla suave + resto de farolas encendidas + solo la 4 apagada.
func begin_scene_6_zone(wall: Node3D) -> void:
	if _scene_zone_active:
		_arm_wall_crossing(wall)
		return
	_scene_zone_active = true
	_show_ground_fog()
	_apply_distance_fog()
	call_deferred("_apply_scene_6_zone_lamps_async")
	_arm_wall_crossing(wall)


## Inicio persecución: todas las farolas en parpadeo.
func begin_chase_lamps() -> void:
	if _chase_presentation_active:
		return
	_chase_presentation_active = true
	_set_all_street_lamps_mode(StreetLampController.LampMode.FLICKERING)


func _apply_scene_6_zone_lamps_async() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_set_other_street_lamps_mode(StreetLampController.LampMode.STABLE)
	_set_end_lamp_mode(StreetLampController.LampMode.OFF)


func _arm_wall_crossing(wall: Node3D) -> void:
	if wall == null or not wall.is_inside_tree():
		return
	_wall_crossing_armed = true
	_position_wall_crossing_area(wall)
	_wall_crossing_area.monitoring = not _wall_crossing_triggered


func _build_ground_fog() -> void:
	_ground_fog_dense = _make_fog_volume(
		"GroundMistDense",
		Vector3(fog_region_size.x, dense_layer_height, fog_region_size.z),
		fog_region_position + Vector3(0.0, dense_layer_height * 0.5, 0.0),
		dense_layer_density
	)
	add_child(_ground_fog_dense)

	var upper_y := dense_layer_height + upper_layer_height * 0.5
	_ground_fog_upper = _make_fog_volume(
		"GroundMistUpper",
		Vector3(fog_region_size.x, upper_layer_height, fog_region_size.z),
		fog_region_position + Vector3(0.0, upper_y, 0.0),
		upper_layer_density
	)
	add_child(_ground_fog_upper)


func _make_fog_volume(
	volume_name: String,
	size: Vector3,
	position: Vector3,
	density: float
) -> FogVolume:
	var fog := FogVolume.new()
	fog.name = volume_name
	fog.position = position
	fog.size = size
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	var fog_mat := FogMaterial.new()
	fog_mat.density = density
	fog_mat.albedo = fog_volume_albedo
	fog.material = fog_mat
	return fog


func _build_wall_crossing_area() -> void:
	_wall_crossing_area = Area3D.new()
	_wall_crossing_area.name = "WallCrossingArea"
	_wall_crossing_area.collision_layer = 0
	_wall_crossing_area.collision_mask = 1
	_wall_crossing_area.monitoring = false
	_wall_crossing_area.monitorable = false
	add_child(_wall_crossing_area)

	_wall_crossing_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = wall_crossing_size
	_wall_crossing_shape.shape = box
	_wall_crossing_shape.position = Vector3(0.0, wall_crossing_size.y * 0.5, 0.0)
	_wall_crossing_area.add_child(_wall_crossing_shape)
	_wall_crossing_area.body_entered.connect(_on_wall_crossing_body_entered)


func _position_wall_crossing_area(wall: Node3D) -> void:
	if wall == null or not wall.is_inside_tree() or _wall_crossing_area == null:
		return
	if not _wall_crossing_area.is_inside_tree():
		return
	_wall_crossing_area.global_transform = wall.global_transform
	var shape := _wall_crossing_shape.shape as BoxShape3D
	if shape != null:
		shape.size = wall_crossing_size


func _on_wall_crossing_body_entered(body: Node3D) -> void:
	if not _wall_crossing_armed or _wall_crossing_triggered:
		return
	if not body.is_in_group("player"):
		return
	_wall_crossing_triggered = true
	call_deferred("_handle_wall_crossed")


func _handle_wall_crossed() -> void:
	_wall_crossing_area.set_deferred("monitoring", false)
	_set_end_lamp_mode(StreetLampController.LampMode.FLICKERING)
	var setup := get_parent() as Scene6FinalSceneSetup
	if setup != null:
		setup.ensure_unlocked_from_end_of_road_cross()
		setup.on_end_of_road_crossed()
	var presentation := _resolve_presentation()
	if presentation != null:
		presentation.on_wall_crossed()


func _resolve_end_lamp() -> StreetLampController:
	if _end_lamp != null and is_instance_valid(_end_lamp):
		return _end_lamp
	if not end_road_lamp_path.is_empty():
		_end_lamp = get_node_or_null(end_road_lamp_path) as StreetLampController
	if _end_lamp != null:
		return _end_lamp
	var lamps_root := _resolve_street_lamps_root()
	if lamps_root == null:
		return null
	_end_lamp = lamps_root.get_node_or_null("StreetLampConfigurable4") as StreetLampController
	return _end_lamp


func _resolve_street_lamps_root() -> Node3D:
	if not street_lamps_root_path.is_empty():
		var from_path := get_node_or_null(street_lamps_root_path) as Node3D
		if from_path != null:
			return from_path
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("StreetLamps") as Node3D


func _set_end_lamp_mode(mode: StreetLampController.LampMode) -> void:
	var lamp := _resolve_end_lamp()
	if lamp == null:
		return
	lamp.set_mode(mode)


func _set_other_street_lamps_mode(mode: StreetLampController.LampMode) -> void:
	var lamps_root := _resolve_street_lamps_root()
	if lamps_root == null:
		return
	var end_lamp := _resolve_end_lamp()
	for child in lamps_root.get_children():
		if child is StreetLampController and child != end_lamp:
			(child as StreetLampController).set_mode(mode)


func _set_all_street_lamps_mode(mode: StreetLampController.LampMode) -> void:
	var lamps_root := _resolve_street_lamps_root()
	if lamps_root == null:
		return
	for child in lamps_root.get_children():
		if child is StreetLampController:
			(child as StreetLampController).set_mode(mode)


func _show_ground_fog() -> void:
	if _ground_fog_dense != null:
		_ground_fog_dense.visible = true
	if _ground_fog_upper != null:
		_ground_fog_upper.visible = true


func _hide_ground_fog() -> void:
	if _ground_fog_dense != null:
		_ground_fog_dense.visible = false
	if _ground_fog_upper != null:
		_ground_fog_upper.visible = false


func _resolve_presentation() -> Scene6FinalPresentation:
	return get_node_or_null(presentation_path) as Scene6FinalPresentation


func _apply_distance_fog() -> void:
	var env := _get_world_environment()
	if env != null:
		_save_environment_if_needed(env)
		if use_depth_fog:
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_DEPTH
			env.fog_depth_begin = depth_fog_begin
			env.fog_depth_end = depth_fog_end
			env.fog_depth_curve = depth_fog_curve
			env.fog_light_color = depth_fog_color
			env.fog_light_energy = 0.85
			env.fog_sky_affect = 0.35
		else:
			env.fog_enabled = false

		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = volumetric_fog_baseline
		env.volumetric_fog_albedo = fog_volume_albedo
		env.volumetric_fog_length = 72.0
		env.volumetric_fog_sky_affect = 0.22

	if tune_sky3d_fog:
		_apply_sky3d_atmospheric_fog()


func _save_environment_if_needed(env: Environment) -> void:
	if not _saved_environment.is_empty():
		return
	_saved_environment = {
		"fog_enabled": env.fog_enabled,
		"fog_mode": env.fog_mode,
		"fog_depth_begin": env.fog_depth_begin,
		"fog_depth_end": env.fog_depth_end,
		"fog_depth_curve": env.fog_depth_curve,
		"fog_light_color": env.fog_light_color,
		"fog_light_energy": env.fog_light_energy,
		"fog_sky_affect": env.fog_sky_affect,
		"volumetric_fog_enabled": env.volumetric_fog_enabled,
		"volumetric_fog_density": env.volumetric_fog_density,
		"volumetric_fog_albedo": env.volumetric_fog_albedo,
		"volumetric_fog_length": env.volumetric_fog_length,
		"volumetric_fog_sky_affect": env.volumetric_fog_sky_affect,
	}


func _get_world_environment() -> Environment:
	var sky3d := _get_sky3d()
	if sky3d == null:
		return null
	return sky3d.environment


func _get_sky3d() -> Sky3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Sky3D") as Sky3D


func _apply_sky3d_atmospheric_fog() -> void:
	var sky3d := _get_sky3d()
	if sky3d == null or sky3d.sky == null:
		return
	var dome: SkyDome = sky3d.sky
	_save_sky_fog_if_needed(dome)
	sky3d.fog_enabled = true
	dome.fog_visible = true
	dome.fog_density = sky_fog_density
	dome.fog_start = sky_fog_start
	dome.fog_end = sky_fog_end
	dome.fog_falloff = sky_fog_falloff
	if dome.is_scene_built and dome.fog_mesh != null:
		dome.fog_mesh.visible = true


func _save_sky_fog_if_needed(dome: SkyDome) -> void:
	if not _saved_sky_fog.is_empty():
		return
	_saved_sky_fog = {
		"fog_density": dome.fog_density,
		"fog_start": dome.fog_start,
		"fog_end": dome.fog_end,
		"fog_falloff": dome.fog_falloff,
	}
