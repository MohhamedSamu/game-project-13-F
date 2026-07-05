extends Node
## Escena 5 — fase 1: OldLadyGhost en ventana. Fase 2: BloodNpcSupermarket + luces/rojo.

enum Phase2VisualState { CLEAR, DARK, RED }

const STARTED_FLAG := &"supermarket_ghost_reveal_started"
const DONE_FLAG := &"supermarket_ghost_reveal_done"
const PHASE_2_STARTED_FLAG := &"supermarket_phase_2_started"
const PHASE_2_DONE_FLAG := &"supermarket_phase_2_done"

const AFTER_VISION_DIALOGUE := preload("res://dialogues/cashier_after_vision.dialogue")

## Misma técnica que escena 4 del baño: recolorear luces existentes (BathroomSinkHorrorSetup).
const HORROR_LIGHT_COLOR := Color(0.65, 0.03, 0.02, 1.0)
const HORROR_LIGHT_ENERGY := 0.52
const TERROR_PROP_GROUP := &"supermarket_phase2_terror_props"
const COUNTER_ITEMS_GROUP := &"supermarket_counter_items"

@export_group("Referencias")
@export var cashier_npc: Node3D
@export var old_lady_ghost: Node3D
@export var supermarket_lights: Array[Light3D] = []
@export var reveal_dimmed_lights: Array[Light3D] = []
@export var bathroom_lights: Array[Light3D] = []

@export_group("Phase 2 Characters")
@export var blood_cashier: Node3D
@export var phase_2_terror_props: Array[Node3D] = []

@export_group("Trigger")
@export var trigger_flag: String = "ready_for_cashier_jumpscare"
@export var run_once: bool = true

@export_group("Tiempos Fase 1")
@export var pre_blackout_flicker_time: float = 0.38
@export var blackout_time: float = 1.0
@export var lights_return_delay: float = 0.1
@export var ghost_reveal_delay_after_lights: float = 0.08

@export_group("Phase 2 Timing")
@export var phase_2_duration: float = 6.0
@export var phase_2_final_blackout_time: float = 0.30
@export var phase_2_empty_red_hold: float = 0.15

@export_group("Phase 2 Flicker")
@export var phase_2_flicker_count_min: int = 2
@export var phase_2_flicker_count_max: int = 3
@export var phase_2_transition_flicker_time: float = 0.28
@export_range(0.2, 0.8, 0.05) var phase_2_clear_chance: float = 0.52
@export_range(0.15, 0.55, 0.05) var phase_2_clear_duration_min: float = 0.22
@export_range(0.25, 0.9, 0.05) var phase_2_clear_duration_max: float = 0.55
## Super4/Super6 encendidas al 100% en CLEAR (las de arriba de la cajera).
@export_range(0.5, 1.0, 0.05) var phase_2_cashier_spotlight_multiplier: float = 1.0

@export_group("Phase 2 Stretch")
@export var stretch_animation_name: String = "neck_stretching_trim2"

@export_group("Iluminación cajera")
@export_range(0.0, 1.0, 0.05) var reveal_dimmed_light_multiplier: float = 0.0

@export_group("Jugador")
@export var lock_player_movement: bool = true
@export var allow_camera_look: bool = true

@export_group("Audio")
@export var scream_audio: AudioStream = preload("res://assets/audio/SFX/screams/soft1.mp3")
@export_range(-40.0, 6.0, 0.5) var scream_volume_db: float = 0.0
@export var phase_2_transition_sound: AudioStream = preload("res://assets/audio/SFX/screams/soft2.mp3")
@export_range(-40.0, 6.0, 0.5) var phase_2_transition_volume_db: float = 0.0
@export var dip_ambient_during_sequence: bool = false
@export_range(-24.0, 0.0, 0.5) var ambient_dip_db: float = -6.0
@export var ambient_bus_name: StringName = &"Music"

var _running: bool = false
var _phase_2_running: bool = false
var _light_states: Dictionary = {}
var _reveal_dimmed_light_states: Dictionary = {}
var _bathroom_light_states: Dictionary = {}
var _cashier_interact: InteractableDialogueComponent
var _cashier_focus_hitbox: Area3D
var _cashier_saved_states: Dictionary = {}
var _cashier_deactivated: bool = false
var _scream_player: AudioStreamPlayer
var _phase_2_sound_player: AudioStreamPlayer
var _red_overlay_layer: CanvasLayer
var _red_rect: ColorRect
var _saved_can_move: bool = true
var _saved_interaction_enabled: bool = true
var _saved_input_enabled: bool = true
var _used_full_input_lock: bool = false
var _saved_ambient_volume_db: float = 0.0
var _counter_item_state_cache: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(&"supermarket_ghost_reveal_sequence")
	_scream_player = get_node_or_null("ScreamSFX") as AudioStreamPlayer
	_phase_2_sound_player = get_node_or_null("Phase2TransitionSFX") as AudioStreamPlayer
	_red_overlay_layer = get_node_or_null("Phase2RedOverlay") as CanvasLayer
	if _red_overlay_layer != null:
		_red_rect = _red_overlay_layer.get_node_or_null("RedRect") as ColorRect

	if _scream_player != null and scream_audio != null:
		_scream_player.stream = scream_audio
		_scream_player.volume_db = scream_volume_db
		_scream_player.bus = &"SFX"

	if _phase_2_sound_player != null and phase_2_transition_sound != null:
		_phase_2_sound_player.stream = phase_2_transition_sound
		_phase_2_sound_player.volume_db = phase_2_transition_volume_db
		_phase_2_sound_player.bus = &"SFX"

	_set_blood_cashier_active(false)
	_set_red_overlay_active(false)
	call_deferred("_initialize_phase_2_terror_props")

	if old_lady_ghost != null and old_lady_ghost.has_method("hide_ghost"):
		old_lady_ghost.hide_ghost()
	elif old_lady_ghost != null:
		old_lady_ghost.visible = false

	if GameManager.get_flag(PHASE_2_DONE_FLAG):
		call_deferred("_apply_post_sequence_state")
		return

	if GameManager.get_flag(STARTED_FLAG) and not _cashier_deactivated:
		call_deferred("_resolve_cashier_refs")
		call_deferred("_set_cashier_active", false)

	if run_once and GameManager.get_flag(DONE_FLAG):
		return

	call_deferred("_cache_light_states")


func try_start_sequence() -> void:
	if _running:
		return
	if run_once and GameManager.get_flag(DONE_FLAG):
		return
	if GameManager.get_flag(STARTED_FLAG):
		return
	if not trigger_flag.is_empty() and not GameManager.get_flag(trigger_flag):
		return

	_running = true
	GameManager.set_flag(STARTED_FLAG, true)
	_run_sequence()


func _run_sequence() -> void:
	await get_tree().process_frame

	_cache_light_states()
	_resolve_cashier_refs()
	_lock_player()
	_dip_ambient_if_enabled()

	await _flicker_lights_short()
	await get_tree().create_timer(0.06).timeout

	_turn_lights_off()
	_set_cashier_active(false)

	await get_tree().create_timer(blackout_time).timeout

	if lights_return_delay > 0.0:
		await get_tree().create_timer(lights_return_delay).timeout

	_restore_lights(true)
	_apply_reveal_dimmed_lights()

	if ghost_reveal_delay_after_lights > 0.0:
		await get_tree().create_timer(ghost_reveal_delay_after_lights).timeout

	_play_scream()
	var stretch_finished := [false]
	if old_lady_ghost != null and old_lady_ghost.has_signal("stretch_animation_finished"):
		old_lady_ghost.stretch_animation_finished.connect(
			func(_anim_name: StringName) -> void: stretch_finished[0] = true,
			CONNECT_ONE_SHOT
		)
	await _reveal_ghost()
	if not stretch_finished[0]:
		await _wait_for_stretch_animation_finished()

	if not _running:
		_safe_cleanup()
		return

	await start_phase_2()

	if run_once:
		GameManager.set_flag(DONE_FLAG, true)

	_running = false


func start_phase_2() -> void:
	if _phase_2_running:
		return
	if GameManager.get_flag(PHASE_2_STARTED_FLAG):
		return

	_phase_2_running = true
	GameManager.set_flag(PHASE_2_STARTED_FLAG, true)

	await _run_phase_2()

	GameManager.set_flag(PHASE_2_DONE_FLAG, true)
	_phase_2_running = false


func _run_phase_2() -> void:
	await _flicker_phase_2_transition()
	_turn_lights_off()

	if old_lady_ghost != null and old_lady_ghost.has_method("hide_ghost"):
		old_lady_ghost.hide_ghost()
	elif old_lady_ghost != null:
		old_lady_ghost.visible = false

	_play_phase_2_transition_sound()
	await get_tree().create_timer(0.06).timeout

	_set_blood_cashier_active(false)
	_apply_phase_2_visual(Phase2VisualState.RED)
	await get_tree().create_timer(phase_2_empty_red_hold).timeout

	_apply_phase_2_visual(Phase2VisualState.DARK)
	await get_tree().create_timer(randf_range(0.08, 0.18)).timeout

	_activate_phase_2_horror_cast()
	await _run_phase_2_light_sequence()

	_apply_phase_2_visual(Phase2VisualState.DARK)
	await get_tree().create_timer(phase_2_final_blackout_time).timeout

	_deactivate_phase_2_horror_cast()
	_set_red_overlay_active(false)
	_restore_supermarket_light_colors()

	_restore_lights(false)
	_clear_reveal_dimmed_override()
	_set_cashier_active(true)

	await _start_after_vision_dialogue()


func _wait_for_stretch_animation_finished() -> void:
	var stretch_name := _get_stretch_animation_name()
	var player := _get_ghost_animation_player()
	if player == null:
		return

	if not player.is_playing():
		var current := StringName(str(player.current_animation))
		if current == stretch_name or current.is_empty():
			return

	var done := [false]
	var on_finished := func(finished_name: StringName) -> void:
		if finished_name == stretch_name:
			done[0] = true
	player.animation_finished.connect(on_finished, CONNECT_ONE_SHOT)
	while _running and not done[0]:
		await get_tree().process_frame


func _get_stretch_animation_name() -> StringName:
	var stretch_name := StringName(stretch_animation_name)
	if old_lady_ghost != null and old_lady_ghost.get("stretch_animation_name") != null:
		stretch_name = StringName(str(old_lady_ghost.stretch_animation_name))
	return stretch_name


func _get_ghost_animation_player() -> AnimationPlayer:
	if old_lady_ghost == null:
		return null
	if old_lady_ghost.has_method("get_animation_player"):
		return old_lady_ghost.get_animation_player()
	return null


func _run_phase_2_light_sequence() -> void:
	var major_count := randi_range(phase_2_flicker_count_min, phase_2_flicker_count_max)
	var major_times: Array[float] = []
	var cursor := randf_range(0.8, 1.6)
	for _i in major_count:
		major_times.append(cursor)
		cursor += randf_range(1.2, 2.2)
	major_times.sort()

	var elapsed := 0.0
	var major_index := 0

	while elapsed < phase_2_duration and _phase_2_running:
		if major_index < major_times.size() and elapsed >= major_times[major_index]:
			await _run_major_phase_2_flicker()
			major_index += 1
			elapsed += randf_range(0.35, 0.85)
			continue

		var state := _pick_phase_2_state()
		var duration := randf_range(0.08, 0.45)
		if state == Phase2VisualState.CLEAR:
			duration = randf_range(phase_2_clear_duration_min, phase_2_clear_duration_max)
		elif state == Phase2VisualState.RED and randf() < 0.35:
			duration = randf_range(0.5, 0.9)

		_apply_phase_2_visual(state)
		await get_tree().create_timer(duration).timeout
		elapsed += duration


func _run_major_phase_2_flicker() -> void:
	var patterns: Array[Array] = [
		[Phase2VisualState.CLEAR, Phase2VisualState.CLEAR, Phase2VisualState.DARK, Phase2VisualState.RED, Phase2VisualState.CLEAR],
		[Phase2VisualState.CLEAR, Phase2VisualState.DARK, Phase2VisualState.CLEAR, Phase2VisualState.RED],
		[Phase2VisualState.CLEAR, Phase2VisualState.RED, Phase2VisualState.DARK, Phase2VisualState.CLEAR],
	]
	var pattern: Array = patterns[randi() % patterns.size()]
	for state_value in pattern:
		_apply_phase_2_visual(state_value as Phase2VisualState)
		var step := randf_range(0.1, 0.28)
		if state_value == Phase2VisualState.CLEAR:
			step = randf_range(phase_2_clear_duration_min, phase_2_clear_duration_max)
		await get_tree().create_timer(step).timeout


func _pick_phase_2_state() -> Phase2VisualState:
	var roll := randf()
	var dark_end := (1.0 - phase_2_clear_chance) * 0.48
	var red_end := 1.0 - phase_2_clear_chance
	if roll < dark_end:
		return Phase2VisualState.DARK
	if roll < red_end:
		return Phase2VisualState.RED
	return Phase2VisualState.CLEAR


func _apply_phase_2_visual(state: Phase2VisualState) -> void:
	match state:
		Phase2VisualState.CLEAR:
			_set_red_overlay_active(false)
			_restore_supermarket_light_colors()
			_restore_phase_2_clear_lights()
		Phase2VisualState.DARK:
			_set_red_overlay_active(false)
			_turn_all_supermarket_lights_off()
		Phase2VisualState.RED:
			_apply_horror_light_colors()
			_set_red_overlay_active(true)
			for light in supermarket_lights:
				if light == null:
					continue
				var id := light.get_instance_id()
				if not _light_states.has(id):
					continue
				var base_energy: float = _light_states[id]["energy"]
				light.visible = true
				light.light_energy = base_energy * randf_range(0.35, 0.65)


func _restore_phase_2_clear_lights() -> void:
	for light in supermarket_lights:
		if light == null:
			continue
		var id := light.get_instance_id()
		if not _light_states.has(id):
			continue
		var saved: Dictionary = _light_states[id]
		light.visible = saved["visible"]
		light.light_energy = saved["energy"]
		if saved.has("color"):
			light.light_color = saved["color"]
	_apply_phase_2_cashier_spotlights(phase_2_cashier_spotlight_multiplier)


func _apply_phase_2_cashier_spotlights(multiplier: float) -> void:
	if reveal_dimmed_lights.is_empty() or _reveal_dimmed_light_states.is_empty():
		return
	for light in reveal_dimmed_lights:
		if light == null:
			continue
		var dim_id := light.get_instance_id()
		if not _reveal_dimmed_light_states.has(dim_id):
			continue
		var saved: Dictionary = _reveal_dimmed_light_states[dim_id]
		var base_energy: float = saved["energy"]
		if multiplier <= 0.001:
			light.light_energy = 0.0
			light.visible = false
		else:
			light.visible = saved["visible"]
			light.light_energy = base_energy * multiplier


func _turn_all_supermarket_lights_off() -> void:
	_turn_lights_off()
	for light in reveal_dimmed_lights:
		if light == null:
			continue
		light.light_energy = 0.0
		light.visible = false


func _apply_horror_light_colors() -> void:
	for light in supermarket_lights:
		if light == null:
			continue
		var id := light.get_instance_id()
		if not _light_states.has(id):
			continue
		var base_energy: float = _light_states[id]["energy"]
		light.visible = true
		light.light_color = HORROR_LIGHT_COLOR
		light.light_energy = maxf(HORROR_LIGHT_ENERGY, base_energy * 0.45)


func _restore_supermarket_light_colors() -> void:
	for light in supermarket_lights:
		if light == null:
			continue
		var id := light.get_instance_id()
		if not _light_states.has(id):
			continue
		var state: Dictionary = _light_states[id]
		if state.has("color"):
			light.light_color = state["color"]


func _set_red_overlay_active(active: bool) -> void:
	if _red_overlay_layer != null:
		_red_overlay_layer.visible = active


func _flicker_phase_2_transition() -> void:
	_set_bathroom_lights_active(false)
	const PATTERN: Array[float] = [1.0, 0.0, 0.55, 0.0]
	var step := phase_2_transition_flicker_time / float(PATTERN.size())
	for multiplier in PATTERN:
		_set_lights_energy(multiplier)
		await get_tree().create_timer(step).timeout


func _play_phase_2_transition_sound() -> void:
	if _phase_2_sound_player == null or phase_2_transition_sound == null:
		return
	_phase_2_sound_player.volume_db = phase_2_transition_volume_db
	_phase_2_sound_player.stop()
	_phase_2_sound_player.play()


func _activate_phase_2_horror_cast() -> void:
	_set_counter_items_visible(false)
	_set_phase_2_terror_props_visible(true)
	_set_blood_cashier_active(true)


func _deactivate_phase_2_horror_cast() -> void:
	_set_blood_cashier_active(false)
	_set_phase_2_terror_props_visible(false)
	_restore_counter_items()


func _initialize_phase_2_terror_props() -> void:
	_register_phase_2_terror_props()
	_set_phase_2_terror_props_visible(false)


func _register_phase_2_terror_props() -> void:
	if not phase_2_terror_props.is_empty():
		for prop in phase_2_terror_props:
			if prop != null and is_instance_valid(prop):
				prop.add_to_group(TERROR_PROP_GROUP)
		return

	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is Node3D and str(child.name).begins_with("TerrorHead"):
			child.add_to_group(TERROR_PROP_GROUP)


func _get_phase_2_terror_props() -> Array[Node3D]:
	var props: Array[Node3D] = []
	if not phase_2_terror_props.is_empty():
		for prop in phase_2_terror_props:
			if prop != null and is_instance_valid(prop):
				props.append(prop)
		return props

	for node in get_tree().get_nodes_in_group(TERROR_PROP_GROUP):
		if node is Node3D and is_instance_valid(node):
			props.append(node as Node3D)
	return props


func _set_phase_2_terror_props_visible(value: bool) -> void:
	for prop in _get_phase_2_terror_props():
		prop.visible = value


func _find_counter_items() -> Array[Node]:
	var items: Array[Node] = []
	for node in get_tree().get_nodes_in_group(COUNTER_ITEMS_GROUP):
		if is_instance_valid(node):
			items.append(node)
	return items


func _cache_counter_item_states() -> void:
	_counter_item_state_cache.clear()
	for item in _find_counter_items():
		_counter_item_state_cache.append(_capture_counter_item_state(item))


func _capture_counter_item_state(item: Node) -> Dictionary:
	var state := {
		"node": item,
		"visible": _read_node_visible(item),
		"collision_states": _capture_collision_states(item),
	}
	return state


func _capture_collision_states(root: Node) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	if root is Area3D:
		var area := root as Area3D
		states.append({
			"node": area,
			"kind": &"area",
			"monitoring": area.monitoring,
			"monitorable": area.monitorable,
			"collision_layer": area.collision_layer,
			"collision_mask": area.collision_mask,
		})
	elif root is RigidBody3D:
		var body := root as RigidBody3D
		states.append({
			"node": body,
			"kind": &"rigidbody",
			"collision_layer": body.collision_layer,
			"collision_mask": body.collision_mask,
		})
	elif root is CollisionShape3D:
		var shape := root as CollisionShape3D
		states.append({
			"node": shape,
			"kind": &"shape",
			"disabled": shape.disabled,
		})

	for child in root.get_children():
		states.append_array(_capture_collision_states(child))
	return states


func _apply_collision_hidden(state: Dictionary) -> void:
	var node: Node = state["node"]
	if not is_instance_valid(node):
		return
	match state.get("kind", &""):
		&"area":
			var area := node as Area3D
			area.monitoring = false
			area.monitorable = false
			area.collision_layer = 0
			area.collision_mask = 0
		&"rigidbody":
			var body := node as RigidBody3D
			body.collision_layer = 0
			body.collision_mask = 0
		&"shape":
			(node as CollisionShape3D).disabled = true


func _restore_collision_state(state: Dictionary) -> void:
	var node: Node = state["node"]
	if not is_instance_valid(node):
		return
	match state.get("kind", &""):
		&"area":
			var area := node as Area3D
			area.monitoring = state.get("monitoring", area.monitoring)
			area.monitorable = state.get("monitorable", area.monitorable)
			area.collision_layer = state.get("collision_layer", area.collision_layer)
			area.collision_mask = state.get("collision_mask", area.collision_mask)
		&"rigidbody":
			var body := node as RigidBody3D
			body.collision_layer = state.get("collision_layer", body.collision_layer)
			body.collision_mask = state.get("collision_mask", body.collision_mask)
		&"shape":
			(node as CollisionShape3D).disabled = state.get("disabled", false)


func _set_counter_items_visible(value: bool) -> void:
	if not value:
		if _counter_item_state_cache.is_empty():
			_cache_counter_item_states()
		for state in _counter_item_state_cache:
			var item: Node = state["node"]
			if not is_instance_valid(item):
				continue
			_set_node_visible(item, false)
			for collision_state in state.get("collision_states", []):
				_apply_collision_hidden(collision_state)
		return

	_restore_counter_items()


func _restore_counter_items() -> void:
	for state in _counter_item_state_cache:
		var item: Node = state["node"]
		if not is_instance_valid(item):
			continue
		_set_node_visible(item, state.get("visible", true))
		for collision_state in state.get("collision_states", []):
			_restore_collision_state(collision_state)
	_counter_item_state_cache.clear()


func _read_node_visible(node: Node) -> bool:
	if node is Node3D:
		return (node as Node3D).visible
	if node is CanvasItem:
		return (node as CanvasItem).visible
	return true


func _set_node_visible(node: Node, value: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = value
	elif node is CanvasItem:
		(node as CanvasItem).visible = value


func _set_blood_cashier_active(active: bool) -> void:
	if blood_cashier == null:
		return
	if blood_cashier.has_method("set_visible_actor"):
		blood_cashier.set_visible_actor(active)
	else:
		blood_cashier.visible = active
	if active:
		_play_blood_cashier_idle()


func _play_blood_cashier_idle() -> void:
	if blood_cashier == null:
		return
	var player := blood_cashier.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation("idle_supermarket"):
		player.play("idle_supermarket")


func _start_after_vision_dialogue() -> void:
	if cashier_npc == null:
		_unlock_player()
		return

	var focus: Node3D = cashier_npc.get_node_or_null("DialogueFocusPoint") as Node3D
	if focus == null:
		focus = cashier_npc

	if DialogueController.dialogue_finished.is_connected(_on_after_vision_dialogue_finished):
		DialogueController.dialogue_finished.disconnect(_on_after_vision_dialogue_finished)
	DialogueController.dialogue_finished.connect(_on_after_vision_dialogue_finished, CONNECT_ONE_SHOT)
	DialogueController.start_dialogue(AFTER_VISION_DIALOGUE, "start", focus, true)


func _on_after_vision_dialogue_finished() -> void:
	_unlock_player()
	_restore_ambient_if_needed()
	_restore_bathroom_lights()


func _apply_post_sequence_state() -> void:
	_register_phase_2_terror_props()
	_set_blood_cashier_active(false)
	_set_phase_2_terror_props_visible(false)
	_set_red_overlay_active(false)
	if old_lady_ghost != null and old_lady_ghost.has_method("hide_ghost"):
		old_lady_ghost.hide_ghost()
	_resolve_cashier_refs()
	if _cashier_deactivated:
		_set_cashier_active(true)


func _safe_cleanup() -> void:
	_deactivate_phase_2_horror_cast()
	_set_red_overlay_active(false)
	_restore_supermarket_light_colors()
	_restore_lights(false)
	_unlock_player()
	_restore_ambient_if_needed()
	_restore_bathroom_lights()


func _cache_light_states() -> void:
	_light_states.clear()
	for light in supermarket_lights:
		if light == null:
			continue
		var id := light.get_instance_id()
		_light_states[id] = {
			"visible": light.visible,
			"energy": light.light_energy,
			"color": light.light_color,
		}

	_reveal_dimmed_light_states.clear()
	for light in reveal_dimmed_lights:
		if light == null:
			continue
		var dim_id := light.get_instance_id()
		_reveal_dimmed_light_states[dim_id] = {
			"visible": light.visible,
			"energy": light.light_energy,
		}

	_bathroom_light_states.clear()
	for light in bathroom_lights:
		if light == null:
			continue
		var bath_id := light.get_instance_id()
		_bathroom_light_states[bath_id] = {
			"visible": light.visible,
			"energy": light.light_energy,
		}


func _set_lights_energy(multiplier: float) -> void:
	if supermarket_lights.is_empty():
		return
	for light in supermarket_lights:
		if light == null:
			continue
		var id := light.get_instance_id()
		if not _light_states.has(id):
			continue
		var base_energy: float = _light_states[id]["energy"]
		if multiplier <= 0.001:
			light.light_energy = 0.0
			light.visible = false
		else:
			light.visible = true
			if _light_states[id].has("color"):
				light.light_color = _light_states[id]["color"]
			light.light_energy = base_energy * multiplier


func _turn_lights_off() -> void:
	_set_lights_energy(0.0)


func _restore_lights(apply_cashier_override: bool = true) -> void:
	for light in supermarket_lights:
		if light == null:
			continue
		var id := light.get_instance_id()
		if not _light_states.has(id):
			continue
		var state: Dictionary = _light_states[id]
		light.visible = state["visible"]
		light.light_energy = state["energy"]
		if state.has("color"):
			light.light_color = state["color"]

	if apply_cashier_override:
		_apply_reveal_dimmed_lights()


func _clear_reveal_dimmed_override() -> void:
	for light in reveal_dimmed_lights:
		if light == null:
			continue
		var dim_id := light.get_instance_id()
		if not _reveal_dimmed_light_states.has(dim_id):
			continue
		var saved: Dictionary = _reveal_dimmed_light_states[dim_id]
		light.visible = saved["visible"]
		light.light_energy = saved["energy"]


func _apply_reveal_dimmed_lights() -> void:
	if reveal_dimmed_lights.is_empty() or _reveal_dimmed_light_states.is_empty():
		return
	for light in reveal_dimmed_lights:
		if light == null:
			continue
		var dim_id := light.get_instance_id()
		if not _reveal_dimmed_light_states.has(dim_id):
			continue
		var saved: Dictionary = _reveal_dimmed_light_states[dim_id]
		var base_energy: float = saved["energy"]
		if reveal_dimmed_light_multiplier <= 0.001:
			light.light_energy = 0.0
			light.visible = false
		else:
			light.visible = saved["visible"]
			light.light_energy = base_energy * reveal_dimmed_light_multiplier


func _flicker_lights_short() -> void:
	_set_bathroom_lights_active(false)

	if supermarket_lights.is_empty():
		await get_tree().create_timer(pre_blackout_flicker_time).timeout
		return

	const FLICKER_PATTERN: Array[float] = [1.0, 0.0, 1.0, 0.0]
	var step_count := FLICKER_PATTERN.size()
	var step_duration := pre_blackout_flicker_time / float(step_count)

	for multiplier in FLICKER_PATTERN:
		_set_lights_energy(multiplier)
		await get_tree().create_timer(step_duration).timeout


func _set_bathroom_lights_active(active: bool) -> void:
	if bathroom_lights.is_empty():
		return
	for light in bathroom_lights:
		if light == null:
			continue
		var id := light.get_instance_id()
		if not _bathroom_light_states.has(id):
			continue
		var state: Dictionary = _bathroom_light_states[id]
		if active:
			light.visible = state["visible"]
			light.light_energy = state["energy"]
		else:
			light.light_energy = 0.0
			light.visible = false


func _restore_bathroom_lights() -> void:
	_set_bathroom_lights_active(true)


func _set_cashier_active(active: bool) -> void:
	if cashier_npc == null:
		push_warning("SupermarketGhostRevealSequence: cashier_npc no asignado.")
		return

	_resolve_cashier_refs()

	if active:
		if _cashier_saved_states.is_empty():
			return
		cashier_npc.visible = _cashier_saved_states.get("npc_visible", true)
		_restore_dialogue_component_state()
		_restore_focus_hitbox_state()
		_cashier_saved_states.clear()
		_cashier_deactivated = false
		return

	if _cashier_saved_states.is_empty():
		_cache_cashier_states()

	cashier_npc.visible = false
	_disable_dialogue_component()
	_disable_focus_hitbox()
	_clear_player_interaction_focus()
	_cashier_deactivated = true


func _cache_cashier_states() -> void:
	_cashier_saved_states.clear()
	_cashier_saved_states["npc_visible"] = cashier_npc.visible

	if _cashier_interact != null:
		_cashier_saved_states["dialogue_enabled"] = _cashier_interact.enabled
		_cashier_saved_states["dialogue_monitoring"] = _cashier_interact.monitoring
		_cashier_saved_states["dialogue_monitorable"] = _cashier_interact.monitorable
		_cashier_saved_states["dialogue_collision_layer"] = _cashier_interact.collision_layer
		_cashier_saved_states["dialogue_shape_disabled"] = _get_collision_shape_disabled(_cashier_interact)

	if _cashier_focus_hitbox != null:
		_cashier_saved_states["focus_monitoring"] = _cashier_focus_hitbox.monitoring
		_cashier_saved_states["focus_monitorable"] = _cashier_focus_hitbox.monitorable
		_cashier_saved_states["focus_collision_layer"] = _cashier_focus_hitbox.collision_layer
		_cashier_saved_states["focus_shape_disabled"] = _get_collision_shape_disabled(_cashier_focus_hitbox)


func _disable_dialogue_component() -> void:
	if _cashier_interact == null:
		return
	_cashier_interact.enabled = false
	_cashier_interact.monitoring = false
	_cashier_interact.monitorable = false
	_cashier_interact.collision_layer = 0
	_set_collision_shapes_disabled(_cashier_interact, true)


func _restore_dialogue_component_state() -> void:
	if _cashier_interact == null:
		return
	_cashier_interact.enabled = _cashier_saved_states.get("dialogue_enabled", true)
	_cashier_interact.monitoring = _cashier_saved_states.get("dialogue_monitoring", true)
	_cashier_interact.monitorable = _cashier_saved_states.get("dialogue_monitorable", true)
	_cashier_interact.collision_layer = _cashier_saved_states.get("dialogue_collision_layer", 1)
	_set_collision_shapes_disabled(
		_cashier_interact,
		_cashier_saved_states.get("dialogue_shape_disabled", false)
	)


func _disable_focus_hitbox() -> void:
	if _cashier_focus_hitbox == null:
		return
	_cashier_focus_hitbox.monitoring = false
	_cashier_focus_hitbox.monitorable = false
	_cashier_focus_hitbox.collision_layer = 0
	_set_collision_shapes_disabled(_cashier_focus_hitbox, true)


func _restore_focus_hitbox_state() -> void:
	if _cashier_focus_hitbox == null:
		return
	_cashier_focus_hitbox.monitoring = _cashier_saved_states.get("focus_monitoring", false)
	_cashier_focus_hitbox.monitorable = _cashier_saved_states.get("focus_monitorable", true)
	_cashier_focus_hitbox.collision_layer = _cashier_saved_states.get("focus_collision_layer", 1)
	_set_collision_shapes_disabled(
		_cashier_focus_hitbox,
		_cashier_saved_states.get("focus_shape_disabled", false)
	)


func _get_collision_shape_disabled(root: Node) -> bool:
	for child in root.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).disabled
	return false


func _set_collision_shapes_disabled(root: Node, disabled: bool) -> void:
	for child in root.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = disabled


func _clear_player_interaction_focus() -> void:
	var player: Node = GameManager.get_player()
	if player == null:
		return
	if player.has_method("clear_interaction_focus"):
		player.clear_interaction_focus()


func _reveal_ghost() -> void:
	if old_lady_ghost == null:
		push_warning("SupermarketGhostRevealSequence: old_lady_ghost no asignado.")
		return

	if old_lady_ghost.has_method("reveal"):
		await old_lady_ghost.reveal()
		return

	if old_lady_ghost.has_method("set_visible_state"):
		old_lady_ghost.set_visible_state(true)
	else:
		old_lady_ghost.visible = true


func _play_scream() -> void:
	if _scream_player == null or scream_audio == null:
		return
	_scream_player.volume_db = scream_volume_db
	_scream_player.stop()
	_scream_player.play()


func _resolve_cashier_refs() -> void:
	_cashier_interact = null
	_cashier_focus_hitbox = null
	if cashier_npc == null:
		return

	var interact := cashier_npc.get_node_or_null("InteractableDialogueComponent")
	if interact is InteractableDialogueComponent:
		_cashier_interact = interact as InteractableDialogueComponent

	var focus_hitbox := cashier_npc.get_node_or_null("DialogueFocusPoint/FocusHitbox")
	if focus_hitbox is Area3D:
		_cashier_focus_hitbox = focus_hitbox as Area3D


func _lock_player() -> void:
	if not lock_player_movement:
		return

	var player: Node = GameManager.get_player()
	if player == null:
		return

	player.stop_movement_immediately()

	if allow_camera_look and player.get("can_move") != null:
		_saved_can_move = player.can_move
		player.can_move = false
		if player.get("interaction_enabled") != null:
			_saved_interaction_enabled = player.interaction_enabled
			player.interaction_enabled = false
		if player.has_method("capture_mouse"):
			player.capture_mouse()
		return

	_used_full_input_lock = true
	if player.get("input_enabled") != null:
		_saved_input_enabled = player.input_enabled
	GameManager.lock_player_minigame()
	if player.has_method("set_input_enabled"):
		player.set_input_enabled(false)


func _unlock_player() -> void:
	if not lock_player_movement:
		return

	var player: Node = GameManager.get_player()
	if player == null:
		return

	if _used_full_input_lock:
		GameManager.unlock_player_minigame()
		if player.has_method("set_input_enabled"):
			player.set_input_enabled(_saved_input_enabled)
		if player.has_method("capture_mouse") and _saved_input_enabled:
			player.capture_mouse()
		_used_full_input_lock = false
		return

	if player.get("can_move") != null:
		player.can_move = _saved_can_move
	if player.get("interaction_enabled") != null:
		player.interaction_enabled = _saved_interaction_enabled


func _dip_ambient_if_enabled() -> void:
	if not dip_ambient_during_sequence:
		return
	var bus_index: int = AudioServer.get_bus_index(String(ambient_bus_name))
	if bus_index < 0:
		return
	_saved_ambient_volume_db = AudioServer.get_bus_volume_db(bus_index)
	AudioServer.set_bus_volume_db(bus_index, _saved_ambient_volume_db + ambient_dip_db)


func _restore_ambient_if_needed() -> void:
	if not dip_ambient_during_sequence:
		return
	var bus_index: int = AudioServer.get_bus_index(String(ambient_bus_name))
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, _saved_ambient_volume_db)
