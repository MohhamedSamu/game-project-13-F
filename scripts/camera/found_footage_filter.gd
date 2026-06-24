extends CanvasLayer

## Post-procesado estilo cinta VHS / found footage nocturno (sin overlays de cámara).

@export_group("Filtro")
@export var filter_enabled: bool = true:
	set(value):
		filter_enabled = value
		_update_visibility()

@export_group("Mezcla")
@export_range(0.0, 1.0) var intensity: float = 0.48:
	set(value):
		intensity = value
		_apply_shader_params()
		_update_visibility()

@export_group("Grano")
@export_range(0.0, 1.0) var grain_amount: float = 0.12:
	set(value):
		grain_amount = value
		_apply_shader_params()

@export_range(0.5, 8.0) var grain_size: float = 2.4:
	set(value):
		grain_size = value
		_apply_shader_params()

## 0 = grano totalmente estático. Valores bajos (0.02–0.08) = deriva casi imperceptible.
@export_range(0.0, 1.0) var grain_drift: float = 0.0:
	set(value):
		grain_drift = value
		_apply_shader_params()

@export_group("Lente")
@export_range(0.0, 0.02) var chromatic_aberration: float = 0.0022:
	set(value):
		chromatic_aberration = value
		_apply_shader_params()

@export_range(0.0, 0.6) var barrel_distortion: float = 0.05:
	set(value):
		barrel_distortion = value
		_apply_shader_params()

@export_range(0.0, 1.0) var vignette: float = 0.28:
	set(value):
		vignette = value
		_apply_shader_params()

## Blur leve sobre la imagen.
@export_range(0.0, 3.0) var softness: float = 0.3:
	set(value):
		softness = value
		_apply_shader_params()

@export_range(0.0, 1.0) var bloom: float = 0.09:
	set(value):
		bloom = value
		_apply_shader_params()

@export_group("Color")
@export_range(0.0, 1.0) var scanlines: float = 0.025:
	set(value):
		scanlines = value
		_apply_shader_params()

@export_range(0.0, 1.5) var saturation: float = 0.62:
	set(value):
		saturation = value
		_apply_shader_params()

@export_range(0.5, 1.5) var contrast: float = 0.98:
	set(value):
		contrast = value
		_apply_shader_params()

@export_range(0.0, 0.15) var lift: float = 0.028:
	set(value):
		lift = value
		_apply_shader_params()

@export_range(0.0, 1.0) var shadow_crush: float = 0.22:
	set(value):
		shadow_crush = value
		_apply_shader_params()

@export_range(0.0, 0.3) var cool_tint: float = 0.08:
	set(value):
		cool_tint = value
		_apply_shader_params()

@export_range(0.0, 0.3) var shadow_coolth: float = 0.1:
	set(value):
		shadow_coolth = value
		_apply_shader_params()

@onready var _filter_rect: ColorRect = $FilterRect

var _material: ShaderMaterial


func _ready() -> void:
	if _filter_rect.material:
		_filter_rect.material = _filter_rect.material.duplicate()
	_material = _filter_rect.material as ShaderMaterial
	call_deferred("_apply_shader_params")
	_update_visibility()


func set_filter_enabled(value: bool) -> void:
	filter_enabled = value


func apply_settings(settings: Dictionary) -> void:
	for key in [
		"filter_enabled", "intensity", "grain_amount", "grain_size", "grain_drift",
		"chromatic_aberration", "barrel_distortion", "vignette", "softness", "bloom",
		"scanlines", "saturation", "contrast", "lift", "shadow_crush", "cool_tint", "shadow_coolth"
	]:
		if settings.has(key):
			set(key, settings[key])


func _apply_shader_params() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("intensity", intensity)
	_material.set_shader_parameter("grain_amount", grain_amount)
	_material.set_shader_parameter("grain_size", grain_size)
	_material.set_shader_parameter("grain_drift", grain_drift)
	_material.set_shader_parameter("chromatic_aberration", chromatic_aberration)
	_material.set_shader_parameter("barrel_distortion", barrel_distortion)
	_material.set_shader_parameter("vignette", vignette)
	_material.set_shader_parameter("softness", softness)
	_material.set_shader_parameter("bloom", bloom)
	_material.set_shader_parameter("scanlines", scanlines)
	_material.set_shader_parameter("saturation", saturation)
	_material.set_shader_parameter("contrast", contrast)
	_material.set_shader_parameter("lift", lift)
	_material.set_shader_parameter("shadow_crush", shadow_crush)
	_material.set_shader_parameter("cool_tint", cool_tint)
	_material.set_shader_parameter("shadow_coolth", shadow_coolth)


func _update_visibility() -> void:
	visible = filter_enabled and intensity > 0.0
