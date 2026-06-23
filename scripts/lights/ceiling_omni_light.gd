extends OmniLight3D
## Coloca este nodo EN el panel/lámpara del techo (no en el centro de la habitación).
## Alcance corto + caída fuerte + poca niebla volumétrica = sensación de luz que baja del techo.

@export_group("Noche")
@export var night_light_energy: float = 8.0
@export_range(3.0, 25.0, 0.5) var night_omni_range: float = 10.0
## Más alto = la luz cae antes (menos sensación de “bola” en todo el espacio).
@export_range(0.5, 4.0, 0.1) var night_omni_attenuation: float = 2.2
## Casi 0: el haz volumétrico no dibuja una esfera en el aire; la fuente la da la emisión del panel.
@export var night_volumetric_fog_energy: float = 0.12
@export var night_light_color: Color = Color(1.0, 0.93, 0.8, 1.0)
## Tamaño del área luminosa (sombras más suaves, como plafón).
@export_range(0.0, 2.0, 0.05) var night_light_size: float = 0.35

@export_group("Día")
@export var day_light_energy: float = 0.0
@export var day_volumetric_fog_energy: float = 0.0

@export_group("Sombras")
@export var cast_shadows: bool = true
@export_range(0.0, 2.0, 0.01) var shadow_bias_setting: float = 0.12
@export_range(0.0, 8.0, 0.1) var shadow_normal_bias_setting: float = 2.0

func _ready() -> void:
	add_to_group("security_lights")
	distance_fade_enabled = false
	light_indirect_energy = 0.0
	light_specular = 0.18
	_apply_shadow_settings()
	apply_time_profile(1.0, 1.0)

func _apply_shadow_settings() -> void:
	shadow_enabled = cast_shadows
	if cast_shadows:
		shadow_bias = shadow_bias_setting
		shadow_normal_bias = shadow_normal_bias_setting
		shadow_opacity = 1.0

func apply_time_profile(day_factor: float, night_factor: float) -> void:
	var night_blend := clampf(night_factor, 0.0, 1.0)
	light_color = night_light_color
	omni_range = night_omni_range
	omni_attenuation = night_omni_attenuation
	light_volumetric_fog_energy = lerpf(
		day_volumetric_fog_energy,
		night_volumetric_fog_energy,
		night_blend
	)
	if is_in_group(&"flicker_managed"):
		light_size = night_light_size
		_apply_shadow_settings()
		return
	light_energy = lerpf(day_light_energy, night_light_energy, night_blend)
	light_size = night_light_size
	visible = light_energy > 0.05
	_apply_shadow_settings()
