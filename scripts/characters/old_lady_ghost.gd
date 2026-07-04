extends Node3D
## Actor OldLadyGhost: aparición estática detrás de ventana (sin IA, diálogo ni jumpscare).

const FALLBACK_HEAD_LIGHT_POS := Vector3(0.0, 3.52, 0.12)
const FALLBACK_CHEST_LIGHT_POS := Vector3(0.0, 3.1, 0.5)

@export var start_hidden: bool = true
@export var play_full_idle_before_stretch: bool = true
@export var idle_hold_before_stretch: float = 3.0
@export var idle_animation_name: String = "old_lady_idle"
@export var stretch_animation_name: String = "neck_stretching_trim2"
@export var stretch_blend_time: float = 0.85
@export_range(0.1, 1.5, 0.05) var stretch_playback_speed: float = 0.58

@export_group("Reveal Light")
@export var use_reveal_light: bool = true
@export var reveal_light_energy: float = 2.65
@export var reveal_light_range: float = 3.2
@export var reveal_light_color: Color = Color(0.74, 0.82, 0.96, 1.0)
@export var reveal_light_attenuation: float = 2.0

@export_group("Face Light")
@export var use_face_light: bool = true
@export var reveal_face_light_energy: float = 2.0
@export_range(20.0, 70.0, 1.0) var reveal_face_spot_angle: float = 46.0
@export var reveal_face_light_range: float = 3.2
@export var reveal_face_light_color: Color = Color(0.78, 0.86, 0.98, 1.0)
@export_range(0.0, 2.0, 0.05) var reveal_face_spot_attenuation: float = 0.92

@export_group("Editor")
@export var preview_reveal_lights: bool = true

@onready var _model_root: Node3D = $Model
@onready var _head_light_anchor: Marker3D = $RevealLights/HeadLightAnchor
@onready var _chest_light_anchor: Marker3D = $RevealLights/ChestLightAnchor
@onready var _reveal_light: OmniLight3D = $RevealLights/ChestLightAnchor/OldLadyRevealLight
@onready var _face_light: SpotLight3D = $RevealLights/HeadLightAnchor/FaceLightAnchor/OldLadyFaceLight

var _reveal_running: bool = false
var _lights_active: bool = false
var _lock_reveal_light_positions: bool = false
var _skeleton: Skeleton3D
var _head_bone_idx: int = -1


func _ready() -> void:
	_apply_fallback_light_positions()
	_cache_bones()
	_configure_reveal_lights()

	if Engine.is_editor_hint() and preview_reveal_lights:
		visible = true
		_sync_lights_to_head_bone()
		_set_reveal_lights_active(true)
		return

	if start_hidden:
		set_visible_state(false)
	else:
		_play_idle()


func _process(_delta: float) -> void:
	if _lights_active and not _lock_reveal_light_positions:
		_sync_lights_to_head_bone()


func reveal() -> void:
	if _reveal_running:
		return
	_reveal_running = true
	await _run_reveal_sequence()


func hide_ghost() -> void:
	_reveal_running = false
	_lock_reveal_light_positions = false
	var model := _get_model()
	if model != null:
		model.stop_animations()
	_set_reveal_lights_active(false)
	set_visible_state(false)


func play_idle() -> void:
	_play_idle()


func play_neck_stretching() -> void:
	_play_stretch()


func set_visible_state(value: bool) -> void:
	visible = value
	if not value:
		_set_reveal_lights_active(false)


func _run_reveal_sequence() -> void:
	var model := _get_model()
	if model == null:
		push_warning("OldLadyGhost: OldLadyGhostModel no encontrado.")
		_reveal_running = false
		return

	_cache_bones()
	_lock_reveal_light_positions = true
	_apply_fallback_light_positions()
	visible = true
	_set_reveal_lights_active(true)

	model.ensure_animations_ready()
	_cache_bones()

	if model.has_method("play_reveal_sequence"):
		await model.play_reveal_sequence(
			idle_animation_name,
			play_full_idle_before_stretch,
			idle_hold_before_stretch,
			stretch_animation_name,
			stretch_blend_time,
			stretch_playback_speed
		)
	else:
		_play_idle()
		if play_full_idle_before_stretch:
			await get_tree().create_timer(_get_idle_cycle_duration(model)).timeout
		elif idle_hold_before_stretch > 0.0:
			await get_tree().create_timer(idle_hold_before_stretch).timeout
		if _reveal_running:
			_play_stretch()

	_reveal_running = false


func _get_model() -> Node:
	if _model_root == null:
		return null
	return _model_root.get_node_or_null("OldLadyGhostModel")


func _play_idle() -> void:
	var model := _get_model()
	if model != null:
		model.play_animation(idle_animation_name)


func _play_stretch() -> void:
	var model := _get_model()
	if model != null:
		model.play_animation(stretch_animation_name, -1.0, stretch_playback_speed)


func _get_idle_cycle_duration(model: Node) -> float:
	if model.has_method("get_animation_length"):
		var length: float = model.get_animation_length(idle_animation_name)
		if length > 0.0:
			return length
	return idle_hold_before_stretch


func _cache_bones() -> void:
	_skeleton = null
	_head_bone_idx = -1
	var model := _get_model()
	if model == null:
		return
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		return
	_head_bone_idx = _find_bone_index(_skeleton, "Head", ["HeadTop"])


func _find_bone_index(skeleton: Skeleton3D, token: String, exclude_tokens: Array[String] = []) -> int:
	for bone_idx in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone_idx)
		var excluded := false
		for exclude_token in exclude_tokens:
			if exclude_token in bone_name:
				excluded = true
				break
		if excluded:
			continue
		if token in bone_name:
			return bone_idx
	return -1


func _apply_fallback_light_positions() -> void:
	if _head_light_anchor != null:
		_head_light_anchor.position = FALLBACK_HEAD_LIGHT_POS
	if _chest_light_anchor != null:
		_chest_light_anchor.position = FALLBACK_CHEST_LIGHT_POS


func _sync_lights_to_head_bone() -> void:
	if _head_light_anchor == null or _chest_light_anchor == null:
		return

	if _skeleton == null or _head_bone_idx < 0:
		_apply_fallback_light_positions()
		return

	_skeleton.force_update_bone_child_transform(0)
	var head_global := _skeleton.get_bone_global_pose(_head_bone_idx)
	var head_local := global_transform.affine_inverse() * head_global

	if head_local.origin.y < 2.0 or head_local.origin.y > 5.5:
		_apply_fallback_light_positions()
		return

	_head_light_anchor.position = head_local.origin + Vector3(0.0, 0.04, 0.12)
	_chest_light_anchor.position = head_local.origin + Vector3(0.0, -0.42, 0.38)


func _configure_reveal_lights() -> void:
	if _reveal_light == null:
		push_warning("OldLadyGhost: OldLadyRevealLight no encontrada en RevealLights/ChestLightAnchor.")
	if _face_light == null:
		push_warning("OldLadyGhost: OldLadyFaceLight no encontrada en RevealLights/HeadLightAnchor.")

	if _reveal_light != null:
		_reveal_light.light_color = reveal_light_color
		_reveal_light.omni_range = reveal_light_range
		_reveal_light.omni_attenuation = reveal_light_attenuation
		_reveal_light.shadow_enabled = false

	if _face_light != null:
		_face_light.light_color = reveal_face_light_color
		_face_light.spot_range = reveal_face_light_range
		_face_light.spot_angle = reveal_face_spot_angle
		_face_light.spot_attenuation = reveal_face_spot_attenuation
		_face_light.shadow_enabled = false

	if not (Engine.is_editor_hint() and preview_reveal_lights):
		_set_reveal_lights_active(false)


func _set_reveal_lights_active(active: bool) -> void:
	_lights_active = active
	if not active:
		_lock_reveal_light_positions = false

	if _reveal_light != null and use_reveal_light:
		_reveal_light.visible = true
		_reveal_light.light_color = reveal_light_color
		_reveal_light.omni_range = reveal_light_range
		_reveal_light.omni_attenuation = reveal_light_attenuation
		_reveal_light.light_energy = reveal_light_energy if active else 0.0

	if _face_light != null and use_face_light:
		_face_light.visible = true
		_face_light.light_color = reveal_face_light_color
		_face_light.spot_range = reveal_face_light_range
		_face_light.spot_angle = reveal_face_spot_angle
		_face_light.spot_attenuation = reveal_face_spot_attenuation
		_face_light.light_energy = reveal_face_light_energy if active else 0.0
