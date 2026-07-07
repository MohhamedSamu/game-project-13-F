@tool
extends Node3D
## Monstruo Character_Monster_04: textura y animaciones Mixamo en AnimationPlayer.

const MODEL_TEXTURE := "res://assets/characters/mounstro_final/Character_Monster_04.png"
const ANIMATIONS_DIR := "res://assets/characters/mounstro_final/animations/"
const SOURCE_ANIM := "mixamo.com"

const MIXAMO_SOURCES: Dictionary = {
	"zombie_biting": "Zombie Biting.fbx",
	"zombie_biting_standing_up": "Zombie Biting standing up.fbx",
	"zombie_running": "Zombie Running.fbx",
	"zombie_scream": "Zombie Scream.fbx",
	"zombie_biting_v2": "Zombie Biting v2.fbx",
	"zombie_biting_standing_up_v2": "Zombie Biting standing up v2.fbx",
	"turn_left": "Action Adventure Pack/left turn.fbx",
	"turn_right": "Action Adventure Pack/right turn.fbx",
}

enum AnimationChoice {
	ZOMBIE_BITING,
	ZOMBIE_BITING_STANDING_UP,
	ZOMBIE_RUNNING,
	ZOMBIE_SCREAM,
	ZOMBIE_BITING_V2,
	ZOMBIE_BITING_STANDING_UP_V2,
	TURN_LEFT,
	TURN_RIGHT,
}

const ANIMATION_NAMES: Array[String] = [
	"zombie_biting",
	"zombie_biting_standing_up",
	"zombie_running",
	"zombie_scream",
	"zombie_biting_v2",
	"zombie_biting_standing_up_v2",
	"turn_left",
	"turn_right",
]

const SINGLE_SHOT_ANIMATIONS: Array[String] = [
	"zombie_biting_standing_up",
	"zombie_biting_standing_up_v2",
	"zombie_scream",
	"turn_left",
	"turn_right",
]

const SEQUENCE_STANCE_REFERENCE := "turn_left"
const NO_HIPS_POSITION := Vector3(INF, INF, INF)
const VERTICAL_ROOT_MOTION_ANIMATIONS: Array[String] = [
	"zombie_biting_standing_up",
	"zombie_biting_standing_up_v2",
	"zombie_scream",
]

@export_group("Reproducción")
@export var autoplay_on_ready: bool = true
@export var animation: AnimationChoice = AnimationChoice.ZOMBIE_BITING:
	set(value):
		animation = value
		call_deferred("_play_selected_animation")


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_setup_mixamo_animations")


func _ready() -> void:
	_apply_character_texture()
	call_deferred("_setup_mixamo_animations")


func _setup_mixamo_animations() -> void:
	if not is_inside_tree():
		return

	var animation_player := _ensure_animation_player()
	if animation_player == null:
		return

	var skeleton := _find_skeleton3d(self)
	if skeleton == null:
		push_warning("Monster04: no se encontró Skeleton3D en el modelo importado.")
		return

	animation_player.root_node = NodePath("..")

	var library := animation_player.get_animation_library("")
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)

	for anim_name in MIXAMO_SOURCES.keys():
		if library.has_animation(anim_name):
			if anim_name in VERTICAL_ROOT_MOTION_ANIMATIONS:
				var existing := library.get_animation(anim_name)
				if not _animation_has_vertical_hip_motion(existing, skeleton, animation_player):
					library.remove_animation(anim_name)
				else:
					continue
			else:
				continue
		var anim := _load_mixamo_animation(anim_name, skeleton, animation_player)
		if anim == null:
			push_warning("Monster04: no se pudo cargar '%s'." % anim_name)
			continue
		library.add_animation(anim_name, anim)

	if animation_player.autoplay != "":
		animation_player.autoplay = ""

	if Engine.is_editor_hint():
		_play_selected_animation()
		return

	if autoplay_on_ready:
		_play_selected_animation()

	_harmonize_stance_animations(animation_player, skeleton)


func _harmonize_stance_animations(
	animation_player: AnimationPlayer,
	skeleton: Skeleton3D
) -> void:
	var library := animation_player.get_animation_library("")
	if library == null or not library.has_animation(SEQUENCE_STANCE_REFERENCE):
		return
	var reference_anim := library.get_animation(SEQUENCE_STANCE_REFERENCE)
	var reference_hips := _read_hips_position(reference_anim, skeleton, animation_player)
	if reference_hips == NO_HIPS_POSITION:
		return
	for anim_name in [
		SEQUENCE_STANCE_REFERENCE,
		"turn_right",
		"zombie_running",
	]:
		if not library.has_animation(anim_name):
			continue
		_lock_hips_on_animation(
			library.get_animation(anim_name),
			reference_hips,
			skeleton,
			animation_player
		)


func _play_selected_animation() -> void:
	var animation_player := _ensure_animation_player()
	if animation_player == null:
		return
	var anim_name := _get_selected_animation_name()
	if anim_name.is_empty() or not animation_player.has_animation(anim_name):
		return
	if not animation_player.is_playing() or animation_player.current_animation != anim_name:
		animation_player.play(anim_name)


func _get_selected_animation_name() -> String:
	if animation < 0 or animation >= ANIMATION_NAMES.size():
		return ""
	return ANIMATION_NAMES[animation]


func play_animation(animation_name: String) -> void:
	play_animation_blended(animation_name, 0.0)


func play_animation_blended(animation_name: String, blend_time: float = 0.3) -> void:
	var animation_player := _ensure_animation_player()
	if animation_player == null:
		return
	if not animation_player.has_animation(animation_name):
		push_warning("Monster04: animación '%s' no registrada." % animation_name)
		return
	if blend_time > 0.0:
		animation_player.play(animation_name, blend_time)
	else:
		animation_player.play(animation_name)


func prepare_sequence_from(
	reference_anim_name: String,
	target_anim_name: String,
	horizontal_only: bool = false,
	reference_key_index: int = 0
) -> void:
	var animation_player := _ensure_animation_player()
	if animation_player == null:
		return
	var library := animation_player.get_animation_library("")
	if library == null:
		return
	if not library.has_animation(reference_anim_name):
		push_warning("Monster04: referencia '%s' no encontrada." % reference_anim_name)
		return
	if not library.has_animation(target_anim_name):
		push_warning("Monster04: objetivo '%s' no encontrada." % target_anim_name)
		return
	var skeleton := _find_skeleton3d(self)
	if skeleton == null:
		return
	var reference_anim := library.get_animation(reference_anim_name)
	var reference_hips := _read_hips_position(
		reference_anim,
		skeleton,
		animation_player,
		reference_key_index
	)
	if reference_hips == NO_HIPS_POSITION:
		return
	_lock_hips_on_animation(
		library.get_animation(target_anim_name),
		reference_hips,
		skeleton,
		animation_player,
		horizontal_only
	)


func get_animation_names() -> PackedStringArray:
	var animation_player := _ensure_animation_player()
	if animation_player == null:
		return PackedStringArray()
	var library := animation_player.get_animation_library("")
	if library == null:
		return PackedStringArray()
	return PackedStringArray(library.get_animation_list())


func _load_mixamo_animation(
	anim_name: String,
	skeleton: Skeleton3D,
	animation_player: AnimationPlayer
) -> Animation:
	var cache_path := _cache_path(anim_name)
	if ResourceLoader.exists(cache_path):
		var cached := load(cache_path) as Animation
		if cached and anim_name in VERTICAL_ROOT_MOTION_ANIMATIONS:
			if not _animation_has_vertical_hip_motion(cached, skeleton, animation_player):
				cached = null
		if cached:
			var anim := _remap_animation(cached.duplicate(), anim_name, skeleton, animation_player)
			_neutralize_root_motion(anim, skeleton, animation_player, anim_name)
			return anim

	var fbx_file: String = MIXAMO_SOURCES.get(anim_name, "")
	if fbx_file.is_empty():
		return null

	var fbx_path := ANIMATIONS_DIR.path_join(fbx_file)
	if not ResourceLoader.exists(fbx_path):
		push_warning("Monster04: FBX no encontrado en '%s'." % fbx_path)
		return null

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
		if src_library.has_animation(SOURCE_ANIM):
			source_anim = src_library.get_animation(SOURCE_ANIM)
		else:
			var names := src_library.get_animation_list()
			if not names.is_empty():
				source_anim = src_library.get_animation(names[0])

	instance.queue_free()
	if source_anim == null:
		return null

	var anim := _remap_animation(source_anim.duplicate(), anim_name, skeleton, animation_player)
	_neutralize_root_motion(anim, skeleton, animation_player, anim_name)
	_try_save_cache(anim_name, anim)
	return anim


func _cache_path(anim_name: String) -> String:
	return ANIMATIONS_DIR.path_join(anim_name + ".res")


func _try_save_cache(anim_name: String, anim: Animation) -> void:
	if not Engine.is_editor_hint():
		return
	var err := ResourceSaver.save(anim, _cache_path(anim_name))
	if err != OK:
		push_warning("Monster04: no se pudo guardar cache '%s' (%s)." % [anim_name, error_string(err)])


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _find_skeleton3d(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton3d(child)
		if found:
			return found
	return null


func _skeleton_prefix(skeleton: Skeleton3D, animation_player: AnimationPlayer) -> String:
	var root := animation_player.get_parent()
	if root == null:
		return ""
	if skeleton == root:
		return "."
	var parts: Array[String] = []
	var node: Node = skeleton
	while node != null and node != root:
		parts.insert(0, node.name)
		node = node.get_parent()
	if node != root:
		return ""
	return "/".join(parts)


func _remap_animation(
	anim: Animation,
	anim_name: String,
	skeleton: Skeleton3D,
	animation_player: AnimationPlayer
) -> Animation:
	anim.resource_name = anim_name
	if anim_name in SINGLE_SHOT_ANIMATIONS:
		anim.loop_mode = Animation.LOOP_NONE
	else:
		anim.loop_mode = Animation.LOOP_LINEAR

	var skel_prefix := _skeleton_prefix(skeleton, animation_player)
	if skel_prefix.is_empty():
		return anim

	for track_idx in range(anim.get_track_count()):
		var path := String(anim.track_get_path(track_idx))
		var sep := path.rfind(":")
		if sep == -1:
			continue
		var bone := path.substr(sep + 1)
		anim.track_set_path(track_idx, NodePath("%s:%s" % [skel_prefix, bone]))

	return anim


func _neutralize_root_motion(
	anim: Animation,
	skeleton: Skeleton3D,
	animation_player: AnimationPlayer,
	anim_name: String = ""
) -> void:
	var skel_prefix := _skeleton_prefix(skeleton, animation_player)
	if skel_prefix.is_empty():
		return

	var hips_pos_track := anim.find_track(
		NodePath("%s:mixamorig_Hips" % skel_prefix),
		Animation.TYPE_POSITION_3D
	)
	if hips_pos_track < 0:
		return

	if anim_name in VERTICAL_ROOT_MOTION_ANIMATIONS:
		_remove_horizontal_root_motion(anim, skel_prefix)
		return

	var key_count := anim.track_get_key_count(hips_pos_track)
	if key_count == 0:
		return

	var locked_pos: Vector3 = anim.track_get_key_value(hips_pos_track, 0)
	_lock_hips_on_animation(anim, locked_pos, skeleton, animation_player)
	_remove_horizontal_root_motion(anim, skel_prefix)


func _animation_has_vertical_hip_motion(
	anim: Animation,
	skeleton: Skeleton3D,
	animation_player: AnimationPlayer
) -> bool:
	var skel_prefix := _skeleton_prefix(skeleton, animation_player)
	if skel_prefix.is_empty():
		return false
	var hips_pos_track := anim.find_track(
		NodePath("%s:mixamorig_Hips" % skel_prefix),
		Animation.TYPE_POSITION_3D
	)
	if hips_pos_track < 0:
		return false
	var key_count := anim.track_get_key_count(hips_pos_track)
	if key_count < 2:
		return false
	var min_y := INF
	var max_y := -INF
	for key_idx in range(key_count):
		var pos: Vector3 = anim.track_get_key_value(hips_pos_track, key_idx)
		min_y = minf(min_y, pos.y)
		max_y = maxf(max_y, pos.y)
	return (max_y - min_y) > 0.05


func _read_hips_position(
	anim: Animation,
	skeleton: Skeleton3D,
	animation_player: AnimationPlayer,
	key_index: int = 0
) -> Vector3:
	if anim == null:
		return NO_HIPS_POSITION
	var skel_prefix := _skeleton_prefix(skeleton, animation_player)
	if skel_prefix.is_empty():
		return NO_HIPS_POSITION
	var hips_pos_track := anim.find_track(
		NodePath("%s:mixamorig_Hips" % skel_prefix),
		Animation.TYPE_POSITION_3D
	)
	if hips_pos_track < 0:
		return NO_HIPS_POSITION
	var key_count := anim.track_get_key_count(hips_pos_track)
	if key_count == 0:
		return NO_HIPS_POSITION
	var resolved_key := key_index
	if resolved_key < 0:
		resolved_key = key_count - 1
	resolved_key = clampi(resolved_key, 0, key_count - 1)
	return anim.track_get_key_value(hips_pos_track, resolved_key) as Vector3


func _lock_hips_on_animation(
	anim: Animation,
	locked_pos: Vector3,
	skeleton: Skeleton3D,
	animation_player: AnimationPlayer,
	horizontal_only: bool = false
) -> void:
	if anim == null:
		return
	var skel_prefix := _skeleton_prefix(skeleton, animation_player)
	if skel_prefix.is_empty():
		return
	var hips_pos_track := anim.find_track(
		NodePath("%s:mixamorig_Hips" % skel_prefix),
		Animation.TYPE_POSITION_3D
	)
	if hips_pos_track < 0:
		return
	var key_count := anim.track_get_key_count(hips_pos_track)
	for key_idx in range(key_count):
		var pos: Vector3 = anim.track_get_key_value(hips_pos_track, key_idx)
		if horizontal_only:
			pos.x = locked_pos.x
			pos.z = locked_pos.z
		else:
			pos = locked_pos
		anim.track_set_key_value(hips_pos_track, key_idx, pos)


func _remove_horizontal_root_motion(anim: Animation, skel_prefix: String) -> void:
	var hips_pos_track := anim.find_track(
		NodePath("%s:mixamorig_Hips" % skel_prefix),
		Animation.TYPE_POSITION_3D
	)
	if hips_pos_track < 0:
		return
	var key_count := anim.track_get_key_count(hips_pos_track)
	for key_idx in range(key_count):
		var pos: Vector3 = anim.track_get_key_value(hips_pos_track, key_idx)
		pos.x = 0.0
		pos.z = 0.0
		anim.track_set_key_value(hips_pos_track, key_idx, pos)


func _ensure_animation_player() -> AnimationPlayer:
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		return animation_player
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	if Engine.is_editor_hint():
		var scene_root := get_tree().edited_scene_root if get_tree() else null
		if scene_root:
			animation_player.owner = scene_root
	return animation_player


func _apply_character_texture() -> void:
	var texture := load(MODEL_TEXTURE) as Texture2D
	if texture == null:
		return
	_apply_texture_recursive(self, texture)


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
