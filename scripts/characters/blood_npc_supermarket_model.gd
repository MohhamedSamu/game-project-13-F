@tool
extends Node3D
## Modelo ensangrentado del NPC del supermercado: mismo rig/mesh que Character_05, textura alternativa.

const MODEL_TEXTURE := "res://assets/characters/blood_npc_supermarket/blood_npc_supermarket_albedo.png"


func _ready() -> void:
	_apply_character_texture()


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
