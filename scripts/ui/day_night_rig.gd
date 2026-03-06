extends Node3D

@export var cycle_seconds: float = 40.0
@export var tilt_degrees: float = 20.0

# Órbita visual (distancia desde el pivote). Ponle el valor que ya te evitó atravesar el mapa.
@export var orbit_radius: float = 2800.0

# Energía de luces
@export var sun_energy_day: float = 2.0
@export var moon_energy_night: float = 0.35

# Transición día/noche alrededor del horizonte
@export_range(0.0, 0.5, 0.01) var transition_softness: float = 0.15

# Exposición (tonemap exposure) controlada por script
@export var exposure_day: float = 1.0
@export var exposure_night: float = 0.75

# Colores de fondo (BG_COLOR)
@export var sky_day_color: Color = Color(0.55, 0.75, 1.0, 1.0)      # celeste claro
@export var sky_sunset_color: Color = Color(1.0, 0.45, 0.15, 1.0)   # anaranjado/rojizo
@export var sky_night_color: Color = Color(0.03, 0.04, 0.08, 1.0)   # noche (azul muy oscuro)

# Qué tan ancho es el “atardecer” alrededor del horizonte
@export_range(0.0, 0.5, 0.01) var sunset_band: float = 0.18

# Debug (opcional)
@export var debug_print: bool = false

@onready var sun_pivot: Node3D = $SunPivot
@onready var moon_pivot: Node3D = $MoonPivot

@onready var sun_light: DirectionalLight3D = $SunPivot/SunDirectional
@onready var moon_light: DirectionalLight3D = $MoonPivot/MoonDirectional

@onready var sun_mesh: Node3D = get_node_or_null("SunPivot/SunMesh")
@onready var moon_mesh: Node3D = get_node_or_null("MoonPivot/MoonMesh")

@onready var we: WorldEnvironment = $WorldEnvironment

var t: float = 0.0 # 0..1

func _ready() -> void:
	# Inclinación estética del plano orbital (si no quieres, pon 0)
	rotation_degrees.z = tilt_degrees

	# Coloca los meshes en una órbita visual a lo largo de -Z local
	if sun_mesh:
		sun_mesh.position = Vector3(0.0, 0.0, -orbit_radius)
	if moon_mesh:
		moon_mesh.position = Vector3(0.0, 0.0, -orbit_radius)

	# Debug confirmación
	if debug_print:
		print("WE path:", we.get_path())
		print("Env instance:", we.environment)

	# Forzamos el modo de fondo a COLOR desde el inicio
	if we.environment:
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = sky_night_color

func _process(delta: float) -> void:
	if cycle_seconds <= 0.01:
		return

	# Tiempo normalizado
	t = fposmod(t + delta / cycle_seconds, 1.0)
	var ang: float = t * TAU

	# Altura del sol: >0 arriba (día), <0 abajo (noche)
	var sun_height: float = sin(ang)

	# Órbita: rotación de pivots
	# Si quieres que el amanecer ocurra en otra dirección, cambia .rotation.x por .rotation.z
	sun_pivot.rotation.x = ang
	moon_pivot.rotation.x = ang + PI

	# Alineación de luz con el sol/luna (para que coincida con lo visual)
	# "Sol → centro": el mesh mira al pivot; la directional adopta esa orientación
	if sun_mesh:
		sun_mesh.look_at(sun_pivot.global_transform.origin, Vector3.UP)
		sun_light.global_transform.basis = sun_mesh.global_transform.basis
	if moon_mesh:
		moon_mesh.look_at(moon_pivot.global_transform.origin, Vector3.UP)
		moon_light.global_transform.basis = moon_mesh.global_transform.basis

	# Factor día suave
	var day_factor: float = _smooth_horizon(sun_height, transition_softness)
	var night_factor: float = 1.0 - day_factor

	# Energía luces
	sun_light.light_energy = lerp(0.0, sun_energy_day, day_factor)
	moon_light.light_energy = lerp(0.0, moon_energy_night, night_factor)

	# Sombras en dominante
	sun_light.shadow_enabled = day_factor > 0.35
	moon_light.shadow_enabled = night_factor > 0.35

	# Exposure
	if we.environment:
		we.environment.tonemap_exposure = lerp(exposure_night, exposure_day, day_factor)

	# Fondo (BG_COLOR) día → atardecer → noche
	var sunset_factor: float = _sunset_factor(sun_height, sunset_band)

	var base_color: Color = sky_night_color.lerp(sky_day_color, day_factor)
	var final_color: Color = base_color.lerp(sky_sunset_color, sunset_factor * 0.55)

	if we.environment:
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = final_color

	# Debug para verificar que el color cambia
	if debug_print and Engine.get_frames_drawn() % 60 == 0:
		print("sun_height:", sun_height, " day:", day_factor, " sunset:", sunset_factor, " final_color:", final_color)

func _smooth_horizon(h: float, softness: float) -> float:
	# h [-1..1] -> x [0..1]
	var x: float = clamp((h * 0.5) + 0.5, 0.0, 1.0)
	var a: float = clamp(0.5 - softness, 0.0, 1.0)
	var b: float = clamp(0.5 + softness, 0.0, 1.0)
	return smoothstep(a, b, x)

func _sunset_factor(h: float, band: float) -> float:
	# 1 cerca del horizonte (h≈0), 0 lejos (h≈±1)
	var d: float = abs(h)
	var denom: float = max(0.001, band)
	var x: float = 1.0 - clamp(d / denom, 0.0, 1.0)
	# smoothstep(0,1,x) manual
	return x * x * (3.0 - 2.0 * x)
