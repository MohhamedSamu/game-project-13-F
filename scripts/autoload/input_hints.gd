extends Node

enum DeviceScheme { KEYBOARD_MOUSE, GAMEPAD }
enum GamepadFamily { XBOX, PLAYSTATION, GENERIC }

var active_scheme: DeviceScheme = DeviceScheme.KEYBOARD_MOUSE
var gamepad_family: GamepadFamily = GamepadFamily.XBOX
var gamepad_locked: bool = false


func _ready() -> void:
	_load_from_settings()


func _input(event: InputEvent) -> void:
	if _is_gamepad_event(event):
		_lock_gamepad_scheme(event)
	elif not gamepad_locked and _is_keyboard_mouse_event(event):
		active_scheme = DeviceScheme.KEYBOARD_MOUSE
		_save_to_settings()


func is_gamepad() -> bool:
	# Sin ningún mando conectado no hay modo gamepad posible. Evita que el lock
	# persistido en settings deje el juego en modo mando para siempre (en el
	# teléfono rompía: E no recogía pickups, el spray del baño se apagaba solo
	# y los prompts mostraban botones de mando en pantalla táctil).
	if Input.get_connected_joypads().is_empty():
		return false
	return gamepad_locked or active_scheme == DeviceScheme.GAMEPAD


func get_family_name() -> String:
	match gamepad_family:
		GamepadFamily.PLAYSTATION:
			return "PlayStation"
		GamepadFamily.XBOX:
			return "Xbox"
	return "Mando"


func label_interact() -> String:
	if not is_gamepad():
		return "[E]"
	match gamepad_family:
		GamepadFamily.PLAYSTATION:
			return "[Cruz]"
	return "[B]"


func label_pickup() -> String:
	if not is_gamepad():
		return "[E]"
	match gamepad_family:
		GamepadFamily.PLAYSTATION:
			return "[Triángulo]"
	return "[Y]"


func label_drop() -> String:
	if not is_gamepad():
		return "[Q]"
	match gamepad_family:
		GamepadFamily.PLAYSTATION:
			return "[Cuadrado]"
	return "[X]"


func label_sprint() -> String:
	return "L3" if is_gamepad() else "SHIFT"


func label_jump() -> String:
	if not is_gamepad():
		return "Espacio"
	match gamepad_family:
		GamepadFamily.PLAYSTATION:
			return "[Cruz]"
	return "[A]"


func label_flashlight() -> String:
	return label_pickup() if is_gamepad() else "[F]"


func label_pause() -> String:
	if not is_gamepad():
		return "Esc"
	match gamepad_family:
		GamepadFamily.PLAYSTATION:
			return "Options"
	return "Start"


func label_menu_confirm() -> String:
	if not is_gamepad():
		return "Enter"
	match gamepad_family:
		GamepadFamily.PLAYSTATION:
			return "[Cruz]"
	return "[A]"


func label_menu_back() -> String:
	return label_pause() if is_gamepad() else "Esc"


func label_spray_hold() -> String:
	if not is_gamepad():
		return tr("HINT_SPRAY_HOLD_MOUSE")
	if Settings.get_locale() == "en":
		return "%s (hold)" % label_interact()
	return "%s (mantener)" % label_interact()


func close_instructions_hint() -> String:
	if is_gamepad():
		if Settings.get_locale() == "en":
			return "%s or %s to close" % [label_menu_confirm(), label_interact()]
		return "%s o %s para cerrar" % [label_menu_confirm(), label_interact()]
	return tr("UI_INSTR_CLOSE")


func adapt_pickup_prompt(prompt: String) -> String:
	var localized := tr(prompt)
	if localized.is_empty() or not is_gamepad():
		return localized
	return localized.replace("[E]", label_pickup())


func adapt_prompt(prompt: String) -> String:
	var localized := tr(prompt)
	if localized.is_empty() or not is_gamepad():
		return localized
	var adapted := localized
	adapted = adapted.replace("[Q]", label_drop())
	adapted = adapted.replace("[F]", label_flashlight())
	adapted = adapted.replace("[E]", label_interact())
	return adapted


func instructions_body() -> String:
	if not is_gamepad():
		return _keyboard_instructions_body()
	return _gamepad_instructions_body()


func _keyboard_instructions_body() -> String:
	return tr("UI_INSTR_BODY_KB")


func _gamepad_instructions_body() -> String:
	var family := get_family_name()
	if gamepad_family == GamepadFamily.PLAYSTATION:
		return tr("UI_INSTR_BODY_PAD_PS") % [
			family,
			label_jump(),
			label_interact(),
			label_pickup(),
			label_drop(),
			label_pause(),
			label_menu_confirm(),
			label_menu_back(),
			label_pickup(),
			label_flashlight(),
		]
	return tr("UI_INSTR_BODY_PAD_XBOX") % [
		family,
		label_jump(),
		label_interact(),
		label_pickup(),
		label_drop(),
		label_pause(),
		label_menu_confirm(),
		label_menu_back(),
		label_pickup(),
		label_flashlight(),
	]


func _lock_gamepad_scheme(event: InputEvent) -> void:
	active_scheme = DeviceScheme.GAMEPAD
	if not gamepad_locked:
		gamepad_locked = true
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var device_id := event.device
		gamepad_family = _detect_family(device_id)
	_save_to_settings()


func _detect_family(device_id: int) -> GamepadFamily:
	var joy_name := String(Input.get_joy_name(device_id)).to_lower()
	if joy_name.contains("sony") or joy_name.contains("playstation") or joy_name.contains("dualshock") or joy_name.contains("dualsense"):
		return GamepadFamily.PLAYSTATION
	if joy_name.contains("xbox") or joy_name.contains("xinput") or joy_name.contains("microsoft"):
		return GamepadFamily.XBOX
	return GamepadFamily.XBOX


func _load_from_settings() -> void:
	var scheme := String(Settings.get_value("input_device_scheme", "keyboard"))
	gamepad_locked = scheme == "gamepad"
	active_scheme = DeviceScheme.GAMEPAD if gamepad_locked else DeviceScheme.KEYBOARD_MOUSE
	var family := String(Settings.get_value("gamepad_family", "xbox"))
	match family:
		"playstation":
			gamepad_family = GamepadFamily.PLAYSTATION
		"generic":
			gamepad_family = GamepadFamily.GENERIC
		_:
			gamepad_family = GamepadFamily.XBOX
	if gamepad_locked and not Input.get_connected_joypads().is_empty():
		gamepad_family = _detect_family(int(Input.get_connected_joypads()[0]))


func _save_to_settings() -> void:
	if gamepad_locked:
		Settings.set_value("input_device_scheme", "gamepad")
	else:
		Settings.set_value("input_device_scheme", "keyboard")
	match gamepad_family:
		GamepadFamily.PLAYSTATION:
			Settings.set_value("gamepad_family", "playstation")
		GamepadFamily.GENERIC:
			Settings.set_value("gamepad_family", "generic")
		_:
			Settings.set_value("gamepad_family", "xbox")
	Settings.save_settings()


func _is_gamepad_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= 0.25
	return false


func _is_keyboard_mouse_event(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		or event is InputEventMouseButton
		or event is InputEventMouseMotion
	)
