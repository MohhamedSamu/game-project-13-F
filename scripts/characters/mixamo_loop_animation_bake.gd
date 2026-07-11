class_name MixamoLoopAnimationBake
extends RefCounted
## Bake de una animación Mixamo (FBX) → Animation en loop para Skeleton3D.

const SOURCE_ANIM := "mixamo.com"

const ROOT_HIPS_BONE_NAMES: PackedStringArray = [
	"mixamorig_Hips",
	"Hips",
	"hips",
]


static func bake_from_fbx(
	fbx_path: String,
	anim_name: String,
	skeleton_node_path: String = "Skeleton3D",
	lock_hips: bool = true
) -> Animation:
	if fbx_path.is_empty() or not ResourceLoader.exists(fbx_path):
		push_warning("MixamoLoopAnimationBake: FBX no encontrado '%s'." % fbx_path)
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

	var anim := _remap_animation(source_anim.duplicate(), anim_name, skeleton_node_path)
	if lock_hips:
		_lock_hips_position(anim, skeleton_node_path)
	return anim


static func save_animation(anim: Animation, output_path: String) -> bool:
	if anim == null:
		return false
	var err := ResourceSaver.save(anim, output_path)
	if err != OK:
		push_warning("MixamoLoopAnimationBake: error al guardar '%s' (%s)." % [output_path, error_string(err)])
		return false
	return true


static func _get_first_mixamo_animation(animation_player: AnimationPlayer) -> Animation:
	for lib_name in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(lib_name)
		if library == null:
			continue
		if library.has_animation(SOURCE_ANIM):
			return library.get_animation(SOURCE_ANIM)
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


static func _remap_animation(
	anim: Animation,
	anim_name: String,
	skeleton_node_path: String
) -> Animation:
	anim.resource_name = anim_name
	anim.loop_mode = Animation.LOOP_LINEAR

	for track_idx in range(anim.get_track_count()):
		var path := String(anim.track_get_path(track_idx))
		var sep := path.rfind(":")
		if sep == -1:
			continue
		var bone := path.substr(sep + 1).replace(":", "_")
		anim.track_set_path(track_idx, NodePath("%s:%s" % [skeleton_node_path, bone]))
	return anim


static func _lock_hips_position(anim: Animation, skeleton_node_path: String) -> void:
	for hips_bone in ROOT_HIPS_BONE_NAMES:
		var hips_pos_track := anim.find_track(
			NodePath("%s:%s" % [skeleton_node_path, hips_bone]),
			Animation.TYPE_POSITION_3D
		)
		if hips_pos_track < 0:
			continue
		var key_count := anim.track_get_key_count(hips_pos_track)
		if key_count == 0:
			continue
		var locked_pos: Vector3 = anim.track_get_key_value(hips_pos_track, 0)
		for key_idx in range(key_count):
			anim.track_set_key_value(hips_pos_track, key_idx, locked_pos)
		return
