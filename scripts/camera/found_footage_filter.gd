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

@export_range(0.85, 1.25) var vignette_aspect: float = 1.06:
	set(value):
		vignette_aspect = value
		_apply_shader_params()

@export_range(0.08, 0.55) var vignette_edge_softness: float = 0.28:
	set(value):
		vignette_edge_softness = value
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
var _vignette_tween: Tween
var _saved_vignette: float = -1.0
var _saved_softness: float = -1.0
var _saved_edge_softness: float = -1.0


func _ready() -> void:
	if _filter_rect.material:
		_filter_rect.material = _filter_rect.material.duplicate()
	_material = _filter_rect.material as ShaderMaterial
	call_deferred("_apply_shader_params")
	_update_visibility()


func set_filter_enabled(value: bool) -> void:
	filter_enabled = value


func animate_chase_vignette(
	enable: bool,
	target_vignette: float = 0.42,
	target_softness: float = 0.42,
	duration: float = 0.65
) -> void:
	if _saved_vignette < 0.0:
		_saved_vignette = vignette
		_saved_softness = softness
		_saved_edge_softness = vignette_edge_softness
	_kill_vignette_tween()
	if duration <= 0.0:
		if enable:
			vignette = target_vignette
			softness = target_softness
			vignette_edge_softness = minf(_saved_edge_softness + 0.12, 0.55)
		else:
			vignette = _saved_vignette
			softness = _saved_softness
			vignette_edge_softness = _saved_edge_softness
		return
	_vignette_tween = create_tween()
	_vignette_tween.set_parallel(true)
	_vignette_tween.set_trans(Tween.TRANS_SINE)
	_vignette_tween.set_ease(Tween.EASE_OUT)
	if enable:
		_vignette_tween.tween_property(self, "vignette", target_vignette, duration)
		_vignette_tween.tween_property(self, "softness", target_softness, duration)
		_vignette_tween.tween_property(
			self,
			"vignette_edge_softness",
			minf(_saved_edge_softness + 0.12, 0.55),
			duration
		)
	else:
		_vignette_tween.tween_property(self, "vignette", _saved_vignette, duration)
		_vignette_tween.tween_property(self, "softness", _saved_softness, duration)
		_vignette_tween.tween_property(self, "vignette_edge_softness", _saved_edge_softness, duration)


func _kill_vignette_tween() -> void:
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette_tween = null


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
	_material.set_shader_parameter("vignette_aspect", vignette_aspect)
	_material.set_shader_parameter("vignette_edge_softness", vignette_edge_softness)
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
