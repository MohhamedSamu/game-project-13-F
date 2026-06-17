# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

extends CharacterBody3D

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 7.0
## Speed of jump.
@export var jump_velocity : float = 4.5
## How fast do we run?
@export var sprint_speed : float = 10.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "left"
## Name of Input Action to move Right.
@export var input_right : String = "right"
## Name of Input Action to move Forward.
@export var input_forward : String = "up"
## Name of Input Action to move Backward.
@export var input_back : String = "down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"

## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"

@export_group("Interacción")
@export var interaction_enabled: bool = true
@export var interaction_distance: float = 2.5
## Pickups: el punto de mira debe caer cerca del centro de pantalla (px).
@export var pickup_crosshair_radius_px: float = 42.0
## Solo si el rayo falla: recogibles muy cerca y bajo el retículo.
@export var pickup_close_aim_distance: float = 1.05
@export var dialogue_focus_speed: float = 2.5
@export var dialogue_focus_stop_threshold: float = 0.02
@export_range(0.0, 1.0) var dialogue_reposition_blend: float = 0.5
@export var dialogue_reposition_speed: float = 1.4
@export var dialogue_reposition_stop_threshold: float = 0.05
@export var input_interact: String = "interact"
@export var input_drop_item: String = "drop_item"
@export var input_flashlight_toggle: String = "flashlight_toggle"
## Si llevas algo y miras otro objeto recogible.
@export var prompt_need_drop_before_pickup: String = "Ya llevas un objeto en la mano. Pulsa [Q] para soltarlo antes de coger otro ([E])."

@export_group("Footsteps")
## Sonidos en subcarpetas de [code]footsteps_root[/code] (p. ej. Dirt, Grass). Vacío = no carga.
@export var footsteps_enabled: bool = true
@export var footsteps_root: String = "res://assets/audio/SFX/footsteps/"
## Carpeta por defecto si el suelo no tiene meta ni propiedad (debe existir bajo footsteps_root).
@export var footstep_default_surface: String = "Dirt"
## Distancia horizontal aproximada entre un pie y el otro (metros).
@export var footstep_stride_m: float = 2
## Velocidad horizontal mínima para considerar que caminas.
@export var footstep_min_speed: float = 0.2
@export_range(-80.0, 24.0) var footstep_volume_db: float = -6.0
@export_range(0.5, 2.0) var footstep_pitch_jitter: float = 1.08

@export_group("Salto / aterrizaje")
@export var jump_land_sfx_enabled: bool = true
@export var jump_sound: AudioStream
@export var land_sound: AudioStream
## Si no asignas [code]jump_sound[/code], usa un paso con tono más agudo (placeholder).
@export var jump_use_footstep_fallback: bool = true
## Si no asignas [code]land_sound[/code], usa un paso según el suelo.
@export var land_use_footstep_fallback: bool = true
@export_range(-80.0, 24.0) var jump_sfx_volume_db: float = -3.0
@export_range(-80.0, 24.0) var land_sfx_volume_db: float = -2.0
## Suma al volumen de pasos solo para el fallback de salto.
@export_range(-24.0, 12.0) var jump_footstep_volume_offset_db: float = -2.0
## Velocidad vertical hacia abajo mínima (m/s) antes de [code]move_and_slide[/code] para sonar aterrizaje.
@export var min_downward_speed_for_land: float = 1.2

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

var input_enabled: bool = true
var camera_focus_target: Node3D = null
var focusing_camera: bool = false
var repositioning_for_dialogue: bool = false
var dialogue_reposition_goal: Vector3 = Vector3.ZERO
var _interaction_crosshair: Control
var _held_pickup: Node3D
var _focus_interactable: Node

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer
@onready var jump_player: AudioStreamPlayer3D = $JumpPlayer
@onready var land_player: AudioStreamPlayer3D = $LandPlayer
@onready var camera_3d: Camera3D = $Head/Camera3D
@onready var hand_right: Marker3D = $Head/Camera3D/HandRight

## Nombre de carpeta (p. ej. "Dirt", "Grass", "Concrete", "Gravel") -> lista de streams cargados.
var _footstep_streams: Dictionary = {}
var _footstep_stride_accum: float = 0.0

func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	
	GameManager.register_player(self)
	
	# 1) quita pausa por si el menú pausaba algo
	get_tree().paused = false

	# 2) captura el mouse para POV
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if footsteps_enabled:
		_load_footstep_library()
		if footstep_player:
			footstep_player.volume_db = footstep_volume_db
	if jump_player:
		jump_player.volume_db = jump_sfx_volume_db
	if land_player:
		land_player.volume_db = land_sfx_volume_db

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capturing (no recapturar durante diálogo: el ratón debe seguir visible).
	if (
		not GameManager.dialogue_active
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		capture_mouse()
	# Solo en la pulsación real de ESC/ui_cancel (is_key_pressed rompe al cerrar el menú de pausa)
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		release_mouse()
	
	# Look around
	if input_enabled and mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func _physics_process(delta: float) -> void:
	if focusing_camera:
		_update_dialogue_camera_focus(delta)

	if input_enabled and interaction_enabled and mouse_captured and not freeflying:
		if Input.is_action_just_pressed(input_interact):
			_try_interact_focused()
		if Input.is_action_just_pressed(input_drop_item):
			_try_drop_held()
		if Input.is_action_just_pressed(input_flashlight_toggle):
			_try_toggle_held_flashlight()

	if not input_enabled:
		if repositioning_for_dialogue:
			_update_dialogue_reposition(delta)
		else:
			if not is_on_floor():
				velocity += get_gravity() * delta
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
		return
	
	# If freeflying, handle freefly and nothing else
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return

	var grounded_start := is_on_floor()
	var vy_before_move := velocity.y

	# Apply gravity to velocity
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta

	# Apply jumping
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity
			_footstep_stride_accum = 0.0
			if jump_land_sfx_enabled:
				_play_jump_sfx()

	# Modify speed based on sprinting
	if can_sprint and Input.is_action_pressed(input_sprint):
			move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Apply desired movement to velocity
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.y = 0
	
	# Use velocity to actually move
	move_and_slide()
	var grounded_end := is_on_floor()
	if jump_land_sfx_enabled and not freeflying and has_gravity:
		if grounded_end and not grounded_start and vy_before_move <= -min_downward_speed_for_land:
			_play_land_sfx()
			_footstep_stride_accum = 0.0
	if interaction_enabled and mouse_captured and not freeflying:
		_update_interaction_focus()
	if footsteps_enabled and not freeflying:
		_update_footsteps(delta)


## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


func enable_freefly() -> void:
	_set_collision_shapes_enabled(false)
	freeflying = true
	velocity = Vector3.ZERO


func disable_freefly() -> void:
	_set_collision_shapes_enabled(true)
	freeflying = false


func _set_collision_shapes_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not enabled


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


func _ensure_crosshair_ref() -> void:
	if _interaction_crosshair != null:
		return
	_interaction_crosshair = get_tree().get_first_node_in_group("interaction_crosshair") as Control


func _interaction_prompt(node: Node) -> String:
	if node == null:
		return ""
	if node.has_method("get_interaction_prompt"):
		var p: Variant = node.call("get_interaction_prompt")
		if p is String:
			return p as String
	if node.has_method("get_interaction_text"):
		var t: Variant = node.call("get_interaction_text")
		if t is String:
			return t as String
	return ""


func _interaction_ray_exclude_rids() -> Array[RID]:
	var exclude_rids: Array[RID] = [get_rid()]
	if _held_pickup != null:
		var rb_h := _held_pickup.find_child("RigidBody3D", true, false)
		if rb_h is CollisionObject3D:
			exclude_rids.append(rb_h.get_rid())
	return exclude_rids


func _collision_object_rid(collider: Object) -> RID:
	if collider is CollisionObject3D:
		return (collider as CollisionObject3D).get_rid()
	if collider is Node:
		var parent := (collider as Node).get_parent()
		if parent is CollisionObject3D:
			return (parent as CollisionObject3D).get_rid()
	return RID()


func _interaction_raycast() -> Dictionary:
	if camera_3d == null:
		return {}
	var dir := -camera_3d.global_basis.z.normalized()
	var origin := camera_3d.global_position
	var exclude_rids := _interaction_ray_exclude_rids()
	var traveled := 0.0
	const RAY_SKIN := 0.03

	while traveled < interaction_distance:
		var segment_len := interaction_distance - traveled
		var to := origin + dir * segment_len
		var pq := PhysicsRayQueryParameters3D.create(origin, to)
		pq.exclude = exclude_rids
		pq.collide_with_areas = true
		pq.collide_with_bodies = true
		var hit := get_world_3d().direct_space_state.intersect_ray(pq)
		if hit.is_empty():
			return {}
		var collider: Object = hit.get("collider")
		if _resolve_interactable(collider) != null:
			return hit
		var body_rid := _collision_object_rid(collider)
		if not body_rid.is_valid():
			return {}
		exclude_rids.append(body_rid)
		var hit_pos: Vector3 = hit.position
		var step := origin.distance_to(hit_pos) + RAY_SKIN
		traveled += step
		origin = hit_pos + dir * RAY_SKIN
	return {}


func _update_interaction_focus() -> void:
	_focus_interactable = null
	_ensure_crosshair_ref()
	if GameManager.dialogue_active:
		_apply_crosshair_ui(false, "")
		return
	var focus: Node = null
	var hit := _interaction_raycast()
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		focus = _resolve_interactable(collider)
	if focus == null:
		focus = _find_dialogue_aim_interactable()
	if focus == null:
		focus = _find_ray_target_aim_interactable()
	if focus == null:
		focus = _find_nearby_pickup_aim()
	if focus == null:
		_apply_crosshair_ui(false, "")
		return
	if focus.has_method("can_interact") and not focus.can_interact():
		_apply_crosshair_ui(false, "")
		return
	if focus.is_in_group("pickup") and not _is_pickup_aimed_at(focus):
		_apply_crosshair_ui(false, "")
		return
	_focus_interactable = focus
	var prompt: String = ""
	if _held_pickup != null and focus != _held_pickup and focus.is_in_group("pickup"):
		prompt = prompt_need_drop_before_pickup
	else:
		prompt = _interaction_prompt(focus)
	_apply_crosshair_ui(true, prompt)


func _is_aiming_at_dialogue_focus(interactable: Node) -> bool:
	if camera_3d == null:
		return false
	if interactable.has_method("is_player_aiming_at_dialogue_focus"):
		return interactable.is_player_aiming_at_dialogue_focus(camera_3d, interaction_distance)
	return false


func _find_dialogue_aim_interactable() -> Node:
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node.has_method("requires_dialogue_focus_aim") or not node.requires_dialogue_focus_aim():
			continue
		if node.has_method("can_interact") and not node.can_interact():
			continue
		if _is_aiming_at_dialogue_focus(node):
			return node
	return null


func _find_ray_target_aim_interactable() -> Node:
	if camera_3d == null:
		return null
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node.has_method("requires_specific_ray_target") or not node.requires_specific_ray_target():
			continue
		if node.has_method("can_interact") and not node.can_interact():
			continue
		if node.has_method("is_player_aiming_at_ray_target") and node.is_player_aiming_at_ray_target(camera_3d, interaction_distance):
			return node
	return null


func _pickup_aim_world_position(node: Node) -> Vector3:
	var target_pos: Vector3 = node.global_position
	var rb := node.find_child("RigidBody3D", true, false) as Node3D
	if rb != null:
		target_pos = rb.global_position
	var collision := node.find_child("CollisionShape3D", true, false) as CollisionShape3D
	if collision != null:
		target_pos = collision.global_position
	return target_pos


func _is_world_point_on_crosshair(world_pos: Vector3, radius_px: float) -> bool:
	if camera_3d == null:
		return false
	if camera_3d.is_position_behind(world_pos):
		return false
	var screen_pos: Vector2 = camera_3d.unproject_position(world_pos)
	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	return screen_pos.distance_to(center) <= radius_px


func _is_pickup_aimed_at(node: Node) -> bool:
	if camera_3d == null:
		return false
	var aim_pos: Vector3 = _pickup_aim_world_position(node)
	if not _is_world_point_on_crosshair(aim_pos, pickup_crosshair_radius_px):
		return false
	var cam_pos: Vector3 = camera_3d.global_position
	var look_dir: Vector3 = -camera_3d.global_basis.z.normalized()
	var to_target: Vector3 = aim_pos - cam_pos
	var dist: float = to_target.length()
	if dist > interaction_distance or dist < 0.02:
		return false
	var aim_dot: float = look_dir.dot(to_target / dist)
	return aim_dot > 0.92


func _find_nearby_pickup_aim() -> Node:
	if camera_3d == null:
		return null
	var cam_pos: Vector3 = camera_3d.global_position
	var best: Node = null
	var best_dist: float = pickup_close_aim_distance
	for node in get_tree().get_nodes_in_group("pickup"):
		if node == _held_pickup or not node.is_in_group("interactable"):
			continue
		if node.has_method("can_interact") and not node.can_interact():
			continue
		if not _is_pickup_aimed_at(node):
			continue
		var aim_pos: Vector3 = _pickup_aim_world_position(node)
		var dist: float = cam_pos.distance_to(aim_pos)
		if dist > pickup_close_aim_distance:
			continue
		if dist < best_dist:
			best_dist = dist
			best = node
	return best


func _resolve_interactable(collider: Object) -> Node:
	var n := collider as Node
	if n == null:
		return null

	var candidate := _find_interactable_on_ancestors(n)
	if candidate == null:
		candidate = _find_interactable_in_node_family(n)
	if candidate == null:
		return null

	if candidate.has_method("is_valid_interaction_hit") and not candidate.is_valid_interaction_hit(collider):
		return null

	if candidate.has_method("requires_dialogue_focus_aim") and candidate.requires_dialogue_focus_aim():
		if _is_aiming_at_dialogue_focus(candidate):
			return candidate
		return null

	return candidate


func _find_interactable_on_ancestors(node: Node) -> Node:
	var candidate := node
	while candidate != null:
		if candidate.is_in_group("interactable"):
			return candidate
		candidate = candidate.get_parent()
	return null


func _find_interactable_in_node_family(node: Node) -> Node:
	var current := node
	while current != null:
		var found := _find_interactable_on_ancestors(current)
		if found != null:
			return found
		found = _find_interactable_among_descendants(current)
		if found != null:
			return found
		found = _find_interactable_among_siblings(current)
		if found != null:
			return found
		current = current.get_parent()
	return null


func _find_interactable_among_siblings(node: Node) -> Node:
	var parent := node.get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child == node:
			continue
		if child.is_in_group("interactable"):
			return child
		var nested := _find_interactable_among_descendants(child)
		if nested != null:
			return nested
	return null


func _find_interactable_among_descendants(root: Node) -> Node:
	for child in root.get_children():
		if child.is_in_group("interactable"):
			return child
		var nested := _find_interactable_among_descendants(child)
		if nested != null:
			return nested
	return null


func _apply_crosshair_ui(active: bool, prompt: String) -> void:
	if _interaction_crosshair != null and _interaction_crosshair.has_method("update_focus"):
		_interaction_crosshair.call("update_focus", active, prompt)


func _try_interact_focused() -> void:
	if _focus_interactable == null:
		return
	if _focus_interactable.has_method("can_interact") and not _focus_interactable.can_interact():
		return
	if (
		_held_pickup == null
		and hand_right != null
		and _focus_interactable.is_in_group("pickup")
		and _focus_interactable.has_method("pickup_to_hand")
	):
		_focus_interactable.pickup_to_hand(hand_right)
		_held_pickup = _focus_interactable as Node3D
		return
	if _focus_interactable.has_method("interact"):
		_focus_interactable.interact()


func _try_drop_held() -> void:
	if _held_pickup == null or camera_3d == null:
		return
	if _held_pickup.has_method("drop_soft"):
		var fwd := -camera_3d.global_basis.z
		var drop_parent := get_parent()
		if drop_parent == null:
			drop_parent = self
		_held_pickup.drop_soft(fwd, drop_parent)
		_held_pickup = null


func _try_toggle_held_flashlight() -> void:
	if _held_pickup != null and _held_pickup.has_method("toggle_spotlight"):
		_held_pickup.toggle_spotlight()


func is_holding_item(item_id: StringName) -> bool:
	if _held_pickup == null or item_id == StringName():
		return false
	if _held_pickup.has_method("get_item_id"):
		return _held_pickup.get_item_id() == item_id
	if "item_id" in _held_pickup:
		return _held_pickup.item_id == item_id
	return false


func consume_held_item(item_id: StringName) -> bool:
	if not is_holding_item(item_id):
		return false
	var item := _held_pickup
	_held_pickup = null
	if is_instance_valid(item):
		item.queue_free()
	return true


func _load_footstep_library() -> void:
	_footstep_streams.clear()
	var root := footsteps_root
	if not root.ends_with("/"):
		root += "/"
	var d_root := DirAccess.open(root)
	if d_root == null:
		push_warning("ProtoController: no se puede abrir footsteps_root: %s" % root)
		return
	d_root.list_dir_begin()
	var sub := d_root.get_next()
	while sub != "":
		if d_root.current_is_dir() and not sub.begins_with("."):
			var subpath := root + sub + "/"
			var streams: Array[AudioStream] = []
			var d_sub := DirAccess.open(subpath)
			if d_sub != null:
				d_sub.list_dir_begin()
				var fn := d_sub.get_next()
				while fn != "":
					if not d_sub.current_is_dir():
						var lower := fn.to_lower()
						if lower.ends_with(".ogg") or lower.ends_with(".wav") or lower.ends_with(".mp3"):
							var res_path := subpath + fn
							var st: Resource = load(res_path)
							if st is AudioStream:
								streams.append(st)
					fn = d_sub.get_next()
				d_sub.list_dir_end()
			if not streams.is_empty():
				_footstep_streams[sub] = streams
		sub = d_root.get_next()
	d_root.list_dir_end()
	if _footstep_streams.is_empty():
		push_warning("ProtoController: no hay clips en subcarpetas de %s" % root)


func _footstep_key_for_name(surface_name: String) -> String:
	if _footstep_streams.has(surface_name):
		return surface_name
	for k in _footstep_streams.keys():
		if String(k).nocasecmp_to(surface_name) == 0:
			return k
	if _footstep_streams.has(footstep_default_surface):
		return footstep_default_surface
	for k in _footstep_streams.keys():
		if String(k).nocasecmp_to(footstep_default_surface) == 0:
			return k
	var all_keys := _footstep_streams.keys()
	if all_keys.is_empty():
		return ""
	return String(all_keys[0])


func _resolve_footstep_surface(collider: Object) -> String:
	var n := collider as Node
	while n != null:
		if n.has_meta("footstep_surface"):
			return str(n.get_meta("footstep_surface"))
		if "footstep_surface" in n:
			var v: Variant = n.get("footstep_surface")
			if v is String:
				return v
		n = n.get_parent()
	return footstep_default_surface


func _floor_collider() -> Object:
	if not is_on_floor():
		return null
	var best_y := 0.0
	var best: Object = null
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var ny := col.get_normal().y
		if ny > best_y:
			best_y = ny
			best = col.get_collider()
	return best


func _update_footsteps(delta: float) -> void:
	if _footstep_streams.is_empty() or footstep_player == null:
		return
	if not is_on_floor():
		_footstep_stride_accum = 0.0
		return
	var hspeed := Vector3(velocity.x, 0.0, velocity.z).length()
	if hspeed < footstep_min_speed:
		_footstep_stride_accum = 0.0
		return
	_footstep_stride_accum += hspeed * delta
	while _footstep_stride_accum >= footstep_stride_m:
		_footstep_stride_accum -= footstep_stride_m
		_play_footstep()


func _get_random_footstep_stream() -> AudioStream:
	if _footstep_streams.is_empty():
		return null
	var collider_obj := _floor_collider()
	var surface_name := _resolve_footstep_surface(collider_obj) if collider_obj != null else footstep_default_surface
	var key := _footstep_key_for_name(surface_name)
	if key.is_empty():
		return null
	var streams: Array = _footstep_streams[key] as Array
	if streams.is_empty():
		return null
	return streams.pick_random() as AudioStream


func _play_footstep() -> void:
	if footstep_player == null:
		return
	var stream := _get_random_footstep_stream()
	if stream == null:
		return
	footstep_player.stream = stream
	footstep_player.volume_db = footstep_volume_db
	footstep_player.pitch_scale = randf_range(1.0 / footstep_pitch_jitter, footstep_pitch_jitter)
	footstep_player.play()


func _play_jump_sfx() -> void:
	if jump_player == null:
		return
	if jump_sound != null:
		jump_player.stream = jump_sound
		jump_player.volume_db = jump_sfx_volume_db
		jump_player.pitch_scale = randf_range(0.96, 1.04)
		jump_player.play()
	elif jump_use_footstep_fallback and footsteps_enabled:
		var stream := _get_random_footstep_stream()
		if stream == null:
			return
		jump_player.stream = stream
		jump_player.volume_db = footstep_volume_db + jump_footstep_volume_offset_db
		jump_player.pitch_scale = randf_range(1.1, 1.32)
		jump_player.play()


func _play_land_sfx() -> void:
	if land_player == null:
		return
	if land_sound != null:
		land_player.stream = land_sound
		land_player.volume_db = land_sfx_volume_db
		land_player.pitch_scale = randf_range(0.94, 1.06)
		land_player.play()
	elif land_use_footstep_fallback and footsteps_enabled:
		var stream := _get_random_footstep_stream()
		if stream == null:
			return
		land_player.stream = stream
		land_player.volume_db = land_sfx_volume_db
		land_player.pitch_scale = randf_range(0.88, 1.02)
		land_player.play()


## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false

func focus_camera_on(target: Node3D) -> void:
	camera_focus_target = target
	focusing_camera = target != null


func clear_camera_focus() -> void:
	camera_focus_target = null
	focusing_camera = false
	clear_dialogue_reposition()


func start_dialogue_reposition(ideal_position: Vector3) -> void:
	dialogue_reposition_goal = global_position.lerp(ideal_position, dialogue_reposition_blend)
	var horizontal_delta := Vector2(
		global_position.x - dialogue_reposition_goal.x,
		global_position.z - dialogue_reposition_goal.z
	).length()
	if horizontal_delta < dialogue_reposition_stop_threshold:
		repositioning_for_dialogue = false
		return
	repositioning_for_dialogue = true
	velocity = Vector3.ZERO


func reposition_for_dialogue(ideal_position: Vector3) -> void:
	start_dialogue_reposition(ideal_position)
	if not repositioning_for_dialogue:
		return
	while repositioning_for_dialogue:
		await get_tree().physics_frame


func clear_dialogue_reposition() -> void:
	repositioning_for_dialogue = false
	velocity.x = 0.0
	velocity.z = 0.0


func _update_dialogue_reposition(delta: float) -> void:
	var current := global_position
	var goal := dialogue_reposition_goal
	var to_goal := Vector3(goal.x - current.x, 0.0, goal.z - current.z)
	var dist := to_goal.length()
	if dist < dialogue_reposition_stop_threshold:
		repositioning_for_dialogue = false
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	var step := minf(dist, dialogue_reposition_speed * delta)
	var horizontal_motion := to_goal.normalized() * step
	# Solo deslizamiento cinemático: evita empujar al NPC con move_and_collide.
	global_position = Vector3(
		current.x + horizontal_motion.x,
		current.y,
		current.z + horizontal_motion.z,
	)


func _update_dialogue_camera_focus(delta: float) -> void:
	if camera_focus_target == null:
		focusing_camera = false
		return

	var target_pos := camera_focus_target.global_position
	var camera_pos := camera_3d.global_position
	var direction := (target_pos - camera_pos).normalized()

	var target_yaw := atan2(-direction.x, -direction.z)
	look_rotation.y = lerp_angle(look_rotation.y, target_yaw, dialogue_focus_speed * delta)

	var local_direction := global_transform.basis.inverse() * direction
	var target_pitch := atan2(local_direction.y, -local_direction.z)
	target_pitch = clamp(target_pitch, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.x = lerp_angle(look_rotation.x, target_pitch, dialogue_focus_speed * delta)

	transform.basis = Basis()
	rotate_y(look_rotation.y)

	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)

	if (
		abs(angle_difference(look_rotation.y, target_yaw)) < dialogue_focus_stop_threshold
		and abs(angle_difference(look_rotation.x, target_pitch)) < dialogue_focus_stop_threshold
	):
		focusing_camera = false


func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not input_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		_focus_interactable = null
		_apply_crosshair_ui(false, "")
