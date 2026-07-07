extends Node3D
class_name Scene6FinalAtmosphere
## Niebla baja, farola final y luces de la escena 6.

@export_group("Farolas")
@export var end_road_lamp_path: NodePath
@export var street_lamps_root_path: NodePath = NodePath("../../../StreetLamps")

@export_group("Niebla baja (FogVolume)")
@export var fog_volume_size: Vector3 = Vector3(110.0, 2.0, 52.0)
@export var fog_volume_position: Vector3 = Vector3(-24.0, 1.0, 30.0)
## Densidad del volumen local. Valores >0.35 suelen lavar la imagen en blanco.
@export_range(0.01, 0.5, 0.01) var fog_volume_density: float = 0.08
@export var fog_volume_albedo: Color = Color(0.48, 0.5, 0.54, 1.0)
## Densidad global mínima para que FogVolume funcione sin lavar la escena.
@export_range(0.0, 0.08, 0.005) var volumetric_fog_baseline: float = 0.018

@export_group("Niebla de distancia (Environment)")
@export var use_depth_fog: bool = true
@export_range(4.0, 80.0, 1.0) var depth_fog_begin: float = 14.0
@export_range(12.0, 120.0, 1.0) var depth_fog_end: float = 58.0
@export_range(0.5, 3.0, 0.05) var depth_fog_curve: float = 1.1
@export var depth_fog_color: Color = Color(0.38, 0.4, 0.44, 1.0)

@export_group("Cruce de pared")
@export var wall_crossing_size: Vector3 = Vector3(26.0, 4.0, 0.8)

var _ground_fog: FogVolume
var _wall_crossing_area: Area3D
var _wall_crossing_shape: CollisionShape3D
var _end_lamp: StreetLampController
var _scene_zone_active: bool = false
var _chase_presentation_active: bool = false
var _wall_crossing_armed: bool = false
var _wall_crossing_triggered: bool = false
var _saved_environment: Dictionary = {}


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
	print("Scene6FinalAtmosphere: zona escena 6 activa (niebla + farola 4 apagada).")


## Inicio persecución: todas las farolas en parpadeo.
func begin_chase_presentation() -> void:
	if _chase_presentation_active:
		return
	_chase_presentation_active = true
	_set_all_street_lamps_mode(StreetLampController.LampMode.FLICKERING)
	print("Scene6FinalAtmosphere: persecución iniciada; todas las farolas en flicker.")


func _apply_scene_6_zone_lamps_async() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_set_other_street_lamps_mode(StreetLampController.LampMode.STABLE)
	_set_end_lamp_mode(StreetLampController.LampMode.OFF)


func _arm_wall_crossing(wall: Node3D) -> void:
	if wall == null or not wall.is_inside_tree():
		push_warning("Scene6FinalAtmosphere: no se pudo armar el cruce de pared.")
		return
	_wall_crossing_armed = true
	_position_wall_crossing_area(wall)
	_wall_crossing_area.monitoring = not _wall_crossing_triggered
	print("Scene6FinalAtmosphere: detector de pared armado en ", _wall_crossing_area.global_position)


func _build_ground_fog() -> void:
	_ground_fog = FogVolume.new()
	_ground_fog.name = "GroundMist"
	_ground_fog.position = fog_volume_position
	_ground_fog.size = fog_volume_size
	_ground_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_update_ground_fog_material()
	add_child(_ground_fog)


func _update_ground_fog_material() -> void:
	if _ground_fog == null:
		return
	var fog_mat := FogMaterial.new()
	fog_mat.density = fog_volume_density
	fog_mat.albedo = fog_volume_albedo
	_ground_fog.material = fog_mat


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
	_wall_crossing_area.monitoring = false
	_set_end_lamp_mode(StreetLampController.LampMode.FLICKERING)
	print("Scene6FinalAtmosphere: jugador cruzó la pared; farola 4 en flicker.")


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
		push_warning("Scene6FinalAtmosphere: no se encontró StreetLampConfigurable4.")
		return
	lamp.set_mode(mode)


func _set_other_street_lamps_mode(mode: StreetLampController.LampMode) -> void:
	var lamps_root := _resolve_street_lamps_root()
	if lamps_root == null:
		push_warning("Scene6FinalAtmosphere: no se encontró el nodo StreetLamps.")
		return
	var end_lamp := _resolve_end_lamp()
	for child in lamps_root.get_children():
		if child is StreetLampController and child != end_lamp:
			(child as StreetLampController).set_mode(mode)


func _set_all_street_lamps_mode(mode: StreetLampController.LampMode) -> void:
	var lamps_root := _resolve_street_lamps_root()
	if lamps_root == null:
		push_warning("Scene6FinalAtmosphere: no se encontró el nodo StreetLamps.")
		return
	for child in lamps_root.get_children():
		if child is StreetLampController:
			(child as StreetLampController).set_mode(mode)


func _show_ground_fog() -> void:
	_update_ground_fog_material()
	if _ground_fog != null:
		_ground_fog.visible = true


func _hide_ground_fog() -> void:
	if _ground_fog != null:
		_ground_fog.visible = false


func _apply_distance_fog() -> void:
	if not use_depth_fog:
		return
	var env := _get_world_environment()
	if env == null:
		return
	_save_environment_if_needed(env)

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = depth_fog_begin
	env.fog_depth_end = depth_fog_end
	env.fog_depth_curve = depth_fog_curve
	env.fog_light_color = depth_fog_color
	env.fog_light_energy = 0.85
	env.fog_sky_affect = 0.0

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = volumetric_fog_baseline
	env.volumetric_fog_albedo = fog_volume_albedo
	env.volumetric_fog_length = 64.0
	env.volumetric_fog_sky_affect = 0.0


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
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var world_env := scene.get_node_or_null("Sky3D") as WorldEnvironment
	if world_env == null:
		return null
	return world_env.environment
