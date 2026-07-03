@tool
extends Node3D
## Modelo base OldLadyGhost: textura PSX + biblioteca de animaciones Mixamo.

const MODEL_TEXTURE := (
	"res://assets/characters/oldLadyGhost/Characters_psx/Textures/Character_Monster_03.png"
)
const ANIM_LIBRARY_PATH := "res://scenes/characters/old_lady_ghost/old_lady_ghost_animations.tres"
const DEFAULT_AUTOPLAY := "old_lady_idle"


func _ready() -> void:
	_apply_character_texture()
	_ensure_animation_library()


func _ensure_animation_library() -> void:
	var player := _find_animation_player(self)
	if player == null:
		push_warning("OldLadyGhostModel: falta AnimationPlayer.")
		return

	var library := _load_or_build_animation_library()
	if library == null:
		return

	_apply_animation_library(player, library)
	if player.autoplay.is_empty():
		player.autoplay = DEFAULT_AUTOPLAY


func _load_or_build_animation_library() -> AnimationLibrary:
	if ResourceLoader.exists(ANIM_LIBRARY_PATH):
		var saved := load(ANIM_LIBRARY_PATH) as AnimationLibrary
		if saved != null and not saved.get_animation_list().is_empty():
			return saved
	return OldLadyGhostBake.build_animation_library()


func _apply_animation_library(player: AnimationPlayer, library: AnimationLibrary) -> void:
	if player.has_animation_library(""):
		var existing := player.get_animation_library("")
		for anim_name in library.get_animation_list():
			if not existing.has_animation(anim_name):
				existing.add_animation(anim_name, library.get_animation(anim_name))
	else:
		player.add_animation_library("", library)


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
