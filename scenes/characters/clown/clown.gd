@tool
extends Node3D
## Carga la animación Mixamo scary_clown_idle en el AnimationPlayer local.

const MIXAMO_FBX := "res://assets/characters/clown/animations/scary_clown_idle.fbx"
const MIXAMO_RES := "res://assets/characters/clown/animations/scary_clown_idle.res"
const ANIM_NAME := "scary_clown_idle"
const SOURCE_ANIM := "mixamo.com"


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_setup_scary_clown_idle")


func _ready() -> void:
	_setup_scary_clown_idle()


func _setup_scary_clown_idle() -> void:
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player == null:
		return

	var library := animation_player.get_animation_library("")
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)

	if not library.has_animation(ANIM_NAME):
		var anim := _load_mixamo_animation()
		if anim == null:
			push_warning("Clown: no se pudo cargar '%s' desde Mixamo." % ANIM_NAME)
			if library.has_animation("idle_arms_down"):
				animation_player.play("idle_arms_down")
			return
		_neutralize_root_motion(anim)
		library.add_animation(ANIM_NAME, anim)

	if animation_player.autoplay != "":
		animation_player.autoplay = ""
	if not animation_player.is_playing() or animation_player.current_animation != ANIM_NAME:
		animation_player.play(ANIM_NAME)


func _load_mixamo_animation() -> Animation:
	if ResourceLoader.exists(MIXAMO_RES):
		var saved_anim := load(MIXAMO_RES) as Animation
		if saved_anim:
			return _remap_animation(saved_anim.duplicate())

	var scene := load(MIXAMO_FBX) as PackedScene
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

	return _remap_animation(source_anim.duplicate())


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _remap_animation(anim: Animation) -> Animation:
	anim.resource_name = ANIM_NAME
	anim.loop_mode = Animation.LOOP_LINEAR

	for track_idx in range(anim.get_track_count()):
		var path := String(anim.track_get_path(track_idx))
		var sep := path.rfind(":")
		if sep == -1:
			continue
		var bone := path.substr(sep + 1)
		anim.track_set_path(track_idx, NodePath("Skeleton3D:" + bone))

	return anim


func _neutralize_root_motion(anim: Animation) -> void:
	var hips_pos_track := anim.find_track(
		NodePath("Skeleton3D:mixamorig_Hips"),
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
