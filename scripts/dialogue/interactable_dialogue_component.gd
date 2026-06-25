class_name InteractableDialogueComponent
extends Area3D
## Diálogo al presionar E dentro de esta área. Reutilizable en puertas, props o NPCs.

@export var dialogue_resource: DialogueResource
@export var dialogue_title: String = "locked"
@export var prompt_text: String = "Presiona [E] para interactuar"

@export var enabled: bool = true
@export var trigger_once: bool = false
@export var already_triggered: bool = false

@export var requires_focus_hitbox: bool = false
@export var focus_hitbox_group: String = "interactable_focus"
@export var require_specific_ray_target: bool = false
@export var ray_target_group: String = "interactable_ray_target"
@export var proximity_radius: float = 2.5

@export_group("Interaction")
@export var interaction_handler: Node
@export var proximity_center_offset: Vector3 = Vector3.ZERO
@export var require_line_of_sight: bool = true
@export_range(0.0, 2.0, 0.05) var line_of_sight_margin: float = 0.25

@export_group("Camera Focus")
@export var use_camera_focus: bool = true
@export var focus_target: Node3D
@export var auto_find_focus_target: bool = true
@export var focus_target_node_name: String = "DialogueFocusPoint"

@export_group("Flags")
@export var set_flag_on_finish: String = ""
@export var set_flag_on_finish_value: bool = true

var player_near: bool = false
var _preparing_dialogue: bool = false

## Capa física dedicada para InteractionRayTarget (layer 3 = bit 4).
const RAY_TARGET_COLLISION_LAYER: int = 4


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = not require_specific_ray_target
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if require_specific_ray_target:
		_configure_ray_target()


func refresh_ray_target() -> void:
	if require_specific_ray_target:
		_configure_ray_target()


func _get_focus_target() -> Node3D:
	return DialogueFocusResolver.resolve_focus_target(
		use_camera_focus,
		focus_target,
		auto_find_focus_target,
		focus_target_node_name,
		self
	)


func _get_aim_focus_target() -> Node3D:
	return DialogueFocusResolver.resolve_focus_target(
		true,
		focus_target,
		auto_find_focus_target,
		focus_target_node_name,
		self
	)


func _get_proximity_center() -> Vector3:
	var target := _get_aim_focus_target()
	var base: Vector3
	if target != null:
		base = target.global_position
	else:
		base = global_position
	if proximity_center_offset != Vector3.ZERO:
		var setup := get_parent() as Node3D
		if setup != null:
			base += setup.global_transform.basis * proximity_center_offset
	return base


func _is_player_in_range() -> bool:
	var player := GameManager.player
	if player == null:
		return false
	var center := _get_proximity_center()
	if player.global_position.distance_to(center) > proximity_radius:
		player_near = false
		return false
	if require_specific_ray_target and require_line_of_sight and not _has_clear_line_of_sight(_get_line_of_sight_origin(player), center):
		return false
	return true


func is_player_in_proximity() -> bool:
	return enabled and _is_player_in_range()


func can_interact() -> bool:
	if _preparing_dialogue:
		return false
	if not enabled:
		return false
	if GameManager.dialogue_active:
		return false
	if GameManager.minigame_active:
		return false
	if not _is_player_in_range():
		return false
	if trigger_once and already_triggered:
		return false
	if interaction_handler != null:
		if interaction_handler.has_method("can_handle_interaction"):
			return interaction_handler.can_handle_interaction()
		return true
	if dialogue_resource == null:
		return false
	return true


func interact() -> void:
	if not can_interact():
		return
	if interaction_handler != null and interaction_handler.has_method("handle_interaction"):
		interaction_handler.handle_interaction()
		return
	_begin_dialogue_interaction()


func _begin_dialogue_interaction() -> void:
	_preparing_dialogue = true
	await _await_dialogue_preparation()
	_preparing_dialogue = false

	if not enabled:
		return
	if GameManager.dialogue_active:
		return
	if not _is_player_in_range():
		return
	if trigger_once and already_triggered:
		return
	if dialogue_resource == null:
		return

	if trigger_once:
		already_triggered = true
	if set_flag_on_finish != "":
		DialogueController.dialogue_finished.connect(
			_on_dialogue_finished_apply_flag,
			CONNECT_ONE_SHOT
		)
	DialogueController.start_dialogue(dialogue_resource, dialogue_title, _get_focus_target())


func _await_dialogue_preparation() -> void:
	var player := GameManager.get_player() as Node3D
	if player == null:
		return
	var dialogue_owner := _get_dialogue_owner()
	if dialogue_owner != null and dialogue_owner.has_method("prepare_dialogue_interaction"):
		await dialogue_owner.prepare_dialogue_interaction(player)


func _get_dialogue_owner() -> Node:
	return get_parent()


func _on_dialogue_finished_apply_flag() -> void:
	if set_flag_on_finish != "":
		GameManager.set_flag(set_flag_on_finish, set_flag_on_finish_value)


func get_interaction_prompt() -> String:
	if interaction_handler != null and interaction_handler.has_method("get_interaction_prompt"):
		var custom_prompt: Variant = interaction_handler.get_interaction_prompt()
		if custom_prompt is String:
			return custom_prompt as String
	return prompt_text


func requires_dialogue_focus_aim() -> bool:
	return requires_focus_hitbox


func get_focus_hitbox_group() -> String:
	return focus_hitbox_group


func requires_specific_ray_target() -> bool:
	return require_specific_ray_target


func get_ray_target_group() -> String:
	return ray_target_group


func is_valid_interaction_hit(collider: Object) -> bool:
	if not require_specific_ray_target:
		return true
	return _collider_belongs_to_ray_target(collider)


func is_player_aiming_at_ray_target(camera: Camera3D, max_distance: float = 2.5) -> bool:
	if not require_specific_ray_target or camera == null:
		return false
	var ray_target := _get_ray_target_area()
	if ray_target == null:
		return false

	var direction := (-camera.global_basis.z).normalized()
	var origin := camera.global_position + direction * 0.12
	var to := origin + direction * max_distance
	var space := get_world_3d().direct_space_state
	if space == null:
		return false

	var pq := PhysicsRayQueryParameters3D.create(origin, to)
	pq.collision_mask = RAY_TARGET_COLLISION_LAYER
	pq.collide_with_areas = true
	pq.collide_with_bodies = false

	var hit := space.intersect_ray(pq)
	if hit.is_empty():
		return false
	if not _collider_belongs_to_ray_target(hit.get("collider")):
		return false
	if not require_line_of_sight:
		return true
	return _has_clear_line_of_sight(origin, hit.get("position"))


func _get_line_of_sight_origin(player: Node3D) -> Vector3:
	return player.global_position + Vector3(0.0, 1.4, 0.0)


func _has_clear_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var pq := PhysicsRayQueryParameters3D.create(from, to)
	pq.collide_with_areas = false
	pq.collide_with_bodies = true
	pq.hit_from_inside = true
	var player := GameManager.player
	if player is CollisionObject3D:
		pq.exclude = [(player as CollisionObject3D).get_rid()]
	var block_hit := space.intersect_ray(pq)
	if block_hit.is_empty():
		return true
	var hit_dist: float = from.distance_to(block_hit.get("position"))
	var target_dist: float = from.distance_to(to)
	return hit_dist >= target_dist - line_of_sight_margin


func _get_ray_target_area() -> Area3D:
	var setup_root := get_parent()
	if setup_root == null:
		return null
	return setup_root.get_node_or_null("InteractionRayTarget") as Area3D


func _configure_ray_target() -> void:
	var ray_target := _get_ray_target_area()
	if ray_target == null:
		push_warning("%s: require_specific_ray_target activo pero falta InteractionRayTarget (Area3D)." % name)
		return
	ray_target.collision_layer = RAY_TARGET_COLLISION_LAYER
	ray_target.collision_mask = 0
	ray_target.monitoring = false
	ray_target.monitorable = true
	if not ray_target.is_in_group(ray_target_group):
		ray_target.add_to_group(ray_target_group)


func _collider_belongs_to_ray_target(collider: Object) -> bool:
	if ray_target_group.is_empty():
		return false
	var hit_node := collider as Node
	if hit_node == null:
		return false
	var current: Node = hit_node
	while current != null:
		if current.is_in_group(ray_target_group):
			return _is_target_under_same_setup(current)
		current = current.get_parent()
	return false


func _is_target_under_same_setup(target_node: Node) -> bool:
	var setup_root := get_parent()
	if setup_root == null:
		return false
	return target_node == setup_root or setup_root.is_ancestor_of(target_node)


func get_dialogue_focus_radius() -> float:
	var target := _get_aim_focus_target()
	if target == null:
		return 0.85
	var shape_node := target.get_node_or_null("FocusHitbox/CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is SphereShape3D:
		var local_radius: float = (shape_node.shape as SphereShape3D).radius
		var scale := shape_node.global_transform.basis.get_scale()
		return local_radius * maxf(scale.x, maxf(scale.y, scale.z))
	return 0.85


func is_player_aiming_at_dialogue_focus(camera: Camera3D, max_distance: float = 2.5) -> bool:
	var target := _get_aim_focus_target()
	if camera == null or target == null:
		return false
	var origin := camera.global_position
	var direction := (-camera.global_basis.z).normalized()
	var center := target.global_position
	return _ray_hits_sphere_forward(origin, direction, center, get_dialogue_focus_radius(), max_distance)


func _ray_hits_sphere_forward(origin: Vector3, direction: Vector3, center: Vector3, radius: float, max_distance: float) -> bool:
	var oc := origin - center
	var a := direction.dot(direction)
	var b := 2.0 * oc.dot(direction)
	var c := oc.dot(oc) - radius * radius
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return false
	var sqrt_d := sqrt(discriminant)
	var inv_2a := 1.0 / (2.0 * a)
	for t in [(-b - sqrt_d) * inv_2a, (-b + sqrt_d) * inv_2a]:
		if t > 0.0 and t <= max_distance:
			return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
