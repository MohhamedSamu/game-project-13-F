extends POM_Clouds
## Parche de proyecto (no toca el addon): en runtime aplica posición, escala y material
## como hace el bloque del editor en POM_Clouds.gd original.

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		super._process(delta)
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var cam_pos := global_position
	if cam != null:
		cam_pos = cam.global_position
	position = Vector3(cam_pos.x, height, cam_pos.z)
	if current_POM_layers != POM_layers:
		do_POM()
		current_POM_layers = POM_layers
	if multimesh == null:
		do_POM()
	if material_override == null:
		var mat: Resource = load("res://addons/POM clouds/POM_Clouds_shader_material.tres")
		if mat is Material:
			material_override = mat.duplicate()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rotation = Vector3.ZERO
	scale = Vector3(_scale, _scale, _scale)
	if material_override is ShaderMaterial:
		material_override.set_shader_parameter("mesh_scale", _scale)
