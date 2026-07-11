@tool
extends Node3D
## Personaje Muerta: rig VRoid (Bone, hips, Waist...) con animaciones FBX compatibles.

const MODEL_TEXTURE := "res://assets/characters/muerta/Pe5.png"
const MODEL_TEXTURE_FALLBACK := "res://assets/characters/muerta/muerta_Pe5.png"
const ANIMATIONS_DIR := "res://assets/characters/muerta/animations/"
const SOURCE_ANIM := "mixamo.com"

const MIXAMO_SOURCES: Dictionary = {
	"laying_seizure": "Laying Seizure.fbx",
	"laying_shaking_head": "Laying Shaking Head.fbx",
	"stroke_shaking_head": "Stroke Shaking Head.fbx",
	"silly_dance": "Silly Dancing.fbx",
}

const ROOT_HIPS_BONE_NAMES: PackedStringArray = [
	"hips",
	"mixamorig_Hips",
	"Hips",
]

enum AnimationChoice {
	LAYING_SEIZURE,
	LAYING_SHAKING_HEAD,
	STROKE_SHAKING_HEAD,
}

const ANIMATION_NAMES: Array[String] = [
	"laying_seizure",
	"laying_shaking_head",
	"stroke_shaking_head",
]

const SINGLE_SHOT_ANIMATIONS: Array[String] = []

@export_group("Escena")
@export_range(0.1, 2.0, 0.05) var model_scale: float = 0.4
@export var center_at_origin: bool = true
@export var remove_imported_camera: bool = true

@export_group("Reproducción")
@export var autoplay_on_ready: bool = true
@export var animation: AnimationChoice = AnimationChoice.LAYING_SEIZURE:
	set(value):
		animation = value
		if is_inside_tree() and _animations_ready:
			call_deferred("_play_selected_animation")

var _animations_ready: bool = false


func _ready() -> void:
	_apply_character_texture()
	call_deferred("_initialize_character")


func _initialize_character() -> void:
	if not is_inside_tree():
		return
	if remove_imported_camera:
		_remove_imported_camera()
	_apply_model_scale()
	if center_at_origin:
		_center_at_origin()
	_setup_animations()


func _apply_model_scale() -> void:
	scale = Vector3.ONE * model_scale


func _remove_imported_camera() -> void:
	for child in get_children():
		if child is Camera3D:
			child.queue_free()


func _center_at_origin() -> void:
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, mesh_instances)
	if mesh_instances.is_empty():
		return

	var bounds := AABB()
	var has_bounds := false
	for mesh_instance in mesh_instances:
		if mesh_instance.mesh == null or not mesh_instance.is_inside_tree():
			continue
		var mesh_aabb := mesh_instance.global_transform * mesh_instance.get_aabb()
		if not has_bounds:
			bounds = mesh_aabb
			has_bounds = true
		else:
			bounds = bounds.merge(mesh_aabb)
	if not has_bounds:
		return

	var offset := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	global_position -= offset


func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, out)


func _setup_animations() -> void:
	if not is_inside_tree():
		return

	var animation_player := _resolve_animation_player()
	if animation_player == null:
		return

	var skeleton := _find_skeleton3d(self)
	if skeleton == null:
		push_warning("Muerta: no se encontró Skeleton3D en el modelo importado.")
		return

	if not animation_player.has_animation_library(""):
		animation_player.add_animation_library("", AnimationLibrary.new())

	var library := animation_player.get_animation_library("")
	if library == null:
		push_warning("Muerta: no se pudo obtener la biblioteca de animaciones.")
		return

	animation_player.root_node = NodePath("..")

	for existing_name in library.get_animation_list():
		library.remove_animation(existing_name)

	for anim_name in MIXAMO_SOURCES.keys():
		var anim := _load_animation(anim_name, skeleton, animation_player)
		if anim == null:
			push_warning("Muerta: no se pudo cargar '%s'." % anim_name)
			continue
		library.add_animation(anim_name, anim)

	if animation_player.autoplay != "":
		animation_player.autoplay = ""

	_animations_ready = true

	if Engine.is_editor_hint() or autoplay_on_ready:
		_play_selected_animation()


func _play_selected_animation() -> void:
	if not is_inside_tree() or not _animations_ready:
		return
	var animation_player := _find_animation_player(self)
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
	var animation_player := _find_animation_player(self)
	if animation_player == null:
		return
	if not animation_player.has_animation(animation_name):
		push_warning("Muerta: animación '%s' no registrada." % animation_name)
		return
	animation_player.play(animation_name)


func get_animation_names() -> PackedStringArray:
	var animation_player := _find_animation_player(self)
	if animation_player == null:
		return PackedStringArray()
	var library := animation_player.get_animation_library("")
	if library == null:
		return PackedStringArray()
	return PackedStringArray(library.get_animation_list())


func _load_animation(
	anim_name: String,
	skeleton: Skeleton3D,
	animation_player: AnimationPlayer
) -> Animation:
	var fbx_file: String = MIXAMO_SOURCES.get(anim_name, "")
	if fbx_file.is_empty():
		return null

	var fbx_path := ANIMATIONS_DIR.path_join(fbx_file)
	if not ResourceLoader.exists(fbx_path):
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

	var anim := _remap_animation(
		source_anim.duplicate(),
		anim_name,
		skeleton,
		animation_player
	)
	_neutralize_root_motion(anim, skeleton, animation_player)
	return anim


func _resolve_animation_player() -> AnimationPlayer:
	var animation_player := _find_animation_player(self)
	if animation_player != null:
		return animation_player
	if not is_inside_tree():
		return null
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	if Engine.is_editor_hint() and get_tree():
		animation_player.owner = get_tree().edited_scene_root
	return animation_player


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


func _animation_root(animation_player: AnimationPlayer) -> Node:
	return animation_player.get_parent()


func _skeleton_prefix(skeleton: Skeleton3D, animation_player: AnimationPlayer) -> String:
	return _relative_node_path(_animation_root(animation_player), skeleton)


func _relative_node_path(from: Node, to: Node) -> String:
	if to == from:
		return "."
	var parts: Array[String] = []
	var node: Node = to
	while node != null and node != from:
		parts.insert(0, node.name)
		node = node.get_parent()
	if node != from:
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
		var bone := path.substr(sep + 1).replace(":", "_")
		anim.track_set_path(track_idx, NodePath("%s:%s" % [skel_prefix, bone]))

	return anim


func _neutralize_root_motion(
	anim: Animation,
	skeleton: Skeleton3D,
	animation_player: AnimationPlayer
) -> void:
	var skel_prefix := _skeleton_prefix(skeleton, animation_player)
	if skel_prefix.is_empty():
		return
	for hips_name in ROOT_HIPS_BONE_NAMES:
		if skeleton.find_bone(hips_name) < 0:
			continue
		var hips_pos_track := anim.find_track(
			NodePath("%s:%s" % [skel_prefix, hips_name]),
			Animation.TYPE_POSITION_3D
		)
		if hips_pos_track < 0:
			continue
		var key_count := anim.track_get_key_count(hips_pos_track)
		if key_count == 0:
			return
		var locked_pos: Vector3 = anim.track_get_key_value(hips_pos_track, 0)
		for key_idx in range(key_count):
			anim.track_set_key_value(hips_pos_track, key_idx, locked_pos)
		return


func _apply_character_texture() -> void:
	var texture := load(MODEL_TEXTURE) as Texture2D
	if texture == null:
		texture = load(MODEL_TEXTURE_FALLBACK) as Texture2D
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
