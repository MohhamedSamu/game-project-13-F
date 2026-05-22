extends Node3D

const SKY_SHADER_PATH := "res://assets/shaders/sky_day_night.gdshader"
const SUN_TEX := preload("res://assets/materials/Sun.png")
const MOON_TEX := preload("res://assets/materials/Moon.png")
const POM_CLOUD_MAT := preload("res://addons/POM clouds/POM_Clouds_shader_material.tres")

enum TimeMode {
	## El ciclo avanza solo (menú, demos).
	CYCLE,
	## Hora fija: no avanza; usa [member fixed_hour] (niveles con ambiente concreto).
	FROZEN,
}

enum AmbienceProfile {
	## Menú = SubViewport; niveles = escena principal.
	AUTO,
	## Fuerza reglas de menú (ciclo, nubes altas, sin niebla de gameplay).
	MENU_CINEMATIC,
	## Fuerza reglas de gameplay (niebla, POM Clouds).
	GAMEPLAY,
}

@export_group("Tiempo")
@export var time_mode: TimeMode = TimeMode.CYCLE
## Solo si [member time_mode] = Ciclo. Segundos reales para un día completo (24 h del ciclo).
@export var cycle_seconds: float = 40.0
## Solo si [member time_mode] = Hora fija. 0–23.75 (p. ej. 15 = 3:00 pm, 0 = medianoche).
@export_range(0.0, 23.75, 0.25) var fixed_hour: float = 12.0
## A las 6:00 del reloj del juego el sol está en el horizonte (amanecer). Ajusta si el ciclo no cuadra.
@export_range(0.0, 23.0, 0.25) var cycle_sunrise_hour: float = 6.0

@export_group("Órbita")
@export var tilt_degrees: float = 20.0
@export var orbit_radius: float = 2800.0

@export_group("Luces")
@export var sun_energy_day: float = 2.0
## Luz direccional de la luna a plena noche (valores bajos = más oscuro).
@export_range(0.0, 1.0, 0.01) var moon_energy_night: float = 0.08
@export_range(0.0, 1.0, 0.01) var moon_indirect_energy: float = 0.12
## Curva extra: 1 = lineal; >1 apaga la luna antes (más contraste día/noche).
@export_range(0.5, 3.0, 0.05) var night_light_falloff: float = 1.8
@export_range(0.0, 0.5, 0.01) var transition_softness: float = 0.15

@export_group("Cielo / exposición")
@export var exposure_day: float = 1.0
@export_range(0.1, 1.5, 0.01) var exposure_night: float = 0.4
@export var sky_day_color: Color = Color(0.55, 0.75, 1.0, 1.0)
@export var sky_sunset_color: Color = Color(1.0, 0.45, 0.15, 1.0)
@export var sky_night_color: Color = Color(0.03, 0.04, 0.08, 1.0)
@export_range(0.0, 0.5, 0.01) var sunset_band: float = 0.18

@export_group("Visibilidad gameplay")
@export var adjust_gameplay_visibility: bool = true
## Si false, el far no baja de noche (la luna/orbita no se recortan); la niebla limita la vista.
@export var limit_visibility_with_camera_far: bool = false
@export_range(2000.0, 50000.0, 100.0) var camera_far_gameplay: float = 8000.0
@export_range(500.0, 10000.0, 50.0) var camera_far_day: float = 3500.0
@export_range(80.0, 1200.0, 10.0) var camera_far_night: float = 350.0
@export var adjust_gameplay_fog: bool = true
@export_range(30.0, 300.0, 1.0) var gameplay_fog_end_day: float = 95.0
@export_range(5.0, 80.0, 1.0) var gameplay_fog_end_night: float = 18.0
## Modo depth: intensidad 0–1 a [member gameplay_fog_end_night] (1 = muro opaco).
@export_range(0.0, 1.0, 0.05) var gameplay_fog_density_day: float = 0.5
@export_range(0.0, 1.0, 0.05) var gameplay_fog_density_night: float = 0.92
@export_range(0.0, 120.0, 1.0) var gameplay_fog_begin_day: float = 35.0
@export_range(0.0, 20.0, 1.0) var gameplay_fog_begin_night: float = 4.0
@export var gameplay_fog_color_day: Color = Color(0.52, 0.58, 0.68, 1.0)
@export var gameplay_fog_color_night: Color = Color(0.14, 0.16, 0.22, 1.0)
## Niebla volumétrica (suele verse mejor que solo depth en Forward+).
@export var gameplay_use_volumetric_fog: bool = true
@export_range(0.0, 2.0, 0.05) var gameplay_volumetric_fog_density_night: float = 0.2
@export_range(0.0, 2.0, 0.05) var gameplay_volumetric_fog_density_day: float = 0.04
## Solo gameplay; el menú desactiva toda la niebla.
@export var gameplay_fog_use_height: bool = true
@export_range(0.0, 500.0, 1.0) var gameplay_fog_height: float = 2.5
@export_range(0.0, 2.0, 0.05) var gameplay_fog_height_density_day: float = 0.08
@export_range(0.0, 2.0, 0.05) var gameplay_fog_height_density_night: float = 0.26

@export_group("Sprites gameplay (PNG)")
@export_range(0.3, 4.0, 0.05) var gameplay_moon_pixel_size: float = 2.0
@export_range(0.2, 2.0, 0.05) var gameplay_sun_pixel_size: float = 0.45

@export_group("Perfil de ambiente")
@export var ambience_profile: AmbienceProfile = AmbienceProfile.AUTO

@export_group("Menú cinemático")
@export_range(0.55, 1.5, 0.05) var menu_exposure_night: float = 0.92
@export_range(0.8, 1.5, 0.05) var menu_exposure_day: float = 1.05
@export_range(0.0, 2.0, 0.05) var menu_sun_energy_day: float = 1.4
@export_range(0.0, 1.0, 0.05) var menu_sun_energy_night: float = 0.18
@export_range(0.0, 1.0, 0.05) var menu_moon_energy: float = 0.3
@export_range(0.0, 0.5, 0.02) var menu_moon_indirect_energy: float = 0.04
@export_range(0.0, 1.0, 0.05) var menu_ambient_energy_night: float = 0.16
@export_range(0.0, 1.0, 0.05) var menu_ambient_energy_day: float = 0.12
@export var menu_show_celestial_sprites: bool = true
## Más lejos que [member orbit_radius] para no tapar el volcán (gameplay sigue en 2800).
@export_range(4000.0, 25000.0, 100.0) var menu_orbit_radius: float = 12000.0
@export_range(0.4, 8.0, 0.05) var menu_sprite_pixel_size: float = 3.2
@export var menu_scale_sprite_with_orbit: bool = true
## La textura de la luna suele verse más pequeña que la del sol (márgenes en el PNG).
@export_range(1.0, 4.0, 0.05) var menu_moon_size_multiplier: float = 2.25
## 0 = misma distancia que el sol; si la acercas, no hace falta subir tanto el multiplicador.
@export_range(0.0, 25000.0, 100.0) var menu_moon_orbit_radius: float = 0.0
## Por encima del pico del terreno (~5 km en este mapa) + margen.
@export_group("POM Clouds (ligeras, valores demo)")
@export var pom_clouds_enabled: bool = true
@export var pom_clouds_in_gameplay: bool = true
## Como la demo: sin sprites 3D de sol/luna cuando hay nubes POM (solo luces direccionales).
@export var hide_celestial_sprites_with_pom: bool = true
@export_range(8, 25, 1) var pom_layers: int = 15
@export_range(3500.0, 12000.0, 50.0) var pom_height: float = 6000.0
@export_range(20000.0, 150000.0, 1000.0) var pom_mesh_scale: float = 100000.0
@export_range(0.01, 0.06, 0.001) var pom_layer_gap: float = 0.03
@export_range(20.0, 300.0, 5.0) var pom_wind_resistance: float = 100.0
@export_range(0.5, 8.0, 0.1) var pom_uv_scale: float = 5.0

@export_group("Estrellas")
@export_range(40.0, 400.0, 1.0) var star_density: float = 140.0
@export_range(0.2, 3.0, 0.05) var star_brightness: float = 1.15
@export_range(0.004, 0.035, 0.001) var star_size: float = 0.014
@export_range(0.5, 3.0, 0.1) var star_glow: float = 1.6
@export_range(0.0, 1.0, 0.01) var star_horizon_cutoff: float = 0.0
@export_range(0.0, 23.0, 0.25) var star_start_hour: float = 18.5
@export_range(0.0, 23.0, 0.25) var star_end_hour: float = 5.5
@export_range(0.0, 3.0, 0.1) var star_fade_hours: float = 1.0
@export_range(0.0, 1.0, 0.01) var star_max_sunset_factor: float = 0.12
@export_range(0.0, 1.0, 0.01) var star_min_night_factor: float = 0.58

@export_group("Debug")
@export var debug_print: bool = false

@onready var sun_pivot: Node3D = $SunPivot
@onready var moon_pivot: Node3D = $MoonPivot
@onready var sun_light: DirectionalLight3D = $SunPivot/SunDirectional
@onready var moon_light: DirectionalLight3D = $MoonPivot/MoonDirectional
@onready var sun_sprite: Sprite3D = $SunPivot/SunSprite3D
@onready var moon_sprite: Sprite3D = $MoonPivot/MoonSprite3D
@onready var we: WorldEnvironment = $WorldEnvironment
@onready var pom_clouds: POM_Clouds = $POM_Clouds

## Posición en el ciclo 0..1 (solo lectura útil en depuración).
var t: float = 0.0
var _sky_material: ShaderMaterial
var _pom_cached_layers: int = -1
var _pom_cached_menu: bool = false

func _ready() -> void:
	rotation_degrees.z = tilt_degrees
	_setup_celestial_textures()
	sun_sprite.position = Vector3(0.0, 0.0, -orbit_radius)
	moon_sprite.position = Vector3(0.0, 0.0, -orbit_radius)
	_prepare_world_environment()
	_sync_cycle_time()
	_apply_at_cycle_t(t)
	if pom_clouds_enabled:
		call_deferred("_setup_pom_clouds")
	if debug_print:
		print(
			"DayNightRig mode:", TimeMode.keys()[time_mode],
			" hour:", get_clock_hour(),
			" profile:", "menu" if _uses_menu_cinematic() else "gameplay"
		)

func _process(delta: float) -> void:
	if time_mode == TimeMode.CYCLE:
		if cycle_seconds <= 0.01:
			return
		t = fposmod(t + delta / cycle_seconds, 1.0)
	else:
		t = _hour_to_cycle_t(fixed_hour)
	_apply_at_cycle_t(t)
	if debug_print and Engine.get_frames_drawn() % 60 == 0:
		print(
			"DayNightRig hour:", get_clock_hour(),
			" stars:", _last_star_factor,
			" mode:", TimeMode.keys()[time_mode]
		)

var _last_star_factor: float = 0.0

## Hora del reloj del juego (0–24) según el ciclo actual.
func get_clock_hour() -> float:
	return _cycle_hour()

## Pasa a ciclo continuo o hora fija en runtime.
func set_time_mode(mode: TimeMode) -> void:
	time_mode = mode
	_sync_cycle_time()

## Atajo: true = ciclo, false = congelado en [param hour].
func set_time_running(running: bool, hour: float = -1.0) -> void:
	if running:
		set_time_mode(TimeMode.CYCLE)
	else:
		if hour >= 0.0:
			fixed_hour = clampf(hour, 0.0, 23.75)
		set_time_mode(TimeMode.FROZEN)

## Fija la hora (solo efecto real si el modo es FROZEN o llamas después a set_time_mode(FROZEN)).
func set_fixed_hour(hour: float) -> void:
	fixed_hour = clampf(hour, 0.0, 23.75)
	if time_mode == TimeMode.FROZEN:
		t = _hour_to_cycle_t(fixed_hour)
		_apply_at_cycle_t(t)

func _sync_cycle_time() -> void:
	if time_mode == TimeMode.FROZEN:
		t = _hour_to_cycle_t(fixed_hour)

func _hour_to_cycle_t(hour: float) -> float:
	return fposmod((hour - cycle_sunrise_hour) / 24.0, 1.0)

func _apply_at_cycle_t(cycle_t: float) -> void:
	var ang: float = cycle_t * TAU
	var sun_height: float = sin(ang)

	sun_pivot.rotation.x = ang
	moon_pivot.rotation.x = ang + PI

	_align_directional_light(sun_sprite, sun_pivot, sun_light)
	_align_directional_light(moon_sprite, moon_pivot, moon_light)

	var day_factor: float = _smooth_horizon(sun_height, transition_softness)
	var night_factor: float = 1.0 - day_factor
	var sunset_factor: float = _sunset_factor(sun_height, sunset_band)

	if _uses_menu_cinematic():
		_apply_menu_cinematic(day_factor, night_factor, sunset_factor)
		return

	sun_sprite.top_level = false
	moon_sprite.top_level = false
	sun_sprite.no_depth_test = false
	moon_sprite.no_depth_test = false
	sun_light.light_energy = lerp(0.0, sun_energy_day, day_factor)
	var night_light: float = pow(night_factor, night_light_falloff)
	moon_light.light_energy = moon_energy_night * night_light
	moon_light.light_indirect_energy = moon_indirect_energy * night_light
	sun_light.shadow_enabled = day_factor > 0.35
	moon_light.shadow_enabled = night_light > 0.2
	_update_gameplay_celestial_layout(day_factor, night_factor)

	var star_vis := _star_visibility_factor(sunset_factor, night_factor)
	star_vis = maxf(star_vis, _star_hour_factor() * night_factor)
	_last_star_factor = star_vis
	_update_sky_shader(day_factor, sunset_factor, night_factor, _last_star_factor)

	if we.environment:
		we.environment.tonemap_exposure = lerp(exposure_night, exposure_day, day_factor)
		we.environment.background_energy_multiplier = lerpf(1.05, 0.85, day_factor)

	_update_gameplay_visibility(day_factor, night_factor, sunset_factor)
	_apply_security_lighting_zones(day_factor, night_factor)
	_apply_pom_clouds_profile(day_factor, night_factor)
	_sync_celestial_sprites_visibility(day_factor, night_factor)

func _is_menu_viewport() -> bool:
	# El rig vive *dentro* del SubViewport; el padre es SubViewportContainer, no SubViewport.
	var vp := get_viewport()
	return vp is SubViewport

func _uses_menu_cinematic() -> bool:
	match ambience_profile:
		AmbienceProfile.MENU_CINEMATIC:
			return true
		AmbienceProfile.GAMEPLAY:
			return false
		_:
			return _is_menu_viewport()

func _apply_menu_cinematic(
	day_factor: float,
	night_factor: float,
	sunset_factor: float
) -> void:
	var night_terrain: float = maxf(night_factor, 0.08)
	sun_light.light_energy = lerpf(menu_sun_energy_night, menu_sun_energy_day, day_factor)
	moon_light.light_energy = menu_moon_energy * night_terrain
	moon_light.light_indirect_energy = menu_moon_indirect_energy * night_terrain
	sun_light.shadow_enabled = false
	moon_light.shadow_enabled = false

	if menu_show_celestial_sprites:
		_apply_menu_celestial_sprites(day_factor, night_factor)

	var menu_stars: float = _star_hour_factor()
	_last_star_factor = menu_stars
	_update_sky_shader(day_factor, sunset_factor, night_factor, menu_stars)

	if we.environment:
		var env := we.environment
		env.tonemap_exposure = lerpf(menu_exposure_night, menu_exposure_day, day_factor)
		env.background_energy_multiplier = lerpf(1.05, 0.95, night_factor)
		_disable_fog_for_menu(env)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = sky_night_color.lerp(sky_day_color, day_factor)
		env.ambient_light_energy = lerpf(
			menu_ambient_energy_night,
			menu_ambient_energy_day,
			day_factor
		)

	_apply_pom_clouds_profile(day_factor, night_factor)
	_sync_celestial_sprites_visibility(day_factor, night_factor)

func _apply_menu_celestial_sprites(day_factor: float, night_factor: float) -> void:
	# Orbitan con SunPivot/MoonPivot (ya rotados arriba); sin top_level ni depth test off.
	sun_sprite.top_level = false
	moon_sprite.top_level = false
	sun_sprite.no_depth_test = false
	moon_sprite.no_depth_test = false
	var sun_r: float = menu_orbit_radius
	var moon_r: float = menu_moon_orbit_radius if menu_moon_orbit_radius > 0.0 else sun_r
	sun_sprite.position = Vector3(0.0, 0.0, -sun_r)
	moon_sprite.position = Vector3(0.0, 0.0, -moon_r)
	var px: float = _menu_sprite_pixel_size()
	sun_sprite.pixel_size = px
	moon_sprite.pixel_size = px * menu_moon_size_multiplier
	sun_sprite.modulate = Color(1.0, 0.98, 0.92, 1.0)
	moon_sprite.modulate = Color(0.92, 0.95, 1.0, 1.0)
	_align_directional_light(sun_sprite, sun_pivot, sun_light)
	_align_directional_light(moon_sprite, moon_pivot, moon_light)

func _menu_sprite_pixel_size() -> float:
	if not menu_scale_sprite_with_orbit or menu_orbit_radius <= 1.0:
		return menu_sprite_pixel_size
	return menu_sprite_pixel_size * orbit_radius / menu_orbit_radius

func _sky_horizon_color(day_factor: float, night_factor: float, sunset_factor: float) -> Color:
	var col := sky_night_color.lerp(sky_day_color, day_factor)
	return col.lerp(sky_sunset_color, sunset_factor * 0.55)

func _setup_pom_clouds() -> void:
	if pom_clouds == null:
		return
	if POM_CLOUD_MAT != null:
		pom_clouds.material_override = POM_CLOUD_MAT.duplicate()
	pom_clouds.visible = pom_clouds_enabled
	_pom_cached_layers = -1
	_apply_pom_clouds_profile(1.0, 0.0)

func _should_show_pom_clouds() -> bool:
	if not pom_clouds_enabled or pom_clouds == null:
		return false
	if _uses_menu_cinematic():
		return true
	return pom_clouds_in_gameplay

func _apply_pom_clouds_profile(_day_factor: float, _night_factor: float) -> void:
	if pom_clouds == null:
		return
	var menu := _uses_menu_cinematic()
	var show := _should_show_pom_clouds()
	pom_clouds.visible = show
	if not show:
		return
	pom_clouds.height = pom_height
	pom_clouds._scale = pom_mesh_scale
	# El script del addon solo aplica escala en el editor; en juego hay que setearla aquí.
	pom_clouds.scale = Vector3.ONE * pom_mesh_scale
	if pom_clouds.material_override is ShaderMaterial:
		var sm := pom_clouds.material_override as ShaderMaterial
		sm.set_shader_parameter("mesh_scale", pom_mesh_scale)
		sm.set_shader_parameter("wind_resistance", pom_wind_resistance)
		sm.set_shader_parameter("uv_scale", pom_uv_scale)
		sm.set_shader_parameter("layer_gap", pom_layer_gap)
	if pom_clouds.POM_layers != pom_layers:
		pom_clouds.POM_layers = pom_layers
	if _pom_cached_layers != pom_layers or _pom_cached_menu != menu:
		pom_clouds.do_POM()
		_pom_cached_layers = pom_layers
		_pom_cached_menu = menu

func _sync_celestial_sprites_visibility(day_factor: float, night_factor: float) -> void:
	if hide_celestial_sprites_with_pom and _should_show_pom_clouds():
		sun_sprite.visible = false
		moon_sprite.visible = false
		return
	if _uses_menu_cinematic():
		if not menu_show_celestial_sprites:
			sun_sprite.visible = false
			moon_sprite.visible = false
			return
		sun_sprite.visible = day_factor > 0.12
		moon_sprite.visible = night_factor > 0.12
		sun_sprite.render_priority = -2
		moon_sprite.render_priority = -1
	else:
		sun_sprite.visible = day_factor > 0.12
		moon_sprite.visible = night_factor > 0.12
		sun_sprite.render_priority = 10
		moon_sprite.render_priority = 11

func _make_celestial_sprite_material(tex: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.albedo_color = Color.WHITE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	mat.disable_receive_shadows = true
	return mat

func _setup_celestial_textures() -> void:
	sun_sprite.material_override = _make_celestial_sprite_material(SUN_TEX)
	moon_sprite.material_override = _make_celestial_sprite_material(MOON_TEX)
	sun_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	moon_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sun_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	moon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sun_sprite.shaded = false
	moon_sprite.shaded = false
	sun_sprite.modulate = Color.WHITE
	moon_sprite.modulate = Color.WHITE
	sun_sprite.render_priority = 10
	moon_sprite.render_priority = 11

func _update_gameplay_celestial_layout(_day_factor: float, _night_factor: float) -> void:
	sun_sprite.position = Vector3(0.0, 0.0, -orbit_radius)
	moon_sprite.position = Vector3(0.0, 0.0, -orbit_radius)
	sun_sprite.pixel_size = gameplay_sun_pixel_size
	moon_sprite.pixel_size = gameplay_moon_pixel_size

func _min_camera_far_for_celestials(cam: Camera3D) -> float:
	var d := maxf(
		cam.global_position.distance_to(sun_sprite.global_position),
		cam.global_position.distance_to(moon_sprite.global_position)
	)
	return d + 250.0

func _update_gameplay_visibility(
	day_factor: float,
	night_factor: float,
	sunset_factor: float
) -> void:
	if not adjust_gameplay_visibility:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	if _uses_menu_cinematic():
		return
	var target_far: float
	if limit_visibility_with_camera_far:
		target_far = lerpf(camera_far_night, camera_far_day, day_factor)
	else:
		target_far = camera_far_gameplay
	cam.far = maxf(target_far, _min_camera_far_for_celestials(cam))
	_apply_gameplay_fog(day_factor, night_factor, sunset_factor)

func _prepare_world_environment() -> void:
	if we == null:
		return
	if we.environment:
		we.environment = we.environment.duplicate(true)
		we.environment.background_mode = Environment.BG_SKY
	_cache_sky_material()
	if debug_print and we.environment:
		print("DayNightRig fog_enabled:", we.environment.fog_enabled)

func _disable_fog_for_menu(env: Environment) -> void:
	env.fog_enabled = false
	env.fog_sky_affect = 0.0
	env.fog_height = 0.0
	env.fog_height_density = 0.0
	env.volumetric_fog_enabled = false

func _apply_security_lighting_zones(day_factor: float, night_factor: float) -> void:
	if _uses_menu_cinematic():
		return
	for node in get_tree().get_nodes_in_group("security_lighting_zones"):
		if node.has_method("apply_time_of_day"):
			node.apply_time_of_day(day_factor, night_factor)
	for node in get_tree().get_nodes_in_group("security_lights"):
		if node.has_method("apply_time_profile"):
			node.apply_time_profile(day_factor, night_factor)

func _apply_gameplay_fog(
	day_factor: float,
	night_factor: float,
	sunset_factor: float
) -> void:
	if _uses_menu_cinematic():
		return
	if not adjust_gameplay_fog or we == null or we.environment == null:
		return
	var env := we.environment
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_sky_affect = 0.0
	env.fog_depth_end = maxf(1.0, lerpf(gameplay_fog_end_night, gameplay_fog_end_day, day_factor))
	env.fog_depth_begin = lerpf(gameplay_fog_begin_night, gameplay_fog_begin_day, day_factor)
	env.fog_depth_curve = 1.8
	env.fog_density = lerpf(gameplay_fog_density_night, gameplay_fog_density_day, day_factor)
	var fog_col := gameplay_fog_color_night.lerp(gameplay_fog_color_day, day_factor)
	fog_col = fog_col.lerp(sky_sunset_color, sunset_factor * 0.25)
	env.fog_light_color = fog_col
	if gameplay_fog_use_height:
		env.fog_height = gameplay_fog_height
		env.fog_height_density = lerpf(
			gameplay_fog_height_density_night,
			gameplay_fog_height_density_day,
			day_factor
		)
	else:
		env.fog_height = 0.0
		env.fog_height_density = 0.0
	if gameplay_use_volumetric_fog:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = lerpf(
			gameplay_volumetric_fog_density_night,
			gameplay_volumetric_fog_density_day,
			day_factor
		)
		env.volumetric_fog_albedo = fog_col
		env.volumetric_fog_emission = fog_col * 0.06
		env.volumetric_fog_length = env.fog_depth_end
		env.volumetric_fog_sky_affect = 0.0
		env.volumetric_fog_ambient_inject = 0.0
	else:
		env.volumetric_fog_enabled = false

func _cache_sky_material() -> void:
	_sky_material = null
	if we == null or we.environment == null or we.environment.sky == null:
		return
	var mat: Material = we.environment.sky.sky_material
	if mat is ShaderMaterial:
		_sky_material = mat as ShaderMaterial
		var sky_shader: Shader = load(SKY_SHADER_PATH) as Shader
		if sky_shader != null:
			_sky_material.shader = sky_shader
		elif not _sky_material.shader:
			push_warning("DayNightRig: no se encontró %s" % SKY_SHADER_PATH)

func _update_sky_shader(
	day_factor: float,
	sunset_factor: float,
	night_factor: float,
	star_factor: float
) -> void:
	if _sky_material == null:
		return
	_sky_material.set_shader_parameter("sky_day_color", sky_day_color)
	_sky_material.set_shader_parameter("sky_night_color", sky_night_color)
	_sky_material.set_shader_parameter("sky_sunset_color", sky_sunset_color)
	_sky_material.set_shader_parameter("day_factor", day_factor)
	_sky_material.set_shader_parameter("sunset_factor", sunset_factor)
	_sky_material.set_shader_parameter("night_factor", night_factor)
	_sky_material.set_shader_parameter("star_factor", star_factor)
	_sky_material.set_shader_parameter("star_density", star_density)
	_sky_material.set_shader_parameter("star_brightness", star_brightness)
	_sky_material.set_shader_parameter("star_size", star_size)
	_sky_material.set_shader_parameter("star_glow", star_glow)
	_sky_material.set_shader_parameter("star_horizon_cutoff", star_horizon_cutoff)
	# Sol/luna siempre como Sprite3D + PNG; el cielo shader no dibuja discos.
	if _sky_material != null:
		_sky_material.set_shader_parameter("sun_disc_strength", 0.0)
		_sky_material.set_shader_parameter("moon_disc_strength", 0.0)

func _cycle_hour() -> float:
	return fposmod(cycle_sunrise_hour + t * 24.0, 24.0)

func _star_hour_factor() -> float:
	var hour := _cycle_hour()
	var fade := maxf(star_fade_hours, 0.001)
	var start_h := star_start_hour
	var end_h := star_end_hour
	if start_h > end_h:
		if hour >= start_h:
			return 1.0
		if hour >= start_h - fade:
			return smoothstep(start_h - fade, start_h, hour)
		if hour < end_h:
			return 1.0
		if hour < end_h + fade:
			return 1.0 - smoothstep(end_h, end_h + fade, hour)
		return 0.0
	if hour < start_h - fade or hour >= end_h + fade:
		return 0.0
	if hour < start_h:
		return smoothstep(start_h - fade, start_h, hour)
	if hour < end_h:
		return 1.0
	return 1.0 - smoothstep(end_h, end_h + fade, hour)

func _star_visibility_factor(sunset_factor: float, night_factor: float) -> float:
	var by_hour := _star_hour_factor()
	var dark_enough := smoothstep(
		star_min_night_factor - 0.12,
		star_min_night_factor + 0.08,
		night_factor
	)
	var no_sunset := 1.0 - smoothstep(
		star_max_sunset_factor,
		star_max_sunset_factor + 0.18,
		sunset_factor
	)
	return by_hour * dark_enough * no_sunset

func _align_directional_light(sprite: Sprite3D, pivot: Node3D, light: DirectionalLight3D) -> void:
	var dir := pivot.global_position - sprite.global_position
	if dir.length_squared() < 0.0001:
		return
	var forward := dir.normalized()
	var up := Vector3.UP
	if absf(forward.dot(up)) > 0.99:
		up = Vector3.RIGHT
	light.global_basis = Basis.looking_at(forward, up)

func _smooth_horizon(h: float, softness: float) -> float:
	var x: float = clamp((h * 0.5) + 0.5, 0.0, 1.0)
	var a: float = clamp(0.5 - softness, 0.0, 1.0)
	var b: float = clamp(0.5 + softness, 0.0, 1.0)
	return smoothstep(a, b, x)

func _sunset_factor(h: float, band: float) -> float:
	var d: float = abs(h)
	var denom: float = max(0.001, band)
	var x: float = 1.0 - clamp(d / denom, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
