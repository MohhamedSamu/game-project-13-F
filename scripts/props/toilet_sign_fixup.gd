@tool
extends MeshInstance3D
## Sustituye el mesh importado (UV rotas) por un quad con mapeo 1:1.

const SIGN_MATERIAL := preload("res://assets/materials/gas_station/toilet_sign.tres")
const FIX_VERSION := 4

# AABB del mesh original (plano en YZ, normal en X).
const SIGN_SIZE_Y := 0.00507024
const SIGN_SIZE_Z := 0.0102542


func _enter_tree() -> void:
	_apply_sign_mesh()


func _ready() -> void:
	_apply_sign_mesh()


func _apply_sign_mesh() -> void:
	if mesh is QuadMesh and mesh.get_meta(&"toilet_sign_version", 0) == FIX_VERSION:
		return

	var quad := QuadMesh.new()
	quad.orientation = QuadMesh.FACE_X
	quad.size = Vector2(SIGN_SIZE_Y, SIGN_SIZE_Z)

	mesh = quad
	mesh.set_meta(&"toilet_sign_version", FIX_VERSION)
	set_surface_override_material(0, _make_sign_material())


func _make_sign_material() -> StandardMaterial3D:
	var mat := SIGN_MATERIAL.duplicate() as StandardMaterial3D
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.emission_enabled = false
	# QuadMesh FACE_X mapea la textura girada y espejada; corregir en UV1.
	mat.uv1_rotation = PI * 0.5
	mat.uv1_scale = Vector3(-1.0, 1.0, 1.0)
	mat.uv1_offset = Vector3(1.0, 0.0, 0.0)
	return mat
