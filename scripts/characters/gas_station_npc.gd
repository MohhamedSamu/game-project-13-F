class_name GasStationNPC
extends CharacterBody3D
## NPC de la gasolinera: física, animaciones y rutina entre bombas.

enum WorkState {
	IDLE,
	TURNING_TO_MOVE_DIRECTION,
	WALKING_TO_POINT,
	ARRIVAL_SETTLE,
	TURNING_TO_LOOK_TARGET,
	LOOK_TURN_SETTLE,
	KNEELING_DOWN,
	INSPECTING,
	STANDING_UP,
	WAITING,
}

@export_group("Pump Markers")
@export var pump_1_point: Marker3D
@export var pump_1_look_target: Marker3D
@export var pump_2_point: Marker3D
@export var pump_2_look_target: Marker3D

@export_group("Behavior")
@export var behavior_enabled: bool = false
@export var start_behavior_after_intro: bool = true
@export var start_behavior_flag: String = "gas_npc_intro_done"
@export var move_speed: float = 0.75
@export var rotation_speed: float = 2.5
@export var arrival_distance: float = 0.20
@export var inspect_time_min: float = 3.0
@export var inspect_time_max: float = 6.0
@export var wait_after_standing_min: float = 0.8
@export var wait_after_standing_max: float = 1.5
@export var pause_behavior_during_dialogue: bool = true

@export_group("Movement Turn")
@export var pre_walk_turn_speed: float = 2.4
@export var pre_walk_angle_tolerance: float = 0.06
@export var walk_correction_turn_speed: float = 2.0
@export var use_walking_in_place_while_turning: bool = true

@export_group("Arrival")
@export var snap_to_marker_on_arrival: bool = true
@export var max_snap_distance: float = 0.30
@export var arrival_settle_time: float = 0.30

@export_group("Look Target Turn")
@export var look_target_turn_speed: float = 2.3
@export var look_target_angle_tolerance: float = 0.06
@export var look_turn_settle_time: float = 0.20

@export_group("Dialogue Turn")
@export var dialogue_turn_speed: float = 2.2
@export var dialogue_turn_angle_tolerance: float = 0.035
@export var max_dialogue_turn_time: float = 1.6
@export var turn_on_repeat_dialogue: bool = false
@export var repeat_dialogue_turn_time_scale: float = 0.5
@export var return_to_original_rotation_after_intro: bool = true
@export var return_turn_speed: float = 2.0
@export var max_return_turn_time: float = 1.6

@export_group("Animation")
@export var walking_target_duration: float = 5.0
@export var use_slow_walking: bool = true
@export var turn_walk_angle_threshold_deg: float = 25.0

const BLEND_IDLE_WALK := 0.25
const BLEND_TURN_IN_PLACE := 0.20
const BLEND_KNEEL_DOWN := 0.15
const BLEND_KNEEL_INSPECT := 0.20
const BLEND_STAND_UP := 0.15
const BLEND_ROUTINE := 0.20
const BLEND_OLD_MAN_TURN := 0.25

const WALK_IN_PLACE_ANIM := &"walking_in_place"
const WALK_ANIM := &"walking"

var _dialogue_turn_active: bool = false
var _turn_visual_active: bool = false
var _pre_dialogue_yaw: float = 0.0
var _has_saved_pre_dialogue_yaw: bool = false
var _waiting_intro_dialogue_to_finish: bool = false
var _intro_sequence_complete: bool = false
var _work_behavior_started: bool = false
var _work_state: WorkState = WorkState.IDLE
var _current_pump_index: int = 0
var _state_timer: float = 0.0
var _turn_anchor_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	await _wait_for_character_animations()
	play_idle()
	_connect_animation_player()
	if not DialogueController.dialogue_finished.is_connected(_on_dialogue_finished):
		DialogueController.dialogue_finished.connect(_on_dialogue_finished)


func _wait_for_character_animations() -> void:
	var character := get_node_or_null("Model/Character09")
	if character == null:
		await get_tree().process_frame
		return
	if character.has_method("are_animations_ready"):
		for _i in 120:
			if character.are_animations_ready():
				return
			await get_tree().process_frame
		push_warning("GasStationNPC: las animaciones del personaje no estuvieron listas a tiempo.")
		return
	await get_tree().process_frame


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if _should_pause_work_behavior():
		_halt_horizontal_movement()
		move_and_slide()
		return

	if behavior_enabled:
		_process_work_behavior(delta)
	elif is_on_floor():
		_halt_horizontal_movement()

	if behavior_enabled and _is_turn_hold_state():
		_hold_turn_position()

	move_and_slide()

	if behavior_enabled and _is_turn_hold_state():
		_hold_turn_position()

	_try_start_work_behavior()


func _should_pause_work_behavior() -> bool:
	return (
		behavior_enabled
		and pause_behavior_during_dialogue
		and GameManager.dialogue_active
	)


func _try_start_work_behavior() -> void:
	if _work_behavior_started or not start_behavior_after_intro:
		return
	if not _intro_sequence_complete:
		return
	if not GameManager.get_flag(start_behavior_flag):
		return
	start_work_behavior()


func start_work_behavior() -> void:
	if _work_behavior_started:
		return
	if pump_1_point == null or pump_1_look_target == null:
		push_warning("GasStationNPC: faltan markers de bomba 1 para la rutina.")
		return
	if pump_2_point == null or pump_2_look_target == null:
		push_warning("GasStationNPC: faltan markers de bomba 2 para la rutina.")
		return

	behavior_enabled = true
	_work_behavior_started = true
	_current_pump_index = 0
	play_routine_idle(BLEND_ROUTINE)
	_begin_pump_cycle()


func start_work_behavior_after_intro() -> void:
	_intro_sequence_complete = true
	_try_start_work_behavior()


func _begin_pump_cycle() -> void:
	var point := _get_pump_point(_current_pump_index)
	if point == null:
		return
	if _is_at_marker(point):
		_arrive_at_marker(point)
	else:
		_set_work_state(WorkState.TURNING_TO_MOVE_DIRECTION)


func _process_work_behavior(delta: float) -> void:
	match _work_state:
		WorkState.IDLE:
			pass
		WorkState.TURNING_TO_MOVE_DIRECTION:
			_process_turning_to_move_direction(delta)
		WorkState.WALKING_TO_POINT:
			_process_walking_to_point(delta)
		WorkState.ARRIVAL_SETTLE:
			_process_arrival_settle(delta)
		WorkState.TURNING_TO_LOOK_TARGET:
			_process_turning_to_look_target(delta)
		WorkState.LOOK_TURN_SETTLE:
			_process_look_turn_settle(delta)
		WorkState.KNEELING_DOWN:
			pass
		WorkState.INSPECTING:
			_process_inspecting(delta)
		WorkState.STANDING_UP:
			pass
		WorkState.WAITING:
			_process_waiting(delta)


func _process_turning_to_move_direction(delta: float) -> void:
	_hold_turn_position()

	var point := _get_pump_point(_current_pump_index)
	if point == null:
		return

	var direction := _horizontal_direction_to(point.global_position)
	if direction.length_squared() < 0.0001:
		_arrive_at_marker(point)
		return

	var target_yaw := atan2(direction.x, direction.z)
	var angle_err := absf(angle_difference(global_rotation.y, target_yaw))
	_play_routine_turn_anim(angle_err)

	if _rotate_yaw_toward(target_yaw, delta, pre_walk_turn_speed, pre_walk_angle_tolerance):
		_set_work_state(WorkState.WALKING_TO_POINT)


func _process_walking_to_point(delta: float) -> void:
	var point := _get_pump_point(_current_pump_index)
	if point == null:
		return

	var to_point := point.global_position - global_position
	to_point.y = 0.0
	var distance := to_point.length()
	if distance <= arrival_distance:
		_arrive_at_marker(point)
		return

	var direction := to_point / distance
	var target_yaw := atan2(direction.x, direction.z)
	var angle_err := absf(angle_difference(global_rotation.y, target_yaw))

	if angle_err > pre_walk_angle_tolerance:
		_halt_horizontal_movement()
		_set_work_state(WorkState.TURNING_TO_MOVE_DIRECTION)
		return

	if angle_err > 0.02:
		global_rotation.y = lerp_angle(
			global_rotation.y,
			target_yaw,
			minf(1.0, walk_correction_turn_speed * delta)
		)

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed


func _process_arrival_settle(delta: float) -> void:
	_halt_horizontal_movement()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_set_work_state(WorkState.TURNING_TO_LOOK_TARGET)


func _process_turning_to_look_target(delta: float) -> void:
	_hold_turn_position()

	var look_target := _get_pump_look_target(_current_pump_index)
	if look_target == null:
		_begin_look_turn_settle()
		return

	var direction := _horizontal_direction_to(look_target.global_position)
	if direction.length_squared() < 0.0001:
		_begin_look_turn_settle()
		return

	var target_yaw := atan2(direction.x, direction.z)
	var angle_err := absf(angle_difference(global_rotation.y, target_yaw))
	_play_routine_turn_anim(angle_err, BLEND_IDLE_WALK)

	if _rotate_yaw_toward(target_yaw, delta, look_target_turn_speed, look_target_angle_tolerance):
		_begin_look_turn_settle()


func _process_look_turn_settle(delta: float) -> void:
	_halt_horizontal_movement()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_set_work_state(WorkState.KNEELING_DOWN)


func _process_inspecting(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_set_work_state(WorkState.STANDING_UP)


func _process_waiting(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_current_pump_index = 1 - _current_pump_index
		_begin_pump_cycle()


func _begin_look_turn_settle() -> void:
	_halt_horizontal_movement()
	play_routine_idle(BLEND_ROUTINE)
	_set_work_state(WorkState.LOOK_TURN_SETTLE)


func _set_work_state(new_state: WorkState) -> void:
	_work_state = new_state
	match new_state:
		WorkState.TURNING_TO_MOVE_DIRECTION, WorkState.TURNING_TO_LOOK_TARGET:
			_begin_turn_in_place()
		WorkState.ARRIVAL_SETTLE:
			_turn_anchor_position = global_position
			_halt_horizontal_movement()
			play_routine_idle(BLEND_ROUTINE)
			_state_timer = arrival_settle_time
		WorkState.LOOK_TURN_SETTLE:
			_halt_horizontal_movement()
			_state_timer = look_turn_settle_time
		WorkState.KNEELING_DOWN:
			play_kneel_down()
		WorkState.INSPECTING:
			play_kneeling_inspecting()
			_state_timer = randf_range(inspect_time_min, inspect_time_max)
		WorkState.STANDING_UP:
			play_standing_up_short()
		WorkState.WAITING:
			play_routine_idle(BLEND_ROUTINE)
			_state_timer = randf_range(wait_after_standing_min, wait_after_standing_max)
		WorkState.WALKING_TO_POINT:
			play_walk_in_place(BLEND_IDLE_WALK)


func _get_pump_point(pump_index: int) -> Marker3D:
	return pump_1_point if pump_index == 0 else pump_2_point


func _get_pump_look_target(pump_index: int) -> Marker3D:
	return pump_1_look_target if pump_index == 0 else pump_2_look_target


func _is_at_marker(marker: Marker3D) -> bool:
	var offset := marker.global_position - global_position
	offset.y = 0.0
	return offset.length() <= arrival_distance


func _halt_horizontal_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _begin_turn_in_place() -> void:
	_turn_anchor_position = global_position
	_halt_horizontal_movement()


func _hold_turn_position() -> void:
	_halt_horizontal_movement()
	global_position.x = _turn_anchor_position.x
	global_position.z = _turn_anchor_position.z


func _is_turn_hold_state() -> bool:
	return _work_state in [
		WorkState.TURNING_TO_MOVE_DIRECTION,
		WorkState.TURNING_TO_LOOK_TARGET,
	]


func _horizontal_direction_to(target_position: Vector3) -> Vector3:
	var direction := target_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Vector3.ZERO
	return direction.normalized()


func _rotate_yaw_toward(
	target_yaw: float,
	delta: float,
	turn_speed: float,
	angle_tolerance: float
) -> bool:
	global_rotation.y = lerp_angle(global_rotation.y, target_yaw, minf(1.0, turn_speed * delta))
	if absf(angle_difference(global_rotation.y, target_yaw)) <= angle_tolerance:
		global_rotation.y = target_yaw
		return true
	return false


func _arrive_at_marker(marker: Marker3D) -> void:
	_halt_horizontal_movement()
	_snap_to_marker_on_arrival(marker)
	_turn_anchor_position = global_position
	play_routine_idle(BLEND_ROUTINE)
	_set_work_state(WorkState.ARRIVAL_SETTLE)


func _snap_to_marker_on_arrival(marker: Marker3D) -> void:
	if not snap_to_marker_on_arrival or marker == null:
		return
	var offset := marker.global_position - global_position
	offset.y = 0.0
	if offset.length() > max_snap_distance:
		return
	global_position.x = marker.global_position.x
	global_position.z = marker.global_position.z


func _play_routine_turn_anim(abs_angle: float, blend: float = BLEND_TURN_IN_PLACE) -> void:
	if use_walking_in_place_while_turning and abs_angle >= deg_to_rad(turn_walk_angle_threshold_deg):
		play_walk_in_place(blend)
	else:
		play_routine_idle(blend)


func _resolve_walk_in_place_anim() -> StringName:
	if _has_animation(WALK_IN_PLACE_ANIM):
		return WALK_IN_PLACE_ANIM
	if _has_animation(WALK_ANIM):
		push_warning(
			"GasStationNPC: 'walking_in_place' no disponible; usando 'walking' como fallback."
		)
		return WALK_ANIM
	return &""


func _get_walk_playback_speed() -> float:
	if not use_slow_walking or walking_target_duration <= 0.0:
		return 1.0
	var animation_player := _get_animation_player()
	if animation_player == null:
		return 1.0
	var anim_name := _resolve_walk_in_place_anim()
	if anim_name == &"" or not animation_player.has_animation(anim_name):
		return 1.0
	var anim := animation_player.get_animation(anim_name)
	if anim == null:
		return 1.0
	return anim.length / walking_target_duration


func _rotate_toward_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(direction.x, direction.z)
	global_rotation.y = lerp_angle(global_rotation.y, target_yaw, minf(1.0, rotation_speed * delta))


func _connect_animation_player() -> void:
	var animation_player := _get_animation_player()
	if animation_player == null:
		return
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)


func _on_animation_finished(anim_name: StringName) -> void:
	if not behavior_enabled or _should_pause_work_behavior():
		return
	match _work_state:
		WorkState.KNEELING_DOWN:
			if anim_name == &"kneeling_down":
				_set_work_state(WorkState.INSPECTING)
		WorkState.STANDING_UP:
			if anim_name == &"standing_up_short" or anim_name == &"standing_up":
				play_routine_idle(BLEND_ROUTINE)
				_set_work_state(WorkState.WAITING)


func _get_animation_player() -> AnimationPlayer:
	var model := get_node_or_null("Model")
	if model == null:
		return null
	return _find_animation_player(model)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _play_anim(anim_name: StringName, blend: float = 0.2, speed: float = 1.0) -> void:
	var animation_player := _get_animation_player()
	if animation_player == null:
		return
	if not animation_player.has_animation(anim_name):
		return
	if animation_player.current_animation == anim_name:
		return
	animation_player.play(anim_name, blend, speed)


func _play_anim_if_not(anim_name: StringName, blend: float = 0.2, speed: float = 1.0) -> void:
	var animation_player := _get_animation_player()
	if animation_player == null:
		return
	if not animation_player.has_animation(anim_name):
		return
	if (
		animation_player.is_playing()
		and animation_player.current_animation == anim_name
		and is_equal_approx(animation_player.speed_scale, speed)
	):
		return
	_play_anim(anim_name, blend, speed)


func _has_animation(anim_name: StringName) -> bool:
	var animation_player := _get_animation_player()
	return animation_player != null and animation_player.has_animation(anim_name)


func _uses_old_man_style() -> bool:
	return not _work_behavior_started


func play_routine_idle(blend: float = BLEND_ROUTINE) -> void:
	if not _work_behavior_started:
		return
	if _has_animation(&"male_standing_pose"):
		_play_anim_if_not(&"male_standing_pose", blend)
		return
	push_warning(
		"GasStationNPC: 'male_standing_pose' no disponible; usando fallback de idle."
	)
	if _has_animation(&"old_man_idle"):
		_play_anim_if_not(&"old_man_idle", blend)


func play_walk_in_place(blend: float = BLEND_IDLE_WALK) -> void:
	var anim_name := _resolve_walk_in_place_anim()
	if anim_name == &"":
		push_warning("GasStationNPC: no hay animación de caminar para la rutina.")
		play_routine_idle(blend)
		return
	_play_anim_if_not(anim_name, blend, _get_walk_playback_speed())


func play_kneel_down() -> void:
	_play_anim(&"kneeling_down", BLEND_KNEEL_DOWN)


func play_kneeling_inspecting() -> void:
	_play_anim_if_not(&"kneeling_inspecting", BLEND_KNEEL_INSPECT)


func play_standing_up_short() -> void:
	if _has_animation(&"standing_up_short"):
		_play_anim(&"standing_up_short", BLEND_STAND_UP)
		return
	if _has_animation(&"standing_up"):
		push_warning(
			"GasStationNPC: 'standing_up_short' no disponible; usando 'standing_up'."
		)
		_play_anim(&"standing_up", BLEND_STAND_UP)
		return
	push_warning("GasStationNPC: no hay animación de levantarse disponible.")


func play_idle() -> void:
	if not _uses_old_man_style():
		return
	_play_anim_if_not(&"old_man_idle", BLEND_OLD_MAN_TURN)


func play_start_walking() -> void:
	if _uses_old_man_style():
		play_old_man_walk()
	else:
		play_walk_in_place()


func play_walking() -> void:
	if _uses_old_man_style():
		play_old_man_walk()
	else:
		play_walk_in_place()


func play_old_man_walk() -> void:
	if _has_animation(&"old_man_walk"):
		_play_anim_if_not(&"old_man_walk", BLEND_IDLE_WALK)
	else:
		play_idle()


func play_talking() -> void:
	_play_anim(&"talking", BLEND_ROUTINE)


func play_look_around() -> void:
	play_idle()


func prepare_dialogue_interaction(interactor: Node3D) -> void:
	if interactor == null or _dialogue_turn_active:
		return

	var intro_done := GameManager.get_flag(start_behavior_flag)
	if intro_done and not turn_on_repeat_dialogue:
		return

	if intro_done and turn_on_repeat_dialogue:
		var repeat_limit := max_dialogue_turn_time * repeat_dialogue_turn_time_scale
		await _turn_smoothly_to_player(interactor, repeat_limit, dialogue_turn_speed)
		return

	_pre_dialogue_yaw = global_rotation.y
	_has_saved_pre_dialogue_yaw = true
	_waiting_intro_dialogue_to_finish = true

	await _turn_smoothly_to_player(interactor, max_dialogue_turn_time, dialogue_turn_speed)
	play_idle()


func _on_dialogue_finished() -> void:
	if not _waiting_intro_dialogue_to_finish:
		return

	_waiting_intro_dialogue_to_finish = false

	if return_to_original_rotation_after_intro:
		await _return_to_pre_dialogue_rotation()

	_has_saved_pre_dialogue_yaw = false
	start_work_behavior_after_intro()


func _play_turn_animation(angle: float) -> void:
	var abs_angle := absf(angle)
	if abs_angle < deg_to_rad(turn_walk_angle_threshold_deg):
		play_idle()
		_turn_visual_active = false
	elif _uses_old_man_style() and _has_animation(&"old_man_walk"):
		_play_anim_if_not(&"old_man_walk", BLEND_IDLE_WALK)
		_turn_visual_active = true
	elif _resolve_walk_in_place_anim() != &"":
		_play_anim_if_not(_resolve_walk_in_place_anim(), BLEND_TURN_IN_PLACE, 1.0)
		_turn_visual_active = true
	else:
		play_idle()
		_turn_visual_active = false


func _turn_smoothly_to_player(player: Node3D, time_limit: float, turn_speed: float) -> void:
	if player == null:
		return
	var direction := player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(direction.x, direction.z)
	await _turn_smoothly_to_yaw(target_yaw, time_limit, turn_speed, player)


func _return_to_pre_dialogue_rotation() -> void:
	if not _has_saved_pre_dialogue_yaw:
		return
	await _turn_smoothly_to_yaw(_pre_dialogue_yaw, max_return_turn_time, return_turn_speed)
	play_idle()


func _turn_smoothly_to_yaw(
	target_yaw: float,
	time_limit: float,
	turn_speed: float,
	player: Node3D = null
) -> void:
	var start_yaw := global_rotation.y
	var angle := angle_difference(start_yaw, target_yaw)
	if absf(angle) <= dialogue_turn_angle_tolerance:
		return

	_dialogue_turn_active = true
	_play_turn_animation(angle)

	var locked_input := false
	if player != null and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
		locked_input = true

	var elapsed := 0.0
	while elapsed < time_limit:
		var delta := get_physics_process_delta_time()
		elapsed += delta
		global_rotation.y = lerp_angle(global_rotation.y, target_yaw, minf(1.0, turn_speed * delta))
		if absf(angle_difference(global_rotation.y, target_yaw)) <= dialogue_turn_angle_tolerance:
			break
		await get_tree().physics_frame

	global_rotation.y = target_yaw
	_turn_visual_active = false
	play_idle()

	if locked_input and is_instance_valid(player) and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)
	_dialogue_turn_active = false
