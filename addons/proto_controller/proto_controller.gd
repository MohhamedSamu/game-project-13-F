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
var _interaction_crosshair: Control
var _held_pickup: Node3D
var _focus_interactable: Node

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
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
	# Mouse capturing
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		capture_mouse()
	# Solo en la pulsación real de ESC/ui_cancel (is_key_pressed rompe al cerrar el menú de pausa)
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		release_mouse()
	
	# Look around
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func _physics_process(delta: float) -> void:
	if input_enabled and interaction_enabled and mouse_captured and not freeflying:
		if Input.is_action_just_pressed(input_interact):
			_try_interact_focused()
		if Input.is_action_just_pressed(input_drop_item):
			_try_drop_held()
		if Input.is_action_just_pressed(input_flashlight_toggle):
			_try_toggle_held_flashlight()

	if not input_enabled:
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


func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false


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


func _interaction_raycast() -> Dictionary:
	if camera_3d == null:
		return {}
	var dir := -camera_3d.global_basis.z.normalized()
	var origin := camera_3d.global_position + dir * 0.12
	var to := origin + dir * interaction_distance
	var exclude_rids: Array[RID] = [self.get_rid()]
	if _held_pickup != null:
		var rb_h := _held_pickup.find_child("RigidBody3D", true, false)
		if rb_h is CollisionObject3D:
			exclude_rids.append(rb_h.get_rid())
	var pq := PhysicsRayQueryParameters3D.create(origin, to)
	pq.exclude = exclude_rids
	pq.collide_with_areas = true
	pq.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(pq)
	if hit.is_empty():
		return {}
	var hit_pos: Vector3 = hit.position
	if origin.distance_to(hit_pos) > interaction_distance:
		return {}
	return hit


func _update_interaction_focus() -> void:
	_focus_interactable = null
	_ensure_crosshair_ref()
	if GameManager.dialogue_active:
		_apply_crosshair_ui(false, "")
		return
	var hit := _interaction_raycast()
	if hit.is_empty():
		_apply_crosshair_ui(false, "")
		return
	var collider: Object = hit.get("collider")
	var focus := _resolve_interactable(collider)
	if focus == null:
		_apply_crosshair_ui(false, "")
		return
	if focus.has_method("can_interact") and not focus.can_interact():
		_apply_crosshair_ui(false, "")
		return
	_focus_interactable = focus
	var prompt: String = ""
	if _held_pickup != null and focus != _held_pickup and focus.is_in_group("pickup"):
		prompt = prompt_need_drop_before_pickup
	else:
		prompt = _interaction_prompt(focus)
	_apply_crosshair_ui(true, prompt)


func _resolve_interactable(collider: Object) -> Node:
	var n := collider as Node
	while n != null:
		if n.is_in_group("interactable"):
			return n
		n = n.get_parent()
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

func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not input_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		_focus_interactable = null
		_apply_crosshair_ui(false, "")
