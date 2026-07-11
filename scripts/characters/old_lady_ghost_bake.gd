class_name OldLadyGhostBake
extends RefCounted
## Utilidad para construir la biblioteca de animaciones de OldLadyGhost (Mixamo → Skeleton3D).

const MIXAMO_SOURCE_ANIM := "mixamo.com"
const SKELETON_PATH := "Skeleton3D"

const ANIMATION_SOURCES: Dictionary = {
	"old_lady_idle": {
		"fbx": "res://assets/characters/oldLadyGhost/animations/Orc Idle.fbx",
		"loop": true,
		"lock_hips": true,
	},
	"orc_idle": {
		"fbx": "res://assets/characters/oldLadyGhost/animations/Orc Idle.fbx",
		"loop": true,
		"lock_hips": true,
	},
	"neck_stretching": {
		"fbx": "res://assets/characters/oldLadyGhost/animations/Neck Stretching.fbx",
		"loop": false,
		"lock_hips": true,
	},
	"neck_stretching_trim": {
		"fbx": "res://assets/characters/oldLadyGhost/animations/Neck_Stretching_Trim.fbx",
		"loop": false,
		"lock_hips": true,
	},
	"neck_stretching_trim2": {
		"fbx": "res://assets/characters/oldLadyGhost/animations/Neck_Stretching_Trim2.fbx",
		"loop": false,
		"lock_hips": true,
		"hips_reference": "neck_stretching_trim",
	},
	"silly_dance": {
		"fbx": "res://assets/characters/oldLadyGhost/animations/Silly Dancing.fbx",
		"loop": true,
		"lock_hips": true,
	},
}


static func build_animation_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for anim_name in ANIMATION_SOURCES:
		bake_animation_into_library(library, anim_name)
	_apply_hips_references(library)
	return library


static func bake_animation_into_library(library: AnimationLibrary, anim_name: String) -> bool:
	if library.has_animation(anim_name):
		return true
	if not ANIMATION_SOURCES.has(anim_name):
		push_warning("OldLadyGhostBake: animación desconocida '%s'." % anim_name)
		return false
	var config: Dictionary = ANIMATION_SOURCES[anim_name]
	var anim := _load_mixamo_animation(config)
	if anim == null:
		push_warning("OldLadyGhostBake: no se pudo cargar '%s'." % anim_name)
		return false
	anim.resource_name = anim_name
	anim.loop_mode = Animation.LOOP_LINEAR if config.get("loop", false) else Animation.LOOP_NONE
	library.add_animation(anim_name, anim)
	return true


static func _apply_hips_references(library: AnimationLibrary) -> void:
	for anim_name in ANIMATION_SOURCES:
		var config: Dictionary = ANIMATION_SOURCES[anim_name]
		if not config.get("lock_hips", false):
			continue
		if config.has("hips_reference"):
			continue
		if not library.has_animation(anim_name):
			continue
		var own_hips: Variant = _read_hips_position_at_start(library.get_animation(anim_name))
		if own_hips is Vector3:
			_lock_hips_position(library.get_animation(anim_name), own_hips)

	for anim_name in ANIMATION_SOURCES:
		var config: Dictionary = ANIMATION_SOURCES[anim_name]
		if not config.get("lock_hips", false):
			continue
		if not config.has("hips_reference"):
			continue
		if not library.has_animation(anim_name):
			continue
		var reference_hips: Variant = _resolve_hips_reference(library, config)
		if reference_hips is Vector3:
			_lock_hips_position(library.get_animation(anim_name), reference_hips)


static func _resolve_hips_reference(library: AnimationLibrary, config: Dictionary) -> Variant:
	var ref_name := String(config.get("hips_reference", ""))
	if not ref_name.is_empty() and library.has_animation(ref_name):
		return _read_hips_position_at_start(library.get_animation(ref_name))
	for fallback_name in ["old_lady_idle", "orc_idle", "neck_stretching_trim"]:
		if library.has_animation(fallback_name):
			var hips_pos: Variant = _read_hips_position_at_start(library.get_animation(fallback_name))
			if hips_pos is Vector3:
				return hips_pos
	return null


static func _read_hips_position_at_start(anim: Animation) -> Variant:
	for hips_bone in ["mixamorig_Hips", "Hips"]:
		var hips_pos_track := anim.find_track(
			NodePath("%s:%s" % [SKELETON_PATH, hips_bone]),
			Animation.TYPE_POSITION_3D
		)
		if hips_pos_track < 0:
			continue
		if anim.track_get_key_count(hips_pos_track) == 0:
			continue
		return anim.track_get_key_value(hips_pos_track, 0)
	return null


static func _load_mixamo_animation(config: Dictionary) -> Animation:
	var fbx_path := String(config.get("fbx", ""))
	if fbx_path.is_empty():
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


static func _lock_hips_position(anim: Animation, reference_pos: Vector3 = Vector3.INF) -> void:
	for hips_bone in ["mixamorig_Hips", "Hips"]:
		var hips_pos_track := anim.find_track(
			NodePath("%s:%s" % [SKELETON_PATH, hips_bone]),
			Animation.TYPE_POSITION_3D
		)
		if hips_pos_track < 0:
			continue
		var key_count := anim.track_get_key_count(hips_pos_track)
		if key_count == 0:
			continue
		var locked_pos: Vector3 = reference_pos if reference_pos != Vector3.INF else (
			anim.track_get_key_value(hips_pos_track, 0)
		)
		for key_idx in range(key_count):
			anim.track_set_key_value(hips_pos_track, key_idx, locked_pos)
		return
