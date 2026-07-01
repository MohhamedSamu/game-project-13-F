class_name BloodStreamEmitter
extends Node3D
## Chorro de sangre: cilindro irregular que crece desde la boquilla.

const BLOOD_COLOR := Color(0.63, 0.07, 0.1, 1.0)

@export_group("Cilindro")
@export_range(0.1, 0.6, 0.01) var stream_length: float = 0.3
@export_range(0.004, 0.05, 0.001) var stream_radius: float = 0.021
@export_range(0.2, 2.0, 0.05) var grow_duration: float = 0.5
@export_range(6, 24, 1) var ring_count: int = 12
@export_range(4, 16, 1) var side_segments: int = 8
@export_range(0.0, 0.03, 0.001) var wobble_amplitude: float = 0.006
@export_range(1.0, 20.0, 0.5) var wobble_speed: float = 7.0
@export_range(1.0, 24.0, 0.5) var wobble_frequency: float = 5.5
@export_range(0.0, 0.55, 0.01) var lump_strength: float = 0.28
@export_range(1.0, 10.0, 0.25) var lump_frequency: float = 4.0
@export var stream_direction: Vector3 = Vector3(0.0, -1.0, 0.15)

var _stream_mesh: MeshInstance3D
var _array_mesh: ArrayMesh
var _material: StandardMaterial3D
var _wobble_time: float = 0.0
var _current_length: float = 0.0
var _streaming: bool = false
var _axis: Vector3 = Vector3.DOWN
var _tangent: Vector3 = Vector3.RIGHT
var _bitangent: Vector3 = Vector3.FORWARD


func _ready() -> void:
	_stream_mesh = get_node_or_null("BloodStreamMesh") as MeshInstance3D
	_cache_stream_basis()
	_setup_material()
	_clear_stream_mesh()
	if _stream_mesh != null:
		_stream_mesh.visible = false


func _process(delta: float) -> void:
	if not _streaming:
		return
	if _current_length < stream_length:
		var grow_rate := stream_length / maxf(grow_duration, 0.05)
		_current_length = minf(stream_length, _current_length + grow_rate * delta)
	_wobble_time += delta * wobble_speed
	_rebuild_stream_mesh()


func _cache_stream_basis() -> void:
	var dir := stream_direction
	if dir.length_squared() < 0.0001:
		dir = Vector3(0.0, -1.0, 0.15)
	_axis = dir.normalized()
	var up_hint := Vector3.UP
	if absf(_axis.dot(up_hint)) > 0.92:
		up_hint = Vector3.FORWARD
	_tangent = _axis.cross(up_hint).normalized()
	_bitangent = _axis.cross(_tangent).normalized()


func _setup_material() -> void:
	if _stream_mesh == null:
		return
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = BLOOD_COLOR
	_material.emission_enabled = false
	_material.roughness = 0.84
	_material.metallic = 0.0
	_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_stream_mesh.material_override = _material


func _lateral_wobble(t_norm: float) -> Vector3:
	var amp := wobble_amplitude * (0.25 + 0.75 * t_norm)
	var phase := t_norm * wobble_frequency - _wobble_time
	return _tangent * sin(phase) * amp + _bitangent * cos(phase * 1.27) * amp * 0.8


func _lump_factor(t_norm: float, angle: float) -> float:
	var a := angle * lump_frequency
	var t := t_norm * lump_frequency * 1.6
	var time := _wobble_time * 0.35
	var n1 := sin(a * 1.3 + t * 2.4 + time)
	var n2 := sin(a * 2.1 - t * 3.1 + time * 0.7)
	var n3 := cos(t * 4.8 + a * 0.6 - time * 0.5)
	var n4 := sin(t * 9.5 + time * 1.1) * 0.55
	return 1.0 + (n1 * 0.45 + n2 * 0.35 + n3 * 0.3 + n4) * lump_strength


func _radius_at(t_norm: float, angle: float) -> float:
	return stream_radius * _lump_factor(t_norm, angle)


func _point_along_stream(t_norm: float) -> Vector3:
	return _axis * (t_norm * _current_length) + _lateral_wobble(t_norm)


func _rebuild_stream_mesh() -> void:
	if _stream_mesh == null:
		return
	if _array_mesh == null:
		_array_mesh = ArrayMesh.new()
		_stream_mesh.mesh = _array_mesh

	if _current_length <= 0.002:
		_clear_stream_mesh()
		return

	var active_rings := maxi(2, int(round(float(ring_count) * (_current_length / stream_length))))

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for ring in active_rings + 1:
		var t_norm := float(ring) / float(active_rings)
		var center := _point_along_stream(t_norm)
		for side in side_segments:
			var angle := TAU * float(side) / float(side_segments)
			var offset := _tangent * cos(angle) + _bitangent * sin(angle)
			var radius := _radius_at(t_norm, angle)
			var vertex := center + offset * radius
			vertices.append(vertex)
			normals.append(offset)
			uvs.append(Vector2(float(side) / float(side_segments), t_norm))

	for ring in active_rings:
		for side in side_segments:
			var i0 := ring * side_segments + side
			var i1 := ring * side_segments + ((side + 1) % side_segments)
			var i2 := (ring + 1) * side_segments + side
			var i3 := (ring + 1) * side_segments + ((side + 1) % side_segments)
			indices.append_array([i0, i2, i1, i1, i2, i3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_array_mesh.clear_surfaces()
	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _clear_stream_mesh() -> void:
	if _array_mesh != null:
		_array_mesh.clear_surfaces()


func start_stream() -> void:
	if _streaming:
		return
	_streaming = true
	_wobble_time = 0.0
	_current_length = 0.0
	_cache_stream_basis()
	_clear_stream_mesh()
	if _stream_mesh != null:
		_stream_mesh.visible = true


func stop_stream() -> void:
	_streaming = false
	_current_length = 0.0
	if _stream_mesh != null:
		_stream_mesh.visible = false
	_clear_stream_mesh()


func is_streaming() -> bool:
	return _streaming
