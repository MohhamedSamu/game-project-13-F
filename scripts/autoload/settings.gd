extends Node

const SETTINGS_PATH := "user://settings.json"

const DEFAULT_MOUSE_SENSITIVITY := 0.25
const DEFAULT_CAMERA_FOV := 75.0
const MAX_CAMERA_FOV := 90.0
const REFERENCE_LOOK_SPEED := 0.002

enum MovementProfile { PRODUCTION, DEVELOP }

# --- GRÁFICOS: calidad de sombras (tamaño del atlas). Aplicable EN VIVO. ---
enum GraphicsQuality { HIGH, MEDIUM, LOW }

const GRAPHICS_SHADOW_SIZES := {
	GraphicsQuality.HIGH: 4096,
	GraphicsQuality.MEDIUM: 2048,
	GraphicsQuality.LOW: 1024,
}
## Alta [4096] por defecto en una partida nueva (pedido de diseño).
const DEFAULT_GRAPHICS_QUALITY := GraphicsQuality.HIGH

const DEVELOP_WALK_SPEED := 7.0
const DEVELOP_SPRINT_SPEED := 10.0
const DEVELOP_FREEFLY_SPEED := 25.0

const PRODUCTION_WALK_SPEED := 3.0
const PRODUCTION_SPRINT_SPEED := 5.5
const DEVELOP_JUMP_VELOCITY := 4.5
## Mitad de altura que develop: v ∝ sqrt(h) → factor sqrt(0.5).
const PRODUCTION_JUMP_VELOCITY := DEVELOP_JUMP_VELOCITY * 0.7071067811865476

var data := {
	"mouse_sensitivity": DEFAULT_MOUSE_SENSITIVITY,
	"camera_fov": DEFAULT_CAMERA_FOV,
	"graphics_quality": DEFAULT_GRAPHICS_QUALITY,
	"movement_profile": "production",
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"fullscreen": false,
}


func _ready() -> void:
	load_settings()
	apply_audio()
	_apply_display()
	apply_graphics_quality()


func set_value(key: String, value) -> void:
	data[key] = value


func get_value(key: String, default_value = null):
	if data.has(key):
		return data[key]
	return default_value


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not open settings file for write: " + SETTINGS_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		save_settings()
		return

	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		push_error("Could not open settings file for read: " + SETTINGS_PATH)
		return

	var txt := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in parsed.keys():
			data[k] = parsed[k]
	else:
		save_settings()
	data["movement_profile"] = "production"


func apply_audio() -> void:
	_set_bus_linear("Master", float(data["master_volume"]))
	_set_bus_linear("Music", float(data["music_volume"]))
	_set_bus_linear("SFX", float(data["sfx_volume"]))


func apply_controls_to_player(player: Node = null) -> void:
	if player == null:
		player = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("apply_control_settings"):
		return
	var sensitivity := float(get_value("mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY))
	var fov := clampf(float(get_value("camera_fov", DEFAULT_CAMERA_FOV)), 40.0, MAX_CAMERA_FOV)
	player.apply_control_settings(sensitivity, fov)


func mouse_sensitivity_to_look_speed(mouse_sensitivity: float) -> float:
	var sens := maxf(mouse_sensitivity, 0.001)
	return REFERENCE_LOOK_SPEED * (sens / DEFAULT_MOUSE_SENSITIVITY)


# --- GRÁFICOS -----------------------------------------------------------------

## Devuelve la calidad guardada (int del enum GraphicsQuality). Se valida contra
## los tamaños conocidos; si el valor guardado es inválido, cae al default (Alta).
func get_graphics_quality() -> int:
	var q := int(get_value("graphics_quality", DEFAULT_GRAPHICS_QUALITY))
	if not GRAPHICS_SHADOW_SIZES.has(q):
		q = int(DEFAULT_GRAPHICS_QUALITY)
	return q


func set_graphics_quality(quality: int) -> void:
	if not GRAPHICS_SHADOW_SIZES.has(quality):
		quality = int(DEFAULT_GRAPHICS_QUALITY)
	data["graphics_quality"] = quality


func get_graphics_shadow_size() -> int:
	return int(GRAPHICS_SHADOW_SIZES.get(get_graphics_quality(), 4096))


## Aplica el tamaño del atlas de sombras EN VIVO (posicional + direccional).
## Funciona mientras el juego corre: cambiar de Alta→Baja se refleja al instante
## sin reiniciar. No añade ni quita luces; solo la resolución de las sombras.
func apply_graphics_quality() -> void:
	var size := get_graphics_shadow_size()
	var tree := get_tree()
	if tree != null and tree.root != null:
		# Atlas de las luces posicionales (12 focos de la estación, 15 farolas, linterna...).
		tree.root.positional_shadow_atlas_size = size
	# Atlas de la sombra direccional (sol/luna gestionados por Sky3D).
	RenderingServer.directional_shadow_atlas_set_size(size, true)


func get_graphics_quality_display_name() -> String:
	match get_graphics_quality():
		GraphicsQuality.HIGH:
			return "Alta"
		GraphicsQuality.MEDIUM:
			return "Medios"
		GraphicsQuality.LOW:
			return "Bajos"
	return "Alta"


# --- MOVEMENT PROFILE ---------------------------------------------------------

func get_movement_profile() -> MovementProfile:
	return MovementProfile.PRODUCTION


func set_movement_profile(_profile: MovementProfile) -> void:
	data["movement_profile"] = "production"


func get_movement_profile_display_name() -> String:
	return "Production"


func get_walk_speed() -> float:
	return DEVELOP_WALK_SPEED if get_movement_profile() == MovementProfile.DEVELOP else PRODUCTION_WALK_SPEED


func get_sprint_speed() -> float:
	return DEVELOP_SPRINT_SPEED if get_movement_profile() == MovementProfile.DEVELOP else PRODUCTION_SPRINT_SPEED


func get_freefly_speed() -> float:
	return DEVELOP_FREEFLY_SPEED if get_movement_profile() == MovementProfile.DEVELOP else 0.0


func get_jump_velocity() -> float:
	return DEVELOP_JUMP_VELOCITY if get_movement_profile() == MovementProfile.DEVELOP else PRODUCTION_JUMP_VELOCITY


func is_freefly_enabled() -> bool:
	return false


func apply_movement_to_player(player: Node = null) -> void:
	if player == null:
		player = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("apply_movement_profile"):
		player.apply_movement_profile()


func _set_bus_linear(bus_name: String, value: float) -> void:
	var id := AudioServer.get_bus_index(bus_name)
	if id != -1:
		AudioServer.set_bus_volume_linear(id, clamp(value, 0.0, 1.0))


func _apply_display() -> void:
	var fs: bool = bool(get_value("fullscreen", false))
	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
