class_name GasStationNPC
extends CharacterBody3D
## NPC de la gasolinera: física, animaciones Mixamo y hooks para rutina futura.

const SPEED := 2.2
const MODEL_TEXTURE := "res://assets/characters/character_npc_gas_station/Character_09.png"
const MIXAMO_SOURCE_ANIM := "mixamo.com"
const SKELETON_PATH := "Skeleton3D"

const ANIMATION_SOURCES: Dictionary = {
	"old_man_idle": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Old_Man_Idle.fbx",
		"loop": true,
		"lock_hips": true,
	},
	"start_walking": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Start_Walking.fbx",
		"loop": false,
		"lock_hips": false,
	},
	"walking": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Walking.fbx",
		"loop": true,
		"lock_hips": false,
	},
	"kneeling_down": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Kneeling_Down.fbx",
		"loop": false,
		"lock_hips": false,
	},
	"kneeling_inspecting": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Kneeling_Inspecting.fbx",
		"loop": true,
		"lock_hips": true,
	},
	"standing_up": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Standing_Up.fbx",
		"loop": false,
		"lock_hips": false,
	},
	"looking_down": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Looking_Down.fbx",
		"loop": false,
		"lock_hips": true,
	},
	"look_away": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Look_Away_Gesture.fbx",
		"loop": false,
		"lock_hips": true,
	},
	"pointing_forward": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Pointing_Forward.fbx",
		"loop": false,
		"lock_hips": true,
	},
	"searching_pockets": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Searching_Pockets.fbx",
		"loop": false,
		"lock_hips": true,
	},
	"talking": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Talking.fbx",
		"loop": true,
		"lock_hips": true,
	},
	"head_nod_yes": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Head_Nod_Yes.fbx",
		"loop": false,
		"lock_hips": true,
	},
	"male_standing_pose": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Male_Standing_Pose.fbx",
		"loop": true,
		"lock_hips": true,
	},
}

@export_group("Behavior")
@export var behavior_enabled: bool = false
@export var start_behavior_after_first_dialogue: bool = true
@export var start_behavior_flag: String = "gas_npc_intro_done"

var _animations_ready: bool = false
var _walk_sequence_active: bool = false


func _ready() -> void:
	_apply_character_texture()
	_setup_animations()
	play_idle()
	_connect_animation_player()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	move_and_slide()
	_try_enable_behavior_after_intro()


func _try_enable_behavior_after_intro() -> void:
	if behavior_enabled or not start_behavior_after_first_dialogue:
		return
	if not GameManager.get_flag(start_behavior_flag):
		return
	behavior_enabled = true


func _connect_animation_player() -> void:
	var animation_player := _get_animation_player()
	if animation_player == null:
		return
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)


func _on_animation_finished(anim_name: StringName) -> void:
	if not _walk_sequence_active:
		return
	if anim_name == &"start_walking":
		play_walking()


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


func _setup_animations() -> void:
	var animation_player := _get_animation_player()
	if animation_player == null:
		push_warning("GasStationNPC: no se encontró AnimationPlayer en Model.")
		return

	var library := animation_player.get_animation_library("")
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)

	for anim_name in ANIMATION_SOURCES:
		if library.has_animation(anim_name):
			continue
		var config: Dictionary = ANIMATION_SOURCES[anim_name]
		var anim := _load_mixamo_animation(String(config["fbx"]))
		if anim == null:
			push_warning("GasStationNPC: no se pudo cargar animación '%s'." % anim_name)
			continue
		anim.resource_name = anim_name
		anim.loop_mode = Animation.LOOP_LINEAR if config.get("loop", false) else Animation.LOOP_NONE
		if config.get("lock_hips", false):
			_lock_hips_position(anim)
		library.add_animation(anim_name, anim)

	_animations_ready = true


func _load_mixamo_animation(fbx_path: String) -> Animation:
	var res_path := fbx_path.get_basename() + ".res"
	if ResourceLoader.exists(res_path):
		var saved_anim := load(res_path) as Animation
		if saved_anim:
			return _remap_animation(saved_anim.duplicate())

	var scene := load(fbx_path) as PackedScene
	if scene == null:
		return null

	var instance := scene.instantiate()
	var src_player := _find_animation_player(instance)
	if src_player == null:
		instance.queue_free()
		return null

	var src_library := src_player.get_animation_library("")
	var source_anim: Animation = null
	if src_library:
		if src_library.has_animation(MIXAMO_SOURCE_ANIM):
			source_anim = src_library.get_animation(MIXAMO_SOURCE_ANIM)
		else:
			var names := src_library.get_animation_list()
			if not names.is_empty():
				source_anim = src_library.get_animation(names[0])

	instance.queue_free()
	if source_anim == null:
		return null

	return _remap_animation(source_anim.duplicate())


func _remap_animation(anim: Animation) -> Animation:
	for track_idx in range(anim.get_track_count()):
		var path := String(anim.track_get_path(track_idx))
		var sep := path.rfind(":")
		if sep == -1:
			continue
		var bone := path.substr(sep + 1).replace(":", "_")
		anim.track_set_path(track_idx, NodePath("%s:%s" % [SKELETON_PATH, bone]))
	return anim


func _lock_hips_position(anim: Animation) -> void:
	var hips_pos_track := anim.find_track(
		NodePath("%s:mixamorig_Hips" % SKELETON_PATH),
		Animation.TYPE_POSITION_3D
	)
	if hips_pos_track < 0:
		return
	var key_count := anim.track_get_key_count(hips_pos_track)
	if key_count == 0:
		return
	var locked_pos: Vector3 = anim.track_get_key_value(hips_pos_track, 0)
	for key_idx in range(key_count):
		anim.track_set_key_value(hips_pos_track, key_idx, locked_pos)


func _apply_character_texture() -> void:
	var texture := load(MODEL_TEXTURE) as Texture2D
	if texture == null:
		return
	var model := get_node_or_null("Model")
	if model == null:
		return
	_apply_texture_recursive(model, texture)


func _apply_texture_recursive(node: Node, texture: Texture2D) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var surface_count := mesh_instance.get_surface_override_material_count()
		if mesh_instance.mesh:
			surface_count = maxi(surface_count, mesh_instance.mesh.get_surface_count())
		for surface_idx in range(surface_count):
			var material := mesh_instance.get_active_material(surface_idx)
			if material is StandardMaterial3D:
				var override_mat := material.duplicate() as StandardMaterial3D
				override_mat.albedo_texture = texture
				mesh_instance.set_surface_override_material(surface_idx, override_mat)
	for child in node.get_children():
		_apply_texture_recursive(child, texture)


func _play_animation(anim_name: StringName) -> void:
	var animation_player := _get_animation_player()
	if animation_player == null:
		return
	if not animation_player.has_animation(anim_name):
		push_warning("GasStationNPC: animación '%s' no disponible." % anim_name)
		return
	animation_player.play(anim_name)


func play_idle() -> void:
	_play_animation(&"old_man_idle")


func play_start_walking() -> void:
	_play_animation(&"start_walking")


func play_walking() -> void:
	_play_animation(&"walking")


func play_talking() -> void:
	_play_animation(&"talking")


func play_kneel_down() -> void:
	_play_animation(&"kneeling_down")


func play_kneeling_inspecting() -> void:
	_play_animation(&"kneeling_inspecting")


func play_stand_up() -> void:
	_play_animation(&"standing_up")


func play_look_around() -> void:
	_play_animation(&"look_away")


func begin_walk_sequence() -> void:
	if not behavior_enabled:
		return
	_walk_sequence_active = true
	play_start_walking()
