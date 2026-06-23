extends SpotLight3D
## Foco tipo farol: cono visible en niebla + sombras para no atravesar muros/pilares.

@export_group("Noche")
@export var night_light_energy: float = 18.0
@export var night_spot_range: float = 20.0
@export var night_spot_angle: float = 38.0
@export var night_spot_attenuation: float = 0.8
## Cono visible en la niebla (estilo farol). Subir si no se ve el haz; bajar si todo se pone blanco.
@export var night_volumetric_fog_energy: float = 3.2
@export var night_light_color: Color = Color(1.0, 0.94, 0.82, 1.0)

@export_group("Día")
@export var day_light_energy: float = 0.0
@export var day_volumetric_fog_energy: float = 0.0

@export_group("Sombras (occlusión)")
@export var cast_shadows: bool = true
@export_range(0.0, 2.0, 0.01) var shadow_bias_setting: float = 0.1
@export_range(0.0, 8.0, 0.1) var shadow_normal_bias_setting: float = 2.0

func _ready() -> void:
	add_to_group("security_lights")
	distance_fade_enabled = false
	light_indirect_energy = 0.0
	light_specular = 0.28
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
	spot_range = night_spot_range
	spot_angle = night_spot_angle
	spot_attenuation = night_spot_attenuation
	light_volumetric_fog_energy = lerpf(
		day_volumetric_fog_energy,
		night_volumetric_fog_energy,
		night_blend
	)
	if is_in_group(&"flicker_managed"):
		_apply_shadow_settings()
		return
	light_energy = lerpf(day_light_energy, night_light_energy, night_blend)
	visible = light_energy > 0.05
	_apply_shadow_settings()
