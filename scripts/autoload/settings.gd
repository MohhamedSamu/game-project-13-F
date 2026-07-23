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

const GRAPHICS_AMBIENT_OFFSET := {
	GraphicsQuality.HIGH: 0.0,
	GraphicsQuality.MEDIUM: 0.16,
	GraphicsQuality.LOW: 0.30,
}

const GRAPHICS_SKY_CONTRIBUTION_OFFSET := {
	GraphicsQuality.HIGH: 0.0,
	GraphicsQuality.MEDIUM: 0.14,
	GraphicsQuality.LOW: 0.26,
}

const GRAPHICS_SKYDOME_ENERGY_OFFSET := {
	GraphicsQuality.HIGH: 0.0,
	GraphicsQuality.MEDIUM: 0.10,
	GraphicsQuality.LOW: 0.18,
}

const GRAPHICS_CAMERA_EXPOSURE_OFFSET := {
	GraphicsQuality.HIGH: 0.0,
	GraphicsQuality.MEDIUM: 0.04,
	GraphicsQuality.LOW: 0.08,
}
## Alta [4096] por defecto en una partida nueva (pedido de diseño).
const DEFAULT_GRAPHICS_QUALITY := GraphicsQuality.HIGH

const DEFAULT_LOCALE := "es"
const SUPPORTED_LOCALES := ["es", "en"]

signal locale_changed(locale: String)

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
	"input_device_scheme": "keyboard",
	"gamepad_family": "xbox",
	"locale": DEFAULT_LOCALE,
}


func _ready() -> void:
	# En móvil el juego arranca en fullscreen por defecto (partida/instalación nueva).
	data["fullscreen"] = OS.has_feature("mobile")
	load_settings()
	_migrate_mobile_fullscreen_default()
	apply_locale()
	apply_audio()
	_apply_display()
	apply_graphics_quality()


func get_locale() -> String:
	var locale := str(get_value("locale", DEFAULT_LOCALE))
	if locale not in SUPPORTED_LOCALES:
		return DEFAULT_LOCALE
	return locale


func set_locale(locale: String) -> void:
	if locale not in SUPPORTED_LOCALES:
		return
	if get_locale() == locale:
		apply_locale()
		return
	data["locale"] = locale
	apply_locale()
	locale_changed.emit(locale)


func apply_locale() -> void:
	var locale := get_locale()
	TranslationServer.set_locale(locale)


## Una sola vez por instalación: en móvil activa fullscreen aunque ya exista un
## settings.json previo guardado con fullscreen=false (instalaciones anteriores).
## Después, el jugador puede apagarlo en el menú y se respeta su elección.
func _migrate_mobile_fullscreen_default() -> void:
	if not OS.has_feature("mobile"):
		return
	if bool(get_value("fullscreen_mobile_defaulted", false)):
		return
	data["fullscreen"] = true
	data["fullscreen_mobile_defaulted"] = true
	save_settings()


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


## Aplica sombras, luces locales y compensación de Sky3D EN VIVO.
func apply_graphics_quality() -> void:
	var size := get_graphics_shadow_size()
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.positional_shadow_atlas_size = size
	RenderingServer.directional_shadow_atlas_set_size(size, true)
	_apply_security_lights_quality(tree)
	_apply_sky_ambient_quality(tree)


func _apply_security_lights_quality(tree: SceneTree) -> void:
	if tree == null:
		return
	var quality := get_graphics_quality()
	for node in tree.get_nodes_in_group(&"security_lights"):
		if node.has_method("apply_graphics_quality"):
			node.call("apply_graphics_quality", quality)
	for node in tree.get_nodes_in_group(&"security_lighting_zones"):
		if node.has_method("apply_time_of_day"):
			var sky3d := _find_gameplay_sky3d(tree)
			if sky3d != null:
				var profile := sky3d.get_node_or_null("ProjectProfile")
				if profile != null and profile.has_method("_time_factors"):
					var factors: Vector2 = profile.call("_time_factors", sky3d)
					node.call("apply_time_of_day", factors.x, factors.y)


func _apply_sky_ambient_quality(tree: SceneTree) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group(&"sky3d_graphics_profiles"):
		if node.has_method("apply_graphics_ambient"):
			node.call("apply_graphics_ambient", get_graphics_quality())


func _find_gameplay_sky3d(tree: SceneTree) -> Sky3D:
	for node in tree.get_nodes_in_group(&"sky3d_graphics_profiles"):
		var sky3d := node.get_parent() as Sky3D
		if sky3d != null:
			return sky3d
	if tree.current_scene != null:
		var direct := tree.current_scene.get_node_or_null("Sky3D") as Sky3D
		if direct != null:
			return direct
	return null


func get_graphics_ambient_offset(quality: int) -> float:
	return float(GRAPHICS_AMBIENT_OFFSET.get(quality, 0.0))


func get_graphics_sky_contribution_offset(quality: int) -> float:
	return float(GRAPHICS_SKY_CONTRIBUTION_OFFSET.get(quality, 0.0))


func get_graphics_skydome_energy_offset(quality: int) -> float:
	return float(GRAPHICS_SKYDOME_ENERGY_OFFSET.get(quality, 0.0))


func get_graphics_camera_exposure_offset(quality: int) -> float:
	return float(GRAPHICS_CAMERA_EXPOSURE_OFFSET.get(quality, 0.0))


func get_graphics_quality_display_name() -> String:
	match get_graphics_quality():
		GraphicsQuality.HIGH:
			return tr("UI_GFX_HIGH")
		GraphicsQuality.MEDIUM:
			return tr("UI_GFX_MED")
		GraphicsQuality.LOW:
			return tr("UI_GFX_LOW")
	return tr("UI_GFX_HIGH")


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
