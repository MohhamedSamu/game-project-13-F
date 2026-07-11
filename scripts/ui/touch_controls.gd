extends Control
## Controles táctiles para móvil (in-game, level 2).
## Solo se activan si el dispositivo tiene pantalla táctil: en PC no hacen nada.
##
## Componentes:
##  - Joystick virtual (zona inferior-izquierda, flotante): alimenta las acciones
##    "left/right/up/down" con Input.action_press(strength), igual que el stick del gamepad.
##  - Botones (TouchScreenButton, multitáctil, disparan las MISMAS acciones del InputMap):
##      E  -> interact (también recoge objetos, mismo flujo que teclado)
##      F  -> flashlight_toggle
##      Q  -> drop_item
##      ↑  -> jump
##      »  -> sprint (toggle: tap para correr, tap para dejar de correr)
##  - Botón hamburguesa (esquina superior derecha): abre el menú de pausa (equivale a Esc).
##  - Look táctil multitáctil: arrastrar con un dedo en zona libre gira la cámara.
##    El primer dedo (index 0) ya funciona hoy vía ratón emulado (no se toca ese camino);
##    aquí se añade el giro con dedos adicionales (index > 0) para poder moverse y mirar a la vez.

const ACTION_LEFT := "left"
const ACTION_RIGHT := "right"
const ACTION_FORWARD := "up"
const ACTION_BACK := "down"
const ACTION_SPRINT := "sprint"

const FONT_PATH := "res://assets/fonts/roboto/Roboto-Black.ttf"

## Sensibilidad del giro con dedos secundarios (1.0 = igual que el ratón/dedo primario).
@export var touch_look_sensitivity: float = 1.0
## Radio del joystick (px lógicos) y del knob.
@export var joystick_radius: float = 92.0
@export var knob_radius: float = 38.0
## Zona muerta radial del joystick (0-1).
@export_range(0.0, 0.5, 0.01) var joystick_deadzone: float = 0.14

var _is_touch: bool = false

# --- Joystick ---
var _joystick_zone := Rect2()
var _joystick_default_center := Vector2.ZERO
var _joystick_center := Vector2.ZERO
var _knob_pos := Vector2.ZERO
var _joystick_finger: int = -1
var _move_vector := Vector2.ZERO

# --- Look táctil (dedos secundarios) ---
var _look_fingers: Dictionary = {}

# --- Zonas de control (para hit-test y bloqueo de ratón emulado) ---
var _cluster_zone := Rect2()
var _hamburger_zone := Rect2()

# --- Nodos construidos por código ---
var _btn_interact: TouchScreenButton
var _btn_jump: TouchScreenButton
var _btn_drop: TouchScreenButton
var _btn_flashlight: TouchScreenButton
var _btn_sprint: TouchScreenButton
var _btn_pause: TouchScreenButton
var _btn_exit_minigame: TouchScreenButton
var _blocker_joystick: Control
var _blocker_cluster: Control
var _blocker_hamburger: Control
var _label_font: FontFile

var _sprint_on: bool = false
var _gameplay_controls_visible: bool = true


func _ready() -> void:
	_is_touch = DisplayServer.is_touchscreen_available()
	if not _is_touch:
		visible = false
		set_process(false)
		set_process_input(false)
		return

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# ALWAYS: al pausar, _input debe seguir recibiendo el "release" del dedo para no
	# dejar acciones de movimiento pegadas, y _process debe ocultar los controles.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label_font = load(FONT_PATH) as FontFile

	_build_blockers()
	_build_buttons()
	_layout()
	get_viewport().size_changed.connect(_layout)


# =============================================================================
# CONSTRUCCIÓN DE UI
# =============================================================================

func _build_blockers() -> void:
	# Controles transparentes con mouse_filter STOP: se comen el ratón EMULADO del
	# primer dedo cuando cae sobre el joystick/botones, para que ese arrastre no
	# gire la cámara (ProtoController escucha MouseMotion en _unhandled_input).
	# Los TouchScreenButton usan el toque crudo, así que siguen funcionando debajo.
	_blocker_joystick = _make_blocker("JoystickBlocker")
	_blocker_cluster = _make_blocker("ClusterBlocker")
	_blocker_hamburger = _make_blocker("HamburgerBlocker")


func _make_blocker(blocker_name: String) -> Control:
	var blocker := Control.new()
	blocker.name = blocker_name
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)
	return blocker


func _build_buttons() -> void:
	_btn_interact = _make_action_button("InteractButton", "E", 52.0, "interact")
	_btn_jump = _make_action_button("JumpButton", "↑", 44.0, "jump")
	_btn_drop = _make_action_button("DropButton", "Q", 38.0, "drop_item")
	_btn_flashlight = _make_action_button("FlashlightButton", "F", 38.0, "flashlight_toggle")
	# Sprint es toggle (tap enciende / tap apaga): sin action directa, se maneja por señal.
	_btn_sprint = _make_action_button("SprintButton", "»", 44.0, "")
	_btn_sprint.pressed.connect(_on_sprint_toggled)

	# Salir del minijuego del baño: envía ui_cancel (misma salida que Esc/Start).
	# No usa la propiedad `action` porque toilet_pee escucha el EVENTO en _unhandled_input.
	_btn_exit_minigame = _make_action_button("ExitMinigameButton", "✕", 44.0, "")
	_btn_exit_minigame.pressed.connect(_on_exit_minigame_pressed)

	_btn_pause = TouchScreenButton.new()
	_btn_pause.name = "PauseButton"
	_btn_pause.texture_normal = _make_hamburger_texture(30, Color(1, 1, 1, 0.55))
	_btn_pause.texture_pressed = _make_hamburger_texture(30, Color(1, 1, 1, 0.95))
	_btn_pause.pressed.connect(_on_pause_pressed)
	add_child(_btn_pause)


func _make_action_button(
	btn_name: String,
	label_text: String,
	radius: float,
	action: String
) -> TouchScreenButton:
	var btn := TouchScreenButton.new()
	btn.name = btn_name
	btn.texture_normal = _make_circle_texture(radius, Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.5))
	btn.texture_pressed = _make_circle_texture(radius, Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.9))
	if not action.is_empty():
		btn.action = action

	var label := Label.new()
	label.name = "Glyph"
	label.text = label_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(radius * 2.0, radius * 2.0)
	label.position = Vector2.ZERO
	if _label_font != null:
		label.add_theme_font_override("font", _label_font)
	label.add_theme_font_size_override("font_size", int(radius * 0.85))
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	btn.add_child(label)

	add_child(btn)
	return btn


func _make_circle_texture(radius: float, fill: Color, border: Color) -> ImageTexture:
	var size := int(radius * 2.0)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(radius, radius)
	var border_width := maxf(3.0, radius * 0.08)
	for y in size:
		for x in size:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if dist <= radius - border_width:
				img.set_pixel(x, y, fill)
			elif dist <= radius:
				img.set_pixel(x, y, border)
	return ImageTexture.create_from_image(img)


func _make_hamburger_texture(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bar_height := maxi(3, int(size * 0.12))
	var margin_x := int(size * 0.12)
	for row in 3:
		var y_start := int(size * (0.2 + 0.28 * row))
		for y in range(y_start, mini(y_start + bar_height, size)):
			for x in range(margin_x, size - margin_x):
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size

	# Joystick: zona inferior-izquierda (flotante dentro de la zona).
	_joystick_default_center = Vector2(joystick_radius + 70.0, vs.y - joystick_radius - 70.0)
	_joystick_center = _joystick_default_center
	_knob_pos = _joystick_center
	_joystick_zone = Rect2(0.0, vs.y * 0.35, vs.x * 0.40, vs.y * 0.65)

	# Cluster de botones: esquina inferior-derecha.
	_place_button(_btn_interact, Vector2(vs.x - 118.0, vs.y - 118.0), 52.0)
	_place_button(_btn_jump, Vector2(vs.x - 248.0, vs.y - 96.0), 44.0)
	_place_button(_btn_drop, Vector2(vs.x - 224.0, vs.y - 216.0), 38.0)
	_place_button(_btn_flashlight, Vector2(vs.x - 96.0, vs.y - 248.0), 38.0)
	_place_button(_btn_sprint, Vector2(vs.x - 370.0, vs.y - 86.0), 44.0)
	_place_button(_btn_exit_minigame, Vector2(vs.x - 118.0, vs.y - 118.0), 44.0)
	_cluster_zone = Rect2(vs.x - 430.0, vs.y - 300.0, 430.0, 300.0)

	# Hamburguesa: esquina superior derecha.
	var pause_size := 30.0
	_btn_pause.position = Vector2(vs.x - pause_size - 22.0, 18.0)
	_hamburger_zone = Rect2(vs.x - pause_size - 34.0, 6.0, pause_size + 34.0, pause_size + 24.0)

	# Bloqueadores de ratón emulado sobre cada zona.
	_blocker_joystick.position = _joystick_zone.position
	_blocker_joystick.size = _joystick_zone.size
	_blocker_cluster.position = _cluster_zone.position
	_blocker_cluster.size = _cluster_zone.size
	_blocker_hamburger.position = _hamburger_zone.position
	_blocker_hamburger.size = _hamburger_zone.size

	queue_redraw()


func _place_button(btn: TouchScreenButton, center: Vector2, radius: float) -> void:
	btn.position = center - Vector2(radius, radius)


# =============================================================================
# VISIBILIDAD (se recalcula por frame; barato y solo en dispositivos táctiles)
# =============================================================================

func _process(_delta: float) -> void:
	_update_visibility()


func _update_visibility() -> void:
	var paused := get_tree().paused
	# Con un gamepad conectado (también en teléfono con mando) se ocultan los controles
	# virtuales: el jugador usa el mando para todo, incluida la pausa (Start).
	var joypad_connected: bool = not Input.get_connected_joypads().is_empty()
	var overlay_block: bool = (
		GameManager.dialogue_active
		or GameManager.level_intro_active
		or GameManager.instructions_overlay_active
	)
	var player := GameManager.get_player()
	var player_ok: bool = player != null and player.input_enabled
	var gameplay_ok := (
		not paused
		and not joypad_connected
		and not overlay_block
		and player_ok
		and not GameManager.minigame_active
	)

	if _gameplay_controls_visible and not gameplay_ok:
		_force_release_all()
	_gameplay_controls_visible = gameplay_ok

	# Botones contextuales: solo aparecen cuando su acción se puede usar ahora mismo.
	var held: Node = player.get_held_pickup() if player_ok and player.has_method("get_held_pickup") else null
	var focus: Node = player.get("_focus_interactable") if player_ok else null
	_btn_interact.visible = gameplay_ok and (
		focus != null
		or (held != null and held.has_method("use_held_item"))
	)
	_btn_drop.visible = gameplay_ok and held != null
	_btn_flashlight.visible = gameplay_ok and held != null and held.has_method("toggle_spotlight")
	_btn_jump.visible = gameplay_ok
	_btn_sprint.visible = gameplay_ok
	_blocker_joystick.visible = gameplay_ok

	# Minijuego del baño: botón ✕ para salir (equivale a Esc/Start via ui_cancel).
	var minigame_touch: bool = (
		not paused
		and not joypad_connected
		and GameManager.minigame_active
	)
	_btn_exit_minigame.visible = minigame_touch
	_blocker_cluster.visible = gameplay_ok or minigame_touch

	# Hamburguesa: como Esc, pero oculta durante diálogos (pausar en medio de un
	# diálogo dejaba la UI de opciones sin respuesta en táctil) y con gamepad presente.
	var pause_ok: bool = (
		not paused
		and not joypad_connected
		and not GameManager.dialogue_active
		and not GameManager.level_intro_active
		and not GameManager.instructions_overlay_active
	)
	_btn_pause.visible = pause_ok
	_blocker_hamburger.visible = pause_ok

	queue_redraw()


# =============================================================================
# ENTRADA TÁCTIL CRUDA (joystick + look multitáctil)
# =============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_touch_begin(touch.index, touch.position)
		else:
			_on_touch_end(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_on_touch_drag(drag.index, drag.position, drag.relative)


func _on_touch_begin(index: int, pos: Vector2) -> void:
	if get_tree().paused:
		return
	# 1) Joystick: un toque dentro de su zona lo reclama (base flotante).
	if _gameplay_controls_visible and _joystick_finger == -1 and _joystick_zone.has_point(pos):
		_joystick_finger = index
		_joystick_center = pos
		_knob_pos = pos
		_move_vector = Vector2.ZERO
		queue_redraw()
		return
	# 2) Zona libre: dedos secundarios (index > 0) giran cámara manualmente.
	#    El dedo primario (index 0) ya gira cámara vía ratón emulado (camino actual).
	if index > 0 and not _is_point_on_controls(pos):
		_look_fingers[index] = true


func _on_touch_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _joystick_finger:
		_update_joystick(pos)
		return
	if _look_fingers.has(index) and _can_touch_look():
		var player := GameManager.get_player()
		if player != null:
			player.rotate_look(relative * touch_look_sensitivity)


func _on_touch_end(index: int) -> void:
	if index == _joystick_finger:
		_release_joystick()
	_look_fingers.erase(index)


func _update_joystick(pos: Vector2) -> void:
	var offset := pos - _joystick_center
	if offset.length() > joystick_radius:
		offset = offset.normalized() * joystick_radius
	_knob_pos = _joystick_center + offset

	var vec := offset / joystick_radius
	if vec.length() < joystick_deadzone:
		vec = Vector2.ZERO
	_move_vector = vec
	_apply_move_vector(vec)
	queue_redraw()


func _release_joystick() -> void:
	_joystick_finger = -1
	_move_vector = Vector2.ZERO
	_joystick_center = _joystick_default_center
	_knob_pos = _joystick_center
	_apply_move_vector(Vector2.ZERO)
	queue_redraw()


func _apply_move_vector(vec: Vector2) -> void:
	# Mismas acciones que el stick izquierdo del gamepad, con strength analógico.
	_set_action_strength(ACTION_LEFT, maxf(-vec.x, 0.0))
	_set_action_strength(ACTION_RIGHT, maxf(vec.x, 0.0))
	_set_action_strength(ACTION_FORWARD, maxf(-vec.y, 0.0))
	_set_action_strength(ACTION_BACK, maxf(vec.y, 0.0))


func _set_action_strength(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _force_release_all() -> void:
	if _joystick_finger != -1:
		_release_joystick()
	else:
		_apply_move_vector(Vector2.ZERO)
	_look_fingers.clear()
	if _sprint_on:
		_sprint_on = false
		Input.action_release(ACTION_SPRINT)
		_update_sprint_visual()


func _is_point_on_controls(pos: Vector2) -> bool:
	if _gameplay_controls_visible and _joystick_zone.has_point(pos):
		return true
	if _blocker_cluster.visible and _cluster_zone.has_point(pos):
		return true
	if _btn_pause.visible and _hamburger_zone.has_point(pos):
		return true
	return false


func _can_touch_look() -> bool:
	# Mismos gates que el look de ratón en ProtoController._unhandled_input.
	if get_tree().paused or GameManager.interaction_prep_active:
		return false
	var player := GameManager.get_player()
	if player == null:
		return false
	if not player.input_enabled or not player.mouse_captured or player.minigame_mode:
		return false
	return true


# =============================================================================
# SPRINT (toggle) Y PAUSA
# =============================================================================

func _on_sprint_toggled() -> void:
	if not _gameplay_controls_visible:
		return
	_sprint_on = not _sprint_on
	if _sprint_on:
		Input.action_press(ACTION_SPRINT)
	else:
		Input.action_release(ACTION_SPRINT)
	_update_sprint_visual()


func _update_sprint_visual() -> void:
	if _btn_sprint != null:
		_btn_sprint.modulate = Color(1.0, 0.85, 0.4, 1.0) if _sprint_on else Color.WHITE


func _on_exit_minigame_pressed() -> void:
	if get_tree().paused or not GameManager.minigame_active:
		return
	# ui_cancel por el pipeline de eventos: toilet_pee_setup lo escucha en
	# _unhandled_input (misma ruta que Esc/Start). El pause menu lo ignora
	# durante minigames (gate en pause_menu.gd).
	var press := InputEventAction.new()
	press.action = "ui_cancel"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = "ui_cancel"
	release.pressed = false
	Input.parse_input_event(release)


func _on_pause_pressed() -> void:
	# Mismos gates que Esc en pause_menu._unhandled_input.
	if get_tree().paused:
		return
	if GameManager.level_intro_active or GameManager.instructions_overlay_active:
		return
	var pause_menu := get_node_or_null("../PauseMenu")
	if pause_menu == null:
		return
	if "is_open" in pause_menu and pause_menu.is_open:
		return
	if pause_menu.has_method("open"):
		pause_menu.open()


# =============================================================================
# DIBUJO DEL JOYSTICK
# =============================================================================

func _draw() -> void:
	if not _is_touch or not _gameplay_controls_visible:
		return
	# Base
	draw_circle(_joystick_center, joystick_radius, Color(1, 1, 1, 0.08))
	draw_arc(_joystick_center, joystick_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	# Knob
	var knob_alpha := 0.5 if _joystick_finger != -1 else 0.28
	draw_circle(_knob_pos, knob_radius, Color(1, 1, 1, knob_alpha))
	draw_arc(_knob_pos, knob_radius, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 2.0, true)
