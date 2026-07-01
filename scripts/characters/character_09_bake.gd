class_name Character09Bake
extends RefCounted
## Utilidad para construir la biblioteca de animaciones del NPC de gasolinera.

const MIXAMO_SOURCE_ANIM := "mixamo.com"
const SKELETON_PATH := "Skeleton3D"

const ANIMATION_SOURCES: Dictionary = {
	"old_man_idle": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Old_Man_Idle.fbx",
		"loop": true,
		"lock_hips": true,
	},
	"old_man_walk": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Old_Man_Walk.fbx",
		"loop": true,
		"lock_hips": true,
	},
	"kneeling_down": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Kneeling_Down.fbx",
		"loop": false,
		"lock_hips": true,
	},
	"kneeling_inspecting": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Kneeling_Inspecting.fbx",
		"loop": false,
		"lock_hips": true,
	},
	"standing_up": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Standing_Up.fbx",
		"loop": false,
		"lock_hips": false,
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
	"walking": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Walking.fbx",
		"loop": true,
		"lock_hips": false,
	},
	"idle": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Idle.fbx",
		"loop": true,
		"lock_hips": true,
	},
	"male_standing_pose": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Male_Standing_Pose.fbx",
		"loop": true,
		"lock_hips": true,
	},
	"sitting": {
		"fbx": "res://assets/characters/character_npc_gas_station/animations/Sitting.fbx",
		"loop": false,
		"lock_hips": false,
	},
}

const ROOT_MOTION_BONE_HINTS: PackedStringArray = [
	"mixamorig_Hips",
	"Hips",
]


static func build_animation_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for anim_name in ANIMATION_SOURCES:
		bake_animation_into_library(library, anim_name)
	_ensure_standing_up_short(library)
	_ensure_walking_in_place(library)
	return library


static func bake_animation_into_library(library: AnimationLibrary, anim_name: String) -> bool:
	if library.has_animation(anim_name):
		return true
	if not ANIMATION_SOURCES.has(anim_name):
		push_warning("Character09Bake: animación desconocida '%s'." % anim_name)
		return false
	var config: Dictionary = ANIMATION_SOURCES[anim_name]
	var anim := _load_mixamo_animation(config)
	if anim == null:
		push_warning("Character09Bake: no se pudo cargar '%s'." % anim_name)
		return false
	anim.resource_name = anim_name
	anim.loop_mode = Animation.LOOP_LINEAR if config.get("loop", false) else Animation.LOOP_NONE
	if config.get("lock_hips", false):
		_lock_hips_position(anim)
	library.add_animation(anim_name, anim)
	return true


static func _load_mixamo_animation(config: Dictionary) -> Animation:
	var fbx_path := String(config.get("fbx", ""))
	if fbx_path == "":
		return null
	var scene := load(fbx_path) as PackedScene
	if scene == null:
		return null
	var instance := scene.instantiate()
	var src_player := _find_animation_player(instance)
	if src_player == null:
		instance.queue_free()
		return null
	var source_anim := _get_first_mixamo_animation(src_player)
	instance.queue_free()
	if source_anim == null:
		return null
	return _remap_animation(source_anim.duplicate())


static func _get_first_mixamo_animation(animation_player: AnimationPlayer) -> Animation:
	for lib_name in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(lib_name)
		if library == null:
			continue
		if library.has_animation(MIXAMO_SOURCE_ANIM):
			return library.get_animation(MIXAMO_SOURCE_ANIM)
		var names := library.get_animation_list()
		if not names.is_empty():
			return library.get_animation(names[0])
	return null


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


static func _remap_animation(anim: Animation) -> Animation:
	for track_idx in range(anim.get_track_count()):
		var path := String(anim.track_get_path(track_idx))
		var sep := path.rfind(":")
		if sep == -1:
			continue
		var bone := path.substr(sep + 1).replace(":", "_")
		anim.track_set_path(track_idx, NodePath("%s:%s" % [SKELETON_PATH, bone]))
	return anim


static func _lock_hips_position(anim: Animation) -> void:
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


static func _ensure_standing_up_short(library: AnimationLibrary) -> void:
	if not library.has_animation("standing_up"):
		return
	const CUT_TIME := 3.0
	var source := library.get_animation("standing_up")
	var short_anim := source.duplicate()
	short_anim.resource_name = "standing_up_short"
	short_anim.length = CUT_TIME
	short_anim.loop_mode = Animation.LOOP_NONE
	for track_idx in range(short_anim.get_track_count()):
		for key_idx in range(short_anim.track_get_key_count(track_idx) - 1, -1, -1):
			if short_anim.track_get_key_time(track_idx, key_idx) > CUT_TIME:
				short_anim.track_remove_key(track_idx, key_idx)
	library.add_animation("standing_up_short", short_anim)


static func _ensure_walking_in_place(library: AnimationLibrary) -> void:
	if not library.has_animation("walking"):
		return
	var reference_hips := _get_walking_in_place_reference_hips(library)
	var in_place := library.get_animation("walking").duplicate()
	in_place.resource_name = "walking_in_place"
	in_place.loop_mode = Animation.LOOP_LINEAR
	_neutralize_horizontal_root_motion(in_place, reference_hips)
	library.add_animation("walking_in_place", in_place)


static func _get_walking_in_place_reference_hips(library: AnimationLibrary) -> Vector3:
	var hips_ref := Vector3.ZERO
	var xz_source: Variant = _read_hips_from_animations(library, [
		"standing_up_short",
		"idle",
		"male_standing_pose",
		"talking",
	])
	if xz_source is Vector3:
		hips_ref.x = xz_source.x
		hips_ref.z = xz_source.z
	var y_source: Variant = _read_hips_from_animations(library, [
		"idle",
		"male_standing_pose",
		"talking",
		"old_man_idle",
		"walking",
	])
	if y_source is Vector3:
		hips_ref.y = y_source.y
	elif xz_source is Vector3:
		hips_ref.y = xz_source.y
	return hips_ref


static func _read_hips_from_animations(library: AnimationLibrary, names: Array) -> Variant:
	for ref_name in names:
		if not library.has_animation(ref_name):
			continue
		var hips_pos: Variant = _read_hips_position_at_start(library.get_animation(ref_name))
		if hips_pos is Vector3:
			return hips_pos
	return null


static func _read_hips_position_at_start(anim: Animation) -> Variant:
	var hips_track := anim.find_track(
		NodePath("%s:mixamorig_Hips" % SKELETON_PATH),
		Animation.TYPE_POSITION_3D
	)
	if hips_track < 0:
		for track_idx in range(anim.get_track_count()):
			if anim.track_get_type(track_idx) != Animation.TYPE_POSITION_3D:
				continue
			if not _is_root_motion_track(anim, track_idx):
				continue
			hips_track = track_idx
			break
	if hips_track < 0:
		return null
	if anim.track_get_key_count(hips_track) == 0:
		return null
	return anim.track_get_key_value(hips_track, 0)


static func _neutralize_horizontal_root_motion(anim: Animation, reference_hips: Vector3) -> void:
	for track_idx in range(anim.get_track_count()):
		if not _is_root_motion_track(anim, track_idx):
			continue
		if anim.track_get_type(track_idx) == Animation.TYPE_POSITION_3D:
			_neutralize_position_3d_track_xz(anim, track_idx, reference_hips)


static func _is_root_motion_track(anim: Animation, track_idx: int) -> bool:
	var path := String(anim.track_get_path(track_idx))
	if path == "." or path == ".." or path.ends_with(":position") or path.ends_with("/position"):
		return true
	for hint in ROOT_MOTION_BONE_HINTS:
		if path.ends_with(":%s" % hint) or path.ends_with("/%s" % hint):
			return true
	return false


static func _neutralize_position_3d_track_xz(
	anim: Animation,
	track_idx: int,
	reference_hips: Vector3
) -> void:
	var key_count := anim.track_get_key_count(track_idx)
	if key_count == 0:
		return
	var first_value: Vector3 = anim.track_get_key_value(track_idx, 0)
	for key_idx in range(key_count):
		var value: Vector3 = anim.track_get_key_value(track_idx, key_idx)
		var y_offset := value.y - first_value.y
		value.x = reference_hips.x
		value.z = reference_hips.z
		value.y = reference_hips.y + y_offset
		anim.track_set_key_value(track_idx, key_idx, value)
