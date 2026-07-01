@tool
extends Node3D
## Personaje base del NPC de gasolinera: textura y biblioteca de animaciones en escena.

const MODEL_TEXTURE := "res://assets/characters/character_npc_gas_station/Character_09.png"
const ANIM_LIBRARY_PATH := "res://scenes/characters/gas_station_npc/character_09_animations.tres"
const SKELETON_PATH := "Skeleton3D"
const Bake := preload("res://scripts/characters/character_09_bake.gd")

const ROOT_MOTION_BONE_HINTS: PackedStringArray = [
	"mixamorig_Hips",
	"Hips",
]


func _ready() -> void:
	_apply_character_texture()
	_ensure_derived_animations_if_needed()


func _ensure_derived_animations_if_needed() -> void:
	var animation_player := _find_animation_player(self)
	if animation_player == null:
		return
	var library := _get_primary_library(animation_player)
	if library == null:
		push_warning("Character09: no hay biblioteca de animaciones en el AnimationPlayer.")
		return
	Bake.bake_animation_into_library(library, "idle")
	_ensure_sitting_animation(library)
	_ensure_standing_up_short(library)
	_ensure_walking_in_place(library)


func _ensure_sitting_animation(library: AnimationLibrary) -> void:
	if library.has_animation("sitting"):
		library.remove_animation("sitting")
	Bake.bake_animation_into_library(library, "sitting")


func _get_primary_library(animation_player: AnimationPlayer) -> AnimationLibrary:
	for lib_name in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(lib_name)
		if library != null:
			return library
	return null


func are_animations_ready() -> bool:
	var animation_player := _find_animation_player(self)
	if animation_player == null:
		return false
	var library := _get_primary_library(animation_player)
	if library == null:
		return false
	return library.has_animation("walking_in_place") and library.has_animation("old_man_idle")


func _ensure_standing_up_short(library: AnimationLibrary) -> void:
	if library.has_animation("standing_up_short"):
		return
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


func _ensure_walking_in_place(library: AnimationLibrary) -> void:
	if library.has_animation("walking_in_place"):
		return
	if not library.has_animation("walking"):
		return
	var reference_hips := _get_walking_in_place_reference_hips(library)
	var in_place := library.get_animation("walking").duplicate()
	in_place.resource_name = "walking_in_place"
	in_place.loop_mode = Animation.LOOP_LINEAR
	_neutralize_horizontal_root_motion(in_place, reference_hips)
	library.add_animation("walking_in_place", in_place)


func _get_walking_in_place_reference_hips(library: AnimationLibrary) -> Vector3:
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


func _read_hips_from_animations(library: AnimationLibrary, names: Array) -> Variant:
	for ref_name in names:
		if not library.has_animation(ref_name):
			continue
		var hips_pos: Variant = _read_hips_position_at_start(library.get_animation(ref_name))
		if hips_pos is Vector3:
			return hips_pos
	return null


func _read_hips_position_at_start(anim: Animation) -> Variant:
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


func _neutralize_horizontal_root_motion(anim: Animation, reference_hips: Vector3) -> void:
	for track_idx in range(anim.get_track_count()):
		if not _is_root_motion_track(anim, track_idx):
			continue
		if anim.track_get_type(track_idx) == Animation.TYPE_POSITION_3D:
			_neutralize_position_3d_track_xz(anim, track_idx, reference_hips)


func _is_root_motion_track(anim: Animation, track_idx: int) -> bool:
	var path := String(anim.track_get_path(track_idx))
	if path == "." or path == ".." or path.ends_with(":position") or path.ends_with("/position"):
		return true
	for hint in ROOT_MOTION_BONE_HINTS:
		if path.ends_with(":%s" % hint) or path.ends_with("/%s" % hint):
			return true
	return false


func _neutralize_position_3d_track_xz(
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


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


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
