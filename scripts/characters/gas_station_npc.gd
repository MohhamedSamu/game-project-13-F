class_name GasStationNPC
extends CharacterBody3D
## NPC de la gasolinera: física, animaciones y rutina entre bombas.

enum WorkState {
	IDLE,
	WALKING_TO_POINT,
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
@export var move_speed: float = 0.9
@export var rotation_speed: float = 2.5
@export var arrival_distance: float = 0.20
@export var wait_after_standing_min: float = 0.8
@export var wait_after_standing_max: float = 1.5
@export var pause_behavior_during_dialogue: bool = true
@export var intro_first_kneel_pause: float = 1.0
@export var intro_first_kneel_down_start_time: float = 1.5

@export_group("Movement Turn")
@export var pre_walk_turn_speed: float = 2.4
@export var pre_walk_angle_tolerance: float = 0.06
@export var walk_correction_turn_speed: float = 2.0
@export var use_walking_in_place_while_turning: bool = true

@export_group("Arrival")
@export var snap_to_marker_on_arrival: bool = true
@export var max_snap_distance: float = 0.30
@export var arrival_momentum_bleed: float = 0.08
@export var arrival_turn_decel_rate: float = 7.0
@export var arrival_look_blend_distance: float = 1.2
@export var arrival_turn_walk_phase: float = 0.7
@export var arrival_turn_idle_start: float = 0.9
@export var arrival_turn_speed_ramp: float = 0.35

@export_group("Look Target Turn")
@export var look_target_turn_speed: float = 2.3
@export var look_target_angle_tolerance: float = 0.06
@export var look_turn_settle_time: float = 0.20

@export_group("Dialogue Turn")
@export var dialogue_turn_speed: float = 2.2
@export var dialogue_turn_angle_tolerance: float = 0.035
@export var max_dialogue_turn_time: float = 1.6
@export var turn_on_repeat_dialogue: bool = true
@export var repeat_dialogue_turn_time_scale: float = 1.0
@export var repeat_camera_focus_on_stand_up: bool = true
@export var return_to_original_rotation_after_intro: bool = true
@export var return_turn_speed: float = 2.0
@export var max_return_turn_time: float = 1.6

@export_group("Animation")
@export var walking_target_duration: float = 4.15
@export var use_slow_walking: bool = true
@export var turn_walk_angle_threshold_deg: float = 25.0
@export var kneeling_inspect_playback_speed: float = 0.72
@export var stand_up_playback_speed: float = 0.7

@export_group("Dialogue Focus")
@export var dialogue_focus_height_standing: float = 1.72
@export var dialogue_focus_height_kneeling: float = 0.95
@export var dialogue_focus_height_lerp_speed: float = 8.0

const BLEND_IDLE_WALK := 0.25
const BLEND_TURN_IN_PLACE := 0.20
const BLEND_KNEEL_DOWN := 0.30
const BLEND_INTRO_FIRST_KNEEL_DOWN := 0.50
const BLEND_KNEEL_INSPECT := 0.50
const BLEND_STAND_UP := 0.50
const BLEND_ROUTINE := 0.20
const BLEND_OLD_MAN_TURN := 0.6

const POST_STANDING_GESTURES: Array[StringName] = [
	&"head_nod_yes",
	&"pointing_forward",
	&"searching_pockets",
]

const WALK_IN_PLACE_ANIM := &"walking_in_place"
const WALK_ANIM := &"walking"
const ROUTINE_IDLE_ANIM := &"idle"
const KNEEL_INTERRUPT_BEAT_ID := "kneel_interrupt"
const KNEEL_INTERRUPT_TITLE := "kneel_interrupt"

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
var _gesture_anim: StringName = &""
var _pending_intro_first_kneel_entry: bool = false
var _intro_first_kneel_pause_active: bool = false
var _use_intro_first_kneel_start_time: bool = false
var _arrival_turn_start_angle: float = 0.0
var _dialogue_prep_active: bool = false
var _dialogue_focus_point: Marker3D
var _focus_height_tween: Tween
var _use_camera_focus_for_dialogue: bool = false
var _pending_resume_after_repeat_dialogue: bool = false
var _resume_was_inspecting: bool = false
var _resume_was_walking: bool = false
var _resume_pump_index: int = 0
var _resume_look_yaw: float = 0.0
var _routine_resume_active: bool = false
var _pending_kneel_interrupt_dialogue: bool = false
var _scripted_sequence_active: bool = false


func _ready() -> void:
	_dialogue_focus_point = get_node_or_null("DialogueFocusPoint") as Marker3D
	await _wait_for_character_animations()
	play_idle()
	_connect_animation_player()
	if not DialogueController.dialogue_finished.is_connected(_on_dialogue_finished):
		DialogueController.dialogue_finished.connect(_on_dialogue_finished)
	if not DialogueController.dialogue_finished.is_connected(_on_any_dialogue_finished_recover):
		DialogueController.dialogue_finished.connect(_on_any_dialogue_finished_recover)


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
	if _scripted_sequence_active:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if _routine_resume_active:
		_halt_horizontal_movement()
		move_and_slide()
		return

	if _should_pause_work_behavior():
		_halt_horizontal_movement()
		move_and_slide()
		_update_dialogue_focus_height(delta)
		if _dialogue_prep_active:
			_recover_dialogue_prep_animation()
		_try_start_work_behavior()
		return

	if behavior_enabled:
		_process_work_behavior(delta)
		_recover_animation_driven_state()
	elif is_on_floor():
		_halt_horizontal_movement()

	move_and_slide()
	_update_dialogue_focus_height(delta)

	_try_start_work_behavior()


func _should_pause_work_behavior() -> bool:
	if not behavior_enabled or not pause_behavior_during_dialogue:
		return false
	if _dialogue_prep_active or _dialogue_turn_active or GameManager.interaction_prep_active:
		return true
	if not GameManager.dialogue_active:
		return false
	return _is_dialogue_with_self()


func _is_dialogue_with_self() -> bool:
	var focus := DialogueController.current_focus_target
	if focus == null:
		return false
	if focus == self:
		return true
	return is_ancestor_of(focus) or focus.is_ancestor_of(self)


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
	if _pending_intro_first_kneel_entry:
		_pending_intro_first_kneel_entry = false
		_begin_intro_first_kneel_entry()
	else:
		play_routine_idle(BLEND_ROUTINE)
		_begin_pump_cycle()


func _begin_intro_first_kneel_entry() -> void:
	_halt_horizontal_movement()
	_intro_first_kneel_pause_active = true
	_work_state = WorkState.IDLE
	_state_timer = intro_first_kneel_pause


func start_work_behavior_after_intro() -> void:
	_intro_sequence_complete = true
	_try_start_work_behavior()


func resume_inspect_at_pump(pump_index: int = 0) -> void:
	behavior_enabled = true
	_work_behavior_started = true
	_intro_sequence_complete = true
	_current_pump_index = pump_index
	_halt_horizontal_movement()
	var point := _get_pump_point(pump_index)
	if point == null:
		return
	_arrive_at_marker(point)


func pause_for_jumpscare() -> void:
	_halt_horizontal_movement()
	behavior_enabled = false
	_dialogue_prep_active = false
	_dialogue_turn_active = false


func begin_scripted_sequence() -> void:
	_scripted_sequence_active = true
	_pending_resume_after_repeat_dialogue = false
	_routine_resume_active = false
	_pending_kneel_interrupt_dialogue = false
	_dialogue_prep_active = false
	_dialogue_turn_active = false
	_use_camera_focus_for_dialogue = false
	pause_for_jumpscare()
	velocity = Vector3.ZERO
	set_physics_process(false)
	_set_npc_interactions_enabled(false)
	visible = true
	_ensure_model_visible()


func prepare_for_bathroom_exit_jumpscare() -> void:
	begin_scripted_sequence()
	_gesture_anim = &""
	_work_state = WorkState.WAITING
	_state_timer = 0.0
	_set_dialogue_focus_height(dialogue_focus_height_standing, true)
	_force_standing_pose_for_scripted()


func restore_after_scene4_dev_reset() -> void:
	_scripted_sequence_active = false
	behavior_enabled = _work_behavior_started
	force_render_visible()
	set_physics_process(true)
	_set_npc_collision_enabled(true)
	_set_npc_interactions_enabled(true)
	_force_standing_pose_for_scripted()


func _ensure_model_visible() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model != null:
		model.visible = true


func force_render_visible() -> void:
	visible = true
	_ensure_model_visible()
	_set_visual_instances_visible(self, true)


func _set_visual_instances_visible(node: Node, should_show: bool) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = should_show
	for child in node.get_children():
		_set_visual_instances_visible(child, should_show)


func move_to_global_pose(world_position: Vector3, world_rotation: Vector3) -> void:
	global_position = world_position
	global_rotation = world_rotation
	velocity = Vector3.ZERO
	force_render_visible()


func _force_standing_pose_for_scripted() -> void:
	for anim_name in [&"male_standing_pose", ROUTINE_IDLE_ANIM, &"idle", &"old_man_idle"]:
		if _has_animation(anim_name):
			_play_anim(anim_name, 0.0)
			return


func finish_scripted_exit() -> void:
	_scripted_sequence_active = true
	behavior_enabled = false
	velocity = Vector3.ZERO
	set_physics_process(false)
	_set_npc_interactions_enabled(false)
	_set_npc_collision_enabled(false)
	visible = false


func is_scripted_sequence_active() -> bool:
	return _scripted_sequence_active


func get_animation_player() -> AnimationPlayer:
	return _get_animation_player()


func play_animation(animation_name: String) -> void:
	var animation_player := _get_animation_player()
	if animation_player == null:
		return
	var anim_name := StringName(animation_name)
	if anim_name == WALK_ANIM and _has_animation(WALK_IN_PLACE_ANIM):
		anim_name = WALK_IN_PLACE_ANIM
	if not animation_player.has_animation(anim_name):
		push_warning("GasStationNPC: animación '%s' no encontrada." % String(anim_name))
		return
	_play_anim(anim_name, 0.15)


func _set_npc_interactions_enabled(enabled: bool) -> void:
	var interact := get_node_or_null("InteractableDialogueComponent") as InteractableDialogueComponent
	if interact != null:
		interact.enabled = enabled
		interact.monitoring = enabled
	var proximity := get_node_or_null("ProximityDialogueComponent") as ProximityDialogueComponent
	if proximity != null:
		proximity.enabled = enabled
		proximity.monitoring = enabled


func _set_npc_collision_enabled(enabled: bool) -> void:
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = not enabled


func _begin_pump_cycle() -> void:
	var point := _get_pump_point(_current_pump_index)
	if point == null:
		return
	if _is_at_marker(point):
		_arrive_at_marker(point)
	else:
		_set_work_state(WorkState.WALKING_TO_POINT)


func _process_work_behavior(delta: float) -> void:
	match _work_state:
		WorkState.IDLE:
			if _intro_first_kneel_pause_active:
				_process_intro_first_kneel_pause(delta)
		WorkState.WALKING_TO_POINT:
			_process_walking_to_point(delta)
		WorkState.TURNING_TO_LOOK_TARGET:
			_process_turning_to_look_target(delta)
		WorkState.LOOK_TURN_SETTLE:
			_process_look_turn_settle(delta)
		WorkState.KNEELING_DOWN:
			pass
		WorkState.INSPECTING:
			pass
		WorkState.STANDING_UP:
			pass
		WorkState.WAITING:
			_process_waiting(delta)


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
	var walk_yaw := atan2(direction.x, direction.z)
	var target_yaw := walk_yaw
	var move_scale := 1.0

	var look_target := _get_pump_look_target(_current_pump_index)
	if look_target != null and distance <= arrival_look_blend_distance:
		var look_direction := _horizontal_direction_to(look_target.global_position)
		if look_direction.length_squared() > 0.0001:
			var look_yaw := atan2(look_direction.x, look_direction.z)
			var blend_t := 1.0 - clampf(distance / arrival_look_blend_distance, 0.0, 1.0)
			target_yaw = lerp_angle(walk_yaw, look_yaw, blend_t)
			move_scale = lerpf(1.0, 0.45, blend_t)

	var angle_err := absf(angle_difference(global_rotation.y, target_yaw))
	var turn_speed := (
		walk_correction_turn_speed
		if angle_err <= pre_walk_angle_tolerance
		else pre_walk_turn_speed
	)

	global_rotation.y = lerp_angle(
		global_rotation.y,
		target_yaw,
		minf(1.0, turn_speed * delta)
	)

	if angle_err <= pre_walk_angle_tolerance:
		play_walk_in_place(BLEND_IDLE_WALK)
		velocity.x = direction.x * move_speed * move_scale
		velocity.z = direction.z * move_speed * move_scale
	else:
		_play_routine_turn_anim(angle_err, BLEND_IDLE_WALK)
		var turn_move_scale := clampf(1.0 - (angle_err / deg_to_rad(90.0)), 0.2, 1.0)
		velocity.x = direction.x * move_speed * move_scale * turn_move_scale
		velocity.z = direction.z * move_speed * move_scale * turn_move_scale


func _process_intro_first_kneel_pause(delta: float) -> void:
	_halt_horizontal_movement()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_intro_first_kneel_pause_active = false
		_use_intro_first_kneel_start_time = true
		_set_work_state(WorkState.KNEELING_DOWN)


func _process_turning_to_look_target(delta: float) -> void:
	var look_target := _get_pump_look_target(_current_pump_index)
	if look_target == null:
		_halt_horizontal_movement()
		_begin_look_turn_settle()
		return

	var direction := _horizontal_direction_to(look_target.global_position)
	if direction.length_squared() < 0.0001:
		_halt_horizontal_movement()
		_begin_look_turn_settle()
		return

	var target_yaw := atan2(direction.x, direction.z)
	var angle_err := absf(angle_difference(global_rotation.y, target_yaw))
	var turn_progress := _get_arrival_turn_progress(angle_err)
	var turn_ease := lerpf(0.45, 1.0, clampf(turn_progress / arrival_turn_speed_ramp, 0.0, 1.0))

	global_rotation.y = lerp_angle(
		global_rotation.y,
		target_yaw,
		minf(1.0, look_target_turn_speed * turn_ease * delta)
	)

	if angle_err <= look_target_angle_tolerance:
		global_rotation.y = target_yaw
		_halt_horizontal_movement()
		_begin_look_turn_settle()
		return

	_play_arrival_turn_visual(angle_err)

	var decel := move_speed * arrival_turn_decel_rate * delta
	velocity.x = move_toward(velocity.x, 0.0, decel)
	velocity.z = move_toward(velocity.z, 0.0, decel)


func _process_look_turn_settle(delta: float) -> void:
	_halt_horizontal_movement()
	if _gesture_anim in POST_STANDING_GESTURES:
		return
	_state_timer -= delta
	if _state_timer <= 0.0:
		_set_work_state(WorkState.KNEELING_DOWN)


func _process_waiting(delta: float) -> void:
	if _gesture_anim in POST_STANDING_GESTURES:
		return
	_state_timer -= delta
	if _state_timer <= 0.0:
		_continue_after_waiting()


func _begin_look_turn_settle() -> void:
	_halt_horizontal_movement()
	_gesture_anim = _play_random_post_standing_gesture(BLEND_ROUTINE)
	_set_work_state(WorkState.LOOK_TURN_SETTLE)


func _set_work_state(new_state: WorkState) -> void:
	_work_state = new_state
	match new_state:
		WorkState.LOOK_TURN_SETTLE:
			_halt_horizontal_movement()
			if not _gesture_anim in POST_STANDING_GESTURES:
				_state_timer = look_turn_settle_time
		WorkState.KNEELING_DOWN:
			play_kneel_down()
		WorkState.INSPECTING:
			play_kneeling_inspecting()
		WorkState.STANDING_UP:
			play_standing_up_short()
		WorkState.WAITING:
			_gesture_anim = _play_random_post_standing_gesture(BLEND_ROUTINE)
			if not _gesture_anim in POST_STANDING_GESTURES:
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
	_snap_to_marker_on_arrival(marker)
	velocity.x *= arrival_momentum_bleed
	velocity.z *= arrival_momentum_bleed
	_cache_arrival_turn_start_angle()
	_set_work_state(WorkState.TURNING_TO_LOOK_TARGET)


func _cache_arrival_turn_start_angle() -> void:
	var look_target := _get_pump_look_target(_current_pump_index)
	if look_target == null:
		_arrival_turn_start_angle = deg_to_rad(45.0)
		return
	var direction := _horizontal_direction_to(look_target.global_position)
	if direction.length_squared() < 0.0001:
		_arrival_turn_start_angle = deg_to_rad(45.0)
		return
	var target_yaw := atan2(direction.x, direction.z)
	_arrival_turn_start_angle = maxf(
		absf(angle_difference(global_rotation.y, target_yaw)),
		deg_to_rad(5.0)
	)


func _get_arrival_turn_progress(angle_err: float) -> float:
	return 1.0 - clampf(angle_err / _arrival_turn_start_angle, 0.0, 1.0)


func _play_arrival_turn_visual(angle_err: float) -> void:
	var progress := _get_arrival_turn_progress(angle_err)
	if progress >= arrival_turn_idle_start:
		play_routine_idle(BLEND_ROUTINE)
		return
	var speed_mult := 1.0
	if progress >= arrival_turn_walk_phase:
		var fade_range := maxf(arrival_turn_idle_start - arrival_turn_walk_phase, 0.001)
		var fade := (progress - arrival_turn_walk_phase) / fade_range
		speed_mult = lerpf(1.0, 0.15, fade)
	play_walk_in_place(BLEND_IDLE_WALK, speed_mult)


func _snap_to_marker_on_arrival(marker: Marker3D) -> void:
	if not snap_to_marker_on_arrival or marker == null:
		return
	var offset := marker.global_position - global_position
	offset.y = 0.0
	if offset.length() > max_snap_distance:
		return
	global_position.x = marker.global_position.x
	global_position.z = marker.global_position.z


func _play_routine_turn_anim(_abs_angle: float, blend: float = BLEND_TURN_IN_PLACE) -> void:
	if use_walking_in_place_while_turning and _resolve_walk_in_place_anim() != &"":
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
	if not behavior_enabled:
		return
	if _dialogue_prep_active:
		_advance_dialogue_prep_animation(anim_name)
		return
	if _dialogue_turn_active or GameManager.interaction_prep_active:
		return
	if _should_pause_work_behavior():
		return
	_advance_work_state_after_animation(anim_name)


func _advance_dialogue_prep_animation(anim_name: StringName) -> void:
	match _work_state:
		WorkState.KNEELING_DOWN:
			if anim_name == &"kneeling_down":
				_force_dialogue_prep_kneel_inspecting()
		WorkState.STANDING_UP:
			if anim_name in [&"standing_up_short", &"standing_up"]:
				_finish_dialogue_prep_stand_up()


func _force_dialogue_prep_kneel_inspecting() -> void:
	_gesture_anim = &""
	_state_timer = 0.0
	_work_state = WorkState.INSPECTING
	play_kneeling_inspecting()


func _finish_dialogue_prep_stand_up() -> void:
	_gesture_anim = &""
	_state_timer = 0.0
	_work_state = WorkState.WAITING
	if _work_behavior_started:
		play_routine_idle(BLEND_ROUTINE)
	else:
		play_idle()


func _on_any_dialogue_finished_recover() -> void:
	if _scripted_sequence_active:
		return
	_recover_animation_driven_state()
	if _pending_resume_after_repeat_dialogue and _work_behavior_started:
		_pending_resume_after_repeat_dialogue = false
		_resume_routine_after_repeat_dialogue()


func _advance_work_state_after_animation(anim_name: StringName) -> void:
	match _work_state:
		WorkState.KNEELING_DOWN:
			if anim_name == &"kneeling_down":
				_set_work_state(WorkState.INSPECTING)
		WorkState.INSPECTING:
			if anim_name == &"kneeling_inspecting":
				_set_work_state(WorkState.STANDING_UP)
		WorkState.STANDING_UP:
			if anim_name == &"standing_up_short" or anim_name == &"standing_up":
				_set_work_state(WorkState.WAITING)
		WorkState.WAITING:
			_on_gesture_animation_finished(anim_name)
		WorkState.LOOK_TURN_SETTLE:
			_on_gesture_animation_finished(anim_name)


## Si una animación termina mientras hay diálogo en el mapa, el signal puede perderse
## o el estado quedar congelado. Recupera cuando el AnimationPlayer ya no reproduce.
func _recover_animation_driven_state() -> void:
	if not behavior_enabled:
		return
	if _dialogue_prep_active:
		_recover_dialogue_prep_animation()
		return
	if _dialogue_turn_active or GameManager.interaction_prep_active:
		return
	if _should_pause_work_behavior():
		return
	var animation_player := _get_animation_player()
	if animation_player == null or animation_player.is_playing():
		return

	match _work_state:
		WorkState.KNEELING_DOWN:
			if animation_player.current_animation == &"kneeling_down":
				_advance_work_state_after_animation(&"kneeling_down")
		WorkState.INSPECTING:
			if animation_player.current_animation == &"kneeling_inspecting":
				_advance_work_state_after_animation(&"kneeling_inspecting")
		WorkState.STANDING_UP:
			if animation_player.current_animation in [&"standing_up_short", &"standing_up"]:
				_advance_work_state_after_animation(animation_player.current_animation)
		WorkState.WAITING:
			if _gesture_anim in POST_STANDING_GESTURES:
				_on_gesture_animation_finished(_gesture_anim)
			else:
				_continue_after_waiting()
		WorkState.LOOK_TURN_SETTLE:
			if _gesture_anim in POST_STANDING_GESTURES:
				_on_gesture_animation_finished(_gesture_anim)
			elif _state_timer <= 0.0:
				_set_work_state(WorkState.KNEELING_DOWN)


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
	if _has_animation(ROUTINE_IDLE_ANIM):
		_play_anim_if_not(ROUTINE_IDLE_ANIM, blend)
		return
	push_warning(
		"GasStationNPC: 'idle' no disponible; usando fallback de idle de rutina."
	)
	if _has_animation(&"male_standing_pose"):
		_play_anim_if_not(&"male_standing_pose", blend)
		return
	if _has_animation(&"old_man_idle"):
		_play_anim_if_not(&"old_man_idle", blend)


func play_walk_in_place(blend: float = BLEND_IDLE_WALK, speed_multiplier: float = 1.0) -> void:
	var anim_name := _resolve_walk_in_place_anim()
	if anim_name == &"":
		push_warning("GasStationNPC: no hay animación de caminar para la rutina.")
		play_routine_idle(blend)
		return
	_play_anim_if_not(anim_name, blend, _get_walk_playback_speed() * speed_multiplier)


func play_kneel_down() -> void:
	var is_intro_first := _use_intro_first_kneel_start_time
	var blend := BLEND_INTRO_FIRST_KNEEL_DOWN if is_intro_first else BLEND_KNEEL_DOWN
	_play_anim(&"kneeling_down", blend)
	if not is_intro_first:
		return
	_use_intro_first_kneel_start_time = false
	var animation_player := _get_animation_player()
	if animation_player == null:
		return
	var kneel_anim := animation_player.get_animation(&"kneeling_down")
	if kneel_anim == null:
		return
	var start_time := clampf(
		intro_first_kneel_down_start_time,
		0.0,
		maxf(0.0, kneel_anim.length - 0.05)
	)
	animation_player.seek(start_time, true)


func play_kneeling_inspecting() -> void:
	var animation_player := _get_animation_player()
	if animation_player != null and animation_player.has_animation(&"kneeling_inspecting"):
		var inspect_anim := animation_player.get_animation(&"kneeling_inspecting")
		if inspect_anim != null:
			inspect_anim.loop_mode = Animation.LOOP_NONE
	_play_anim_if_not(&"kneeling_inspecting", BLEND_KNEEL_INSPECT, kneeling_inspect_playback_speed)


func play_standing_up_short() -> void:
	if _has_animation(&"standing_up_short"):
		_play_anim(&"standing_up_short", BLEND_STAND_UP, stand_up_playback_speed)
		return
	if _has_animation(&"standing_up"):
		push_warning(
			"GasStationNPC: 'standing_up_short' no disponible; usando 'standing_up'."
		)
		_play_anim(&"standing_up", BLEND_STAND_UP, stand_up_playback_speed)
		return
	push_warning("GasStationNPC: no hay animación de levantarse disponible.")


func _continue_after_waiting() -> void:
	if _work_state != WorkState.WAITING:
		return
	_gesture_anim = &""
	_current_pump_index = 1 - _current_pump_index
	_begin_pump_cycle()


func _on_gesture_animation_finished(anim_name: StringName) -> void:
	if anim_name != _gesture_anim or not _gesture_anim in POST_STANDING_GESTURES:
		return
	match _work_state:
		WorkState.WAITING:
			_continue_after_waiting()
		WorkState.LOOK_TURN_SETTLE:
			_gesture_anim = &""
			_set_work_state(WorkState.KNEELING_DOWN)


func _play_random_post_standing_gesture(blend: float = BLEND_ROUTINE) -> StringName:
	var available: Array[StringName] = []
	for anim_name in POST_STANDING_GESTURES:
		if _has_animation(anim_name):
			available.append(anim_name)
	if available.is_empty():
		push_warning(
			"GasStationNPC: no hay gestos post-levantarse; usando idle de rutina."
		)
		play_routine_idle(blend)
		if _has_animation(ROUTINE_IDLE_ANIM):
			return ROUTINE_IDLE_ANIM
		if _has_animation(&"male_standing_pose"):
			return &"male_standing_pose"
		return &""
	var chosen := available[randi() % available.size()]
	_force_animation_no_loop(chosen)
	_play_anim(chosen, blend)
	return chosen


func _force_animation_no_loop(anim_name: StringName) -> void:
	var animation_player := _get_animation_player()
	if animation_player == null or not animation_player.has_animation(anim_name):
		return
	var anim := animation_player.get_animation(anim_name)
	if anim != null:
		anim.loop_mode = Animation.LOOP_NONE


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
		_play_anim_if_not(&"old_man_walk", BLEND_OLD_MAN_TURN)
	else:
		play_idle()


func play_talking() -> void:
	_play_anim(&"talking", BLEND_ROUTINE)


func play_look_around() -> void:
	play_idle()


func should_use_dialogue_camera_focus() -> bool:
	return _use_camera_focus_for_dialogue


func cancel_dialogue_prep() -> void:
	var should_resume := _pending_resume_after_repeat_dialogue
	_dialogue_prep_active = false
	_use_camera_focus_for_dialogue = false
	_pending_resume_after_repeat_dialogue = false
	_pending_kneel_interrupt_dialogue = false
	if GameManager.interaction_prep_active and not GameManager.dialogue_active:
		GameManager.unlock_player_interaction_prep()
	var player := GameManager.get_player()
	if player != null and player.has_method("clear_camera_focus"):
		player.clear_camera_focus()
	if should_resume and _work_behavior_started and not GameManager.dialogue_active:
		_resume_routine_after_repeat_dialogue()


func should_play_kneel_interrupt_dialogue() -> bool:
	if _scripted_sequence_active:
		return false
	if not _work_behavior_started or not GameManager.get_flag(start_behavior_flag):
		return false
	if GameManager.was_dialogue_beat_played("gas_station_npc", KNEEL_INTERRUPT_BEAT_ID):
		return false
	return _is_kneeling_focus_state()


func consume_dialogue_interaction_override() -> Dictionary:
	if _scripted_sequence_active:
		return {}
	if not _pending_kneel_interrupt_dialogue:
		return {}
	_pending_kneel_interrupt_dialogue = false
	return {
		"title": KNEEL_INTERRUPT_TITLE,
		"beat_id": KNEEL_INTERRUPT_BEAT_ID,
	}


func _uses_repeat_dialogue_prep() -> bool:
	return turn_on_repeat_dialogue and (
		_work_behavior_started
		or GameManager.get_flag(start_behavior_flag)
	)


func prepare_dialogue_interaction(interactor: Node3D) -> void:
	if _scripted_sequence_active:
		return
	if interactor == null or _dialogue_turn_active or _dialogue_prep_active:
		return

	if _uses_repeat_dialogue_prep():
		if should_play_kneel_interrupt_dialogue():
			await _prepare_kneel_interrupt_dialogue(interactor)
			return
		await _prepare_repeat_dialogue(interactor)
		return

	if GameManager.get_flag(start_behavior_flag):
		return

	_pre_dialogue_yaw = global_rotation.y
	_has_saved_pre_dialogue_yaw = true
	_waiting_intro_dialogue_to_finish = true

	await _turn_smoothly_to_player(interactor, max_dialogue_turn_time, dialogue_turn_speed)
	play_idle()


func _prepare_repeat_dialogue(interactor: Node3D) -> void:
	_dialogue_prep_active = true
	_use_camera_focus_for_dialogue = false
	_halt_horizontal_movement()
	GameManager.lock_player_interaction_prep()

	await _wait_for_posture_transition_to_finish()
	if _work_state == WorkState.KNEELING_DOWN:
		await _wait_for_dialogue_prep_posture(WorkState.INSPECTING, 6.0)

	_cache_routine_snapshot_for_resume()
	_pending_resume_after_repeat_dialogue = true

	var needs_stand_up := _is_kneeling_focus_state()
	_use_camera_focus_for_dialogue = needs_stand_up and repeat_camera_focus_on_stand_up

	await _stand_up_for_dialogue_if_needed(interactor, needs_stand_up)
	_interrupt_routine_for_dialogue()

	_set_dialogue_focus_height(dialogue_focus_height_standing, true)

	var turn_limit := max_dialogue_turn_time * repeat_dialogue_turn_time_scale
	await _turn_smoothly_to_player(interactor, turn_limit, dialogue_turn_speed)
	play_routine_idle(BLEND_ROUTINE)

	_dialogue_prep_active = false


func _prepare_kneel_interrupt_dialogue(_interactor: Node3D) -> void:
	_dialogue_prep_active = true
	_use_camera_focus_for_dialogue = false
	_halt_horizontal_movement()

	if _work_state == WorkState.KNEELING_DOWN:
		await _wait_for_dialogue_prep_posture(WorkState.INSPECTING, 6.0)

	_set_dialogue_focus_height(dialogue_focus_height_kneeling, true)
	play_kneeling_inspecting()
	_pending_kneel_interrupt_dialogue = true
	_dialogue_prep_active = false


func _cache_routine_snapshot_for_resume() -> void:
	_resume_pump_index = _current_pump_index
	_resume_was_inspecting = _work_state == WorkState.INSPECTING
	_resume_was_walking = _work_state in [
		WorkState.WALKING_TO_POINT,
		WorkState.TURNING_TO_LOOK_TARGET,
	]
	_resume_look_yaw = _get_pump_look_yaw(_current_pump_index)


func _get_pump_look_yaw(pump_index: int) -> float:
	var look_target := _get_pump_look_target(pump_index)
	if look_target == null:
		return global_rotation.y
	var direction := _horizontal_direction_to(look_target.global_position)
	if direction.length_squared() < 0.0001:
		return global_rotation.y
	return atan2(direction.x, direction.z)


func _get_pump_walk_yaw(pump_index: int) -> float:
	var point := _get_pump_point(pump_index)
	if point == null:
		return global_rotation.y
	var direction := _horizontal_direction_to(point.global_position)
	if direction.length_squared() < 0.0001:
		return global_rotation.y
	return atan2(direction.x, direction.z)


func _resume_routine_after_repeat_dialogue() -> void:
	if not behavior_enabled or not _work_behavior_started:
		return

	_routine_resume_active = true
	_current_pump_index = _resume_pump_index

	if _resume_was_walking:
		await _turn_smoothly_to_yaw(
			_get_pump_walk_yaw(_current_pump_index),
			max_return_turn_time,
			return_turn_speed
		)
		_set_work_state(WorkState.WALKING_TO_POINT)
		_routine_resume_active = false
		return

	await _turn_smoothly_to_yaw(_resume_look_yaw, max_return_turn_time, return_turn_speed)
	_gesture_anim = &""
	_set_work_state(WorkState.KNEELING_DOWN)
	_routine_resume_active = false


func _wait_for_posture_transition_to_finish() -> void:
	while _work_state in [WorkState.KNEELING_DOWN, WorkState.STANDING_UP]:
		await get_tree().physics_frame


func _stand_up_for_dialogue_if_needed(interactor: Node3D, needs_stand_up: bool) -> void:
	if not needs_stand_up:
		return

	if _work_state == WorkState.STANDING_UP:
		await _wait_for_dialogue_prep_posture(WorkState.WAITING, 4.0)
		return

	_set_work_state(WorkState.STANDING_UP)
	_set_dialogue_focus_height(dialogue_focus_height_kneeling, true)

	if (
		repeat_camera_focus_on_stand_up
		and interactor != null
		and interactor.has_method("focus_camera_on")
	):
		interactor.focus_camera_on(_get_dialogue_focus_point())

	var stand_duration := _get_stand_up_duration()
	_begin_tween_dialogue_focus_height(dialogue_focus_height_standing, stand_duration)
	await _wait_for_dialogue_prep_posture(WorkState.WAITING, stand_duration + 0.5)
	await _await_focus_height_tween()


func _wait_for_dialogue_prep_posture(target_state: WorkState, timeout_sec: float) -> void:
	await _wait_for_work_state(target_state, timeout_sec)
	if _work_state == target_state:
		return
	match target_state:
		WorkState.INSPECTING:
			_force_dialogue_prep_kneel_inspecting()
		WorkState.WAITING:
			_finish_dialogue_prep_stand_up()


func _recover_dialogue_prep_animation() -> void:
	var animation_player := _get_animation_player()
	if animation_player == null or animation_player.is_playing():
		return
	match _work_state:
		WorkState.KNEELING_DOWN:
			if animation_player.current_animation == &"kneeling_down":
				_force_dialogue_prep_kneel_inspecting()
		WorkState.STANDING_UP:
			if animation_player.current_animation in [&"standing_up_short", &"standing_up"]:
				_finish_dialogue_prep_stand_up()


func _wait_for_work_state(target_state: WorkState, timeout_sec: float = -1.0) -> void:
	var elapsed := 0.0
	while _work_state != target_state:
		if timeout_sec >= 0.0:
			elapsed += get_physics_process_delta_time()
			if elapsed >= timeout_sec:
				push_warning(
					"GasStationNPC: timeout esperando estado %s (actual %s)."
					% [WorkState.keys()[target_state], WorkState.keys()[_work_state]]
				)
				return
		await get_tree().physics_frame


func _interrupt_routine_for_dialogue() -> void:
	_halt_horizontal_movement()
	match _work_state:
		WorkState.WALKING_TO_POINT, WorkState.TURNING_TO_LOOK_TARGET:
			_gesture_anim = &""
			_work_state = WorkState.WAITING
			_state_timer = 0.0
			play_routine_idle(BLEND_ROUTINE)
		WorkState.INSPECTING, WorkState.KNEELING_DOWN:
			_gesture_anim = &""
			_state_timer = 0.0


func _get_dialogue_focus_point() -> Node3D:
	if _dialogue_focus_point != null:
		return _dialogue_focus_point
	return self


func _is_kneeling_focus_state() -> bool:
	return _work_state in [WorkState.KNEELING_DOWN, WorkState.INSPECTING]


func _get_target_dialogue_focus_height() -> float:
	if not _work_behavior_started:
		return dialogue_focus_height_standing
	if _is_kneeling_focus_state():
		return dialogue_focus_height_kneeling
	return dialogue_focus_height_standing


func _set_dialogue_focus_height(height: float, immediate: bool) -> void:
	if _dialogue_focus_point == null:
		return
	var pos := _dialogue_focus_point.position
	if immediate:
		pos.y = height
		_dialogue_focus_point.position = pos
		return
	_kill_focus_height_tween()
	var tween := create_tween()
	_focus_height_tween = tween
	tween.tween_property(_dialogue_focus_point, "position:y", height, 0.35)


func _tween_dialogue_focus_height(target_height: float, duration: float) -> void:
	_begin_tween_dialogue_focus_height(target_height, duration)
	await _await_focus_height_tween()


func _begin_tween_dialogue_focus_height(target_height: float, duration: float) -> void:
	if _dialogue_focus_point == null:
		return
	_kill_focus_height_tween()
	var tween := create_tween()
	_focus_height_tween = tween
	tween.tween_property(
		_dialogue_focus_point,
		"position:y",
		target_height,
		maxf(duration, 0.05)
	)


func _await_focus_height_tween() -> void:
	if _focus_height_tween == null or not _focus_height_tween.is_valid():
		return
	await _focus_height_tween.finished
	_focus_height_tween = null


func _kill_focus_height_tween() -> void:
	if _focus_height_tween != null and _focus_height_tween.is_valid():
		_focus_height_tween.kill()
	_focus_height_tween = null


func _update_dialogue_focus_height(delta: float) -> void:
	if (
		_dialogue_focus_point == null
		or not _work_behavior_started
		or _dialogue_prep_active
		or GameManager.dialogue_active
	):
		return

	var target_y := _get_target_dialogue_focus_height()
	var pos := _dialogue_focus_point.position
	if is_equal_approx(pos.y, target_y):
		return
	pos.y = lerpf(pos.y, target_y, minf(1.0, dialogue_focus_height_lerp_speed * delta))
	_dialogue_focus_point.position = pos


func _get_stand_up_duration() -> float:
	var animation_player := _get_animation_player()
	if animation_player == null:
		return 1.0
	var anim_name := &"standing_up_short"
	if not animation_player.has_animation(anim_name):
		anim_name = &"standing_up"
	if not animation_player.has_animation(anim_name):
		return 1.0
	var anim := animation_player.get_animation(anim_name)
	if anim == null:
		return 1.0
	return anim.length / maxf(stand_up_playback_speed, 0.01)


func _on_dialogue_finished() -> void:
	if not _waiting_intro_dialogue_to_finish:
		return

	_waiting_intro_dialogue_to_finish = false

	if return_to_original_rotation_after_intro:
		await _return_to_pre_dialogue_rotation()

	_has_saved_pre_dialogue_yaw = false
	call_deferred("_start_work_behavior_after_intro_dialogue")


func _start_work_behavior_after_intro_dialogue() -> void:
	_pending_intro_first_kneel_entry = true
	start_work_behavior_after_intro()


func _play_turn_animation(angle: float) -> void:
	var abs_angle := absf(angle)
	if abs_angle < deg_to_rad(turn_walk_angle_threshold_deg):
		_play_post_turn_idle()
		_turn_visual_active = false
	elif _uses_old_man_style() and _has_animation(&"old_man_walk"):
		_play_anim_if_not(&"old_man_walk", BLEND_OLD_MAN_TURN)
		_turn_visual_active = true
	elif _resolve_walk_in_place_anim() != &"":
		_play_anim_if_not(_resolve_walk_in_place_anim(), BLEND_TURN_IN_PLACE, 1.0)
		_turn_visual_active = true
	else:
		_play_post_turn_idle()
		_turn_visual_active = false


func _play_post_turn_idle() -> void:
	if _work_behavior_started:
		play_routine_idle(BLEND_ROUTINE)
	else:
		play_idle()


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
	_play_post_turn_idle()

	if locked_input and is_instance_valid(player) and player.has_method("set_input_enabled"):
		if (
			not GameManager.interaction_prep_active
			and not GameManager.interaction_prep_committed
			and not GameManager.dialogue_active
		):
			player.set_input_enabled(true)
	_dialogue_turn_active = false
