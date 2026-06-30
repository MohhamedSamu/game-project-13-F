@tool
extends Node3D
## Registra animaciones Mixamo del policía en el AnimationPlayer local (cache .res en editor).

const ANIMATIONS_DIR := "res://assets/characters/policeNpc/animations/"
const SOURCE_ANIM := "mixamo.com"

## Nombre lógico → FBX en assets/characters/policeNpc/animations/
const MIXAMO_SOURCES: Dictionary = {
	"breathing_idle": "Breathing Idle.fbx",
	"idle": "Idle.fbx",
	"running": "Running.fbx",
	"start_walking": "Start Walking.fbx",
	"walking": "Walking.fbx",
}

const SINGLE_SHOT_ANIMATIONS: Array[String] = ["start_walking"]

@export_group("Reproducción")
@export var autoplay_on_ready: bool = false
@export var default_animation: String = "breathing_idle"


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_setup_mixamo_animations")


func _ready() -> void:
	_setup_mixamo_animations()


func _setup_mixamo_animations() -> void:
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player == null:
		return

	var library := animation_player.get_animation_library("")
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)

	for anim_name in MIXAMO_SOURCES.keys():
		if library.has_animation(anim_name):
			continue
		var anim := _load_mixamo_animation(anim_name)
		if anim == null:
			push_warning("PoliceNpc: no se pudo cargar '%s'." % anim_name)
			continue
		library.add_animation(anim_name, anim)

	if animation_player.autoplay != "":
		animation_player.autoplay = ""

	if Engine.is_editor_hint():
		return

	if autoplay_on_ready and not default_animation.is_empty() and library.has_animation(default_animation):
		if not animation_player.is_playing() or animation_player.current_animation != default_animation:
			animation_player.play(default_animation)


func play_animation(animation_name: String) -> void:
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player == null:
		return
	if not animation_player.has_animation(animation_name):
		push_warning("PoliceNpc: animación '%s' no registrada." % animation_name)
		return
	animation_player.play(animation_name)


func get_animation_player() -> AnimationPlayer:
	return get_node_or_null("AnimationPlayer") as AnimationPlayer


func get_animation_names() -> PackedStringArray:
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player == null:
		return PackedStringArray()
	var library := animation_player.get_animation_library("")
	if library == null:
		return PackedStringArray()
	return PackedStringArray(library.get_animation_list())


func _load_mixamo_animation(anim_name: String) -> Animation:
	var cache_path := _cache_path(anim_name)
	if ResourceLoader.exists(cache_path):
		var cached := load(cache_path) as Animation
		if cached:
			return cached.duplicate()

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

	var anim := _remap_animation(source_anim.duplicate(), anim_name)
	_neutralize_root_motion(anim)
	_try_save_cache(anim_name, anim)
	return anim


func _cache_path(anim_name: String) -> String:
	return ANIMATIONS_DIR.path_join(anim_name + ".res")


func _try_save_cache(anim_name: String, anim: Animation) -> void:
	if not Engine.is_editor_hint():
		return
	var err := ResourceSaver.save(anim, _cache_path(anim_name))
	if err != OK:
		push_warning("PoliceNpc: no se pudo guardar cache '%s' (%s)." % [anim_name, error_string(err)])


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _remap_animation(anim: Animation, anim_name: String) -> Animation:
	anim.resource_name = anim_name
	if anim_name in SINGLE_SHOT_ANIMATIONS:
		anim.loop_mode = Animation.LOOP_NONE
	else:
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
