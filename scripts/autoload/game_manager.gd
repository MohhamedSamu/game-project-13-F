extends Node

signal level_started(level_id: String)
signal level_scene_changed(level_id: String, scene_id: String, previous_scene_id: String)
signal objective_completed(level_id: String, scene_id: String, objective_id: String)
signal dialogue_beat_played(npc_id: String, beat_id: String)

var dialogue_active: bool = false
var minigame_active: bool = false
var level_intro_active: bool = false
var player: Node = null
var has_met_clown: bool = false
var flags: Dictionary = {}

## Nivel y escena narrativa activos (varias escenas dentro del mismo nivel).
var current_level_id: String = ""
var current_scene_id: String = ""

const TOILET_BLADDER_UNSET := -1.0
var toilet_bladder_remaining: float = TOILET_BLADDER_UNSET

var _level_scene_profiles: Dictionary = {}
var _level_narrative_state: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func set_dialogue_active(value: bool) -> void:
	dialogue_active = value

func register_player(player_node: Node) -> void:
	if player != null and is_instance_valid(player) and player != player_node:
		if player.tree_exited.is_connected(_on_player_tree_exited):
			player.tree_exited.disconnect(_on_player_tree_exited)
	player = player_node
	if player != null and not player.tree_exited.is_connected(_on_player_tree_exited):
		player.tree_exited.connect(_on_player_tree_exited)
	Settings.apply_controls_to_player()
	Settings.apply_movement_to_player(player)


func get_player() -> Node:
	if player != null and not is_instance_valid(player):
		player = null
	return player


func _on_player_tree_exited() -> void:
	player = null


func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value


func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func begin_level(
	level_id: String,
	initial_scene_id: String = "default",
	scene_profile: LevelSceneProfile = null
) -> void:
	current_level_id = level_id
	_level_narrative_state[level_id] = {
		"current_scene": "default",
		"scenes": {},
		"played_beats": {},
	}
	if scene_profile != null:
		register_level_scene_profile(scene_profile)
	var scene_id := initial_scene_id
	if scene_profile != null and not scene_profile.initial_scene_id.is_empty():
		scene_id = scene_profile.initial_scene_id
	_set_level_scene_internal(level_id, scene_id, false)
	level_started.emit(level_id)


func register_level_scene_profile(scene_profile: LevelSceneProfile) -> void:
	if scene_profile == null or scene_profile.level_id.is_empty():
		return
	_level_scene_profiles[scene_profile.level_id] = scene_profile


func get_level_scene_profile(level_id: String = "") -> LevelSceneProfile:
	var id := level_id if not level_id.is_empty() else current_level_id
	return _level_scene_profiles.get(id, null) as LevelSceneProfile


func get_level_scene() -> String:
	return current_scene_id


func set_level_scene(scene_id: String) -> bool:
	if current_level_id.is_empty():
		push_warning("GameManager: set_level_scene sin nivel activo.")
		return false
	var profile := get_level_scene_profile()
	if profile != null and not profile.has_scene(scene_id):
		push_warning("GameManager: escena narrativa desconocida '%s' en %s." % [scene_id, current_level_id])
		return false
	return _set_level_scene_internal(current_level_id, scene_id, true)


func complete_objective(objective_id: String, scene_id: String = "") -> void:
	if current_level_id.is_empty() or objective_id.is_empty():
		return
	var target_scene := scene_id if not scene_id.is_empty() else current_scene_id
	if target_scene.is_empty():
		target_scene = "default"
	_ensure_level_state(current_level_id)
	var level_state: Dictionary = _level_narrative_state[current_level_id]
	var scenes: Dictionary = level_state["scenes"]
	if not scenes.has(target_scene):
		scenes[target_scene] = {"objectives": {}}
	var scene_state: Dictionary = scenes[target_scene]
	var objectives: Dictionary = scene_state["objectives"]
	if objectives.get(objective_id, false):
		return
	objectives[objective_id] = true
	objective_completed.emit(current_level_id, target_scene, objective_id)


func has_objective(objective_id: String, scene_id: String = "") -> bool:
	if current_level_id.is_empty() or objective_id.is_empty():
		return false
	var target_scene := scene_id if not scene_id.is_empty() else current_scene_id
	if target_scene.is_empty():
		return false
	var level_state: Dictionary = _level_narrative_state.get(current_level_id, {})
	var scenes: Dictionary = level_state.get("scenes", {})
	var scene_state: Dictionary = scenes.get(target_scene, {})
	var objectives: Dictionary = scene_state.get("objectives", {})
	return objectives.get(objective_id, false)


func has_objective_in_level(objective_id: String) -> bool:
	if current_level_id.is_empty() or objective_id.is_empty():
		return false
	var level_state: Dictionary = _level_narrative_state.get(current_level_id, {})
	var scenes: Dictionary = level_state.get("scenes", {})
	for scene_state in scenes.values():
		var objectives: Dictionary = scene_state.get("objectives", {})
		if objectives.get(objective_id, false):
			return true
	return false


func get_completed_objectives(scene_id: String = "") -> PackedStringArray:
	var completed := PackedStringArray()
	if current_level_id.is_empty():
		return completed
	var target_scene := scene_id if not scene_id.is_empty() else current_scene_id
	var level_state: Dictionary = _level_narrative_state.get(current_level_id, {})
	var scenes: Dictionary = level_state.get("scenes", {})
	var scene_state: Dictionary = scenes.get(target_scene, {})
	var objectives: Dictionary = scene_state.get("objectives", {})
	for objective_id in objectives.keys():
		if objectives[objective_id]:
			completed.append(objective_id)
	return completed


func resolve_npc_dialogue_title(profile: NpcDialogueProfile, npc_id: String = "") -> String:
	return DialogueBeatResolver.resolve_title(profile, npc_id)


func resolve_npc_dialogue_beat(profile: NpcDialogueProfile, npc_id: String = "") -> NpcDialogueBeat:
	return DialogueBeatResolver.resolve(profile, npc_id)


func was_dialogue_beat_played(npc_id: String, beat_id: String) -> bool:
	if npc_id.is_empty() or beat_id.is_empty():
		return false
	var level_state: Dictionary = _level_narrative_state.get(current_level_id, {})
	var played_beats: Dictionary = level_state.get("played_beats", {})
	return played_beats.get(_beat_key(npc_id, beat_id), false)


func apply_dialogue_beat_finished(beat: NpcDialogueBeat, npc_id: String = "") -> void:
	if beat == null:
		return
	var resolved_npc_id := npc_id if not npc_id.is_empty() else ""
	if not beat.beat_id.is_empty() and not resolved_npc_id.is_empty():
		_mark_dialogue_beat_played(resolved_npc_id, beat.beat_id)
	for objective_id in beat.complete_objectives_on_finish:
		complete_objective(objective_id)
	for flag_name in beat.set_flags_on_finish.keys():
		var flag_value: Variant = beat.set_flags_on_finish[flag_name]
		set_flag(flag_name, bool(flag_value))
	if not beat.set_scene_on_finish.is_empty():
		set_level_scene(beat.set_scene_on_finish)


func _mark_dialogue_beat_played(npc_id: String, beat_id: String) -> void:
	if current_level_id.is_empty():
		return
	_ensure_level_state(current_level_id)
	var level_state: Dictionary = _level_narrative_state[current_level_id]
	var played_beats: Dictionary = level_state["played_beats"]
	var key := _beat_key(npc_id, beat_id)
	if played_beats.get(key, false):
		return
	played_beats[key] = true
	dialogue_beat_played.emit(npc_id, beat_id)


func _beat_key(npc_id: String, beat_id: String) -> String:
	return "%s::%s" % [npc_id, beat_id]


func _ensure_level_state(level_id: String) -> void:
	if _level_narrative_state.has(level_id):
		return
	_level_narrative_state[level_id] = {
		"current_scene": "default",
		"scenes": {},
		"played_beats": {},
	}


func _set_level_scene_internal(level_id: String, scene_id: String, should_emit: bool) -> bool:
	_ensure_level_state(level_id)
	var level_state: Dictionary = _level_narrative_state[level_id]
	var previous_scene_id: String = level_state.get("current_scene", "")
	if previous_scene_id == scene_id and should_emit:
		return true
	level_state["current_scene"] = scene_id
	current_level_id = level_id
	current_scene_id = scene_id
	if not level_state["scenes"].has(scene_id):
		level_state["scenes"][scene_id] = {"objectives": {}}
	if should_emit:
		level_scene_changed.emit(level_id, scene_id, previous_scene_id)
	return true


func get_toilet_bladder_remaining(default_capacity: float) -> float:
	if toilet_bladder_remaining < 0.0:
		return default_capacity
	return clampf(toilet_bladder_remaining, 0.0, default_capacity)


func set_toilet_bladder_remaining(value: float, capacity: float) -> void:
	toilet_bladder_remaining = clampf(value, 0.0, capacity)

func _set_crosshair_dialogue_hidden(is_hidden: bool) -> void:
	var crosshair := get_tree().get_first_node_in_group("interaction_crosshair") as Control
	if crosshair and crosshair.has_method("set_dialogue_hidden"):
		crosshair.set_dialogue_hidden(is_hidden)


func lock_player() -> void:
	dialogue_active = true
	_set_crosshair_dialogue_hidden(true)
	InnerThoughts.hide_thought()

	if player and player.has_method("stop_movement_immediately"):
		player.stop_movement_immediately()

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	if player and player.has_method("release_mouse"):
		player.release_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func unlock_player() -> void:
	dialogue_active = false
	_set_crosshair_dialogue_hidden(false)

	if player and player.has_method("clear_camera_focus"):
		player.clear_camera_focus()

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)

	if player and player.has_method("capture_mouse"):
		player.capture_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func lock_player_minigame() -> void:
	minigame_active = true
	_set_crosshair_dialogue_hidden(true)
	InnerThoughts.hide_thought()

	if player and player.has_method("stop_movement_immediately"):
		player.stop_movement_immediately()

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	if player and player.has_method("release_mouse"):
		player.release_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func unlock_player_minigame() -> void:
	minigame_active = false
	_set_crosshair_dialogue_hidden(false)

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)

	if player and player.has_method("capture_mouse"):
		player.capture_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
