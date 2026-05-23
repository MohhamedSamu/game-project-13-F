extends Node
## Ajustes de ambiente para Sky3D: menú (sin AtmFog, cielo vivo, noche suave) y gameplay nocturno.

enum Profile { MENU, GAMEPLAY }

@export var profile: Profile = Profile.GAMEPLAY
@export var apply_security_lighting: bool = true
@export_range(1.0, 3.0, 0.05) var local_light_energy_mul: float = 1.45
@export_range(0.0, 8.0, 0.1) var local_light_min_volumetric_fog: float = 2.2

const SECURITY_GROUP := &"security_lighting_zones"

var _menu_sky3d: Sky3D


func _ready() -> void:
	call_deferred("_apply")


func _apply() -> void:
	var sky3d := get_parent() as Sky3D
	if sky3d == null or sky3d.sky == null:
		push_warning("Sky3DProjectProfile: el padre debe ser un nodo Sky3D con SkyDome.")
		return
	await get_tree().process_frame
	match profile:
		Profile.MENU:
			_apply_menu(sky3d)
		Profile.GAMEPLAY:
			_apply_gameplay(sky3d)
	if apply_security_lighting:
		_sync_security_lighting(sky3d)
	if profile == Profile.GAMEPLAY:
		_boost_local_lights_in_scene()


func _apply_menu(sky3d: Sky3D) -> void:
	_menu_sky3d = sky3d
	var dome: SkyDome = sky3d.sky
	sky3d.sky_enabled = true
	sky3d.clouds_enabled = true
	sky3d.lights_enabled = true
	sky3d.night_ambient_boost = false
	sky3d.tonemap_exposure = 1.02

	if sky3d.environment:
		sky3d.environment.background_mode = Environment.BG_SKY
		sky3d.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

	dome.atm_level_params = Vector3(0.72, 0.1, 0.08)
	_disable_menu_fog(sky3d)
	_apply_menu_lighting(sky3d)
	_sync_menu_shader_ground(sky3d)

	if sky3d.sky_material:
		sky3d.sky_material.set_shader_parameter("horizon_offset", 0.05)
		sky3d.sky_material.set_shader_parameter("atm_level_params", dome.atm_level_params)
		sky3d.sky_material.set_shader_parameter("cumulus_sky_tint_fade", 0.2)
		sky3d.sky_material.set_shader_parameter("cumulus_thickness", 0.016)
		sky3d.sky_material.set_shader_parameter("cumulus_coverage", 0.48)

	if not dome.day_night_changed.is_connected(_on_menu_day_night_changed):
		dome.day_night_changed.connect(_on_menu_day_night_changed)
	if sky3d.tod and not sky3d.tod.time_changed.is_connected(_on_menu_time_changed):
		sky3d.tod.time_changed.connect(_on_menu_time_changed)

	set_process(true)


func _apply_menu_lighting(sky3d: Sky3D) -> void:
	var dome: SkyDome = sky3d.sky
	var menu_night := MenuHorizonColor.menu_night_blend(sky3d.current_time)
	sky3d.ambient_energy = lerpf(0.9, 0.74, menu_night)
	sky3d.skydome_energy = lerpf(1.12, 0.96, menu_night)
	sky3d.cloud_intensity = lerpf(0.46, 0.4, menu_night)
	sky3d.sky_contribution = lerpf(0.94, 0.84, menu_night)
	sky3d.camera_exposure = lerpf(1.12, 1.0, menu_night)
	sky3d.sun_energy = lerpf(1.05, 0.6, menu_night)
	sky3d.moon_energy = lerpf(0.05, 0.28, menu_night)
	dome.atm_darkness = lerpf(0.34, 0.46, menu_night)
	if sky3d.environment:
		sky3d.environment.ambient_light_energy = sky3d.ambient_energy
		sky3d.environment.ambient_light_sky_contribution = lerpf(0.94, 0.86, menu_night)


func _disable_menu_fog(sky3d: Sky3D) -> void:
	sky3d.fog_enabled = false
	if sky3d.sky == null:
		return
	sky3d.sky.fog_visible = false
	sky3d.sky.fog_density = 0.0
	if sky3d.sky.is_scene_built and sky3d.sky.fog_mesh != null:
		sky3d.sky.fog_mesh.visible = false


func _sync_menu_shader_ground(sky3d: Sky3D) -> void:
	if sky3d.sky_material:
		sky3d.sky_material.set_shader_parameter(
			"ground_color",
			MenuHorizonColor.from_sky3d(sky3d, true)
		)


func _on_menu_day_night_changed(_is_day: bool) -> void:
	if _menu_sky3d != null:
		_disable_menu_fog(_menu_sky3d)
		_apply_menu_lighting(_menu_sky3d)
		_sync_menu_shader_ground(_menu_sky3d)


func _on_menu_time_changed(_time: float) -> void:
	if _menu_sky3d != null:
		_apply_menu_lighting(_menu_sky3d)
		_sync_menu_shader_ground(_menu_sky3d)


func _process(_delta: float) -> void:
	if profile != Profile.MENU or _menu_sky3d == null:
		set_process(false)
		return
	_disable_menu_fog(_menu_sky3d)


func _apply_gameplay(sky3d: Sky3D) -> void:
	_menu_sky3d = null
	set_process(false)
	var dome: SkyDome = sky3d.sky
	if sky3d.environment:
		sky3d.environment.background_mode = Environment.BG_SKY
	sky3d.fog_enabled = true
	sky3d.moon_energy = 0.22
	sky3d.sun_energy = 0.0
	sky3d.skydome_energy = 0.78
	sky3d.cloud_intensity = 0.45
	sky3d.sky_contribution = 0.52
	sky3d.ambient_energy = 0.34
	sky3d.night_ambient_boost = true
	sky3d.night_sky_contribution = 0.42
	sky3d.contribution_tween_time = 0.5

	dome.atm_darkness = 0.58
	dome.atm_night_tint = Color(0.12, 0.15, 0.2, 1.0)
	dome.atm_moon_mie_intensity = 0.4
	dome.fog_density = 0.00022
	dome.fog_start = 75.0
	dome.fog_end = 520.0
	dome.fog_falloff = 1.65
	dome.fog_rayleigh_depth = 0.045
	dome.fog_mie_depth = 0.00004
	dome.fog_atm_level_params_offset = Vector3(0.0, 0.0, -0.35)

	if sky3d.environment:
		sky3d.environment.ambient_light_color = Color(0.22, 0.25, 0.32, 1.0)
		sky3d.environment.ambient_light_energy = 0.34
		sky3d.environment.ambient_light_sky_contribution = 0.42
		sky3d.tonemap_exposure = 1.02
		sky3d.camera_exposure = 1.08

	if sky3d.sky_material:
		sky3d.sky_material.set_shader_parameter("horizon_offset", 0.02)
		sky3d.sky_material.set_shader_parameter("atm_night_tint", dome.atm_night_tint)
		sky3d.sky_material.set_shader_parameter("atm_darkness", dome.atm_darkness)

	sky3d._start_sky_contrib_tween(false)


func _boost_local_lights_in_scene() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	_boost_local_lights_recursive(root)


func _boost_local_lights_recursive(node: Node) -> void:
	if node is SpotLight3D or node is OmniLight3D:
		var light := node as Light3D
		light.light_energy *= local_light_energy_mul
		light.light_indirect_energy = maxf(light.light_indirect_energy, 0.08)
		light.light_volumetric_fog_energy = maxf(
			light.light_volumetric_fog_energy,
			local_light_min_volumetric_fog
		)
	for child in node.get_children():
		_boost_local_lights_recursive(child)


func _sync_security_lighting(sky3d: Sky3D) -> void:
	var factors := _time_factors(sky3d)
	var day_factor: float = factors.x
	var night_factor: float = factors.y
	for node in get_tree().get_nodes_in_group(SECURITY_GROUP):
		if node.has_method("apply_time_of_day"):
			node.apply_time_of_day(day_factor, night_factor)


func _time_factors(sky3d: Sky3D) -> Vector2:
	var hour := sky3d.current_time
	var night := MenuHorizonColor.night_factor(hour)
	if profile == Profile.GAMEPLAY and hour >= 18.0:
		night = maxf(night, 0.85)
	return Vector2(1.0 - night, night)
