extends Node
## Escena 6: secuencia endcam cuando el monstruo atrapa al jugador (superhuman_choke_lift).

const MIXAMO_YAW_CORRECTION := PI
const LIFT_ANIMATION := &"superhuman_choke_lift"
const SCREAM_ANIMATION := &"zombie_scream"
const EATING_ANIMATION := &"zombie_biting_v2"

const AUDIO_HARD2_SCREAM := preload("res://assets/audio/SFX/screams/hard2.mp3")
const AUDIO_HEAD_IMPACT := preload("res://assets/audio/SFX/varios/head-=impact.mp3")
const AUDIO_DEMON_GROWL := preload(
	"res://assets/audio/SFX/varios/ending-demo/demon-voice-growlingmp3.mp3"
)
const AUDIO_DEMON_SMELL_FLESH := preload(
	"res://assets/audio/SFX/varios/ending-demo/demon-voice-smell-flesh.mp3"
)
const AUDIO_DEMONIC_LAUGH := preload("res://assets/audio/SFX/varios/ending-demo/demonic-laugh.mp3")
const AUDIO_CREATURE_EATING := preload("res://assets/audio/SFX/others/creature-eating.mp3")
const ENDING_SCENE_PATH := "res://scenes/levels/ending.tscn"

class EndCamKeyframe:
	var time: float = 0.0
	var local_position: Vector3 = Vector3.ZERO
	var local_look_at: Vector3 = Vector3.ZERO
	var roll_deg: float = 0.0

	func _init(
		p_time: float = 0.0,
		p_local_position: Vector3 = Vector3.ZERO,
		p_local_look_at: Vector3 = Vector3.ZERO,
		p_roll_deg: float = 0.0
	) -> void:
		time = p_time
		local_position = p_local_position
		local_look_at = p_local_look_at
		roll_deg = p_roll_deg


@export_group("Animación")
@export var lift_animation: StringName = LIFT_ANIMATION
@export_range(0.05, 1.0, 0.05) var animation_blend_time: float = 0.2
@export_range(0.5, 1.5, 0.05) var animation_speed_scale: float = 1.0

@export_group("Alineación")
@export_range(0.2, 2.0, 0.05) var grab_forward_distance: float = 0.95
@export_range(0.0, 0.5, 0.01) var grab_height_offset: float = 0.0
@export var snap_to_floor: bool = true
@export var floor_ray_height: float = 3.0
@export var floor_ray_depth: float = 12.0

@export_group("Cámara (posición)")
@export_range(0.5, 4.0, 0.05) var camera_offset_y_scale: float = 2.0
@export_range(0.25, 1.0, 0.05) var camera_ground_y_scale: float = 0.5
## Escala la distancia frontal capturada del jugador (1 = misma distancia, 2 = el doble).
@export_range(0.8, 3.5, 0.05) var camera_forward_distance_scale: float = 2.0
## Empuje extra hacia el jugador (aleja la cámara del centro del monstruo).
@export_range(0.0, 2.0, 0.05) var camera_forward_pull_offset: float = 0.55
## Signo del eje frontal local (+1 o -1). Cambia el lado donde queda la cámara.
@export_range(-1.0, 1.0, 1.0) var camera_forward_axis_sign: float = 1.0
## Punto de mira en el eje frontal del monstruo (hacia su cuerpo/cara).
@export_range(-0.8, 0.8, 0.01) var camera_face_look_z: float = 0.18
## 1 = mira a la misma altura de la cámara; 0 = usa el look de los keyframes.
@export_range(0.0, 1.0, 0.05) var camera_look_level_blend: float = 0.8
@export_range(-0.4, 0.4, 0.02) var camera_look_vertical_offset: float = 0.1

const NOMINAL_KEYFRAME_FORWARD_Z := 0.82

@export_group("Transición (agarre)")
@export var catch_fade_enabled: bool = true
@export_range(0.05, 1.0, 0.05) var fade_to_black_duration: float = 0.28
@export_range(0.0, 0.8, 0.05) var fade_hold_on_black: float = 0.22
@export_range(0.05, 1.2, 0.05) var fade_from_black_duration: float = 0.48
@export_range(0.0, 0.5, 0.01) var black_transition_blend_time: float = 0.0
@export_range(2, 12, 1) var black_settle_frames: int = 5

@export_group("Cámara (aire)")
@export_range(0.0, 25.0, 0.5) var air_roll_wobble_deg: float = 10.0
@export_range(0.5, 12.0, 0.25) var air_roll_wobble_speed: float = 4.2
@export_range(0.0, 0.2, 0.005) var air_side_wobble: float = 0.0
@export_range(3.0, 8.5, 0.05) var air_wobble_start_time: float = 3.9
@export_range(6.5, 9.0, 0.05) var air_wobble_end_time: float = 7.65
## Inclinación extra hacia arriba durante la subida y en el punto más alto del lift.
@export_range(0.0, 75.0, 1.0) var lift_air_pitch_boost_deg: float = 60.0
## Empieza tras el primer movimiento de cámara del lift (keyframe en t=2.0).
@export_range(0.0, 12.0, 0.05) var lift_air_pitch_start_time: float = 2.0
## Hasta este tiempo el pitch sube de 0 al máximo (evita el giro brusco al entrar en el aire).
@export_range(0.0, 12.0, 0.05) var lift_air_pitch_ramp_end_time: float = 3.55
## Hasta este tiempo de la animación lift se aplica el pitch (antes del lanzamiento al suelo).
@export_range(0.0, 12.0, 0.05) var lift_air_pitch_end_time: float = 7.69

@export_group("Insta pickup (scream)")
@export_range(2.0, 5.0, 0.05) var pickup_scream_duration: float = 3.0
@export_range(22.0, 55.0, 1.0) var pickup_scream_fov: float = 34.0
## Posición de cámara en espacio local del monstruo (X, Y, Z).
@export_range(0.0, 4.0, 0.05) var pickup_camera_local_x: float = 0.0
@export_range(0.5, 4.5, 0.02) var pickup_camera_local_y: float = 3.5
@export_range(-1.0, 4.0, 0.05) var pickup_camera_local_z: float = 2.5
## Punto de mira en espacio local del monstruo (origen X/Z, altura Y).
@export_range(0.5, 4.5, 0.02) var pickup_camera_look_local_y: float = 3.5
## Distancia jugador → cara del monstruo.
@export_range(0.18, 0.85, 0.02) var pickup_face_distance_from_camera: float = 0.48
## Altura de la cara sobre el origen del monstruo (pies/hips).
@export_range(1.2, 2.5, 0.05) var pickup_face_look_height: float = 2.05
## La cara queda un poco por encima del centro del jugador.
@export_range(-0.1, 0.35, 0.01) var pickup_face_vertical_offset: float = 0.1
@export_range(0.0, 0.35, 0.01) var pickup_scream_blend_time: float = 0.08
@export_range(-12.0, 12.0, 0.5) var pickup_scream_volume_db: float = 2.0
@export_range(0.0, 1.5, 0.05) var pickup_scream_sfx_delay: float = 0.5

@export_group("Audio lift")
@export_range(0.0, 2.0, 0.05) var lift_growl_time: float = 0.15
@export_range(2.0, 6.0, 0.05) var lift_smell_flesh_time: float = 3.6
@export_range(-12.0, 12.0, 0.5) var lift_voice_volume_db: float = 0.0
@export_range(-12.0, 12.0, 0.5) var head_impact_volume_db: float = 2.0

@export_group("Impacto suelo")
@export_range(7.5, 9.0, 0.05) var ground_impact_time: float = 8.05
@export_range(0.3, 2.5, 0.05) var trauma_warmup_duration: float = 0.85
@export_range(0.0, 0.8, 0.01) var blood_fade_in_duration: float = 0.12
@export_range(0.2, 1.5, 0.05) var blood_fade_out_duration: float = 0.55
@export_range(0.2, 1.5, 0.05) var trauma_pulse_period: float = 0.52
@export_range(0.0, 1.5, 0.02) var blood_overlay_intensity: float = 1.05
@export_range(0.0, 1.0, 0.02) var blood_drip_amount: float = 0.9
@export_range(0.0, 1.0, 0.02) var blood_splat_amount: float = 1.0
@export_range(0.0, 1.0, 0.02) var blood_edge_pool: float = 0.78
@export_range(0.0, 3.0, 0.05) var disorientation_blur_min: float = 0.16
@export_range(0.0, 3.0, 0.05) var disorientation_blur_max: float = 0.62
@export_range(0.0, 1.0, 0.02) var disorientation_vignette: float = 0.34
@export_range(0.0, 0.02, 0.001) var trauma_chromatic_max: float = 0.006

@export_group("Mordida final")
@export var eating_animation: StringName = EATING_ANIMATION
@export_range(0.04, 0.55, 0.01) var eating_animation_speed_scale: float = 0.12
@export_range(0.0, 0.95, 0.02) var eating_play_start_ratio: float = 0.74
@export_range(0.05, 1.0, 0.05) var eating_blend_time: float = 0.42
@export_range(0.5, 8.0, 0.1) var eating_bite_max_duration: float = 5.5
@export_range(0.5, 4.0, 0.05) var look_up_duration: float = 2.4
@export_range(0.4, 2.0, 0.05) var look_up_monster_height: float = 1.05
## Acercamiento mínimo hacia la cámara (metros).
@export_range(0.0, 1.4, 0.05) var eating_monster_approach_distance: float = 0.72
@export_range(0.2, 2.5, 0.05) var eating_monster_approach_duration: float = 1.15
## Distancia horizontal final cámara→monstruo (centra en el eje de mirada).
@export_range(0.35, 2.5, 0.05) var eating_target_camera_distance: float = 0.95
## Empuje lateral en espacio de cámara (+derecha / -izquierda).
@export_range(-0.8, 0.8, 0.05) var eating_lateral_bias: float = 0.0
@export_range(-12.0, 12.0, 0.5) var eating_sfx_volume_db: float = 0.0

@export_group("Fin")
@export var fin_title: String = "FIN"
@export_range(0.3, 2.5, 0.05) var fin_fade_duration: float = 1.15
@export_range(0.5, 8.0, 0.1) var fin_hold_duration: float = 3.5
@export var fin_continue_hint_text: String = "click para continuar"
@export_range(0.0, 6.0, 0.1) var fin_continue_hint_delay: float = 2.0

@export_group("Progreso")
@export var death_flag: String = "scene6_player_killed"

var _running: bool = false
var _end_camera: Camera3D
var _catch_camera_local: Vector3 = Vector3.ZERO
var _catch_look_local: Vector3 = Vector3.ZERO
var _catch_monster_transform: Transform3D = Transform3D.IDENTITY
var _catch_forward_distance: float = 1.2
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _blood_rect: ColorRect
var _blood_material: ShaderMaterial
var _fin_label: Label
var _fin_continue_label: Label
var _footage_filter: Node
var _look_up_blend: float = 0.0
var _ground_impact_triggered: bool = false
var _ground_impact_msec: int = 0
var _trauma_blood_tween: Tween
var _look_up_tween: Tween
var _monster_approach_tween: Tween
var _sfx_player: AudioStreamPlayer
var _monster_voice_player: AudioStreamPlayer3D
var _trauma_running: bool = false
var _blood_running: bool = false
var _saved_endcam_fov: float = 75.0
var _lift_growl_played: bool = false
var _lift_smell_played: bool = false
var _lift_throw_played: bool = false
var _head_impact_played: bool = false
var _pickup_camera_pos: Vector3 = Vector3.ZERO
var _pickup_camera_forward: Vector3 = Vector3.FORWARD
var _lift_start_captured: bool = false
var _lift_start_cam_local: Vector3 = Vector3.ZERO
var _lift_start_look_local: Vector3 = Vector3.ZERO
var _death_sequence_player: Node3D
var _fin_awaiting_input: bool = false


func play_sequence(setup: Node, player: Node3D, monster: Node3D) -> void:
	if _running:
		return
	if setup == null or player == null or monster == null:
		return
	if not is_instance_valid(player) or not is_instance_valid(monster):
		return
	if not player.is_inside_tree() or not monster.is_inside_tree():
		push_warning("Scene6FinalDeathDirector: el jugador o el monstruo no están en el árbol de escena.")
		return

	_running = true
	_death_sequence_player = player
	set_process(true)
	_ground_impact_triggered = false
	_ground_impact_msec = 0
	_look_up_blend = 0.0
	_trauma_running = false
	_blood_running = false
	_lift_growl_played = false
	_lift_smell_played = false
	_lift_throw_played = false
	_head_impact_played = false
	_lift_start_captured = false
	await get_tree().process_frame

	_stop_chase_presentation(setup)
	_apply_setup_endcam_overrides(setup)
	_lock_player_for_death(player)
	_hide_player_body(player)

	var animation_player := _get_animation_player(monster)
	if animation_player == null:
		_finish_death_sequence()
		return

	var camera_anchor := _resolve_camera_anchor(setup, monster)
	_ensure_end_camera(camera_anchor)
	if not _end_camera.is_inside_tree():
		push_warning("Scene6FinalDeathDirector: no se pudo crear la cámara endcam en el árbol 3D.")
		_finish_death_sequence()
		return

	if player.has_node("Head/Camera3D"):
		var player_camera := player.get_node("Head/Camera3D") as Camera3D
		if player_camera != null:
			_saved_endcam_fov = player_camera.fov
			_end_camera.fov = player_camera.fov
			_end_camera.near = player_camera.near
			_end_camera.far = player_camera.far

	await _run_death_sequence(player, monster, animation_player)

	if not death_flag.is_empty():
		GameManager.set_flag(death_flag, true)

	_finish_death_sequence()


func _finish_death_sequence() -> void:
	_running = false
	_death_sequence_player = null
	set_process(false)


func _process(_delta: float) -> void:
	if not _running:
		return
	_hide_death_sequence_mouse(_death_sequence_player)


func _run_lift_and_aftermath(
	player: Node3D,
	monster: Node3D,
	animation_player: AnimationPlayer
) -> void:
	await _run_camera_with_animation(monster, animation_player, player)
	if is_instance_valid(monster) and is_instance_valid(animation_player):
		_begin_look_up_tween()
		await _play_final_bite(monster, animation_player, player)
	await _show_fin_screen()


func _run_death_sequence(
	player: Node3D,
	monster: Node3D,
	animation_player: AnimationPlayer
) -> void:
	await _run_insta_pickup_jumpscare(player, monster, animation_player)

	_prepare_catch_alignment(player, monster)
	if not _lift_start_captured:
		_capture_catch_camera_reference(player, monster)
	_end_camera.fov = _saved_endcam_fov

	if monster.has_method("prepare_sequence_from"):
		monster.prepare_sequence_from(String(SCREAM_ANIMATION), String(lift_animation), true)

	if player != null and player.has_method("use_external_camera"):
		player.use_external_camera(_end_camera)
	_hide_death_sequence_mouse(player)

	_play_lift_animation(monster, animation_blend_time)
	await get_tree().physics_frame
	await get_tree().physics_frame

	await _run_lift_and_aftermath(player, monster, animation_player)

	if _fade_layer != null:
		_fade_layer.visible = true
		_set_fade_alpha(1.0)


func _run_insta_pickup_jumpscare(
	player: Node3D,
	monster: Node3D,
	animation_player: AnimationPlayer
) -> void:
	if monster == null or player == null or animation_player == null:
		return

	await _prepare_pickup_scream_alignment(player, monster)

	if player.has_method("use_external_camera"):
		player.use_external_camera(_end_camera)
	_hide_death_sequence_mouse(player)
	_end_camera.fov = pickup_scream_fov
	_apply_pickup_scream_camera(player, monster)

	_resolve_footage_filter(player)
	_begin_disorientation_effects()

	var from_anim := String(Scene6FinalChaseDirector.chase_animation)
	if not animation_player.current_animation.is_empty():
		from_anim = animation_player.current_animation

	if monster.has_method("prepare_sequence_from"):
		monster.prepare_sequence_from(from_anim, String(SCREAM_ANIMATION), true, -1)

	_play_scream_animation(monster, pickup_scream_blend_time)
	_play_pickup_scream_sfx()

	var elapsed := 0.0
	while elapsed < pickup_scream_duration and is_instance_valid(monster) and is_instance_valid(player):
		_refresh_pickup_scream_view(player, monster)
		var delta := get_process_delta_time()
		if delta <= 0.0:
			delta = 1.0 / 60.0
		elapsed += delta
		await get_tree().process_frame

	_stop_pickup_scream_sfx()
	_capture_scream_end_as_lift_start(monster)


func _get_default_keyframes() -> Array[EndCamKeyframe]:
	return [
		_make_camera_keyframe(0.0, Vector3(0.0, 1.58, 0.82), Vector3(0.0, 1.65, -2.4), 8.0),
		_make_camera_keyframe(2.0, Vector3(0.0, 1.78, 0.52), Vector3(0.0, 1.50, -2.62), 12.0),
		_make_camera_keyframe(2.65, Vector3(0.0, 2.02, 0.50), Vector3(0.0, 1.56, -2.56), 16.0),
		_make_camera_keyframe(3.25, Vector3(0.0, 2.38, 0.46), Vector3(0.0, 1.64, -2.52), 21.0),
		_make_camera_keyframe(3.85, Vector3(0.0, 2.78, 0.42), Vector3(0.0, 1.70, -2.48), 26.0),
		_make_camera_keyframe(7.69, Vector3(0.0, 3.05, 0.38), Vector3(0.0, 1.7, -2.45), 36.0),
		_make_camera_keyframe(8.18, Vector3(0.0, 0.42, 0.48), Vector3(0.0, 0.6, -2.8), 68.0, true),
		_make_camera_keyframe(8.77, Vector3(0.0, 0.14, 0.52), Vector3(0.0, 0.2, -2.6), 90.0, true),
	]


func _make_camera_keyframe(
	time: float,
	local_position: Vector3,
	local_look_at: Vector3,
	roll_deg: float,
	on_ground: bool = false
) -> EndCamKeyframe:
	return EndCamKeyframe.new(
		time,
		_scale_camera_position(local_position, on_ground),
		_scale_camera_look(local_look_at),
		roll_deg
	)


func _scale_camera_position(local_position: Vector3, on_ground: bool = false) -> Vector3:
	var y_scale := camera_offset_y_scale
	if on_ground:
		y_scale *= camera_ground_y_scale
	return Vector3(
		local_position.x,
		local_position.y * y_scale,
		local_position.z
	)


func _scale_camera_look(local_look_at: Vector3) -> Vector3:
	return Vector3(
		local_look_at.x,
		local_look_at.y * camera_offset_y_scale,
		local_look_at.z
	)


func _apply_setup_endcam_overrides(setup: Node) -> void:
	if setup == null:
		return
	if setup.has_method("get_endcam_height_scale"):
		camera_offset_y_scale = float(setup.call("get_endcam_height_scale"))
	if setup.has_method("get_endcam_face_look_z"):
		camera_face_look_z = float(setup.call("get_endcam_face_look_z"))
	if setup.has_method("get_endcam_forward_distance_scale"):
		camera_forward_distance_scale = float(setup.call("get_endcam_forward_distance_scale"))
	if setup.has_method("get_endcam_forward_pull_offset"):
		camera_forward_pull_offset = float(setup.call("get_endcam_forward_pull_offset"))
	if setup.has_method("get_endcam_forward_axis_sign"):
		camera_forward_axis_sign = float(setup.call("get_endcam_forward_axis_sign"))
	if setup.has_method("get_endcam_look_level_blend"):
		camera_look_level_blend = float(setup.call("get_endcam_look_level_blend"))
	if setup.has_method("get_endcam_catch_fade_enabled"):
		catch_fade_enabled = bool(setup.call("get_endcam_catch_fade_enabled"))
	if setup.has_method("get_endcam_ground_impact_time"):
		ground_impact_time = float(setup.call("get_endcam_ground_impact_time"))
	if setup.has_method("get_endcam_blood_fade_in"):
		blood_fade_in_duration = float(setup.call("get_endcam_blood_fade_in"))
	if setup.has_method("get_endcam_blood_intensity"):
		blood_overlay_intensity = float(setup.call("get_endcam_blood_intensity"))
	if setup.has_method("get_endcam_blood_drip_amount"):
		blood_drip_amount = float(setup.call("get_endcam_blood_drip_amount"))
	if setup.has_method("get_endcam_blood_splat_amount"):
		blood_splat_amount = float(setup.call("get_endcam_blood_splat_amount"))
	if setup.has_method("get_endcam_blood_edge_pool"):
		blood_edge_pool = float(setup.call("get_endcam_blood_edge_pool"))
	if setup.has_method("get_endcam_eating_speed_scale"):
		eating_animation_speed_scale = float(setup.call("get_endcam_eating_speed_scale"))
	if setup.has_method("get_endcam_eating_approach_distance"):
		eating_monster_approach_distance = float(setup.call("get_endcam_eating_approach_distance"))
	if setup.has_method("get_endcam_eating_approach_duration"):
		eating_monster_approach_duration = float(setup.call("get_endcam_eating_approach_duration"))
	if setup.has_method("get_endcam_eating_target_camera_distance"):
		eating_target_camera_distance = float(setup.call("get_endcam_eating_target_camera_distance"))
	if setup.has_method("get_endcam_eating_lateral_bias"):
		eating_lateral_bias = float(setup.call("get_endcam_eating_lateral_bias"))
	if setup.has_method("get_endcam_pickup_scream_duration"):
		pickup_scream_duration = float(setup.call("get_endcam_pickup_scream_duration"))
	if setup.has_method("get_endcam_pickup_scream_fov"):
		pickup_scream_fov = float(setup.call("get_endcam_pickup_scream_fov"))
	if setup.has_method("get_endcam_pickup_face_distance_from_camera"):
		pickup_face_distance_from_camera = float(setup.call("get_endcam_pickup_face_distance_from_camera"))
	if setup.has_method("get_endcam_pickup_grab_distance"):
		pickup_face_distance_from_camera = float(setup.call("get_endcam_pickup_grab_distance"))
	if setup.has_method("get_endcam_pickup_face_look_height"):
		pickup_face_look_height = float(setup.call("get_endcam_pickup_face_look_height"))
	if setup.has_method("get_endcam_pickup_face_height"):
		pickup_face_look_height = float(setup.call("get_endcam_pickup_face_height"))
	if setup.has_method("get_endcam_pickup_face_vertical_offset"):
		pickup_face_vertical_offset = float(setup.call("get_endcam_pickup_face_vertical_offset"))
	if setup.has_method("get_endcam_pickup_camera_local_x"):
		pickup_camera_local_x = float(setup.call("get_endcam_pickup_camera_local_x"))
	if setup.has_method("get_endcam_pickup_camera_local_y"):
		pickup_camera_local_y = float(setup.call("get_endcam_pickup_camera_local_y"))
	if setup.has_method("get_endcam_pickup_camera_local_z"):
		pickup_camera_local_z = float(setup.call("get_endcam_pickup_camera_local_z"))
	if setup.has_method("get_endcam_pickup_camera_look_local_y"):
		pickup_camera_look_local_y = float(setup.call("get_endcam_pickup_camera_look_local_y"))


func _run_camera_with_animation(
	monster: Node3D,
	animation_player: AnimationPlayer,
	player: Node3D
) -> void:
	var anim_key := String(lift_animation)
	if not animation_player.has_animation(anim_key):
		await get_tree().process_frame
		return

	var keyframes := _get_default_keyframes()
	var duration := animation_player.get_animation(anim_key).length
	if duration <= 0.0:
		var last_keyframe: EndCamKeyframe = keyframes.back()
		duration = last_keyframe.time

	while is_instance_valid(monster) and is_instance_valid(animation_player):
		if animation_player.current_animation != anim_key:
			break
		var t := animation_player.current_animation_position
		_apply_camera_sample(monster, keyframes, t, _look_up_blend)
		_update_lift_audio_cues(monster, t)
		if not _ground_impact_triggered and t >= ground_impact_time:
			_ground_impact_triggered = true
			_ground_impact_msec = Time.get_ticks_msec()
			_on_ground_impact(monster)
		if t >= duration - 0.01 and not animation_player.is_playing():
			break
		await get_tree().process_frame

	_apply_camera_sample(monster, keyframes, duration, _look_up_blend)


func _apply_camera_sample(
	monster: Node3D,
	keyframes: Array[EndCamKeyframe],
	time: float,
	look_up_blend: float = 0.0
) -> void:
	if _end_camera == null or not is_instance_valid(monster) or not _end_camera.is_inside_tree():
		return

	if monster.is_inside_tree():
		_catch_monster_transform = monster.global_transform

	var sample := _sample_keyframes(keyframes, time)
	var local_pos := sample.local_position
	var local_look := sample.local_look_at
	var roll_deg := sample.roll_deg

	if _lift_start_captured:
		var baseline := _sample_keyframes(keyframes, 0.0)
		local_pos = _lift_start_cam_local + (sample.local_position - baseline.local_position)
		local_look = _lift_start_look_local + (sample.local_look_at - baseline.local_look_at)
	else:
		local_pos = _resolve_frontal_camera_offset(local_pos, time)
		local_look = _resolve_frontal_camera_look(local_look, local_pos, time)

	if time >= air_wobble_start_time and time <= air_wobble_end_time:
		var wobble_t := time - air_wobble_start_time
		roll_deg += sin(wobble_t * air_roll_wobble_speed) * air_roll_wobble_deg

	if look_up_blend > 0.0:
		var look_sign := -signf(camera_forward_axis_sign)
		if look_sign == 0.0:
			look_sign = -1.0
		var up_target := Vector3(0.0, look_up_monster_height, look_sign * absf(camera_face_look_z))
		local_look = local_look.lerp(up_target, clampf(look_up_blend, 0.0, 1.0))

	var world_pos := _catch_monster_transform * local_pos
	var world_look := _catch_monster_transform * local_look
	var pitch_deg := _resolve_lift_air_pitch_deg(time)
	if pitch_deg > 0.0:
		world_look = _pitch_look_target_up(world_pos, world_look, pitch_deg)
	_set_camera_world_pose(_end_camera, world_pos, world_look, roll_deg)


func _resolve_frontal_camera_offset(local_pos: Vector3, _time: float) -> Vector3:
	var nominal_ratio := 1.0
	if absf(NOMINAL_KEYFRAME_FORWARD_Z) > 0.01:
		nominal_ratio = local_pos.z / NOMINAL_KEYFRAME_FORWARD_Z
	var forward_distance := _catch_forward_distance * camera_forward_distance_scale * nominal_ratio
	forward_distance += camera_forward_pull_offset
	var axis_sign := camera_forward_axis_sign
	if axis_sign == 0.0:
		axis_sign = 1.0
	var resolved_z := axis_sign * maxf(forward_distance, 0.35)
	if absf(_catch_camera_local.z) > 0.01 and signf(_catch_camera_local.z) == signf(axis_sign):
		if axis_sign > 0.0:
			resolved_z = maxf(resolved_z, _catch_camera_local.z)
		else:
			resolved_z = minf(resolved_z, _catch_camera_local.z)
	return Vector3(0.0, local_pos.y, resolved_z)


func _resolve_frontal_camera_look(local_look: Vector3, local_pos: Vector3, _time: float) -> Vector3:
	var look_sign := -signf(camera_forward_axis_sign)
	if look_sign == 0.0:
		look_sign = -1.0
	var look_y := local_look.y
	if local_pos.y > 0.55:
		look_y = lerpf(local_look.y, local_pos.y, camera_look_level_blend)
		look_y += camera_look_vertical_offset
	return Vector3(0.0, look_y, look_sign * absf(camera_face_look_z))


func _ensure_fade_overlay() -> void:
	if _fade_rect != null and is_instance_valid(_fade_rect):
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "EndcamFadeLayer"
	_fade_layer.layer = 120
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_layer.add_child(_fade_rect)


func _fade_alpha(from: float, to: float, duration: float) -> void:
	if _fade_rect == null:
		return
	if duration <= 0.0:
		_set_fade_alpha(to)
		return
	var tween := create_tween()
	tween.tween_method(_set_fade_alpha, from, to, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _set_fade_alpha(alpha: float) -> void:
	if _fade_rect == null:
		return
	var color := _fade_rect.color
	color.a = clampf(alpha, 0.0, 1.0)
	_fade_rect.color = color


func _begin_disorientation_effects() -> void:
	if _trauma_running:
		return
	_trauma_running = true
	_kill_trauma_blood_tween()
	if _footage_filter != null and _footage_filter.has_method("begin_trauma_pulse"):
		_footage_filter.call(
			"begin_trauma_pulse",
			disorientation_blur_min,
			disorientation_blur_max,
			trauma_chromatic_max,
			trauma_pulse_period
		)
	if _footage_filter != null and _footage_filter.has_method("animate_chase_vignette"):
		_footage_filter.call(
			"animate_chase_vignette",
			true,
			disorientation_vignette,
			disorientation_blur_max * 0.55,
			0.35
		)
	if _blood_rect != null:
		_blood_rect.visible = false
		_set_blood_intensity(0.0)
		_set_blood_pulse(0.0)


func _begin_blood_effects() -> void:
	if _blood_running:
		return
	_blood_running = true
	_ensure_blood_overlay()
	_kill_trauma_blood_tween()
	if _blood_rect == null or _blood_material == null:
		return
	_blood_rect.visible = true
	_set_blood_pulse(0.0)
	if blood_fade_in_duration <= 0.02:
		_set_blood_intensity(blood_overlay_intensity)
		_start_blood_pulse_loop()
		return
	_set_blood_intensity(0.0)
	_trauma_blood_tween = create_tween()
	_trauma_blood_tween.set_trans(Tween.TRANS_QUAD)
	_trauma_blood_tween.set_ease(Tween.EASE_OUT)
	_trauma_blood_tween.tween_method(
		_set_blood_intensity,
		0.0,
		blood_overlay_intensity,
		blood_fade_in_duration
	)
	_trauma_blood_tween.tween_callback(_start_blood_pulse_loop)


func _fade_out_blood() -> void:
	if not _blood_running:
		return
	_kill_trauma_blood_tween()
	var start_intensity := 0.0
	if _blood_material != null:
		start_intensity = float(_blood_material.get_shader_parameter("intensity"))
	if blood_fade_out_duration <= 0.02 or start_intensity <= 0.01:
		_clear_blood_overlay()
		return
	var tween := create_tween()
	tween.tween_method(_set_blood_intensity, start_intensity, 0.0, blood_fade_out_duration)
	await tween.finished
	_clear_blood_overlay()


func _freeze_blood_overlay() -> void:
	if not _blood_running:
		return
	_kill_trauma_blood_tween()
	_set_blood_pulse(1.0)


func _capture_scream_end_as_lift_start(monster: Node3D) -> void:
	_lift_start_captured = false
	if _end_camera == null or not _end_camera.is_inside_tree():
		return
	if monster == null or not monster.is_inside_tree():
		return

	_catch_monster_transform = monster.global_transform
	var inv := _catch_monster_transform.affine_inverse()
	_lift_start_cam_local = inv * _end_camera.global_position
	var look_target := _end_camera.global_position - _end_camera.global_basis.z
	_lift_start_look_local = inv * look_target
	_lift_start_captured = true


func _clear_blood_overlay() -> void:
	_blood_running = false
	if _blood_rect != null:
		_blood_rect.visible = false
	_set_blood_intensity(0.0)
	_set_blood_pulse(0.0)


func _begin_trauma_effects() -> void:
	_begin_disorientation_effects()


func _start_blood_pulse_loop() -> void:
	_kill_trauma_blood_tween()
	_trauma_blood_tween = create_tween().set_loops()
	_trauma_blood_tween.set_trans(Tween.TRANS_SINE)
	_trauma_blood_tween.set_ease(Tween.EASE_IN_OUT)
	_trauma_blood_tween.tween_method(_set_blood_pulse, 0.15, 1.0, trauma_pulse_period * 0.5)
	_trauma_blood_tween.tween_method(_set_blood_pulse, 1.0, 0.15, trauma_pulse_period * 0.5)


func _stop_trauma_effects(keep_blood_visible: bool = false) -> void:
	_kill_trauma_blood_tween()
	_kill_monster_approach_tween()
	_trauma_running = false
	if _footage_filter != null and _footage_filter.has_method("end_trauma_pulse"):
		_footage_filter.call("end_trauma_pulse")
	if _footage_filter != null and _footage_filter.has_method("animate_chase_vignette"):
		_footage_filter.call("animate_chase_vignette", false, 0.0, 0.0, 0.35)
	if keep_blood_visible:
		return
	_clear_blood_overlay()


func _begin_look_up_tween() -> void:
	_kill_look_up_tween()
	if look_up_duration <= 0.0:
		_look_up_blend = 1.0
		return
	_look_up_tween = create_tween()
	_look_up_tween.tween_property(self, "_look_up_blend", 1.0, look_up_duration).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)


func _play_final_bite(
	monster: Node3D,
	animation_player: AnimationPlayer,
	player: Node3D
) -> void:
	if animation_player == null or not is_instance_valid(monster):
		return
	_hide_death_sequence_mouse(player)
	var anim_key := String(eating_animation)
	if not animation_player.has_animation(anim_key):
		return

	var from_anim := String(lift_animation)
	if animation_player.current_animation != from_anim:
		from_anim = animation_player.current_animation

	if monster.has_method("prepare_sequence_from") and not from_anim.is_empty():
		monster.prepare_sequence_from(from_anim, anim_key, true, -1)

	var keyframes := _get_default_keyframes()
	var last_keyframe: EndCamKeyframe = keyframes.back()
	var ground_time: float = last_keyframe.time
	_apply_camera_sample(monster, keyframes, ground_time, _look_up_blend)

	var locked_camera_pos := Vector3.ZERO
	var locked_camera_basis := Basis.IDENTITY
	var has_locked_camera := false
	if _end_camera != null and _end_camera.is_inside_tree():
		locked_camera_pos = _end_camera.global_position
		locked_camera_basis = _end_camera.global_basis
		has_locked_camera = true

	_begin_monster_approach(monster)

	animation_player.speed_scale = maxf(eating_animation_speed_scale, 0.04)
	if monster.has_method("play_animation_blended"):
		monster.play_animation_blended(anim_key, eating_blend_time)
	elif animation_player.has_animation(anim_key):
		if eating_blend_time > 0.0:
			animation_player.play(anim_key, eating_blend_time)
		else:
			animation_player.play(anim_key)

	await get_tree().process_frame
	await get_tree().physics_frame
	await _await_demonic_laugh_finished()
	_play_eating_sfx()

	var eating_anim := animation_player.get_animation(anim_key)
	if eating_anim == null:
		_stop_eating_sfx()
		return
	var start_t := eating_anim.length * clampf(eating_play_start_ratio, 0.0, 0.95)
	var end_t := eating_anim.length - 0.04
	animation_player.seek(start_t, true)

	var elapsed := 0.0
	while is_instance_valid(monster) and is_instance_valid(animation_player):
		if animation_player.current_animation != anim_key:
			break
		var t := animation_player.current_animation_position
		if t >= end_t:
			break
		if has_locked_camera and _end_camera != null and _end_camera.is_inside_tree():
			_end_camera.global_position = locked_camera_pos
			_end_camera.global_basis = locked_camera_basis
		elif monster.is_inside_tree():
			_catch_monster_transform = monster.global_transform
			_apply_camera_sample(monster, keyframes, ground_time, _look_up_blend)
		elapsed += get_process_delta_time()
		if elapsed >= eating_bite_max_duration:
			break
		await get_tree().process_frame

	if animation_player.is_playing():
		animation_player.stop()
	animation_player.speed_scale = maxf(animation_speed_scale, 0.1)
	_stop_eating_sfx()


func _begin_monster_approach(monster: Node3D) -> void:
	_kill_monster_approach_tween()
	if monster == null or not monster.is_inside_tree():
		return
	if _end_camera == null or not _end_camera.is_inside_tree():
		return

	var start_pos := monster.global_position
	var cam_pos := _end_camera.global_position
	var cam_basis := _end_camera.global_basis
	var forward := -cam_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = cam_pos - start_pos
		forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = -monster.global_basis.z
		forward.y = 0.0
	forward = forward.normalized()

	var right := cam_basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()

	# Coloca al monstruo en el centro de la mirada, a distancia controlada.
	var desired_distance := maxf(eating_target_camera_distance, 0.35)
	var target_pos := cam_pos + forward * desired_distance + right * eating_lateral_bias
	target_pos.y = start_pos.y

	# Garantiza un acercamiento mínimo si ya estaba demasiado lejos.
	var flat_to_target := target_pos - start_pos
	flat_to_target.y = 0.0
	var approach_needed := flat_to_target.length()
	if approach_needed < eating_monster_approach_distance * 0.35:
		var to_camera := cam_pos - start_pos
		to_camera.y = 0.0
		if to_camera.length_squared() > 0.0001:
			target_pos = start_pos + to_camera.normalized() * eating_monster_approach_distance
			target_pos += right * eating_lateral_bias
			target_pos.y = start_pos.y

	if snap_to_floor:
		target_pos = _project_to_floor(target_pos, monster)
	else:
		target_pos.y = start_pos.y

	if eating_monster_approach_duration <= 0.0:
		monster.global_position = target_pos
		return

	_monster_approach_tween = create_tween()
	_monster_approach_tween.set_trans(Tween.TRANS_SINE)
	_monster_approach_tween.set_ease(Tween.EASE_OUT)
	_monster_approach_tween.tween_method(
		func(pos: Vector3) -> void:
			if is_instance_valid(monster) and monster.is_inside_tree():
				monster.global_position = pos,
		start_pos,
		target_pos,
		eating_monster_approach_duration
	)


func _show_fin_screen() -> void:
	_stop_trauma_effects(true)
	_freeze_blood_overlay()
	_kill_look_up_tween()
	_ensure_fade_overlay()
	_ensure_fin_label()
	_ensure_fin_continue_hint()
	_fade_layer.visible = true
	_fin_label.text = fin_title
	_fin_label.modulate.a = 0.0
	if _fin_continue_label != null:
		_fin_continue_label.modulate.a = 0.0
	if _blood_rect != null and is_instance_valid(_blood_rect):
		_blood_rect.visible = true
		_blood_rect.move_to_front()
	_fin_label.move_to_front()
	var start_alpha := _fade_rect.color.a if _fade_rect != null else 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_fade_alpha, start_alpha, 1.0, fin_fade_duration).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	tween.tween_property(_fin_label, "modulate:a", 1.0, fin_fade_duration * 0.9).set_delay(
		fin_fade_duration * 0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	_set_fade_alpha(1.0)
	await _show_fin_continue_hint()
	await _wait_for_fin_continue_input()
	_teardown_death_overlays()
	if not death_flag.is_empty():
		GameManager.set_flag(death_flag, true)
	_running = false
	_death_sequence_player = null
	set_process(false)
	get_tree().change_scene_to_file(ENDING_SCENE_PATH)


func _teardown_death_overlays() -> void:
	_stop_eating_sfx()
	_stop_trauma_effects(true)
	_kill_look_up_tween()
	_kill_monster_approach_tween()
	if _fade_layer != null and is_instance_valid(_fade_layer):
		_fade_layer.queue_free()
	_fade_layer = null
	_fade_rect = null
	_blood_rect = null
	_blood_material = null
	_fin_label = null
	_fin_continue_label = null


func _await_demonic_laugh_finished() -> void:
	_ensure_audio_players()
	if _monster_voice_player == null or not is_instance_valid(_monster_voice_player):
		return
	if not _monster_voice_player.playing:
		return
	if _monster_voice_player.stream != AUDIO_DEMONIC_LAUGH:
		return
	await _monster_voice_player.finished


func _wait_for_fin_continue_input() -> void:
	_fin_awaiting_input = true
	set_process_unhandled_input(true)
	while _fin_awaiting_input:
		await get_tree().process_frame
	_fin_awaiting_input = false
	set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _fin_awaiting_input:
		return
	if _is_fin_continue_input(event):
		_fin_awaiting_input = false


func _is_fin_continue_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo
	if event is InputEventJoypadButton:
		var pad_event := event as InputEventJoypadButton
		return pad_event.pressed
	return false


func _resolve_footage_filter(player: Node3D) -> void:
	if _footage_filter != null and is_instance_valid(_footage_filter):
		return
	if player != null and player.has_node("FoundFootageFilter"):
		_footage_filter = player.get_node("FoundFootageFilter")


func _ensure_blood_overlay() -> void:
	_ensure_fade_overlay()
	if _blood_rect != null and is_instance_valid(_blood_rect):
		_apply_blood_shader_params()
		return
	_blood_rect = ColorRect.new()
	_blood_rect.name = "BloodOverlay"
	_blood_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blood_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blood_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	_blood_rect.visible = false
	_blood_material = ShaderMaterial.new()
	_blood_material.shader = load("res://assets/shaders/endcam_blood_overlay.gdshader") as Shader
	_blood_rect.material = _blood_material
	_fade_layer.add_child(_blood_rect)
	_blood_rect.move_to_front()
	if _fade_rect != null:
		_fade_rect.move_to_front()
	_apply_blood_shader_params()
	_set_blood_intensity(0.0)


func _ensure_fin_label() -> void:
	_ensure_fade_overlay()
	if _fin_label != null and is_instance_valid(_fin_label):
		return
	_fin_label = Label.new()
	_fin_label.name = "FinLabel"
	_fin_label.text = fin_title
	_fin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fin_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fin_label.add_theme_font_size_override("font_size", 72)
	_fin_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_fade_layer.add_child(_fin_label)
	_fin_label.move_to_front()


func _ensure_fin_continue_hint() -> void:
	_ensure_fade_overlay()
	if _fin_continue_label != null and is_instance_valid(_fin_continue_label):
		return
	_fin_continue_label = Label.new()
	_fin_continue_label.name = "FinContinueHint"
	_fin_continue_label.text = fin_continue_hint_text
	_fin_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fin_continue_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_fin_continue_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_fin_continue_label.offset_bottom = -40.0
	_fin_continue_label.add_theme_font_size_override("font_size", 18)
	_fin_continue_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_fade_layer.add_child(_fin_continue_label)
	_fin_continue_label.move_to_front()


func _show_fin_continue_hint() -> void:
	_ensure_fin_continue_hint()
	if _fin_continue_label == null:
		return
	if fin_continue_hint_delay > 0.0:
		await get_tree().create_timer(fin_continue_hint_delay).timeout
	var tween := create_tween()
	tween.tween_property(_fin_continue_label, "modulate:a", 0.82, 0.5).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	await tween.finished


func _apply_blood_shader_params() -> void:
	if _blood_material == null:
		return
	_blood_material.set_shader_parameter("drip_amount", blood_drip_amount)
	_blood_material.set_shader_parameter("splat_amount", blood_splat_amount)
	_blood_material.set_shader_parameter("edge_pool", blood_edge_pool)


func _set_blood_intensity(value: float) -> void:
	if _blood_material == null:
		return
	_blood_material.set_shader_parameter("intensity", clampf(value, 0.0, 1.5))


func _set_blood_pulse(value: float) -> void:
	if _blood_material == null:
		return
	_blood_material.set_shader_parameter("pulse", clampf(value, 0.0, 1.0))


func _kill_trauma_blood_tween() -> void:
	if _trauma_blood_tween != null and _trauma_blood_tween.is_valid():
		_trauma_blood_tween.kill()
	_trauma_blood_tween = null


func _kill_look_up_tween() -> void:
	if _look_up_tween != null and _look_up_tween.is_valid():
		_look_up_tween.kill()
	_look_up_tween = null


func _kill_monster_approach_tween() -> void:
	if _monster_approach_tween != null and _monster_approach_tween.is_valid():
		_monster_approach_tween.kill()
	_monster_approach_tween = null


func _sample_keyframes(keyframes: Array[EndCamKeyframe], time: float) -> EndCamKeyframe:
	if keyframes.is_empty():
		return EndCamKeyframe.new()

	if time <= keyframes[0].time:
		return keyframes[0]

	for index in range(keyframes.size() - 1):
		var current := keyframes[index]
		var next := keyframes[index + 1]
		if time > next.time:
			continue
		var span := maxf(next.time - current.time, 0.0001)
		var blend := clampf((time - current.time) / span, 0.0, 1.0)
		return EndCamKeyframe.new(
			time,
			current.local_position.lerp(next.local_position, blend),
			current.local_look_at.lerp(next.local_look_at, blend),
			lerpf(current.roll_deg, next.roll_deg, blend)
		)

	return keyframes.back()


func _set_camera_world_pose(
	camera: Camera3D,
	world_position: Vector3,
	world_look_at: Vector3,
	roll_deg: float
) -> void:
	if camera == null or not camera.is_inside_tree():
		return
	camera.global_position = world_position
	var look_dir := world_look_at - world_position
	if look_dir.length_squared() < 0.0001:
		look_dir = -camera.global_basis.z
	camera.look_at(world_position + look_dir, Vector3.UP)
	camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(roll_deg))


func _resolve_lift_air_pitch_deg(time: float) -> float:
	if lift_air_pitch_boost_deg <= 0.0:
		return 0.0
	if time < lift_air_pitch_start_time or time > lift_air_pitch_end_time:
		return 0.0
	var ramp_end := maxf(lift_air_pitch_ramp_end_time, lift_air_pitch_start_time + 0.05)
	if time >= ramp_end:
		return lift_air_pitch_boost_deg
	var ramp_t := clampf((time - lift_air_pitch_start_time) / (ramp_end - lift_air_pitch_start_time), 0.0, 1.0)
	ramp_t = ramp_t * ramp_t * (3.0 - 2.0 * ramp_t)
	return lift_air_pitch_boost_deg * ramp_t


func _pitch_look_target_up(cam_pos: Vector3, look_at: Vector3, pitch_deg: float) -> Vector3:
	var offset := look_at - cam_pos
	var distance := offset.length()
	if distance < 0.0001:
		return look_at
	var forward := offset / distance
	var right := forward.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var pitched := forward.rotated(right, deg_to_rad(pitch_deg))
	return cam_pos + pitched * distance


func _prepare_pickup_scream_alignment(player: Node3D, monster: Node3D) -> void:
	if not player.is_inside_tree() or not monster.is_inside_tree():
		return

	for _pass in 2:
		_snap_monster_in_front_of_player(player, monster)
		_face_monster_toward_player(monster, player)
		_aim_player_at_monster_face(player, monster)
		_update_pickup_scream_camera_reference(monster)
		await get_tree().physics_frame

	_snap_monster_in_front_of_player(player, monster)
	_face_monster_toward_player(monster, player)
	_aim_player_at_monster_face(player, monster)
	_update_pickup_scream_camera_reference(monster)


func _refresh_pickup_scream_view(player: Node3D, monster: Node3D) -> void:
	if player == null or monster == null:
		return
	if not player.is_inside_tree() or not monster.is_inside_tree():
		return
	_aim_player_at_monster_face(player, monster)
	_apply_pickup_scream_camera(player, monster)


func _update_pickup_scream_camera_reference(monster: Node3D) -> void:
	var pose: Array[Vector3] = _compute_pickup_scream_camera_pose(monster)
	_pickup_camera_pos = pose[0]
	var look_dir: Vector3 = pose[1] - pose[0]
	if look_dir.length_squared() < 0.0001:
		_pickup_camera_forward = Vector3.FORWARD
	else:
		_pickup_camera_forward = look_dir.normalized()


func _compute_pickup_scream_camera_pose(monster: Node3D) -> Array[Vector3]:
	var local_cam := Vector3(pickup_camera_local_x, pickup_camera_local_y, pickup_camera_local_z)
	var local_look := Vector3(0.0, pickup_camera_look_local_y, 0.0)
	var cam_pos := monster.global_transform * local_cam
	var look_at := monster.global_transform * local_look
	return [cam_pos, look_at]


func _get_player_confront_height(player: Node3D) -> float:
	if player == null or not player.is_inside_tree():
		return 1.62
	if player.has_node("Head"):
		var head := player.get_node("Head") as Node3D
		if head != null and head.is_inside_tree():
			return head.global_position.y
	return player.global_position.y + 1.62


func _snap_monster_in_front_of_player(player: Node3D, monster: Node3D) -> void:
	var forward := -player.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	var confront_y := _get_player_confront_height(player) + pickup_face_vertical_offset
	var face_target := player.global_position + forward * pickup_face_distance_from_camera
	face_target.y = confront_y

	var root_pos := face_target - Vector3(0.0, pickup_face_look_height, 0.0)
	if snap_to_floor:
		var floor_xz := _project_to_floor(
			Vector3(root_pos.x, monster.global_position.y, root_pos.z),
			monster
		)
		root_pos.x = floor_xz.x
		root_pos.z = floor_xz.z
	monster.global_position = root_pos


func _aim_player_at_monster_face(player: Node3D, monster: Node3D) -> void:
	var face_point := _get_monster_face_world(monster, Vector3.ZERO)
	if player.has_method("apply_look_at_world_point"):
		player.apply_look_at_world_point(face_point)
		return
	var look_origin := player.global_position + Vector3(0.0, 0.9, 0.0)
	var look_dir := face_point - look_origin
	if look_dir.length_squared() > 0.0001 and player.has_method("apply_look_direction"):
		player.apply_look_direction(look_dir.normalized())


func _get_monster_face_world(monster: Node3D, _camera_pos: Vector3) -> Vector3:
	if monster == null or not monster.is_inside_tree():
		return Vector3.ZERO
	return monster.global_position + Vector3(0.0, pickup_face_look_height, 0.0)


func _apply_pickup_scream_camera(_player: Node3D, monster: Node3D) -> void:
	if _end_camera == null or not _end_camera.is_inside_tree() or monster == null:
		return
	if not monster.is_inside_tree():
		return

	var pose: Array[Vector3] = _compute_pickup_scream_camera_pose(monster)
	_pickup_camera_pos = pose[0]
	_set_camera_world_pose(_end_camera, pose[0], pose[1], 0.0)


func _play_scream_animation(monster: Node3D, blend_time: float) -> void:
	var animation_player := _get_animation_player(monster)
	if animation_player == null:
		return
	animation_player.speed_scale = maxf(animation_speed_scale, 0.1)
	var anim_key := String(SCREAM_ANIMATION)
	if monster.has_method("play_animation_blended"):
		monster.play_animation_blended(anim_key, blend_time)
	elif animation_player.has_animation(anim_key):
		if blend_time > 0.0:
			animation_player.play(anim_key, blend_time)
		else:
			animation_player.play(anim_key)


func _ensure_audio_players() -> void:
	if _sfx_player == null or not is_instance_valid(_sfx_player):
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.name = "EndcamSFX"
		_sfx_player.bus = &"SFX"
		add_child(_sfx_player)
	if _monster_voice_player == null or not is_instance_valid(_monster_voice_player):
		_monster_voice_player = AudioStreamPlayer3D.new()
		_monster_voice_player.name = "EndcamMonsterVoice"
		_monster_voice_player.bus = &"SFX"
		_monster_voice_player.volume_db = lift_voice_volume_db
		add_child(_monster_voice_player)


func _play_pickup_scream_sfx() -> void:
	_play_pickup_scream_sfx_delayed()


func _play_pickup_scream_sfx_delayed() -> void:
	if pickup_scream_sfx_delay > 0.0:
		await get_tree().create_timer(pickup_scream_sfx_delay).timeout
	_ensure_audio_players()
	if AUDIO_HARD2_SCREAM == null:
		return
	_sfx_player.volume_db = pickup_scream_volume_db
	_sfx_player.stream = AUDIO_HARD2_SCREAM
	_sfx_player.play()


func _stop_pickup_scream_sfx() -> void:
	if _sfx_player != null and _sfx_player.playing:
		_sfx_player.stop()


func _play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	_ensure_audio_players()
	if stream == null:
		return
	_sfx_player.volume_db = volume_db
	_sfx_player.stream = stream
	_sfx_player.play()


func _play_eating_sfx() -> void:
	_ensure_audio_players()
	if AUDIO_CREATURE_EATING == null:
		return
	var stream := AUDIO_CREATURE_EATING.duplicate(true)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_sfx_player.volume_db = eating_sfx_volume_db
	_sfx_player.stream = stream
	_sfx_player.play()


func _stop_eating_sfx() -> void:
	if _sfx_player != null and is_instance_valid(_sfx_player) and _sfx_player.playing:
		_sfx_player.stop()


func _play_monster_voice(stream: AudioStream, monster: Node3D) -> void:
	_ensure_audio_players()
	if stream == null or monster == null or not monster.is_inside_tree():
		return
	_monster_voice_player.volume_db = lift_voice_volume_db
	_monster_voice_player.global_position = monster.global_position + Vector3(0.0, pickup_face_look_height, 0.0)
	_monster_voice_player.stream = stream
	_monster_voice_player.play()


func _update_lift_audio_cues(monster: Node3D, anim_time: float) -> void:
	if not _lift_growl_played and anim_time >= lift_growl_time:
		_lift_growl_played = true
		_play_monster_voice(AUDIO_DEMON_GROWL, monster)
	if not _lift_smell_played and anim_time >= lift_smell_flesh_time:
		_lift_smell_played = true
		_play_monster_voice(AUDIO_DEMON_SMELL_FLESH, monster)


func _on_ground_impact(monster: Node3D) -> void:
	_begin_blood_effects()
	_boost_trauma_on_impact()
	if not _head_impact_played:
		_head_impact_played = true
		_play_sfx(AUDIO_HEAD_IMPACT, head_impact_volume_db)
	if not _lift_throw_played:
		_lift_throw_played = true
		_play_monster_voice(AUDIO_DEMONIC_LAUGH, monster)


func _boost_trauma_on_impact() -> void:
	if not _blood_running:
		return
	var boosted := minf(blood_overlay_intensity * 1.18, 1.45)
	_set_blood_intensity(boosted)


func _prepare_catch_alignment(player: Node3D, monster: Node3D) -> void:
	if not player.is_inside_tree() or not monster.is_inside_tree():
		return
	_face_monster_toward_player(monster, player)

	var flat_to_player := player.global_position - monster.global_position
	flat_to_player.y = 0.0
	if flat_to_player.length_squared() < 0.0001:
		flat_to_player = -monster.global_basis.z
	flat_to_player = flat_to_player.normalized()

	var grab_pos := monster.global_position + flat_to_player * grab_forward_distance
	grab_pos.y = player.global_position.y + grab_height_offset
	if snap_to_floor:
		grab_pos = _project_to_floor(grab_pos, monster)
	player.global_position = grab_pos

	var face_dir := monster.global_position - player.global_position
	face_dir.y = 0.0
	if face_dir.length_squared() > 0.0001 and player.has_method("apply_look_direction"):
		player.apply_look_direction(face_dir.normalized())


func _capture_catch_camera_reference(player: Node3D, monster: Node3D) -> void:
	if not monster.is_inside_tree():
		_catch_camera_local = Vector3(0.0, 1.65, -1.45)
		_catch_look_local = Vector3(0.0, 1.45, -2.2)
		_catch_monster_transform = Transform3D.IDENTITY
		_catch_forward_distance = grab_forward_distance + 0.55
		return

	_catch_monster_transform = monster.global_transform

	var camera: Camera3D = null
	if player.is_inside_tree() and player.has_node("Head/Camera3D"):
		camera = player.get_node("Head/Camera3D") as Camera3D
	if camera == null or not camera.is_inside_tree():
		_catch_camera_local = Vector3(0.0, 1.65, -1.45)
		_catch_look_local = Vector3(0.0, 1.45, -2.2)
		_catch_forward_distance = grab_forward_distance + 0.55
		return

	var inv := _catch_monster_transform.affine_inverse()
	_catch_camera_local = inv * camera.global_position
	var look_target := camera.global_position - camera.global_basis.z
	_catch_look_local = inv * look_target
	_catch_forward_distance = _measure_forward_distance_from_monster(_catch_camera_local)


func _measure_forward_distance_from_monster(local_camera_position: Vector3) -> float:
	var flat_offset := Vector3(local_camera_position.x, 0.0, local_camera_position.z)
	var world_flat := _catch_monster_transform.basis * flat_offset
	var distance := Vector2(world_flat.x, world_flat.z).length()
	if distance < 0.45:
		distance = grab_forward_distance + 0.55
	return distance


func _lock_player_for_death(player: Node3D) -> void:
	GameManager.lock_player()
	_hide_death_sequence_mouse(player)
	if player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
	if player.has_method("stop_movement_immediately"):
		player.stop_movement_immediately()
	if player.has_method("force_clear_nervous_camera_shake"):
		player.force_clear_nervous_camera_shake()
	if player.has_method("clear_camera_focus"):
		player.clear_camera_focus()


func _hide_death_sequence_mouse(player: Node3D) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN


func _hide_player_body(player: Node3D) -> void:
	if player.has_method("set_minigame_body_visible"):
		player.set_minigame_body_visible(false)


func _stop_chase_presentation(setup: Node) -> void:
	if setup == null or not setup.has_method("get_presentation"):
		return
	var presentation: Scene6FinalPresentation = setup.call("get_presentation") as Scene6FinalPresentation
	if presentation != null and presentation.has_method("stop_chase_presentation"):
		presentation.call("stop_chase_presentation")


func _resolve_camera_anchor(setup: Node, monster: Node3D) -> Node3D:
	if setup is Node3D and setup.is_inside_tree():
		return setup as Node3D
	if monster != null and monster.is_inside_tree():
		var parent := monster.get_parent()
		if parent is Node3D:
			return parent as Node3D
	return null


func _ensure_end_camera(anchor: Node3D) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	if _end_camera == null or not is_instance_valid(_end_camera):
		_end_camera = Camera3D.new()
		_end_camera.name = "Scene6EndCamera"
	if _end_camera.get_parent() != anchor:
		if _end_camera.get_parent() != null:
			_end_camera.reparent(anchor)
		else:
			anchor.add_child(_end_camera)


func _play_lift_animation(monster: Node3D, blend_time: float) -> void:
	var animation_player := _get_animation_player(monster)
	if animation_player == null:
		return
	animation_player.speed_scale = maxf(animation_speed_scale, 0.1)
	if monster.has_method("play_animation_blended"):
		monster.play_animation_blended(String(lift_animation), blend_time)
	elif animation_player.has_animation(String(lift_animation)):
		if blend_time > 0.0:
			animation_player.play(String(lift_animation), blend_time)
		else:
			animation_player.play(String(lift_animation))


func _face_monster_toward_player(monster: Node3D, player: Node3D) -> void:
	if monster == null or player == null:
		return
	if not monster.is_inside_tree() or not player.is_inside_tree():
		return
	var direction := player.global_position - monster.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var look_basis := Basis.looking_at(direction.normalized(), Vector3.UP)
	look_basis = look_basis.rotated(Vector3.UP, MIXAMO_YAW_CORRECTION)
	monster.global_rotation = look_basis.get_euler()


func _get_animation_player(actor: Node3D) -> AnimationPlayer:
	if actor == null:
		return null
	return actor.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _project_to_floor(world_pos: Vector3, context: Node3D) -> Vector3:
	if context == null or not context.is_inside_tree():
		return world_pos
	var space := context.get_world_3d().direct_space_state
	if space == null:
		return world_pos
	var from := world_pos + Vector3.UP * floor_ray_height
	var to := world_pos + Vector3.DOWN * floor_ray_depth
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return world_pos
	return Vector3(world_pos.x, hit.position.y, world_pos.z)
