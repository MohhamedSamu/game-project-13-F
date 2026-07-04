@tool
extends Node3D
## Modelo base OldLadyGhost: textura PSX + biblioteca de animaciones Mixamo.

const MODEL_TEXTURE := (
	"res://assets/characters/oldLadyGhost/Characters_psx/Textures/Character_Monster_03.png"
)
const ANIM_LIBRARY_PATH := "res://scenes/characters/old_lady_ghost/old_lady_ghost_animations.tres"
const DEFAULT_AUTOPLAY := "old_lady_idle"

var _animations_ready: bool = false
var _reveal_sequence_running: bool = false


func _ready() -> void:
	_apply_character_texture()
	ensure_animations_ready()


func ensure_animations_ready() -> void:
	if _animations_ready:
		return
	var player := get_animation_player()
	if player == null:
		push_warning("OldLadyGhostModel: falta AnimationPlayer.")
		return

	var baked_library := _load_or_build_animation_library()
	if baked_library == null:
		return

	_merge_animation_library(player, baked_library)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.autoplay = ""
	_animations_ready = true


func get_animation_player() -> AnimationPlayer:
	return _find_animation_player(self)


func are_animations_ready() -> bool:
	if not _animations_ready:
		return false
	var player := get_animation_player()
	if player == null:
		return false
	return (
		player.has_animation("old_lady_idle")
		and player.has_animation("neck_stretching")
		and player.has_animation("neck_stretching_trim")
		and player.has_animation("neck_stretching_trim2")
	)


func play_animation(anim_name: String, custom_blend: float = -1.0, custom_speed: float = 1.0) -> bool:
	ensure_animations_ready()
	var player := get_animation_player()
	if player == null:
		return false
	if anim_name.is_empty() or not player.has_animation(anim_name):
		push_warning("OldLadyGhostModel: animación '%s' no encontrada." % anim_name)
		return false
	player.active = true
	player.play(anim_name, custom_blend, custom_speed)
	return true


func play_reveal_sequence(
	idle_anim: String,
	play_full_idle: bool,
	idle_duration: float,
	stretch_anim: String,
	blend_time: float,
	stretch_speed: float
) -> void:
	ensure_animations_ready()
	var player := get_animation_player()
	if player == null:
		return
	if not player.has_animation(idle_anim):
		push_warning("OldLadyGhostModel: idle '%s' no encontrada." % idle_anim)
		return
	if not player.has_animation(stretch_anim):
		push_warning("OldLadyGhostModel: stretch '%s' no encontrada." % stretch_anim)
		return

	_reveal_sequence_running = true
	player.active = true
	player.play(idle_anim, -1.0, 1.0)

	await _wait_idle_phase(player, idle_anim, play_full_idle, idle_duration)

	if not _reveal_sequence_running:
		return

	await _play_stretch_and_hold(player, stretch_anim, blend_time, stretch_speed)
	_reveal_sequence_running = false


func get_animation_length(anim_name: String) -> float:
	ensure_animations_ready()
	var player := get_animation_player()
	if player == null or not player.has_animation(anim_name):
		return 0.0
	return player.get_animation(anim_name).length


func _wait_idle_phase(
	player: AnimationPlayer,
	idle_anim: String,
	play_full_idle: bool,
	idle_duration: float
) -> void:
	if play_full_idle:
		await _wait_one_animation_cycle(player, idle_anim)
	elif idle_duration > 0.0:
		await get_tree().create_timer(idle_duration).timeout


func _wait_one_animation_cycle(
	player: AnimationPlayer,
	anim_name: String,
	speed: float = 1.0
) -> void:
	var anim := player.get_animation(anim_name)
	if anim == null:
		return

	if anim.loop_mode == Animation.LOOP_NONE:
		await _wait_animation_finished(player, anim_name)
		return

	var cycle_time := anim.length / maxf(speed, 0.001)
	if cycle_time <= 0.0:
		return
	await get_tree().create_timer(cycle_time).timeout


func _wait_animation_finished(player: AnimationPlayer, anim_name: String) -> void:
	var finished := [false]
	var on_finished := func(finished_name: StringName) -> void:
		if finished_name == anim_name:
			finished[0] = true
	if player.animation_finished.is_connected(on_finished):
		player.animation_finished.disconnect(on_finished)
	player.animation_finished.connect(on_finished, CONNECT_ONE_SHOT)

	while _reveal_sequence_running and not finished[0]:
		await get_tree().process_frame


func stop_animations() -> void:
	_reveal_sequence_running = false
	var player := get_animation_player()
	if player != null:
		player.stop()


func _play_stretch_and_hold(
	player: AnimationPlayer,
	stretch_anim: String,
	blend_time: float,
	stretch_speed: float
) -> void:
	var finished := [false]
	var on_finished := func(anim_name: StringName) -> void:
		if anim_name == stretch_anim:
			finished[0] = true
	if player.animation_finished.is_connected(on_finished):
		player.animation_finished.disconnect(on_finished)
	player.animation_finished.connect(on_finished, CONNECT_ONE_SHOT)
	player.play(stretch_anim, blend_time, stretch_speed)

	while _reveal_sequence_running and not finished[0]:
		await get_tree().process_frame

	if not _reveal_sequence_running:
		return

	_freeze_animation_at_end(player, stretch_anim)


func _freeze_animation_at_end(player: AnimationPlayer, anim_name: String) -> void:
	var anim := player.get_animation(anim_name)
	if anim == null:
		player.pause()
		return
	player.seek(anim.length, true)
	player.pause()


func _load_or_build_animation_library() -> AnimationLibrary:
	var baked_library := OldLadyGhostBake.build_animation_library()
	if baked_library == null:
		return null
	if ResourceLoader.exists(ANIM_LIBRARY_PATH):
		var saved := load(ANIM_LIBRARY_PATH) as AnimationLibrary
		if saved != null and not saved.get_animation_list().is_empty():
			for anim_name in baked_library.get_animation_list():
				if saved.has_animation(anim_name):
					saved.remove_animation(anim_name)
				saved.add_animation(anim_name, baked_library.get_animation(anim_name))
			return saved
	return baked_library


func _merge_animation_library(player: AnimationPlayer, library: AnimationLibrary) -> void:
	var target := _get_primary_library(player)
	if target == null:
		player.add_animation_library("", library)
		return
	for anim_name in library.get_animation_list():
		if target.has_animation(anim_name):
			target.remove_animation(anim_name)
		target.add_animation(anim_name, library.get_animation(anim_name))


func _get_primary_library(player: AnimationPlayer) -> AnimationLibrary:
	for lib_name in player.get_animation_library_list():
		var library := player.get_animation_library(lib_name)
		if library != null:
			return library
	return null


func _apply_character_texture() -> void:
	var texture := load(MODEL_TEXTURE) as Texture2D
	if texture == null:
		push_warning("OldLadyGhostModel: no se encontró la textura.")
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
				override_mat.vertex_color_use_as_albedo = true
				mesh_instance.set_surface_override_material(surface_idx, override_mat)
	for child in node.get_children():
		_apply_texture_recursive(child, texture)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
