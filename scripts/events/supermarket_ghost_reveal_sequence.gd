extends Node
## Escena 5 — fase 1: apagón breve del supermercado, cajera desaparece, OldLadyGhost en ventana.

const STARTED_FLAG := &"supermarket_ghost_reveal_started"
const DONE_FLAG := &"supermarket_ghost_reveal_done"

@export_group("Referencias")
@export var cashier_npc: Node3D
@export var old_lady_ghost: Node3D
@export var supermarket_lights: Array[Light3D] = []
@export var reveal_dimmed_lights: Array[Light3D] = []

@export_group("Trigger")
@export var trigger_flag: String = "ready_for_cashier_jumpscare"
@export var run_once: bool = true

@export_group("Tiempos")
@export var pre_blackout_flicker_time: float = 1.2
@export var blackout_time: float = 1.0
@export var lights_return_delay: float = 0.1
@export var ghost_reveal_delay_after_lights: float = 0.08
@export var after_reveal_hold_time: float = 2.5
@export var player_release_delay: float = 0.4

@export_group("Iluminación cajera")
@export_range(0.0, 1.0, 0.05) var reveal_dimmed_light_multiplier: float = 0.0

@export_group("Jugador")
@export var lock_player_movement: bool = true
@export var allow_camera_look: bool = true

@export_group("Audio")
@export var scream_audio: AudioStream = preload("res://assets/audio/SFX/screams/soft1.mp3")
@export_range(-40.0, 6.0, 0.5) var scream_volume_db: float = 0.0
@export var dip_ambient_during_sequence: bool = false
@export_range(-24.0, 0.0, 0.5) var ambient_dip_db: float = -6.0
@export var ambient_bus_name: StringName = &"Music"

var _running: bool = false
var _light_states: Dictionary = {}
var _reveal_dimmed_light_states: Dictionary = {}
var _cashier_interact: InteractableDialogueComponent
var _cashier_focus_hitbox: Area3D
var _cashier_saved_states: Dictionary = {}
var _cashier_deactivated: bool = false
var _scream_player: AudioStreamPlayer
var _saved_can_move: bool = true
var _saved_interaction_enabled: bool = true
var _saved_input_enabled: bool = true
var _used_full_input_lock: bool = false
var _saved_ambient_volume_db: float = 0.0


func _ready() -> void:
	add_to_group(&"supermarket_ghost_reveal_sequence")
	_scream_player = get_node_or_null("ScreamSFX") as AudioStreamPlayer
	if _scream_player != null and scream_audio != null:
		_scream_player.stream = scream_audio
		_scream_player.volume_db = scream_volume_db
		_scream_player.bus = &"SFX"

	if old_lady_ghost != null and old_lady_ghost.has_method("hide_ghost"):
		old_lady_ghost.hide_ghost()
	elif old_lady_ghost != null:
		old_lady_ghost.visible = false

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
	await get_tree().create_timer(0.12).timeout

	_turn_lights_off()
	_set_cashier_active(false)

	await get_tree().create_timer(blackout_time).timeout

	if lights_return_delay > 0.0:
		await get_tree().create_timer(lights_return_delay).timeout

	await _restore_lights_with_sting()
	_apply_reveal_dimmed_lights()

	if ghost_reveal_delay_after_lights > 0.0:
		await get_tree().create_timer(ghost_reveal_delay_after_lights).timeout

	_play_scream()
	await _reveal_ghost()

	if after_reveal_hold_time > 0.0:
		await get_tree().create_timer(after_reveal_hold_time).timeout
	if player_release_delay > 0.0:
		await get_tree().create_timer(player_release_delay).timeout

	_unlock_player()
	_restore_ambient_if_needed()

	if run_once:
		GameManager.set_flag(DONE_FLAG, true)

	_running = false


func _cache_light_states() -> void:
	_light_states.clear()
	for light in supermarket_lights:
		if light == null:
			continue
		var id := light.get_instance_id()
		_light_states[id] = {
			"visible": light.visible,
			"energy": light.light_energy,
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

	if apply_cashier_override:
		_apply_reveal_dimmed_lights()


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
	if supermarket_lights.is_empty():
		await get_tree().create_timer(pre_blackout_flicker_time).timeout
		return

	var elapsed := 0.0
	var multipliers: Array[float] = [1.0, 0.0, 0.35, 0.0, 0.65, 0.12, 0.0, 0.45, 0.0, 0.8, 0.0]

	while elapsed < pre_blackout_flicker_time:
		var multiplier: float = multipliers[randi() % multipliers.size()]
		if randf() < 0.35:
			multiplier = 0.0
		elif randf() < 0.2:
			multiplier = randf_range(0.15, 0.55)

		var step: float = randf_range(0.04, 0.18)
		var remaining: float = pre_blackout_flicker_time - elapsed
		if step > remaining:
			step = remaining
		if step <= 0.0:
			break

		_set_lights_energy(multiplier)
		await get_tree().create_timer(step).timeout
		elapsed += step

	_set_lights_energy(randf_range(0.5, 1.0))
	await get_tree().create_timer(randf_range(0.05, 0.1)).timeout
	_set_lights_energy(0.0)
	await get_tree().create_timer(randf_range(0.04, 0.08)).timeout


func _restore_lights_with_sting() -> void:
	_restore_lights(false)
	await get_tree().create_timer(0.05).timeout
	_turn_lights_off()
	await get_tree().create_timer(0.1).timeout
	_restore_lights(true)


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
