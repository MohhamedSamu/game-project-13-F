class_name MenuHorizonColor
extends RefCounted
## Color de horizonte derivado del Sky3D (altitud solar + tintes del shader).


static func from_sky3d(sky3d: Sky3D, soft_menu_night: bool = false) -> Color:
	if sky3d == null:
		return Color(0.78, 0.87, 0.98)
	var day := Color(0.808, 0.91, 1.0)
	var night := Color(0.14, 0.17, 0.24)
	var sunset := Color(0.98, 0.635, 0.463)
	if sky3d.sky_material:
		var p_day = sky3d.sky_material.get_shader_parameter("atm_day_tint")
		if p_day is Color:
			day = p_day
		var p_night = sky3d.sky_material.get_shader_parameter("atm_night_tint")
		if p_night is Color:
			night = p_night
		var p_sunset = sky3d.sky_material.get_shader_parameter("atm_horizon_light_tint")
		if p_sunset is Color:
			sunset = p_sunset
	var night_f := night_factor(sky3d.current_time)
	if soft_menu_night:
		night_f = minf(night_f * 0.12, 0.14)
	var sun_alt := 0.0
	if sky3d.sky != null:
		sun_alt = sky3d.sky.sun_altitude
	var sun_height := sin(sun_alt)
	var dusk := 0.0
	if sun_height < 0.35:
		dusk = clampf(1.0 - sun_height / 0.35, 0.0, 1.0)
		dusk = pow(dusk, 0.65)
	var horizon := day.lerp(sunset, dusk)
	return horizon.lerp(night, night_f)


static func night_factor(hour: float) -> float:
	var night := 0.0
	if hour >= 19.5 or hour < 6.0:
		var edge := 1.5
		if hour >= 19.5:
			night = clampf((hour - 19.5) / edge, 0.0, 1.0)
		else:
			night = clampf((6.0 - hour) / edge, 0.0, 1.0)
	return night


static func menu_night_blend(hour: float) -> float:
	return minf(night_factor(hour) * 0.35, 0.22)
