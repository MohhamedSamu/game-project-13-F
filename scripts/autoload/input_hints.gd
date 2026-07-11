extends Node

enum DeviceScheme { KEYBOARD_MOUSE, GAMEPAD }

var active_scheme: DeviceScheme = DeviceScheme.KEYBOARD_MOUSE


func _input(event: InputEvent) -> void:
	if _is_gamepad_event(event):
		active_scheme = DeviceScheme.GAMEPAD
	elif _is_keyboard_mouse_event(event):
		active_scheme = DeviceScheme.KEYBOARD_MOUSE


func is_gamepad() -> bool:
	return active_scheme == DeviceScheme.GAMEPAD


func label_interact() -> String:
	return "[B]" if is_gamepad() else "[E]"


func label_pickup() -> String:
	return "[Y]" if is_gamepad() else "[E]"


func label_drop() -> String:
	return "[X]" if is_gamepad() else "[Q]"


func label_sprint() -> String:
	return "L3" if is_gamepad() else "SHIFT"


func label_jump() -> String:
	return "[A]" if is_gamepad() else "Espacio"


func label_flashlight() -> String:
	return "[Y]" if is_gamepad() else "[F]"


func label_pause() -> String:
	return "Start" if is_gamepad() else "Esc"


func close_instructions_hint() -> String:
	if is_gamepad():
		return "Clic o %s para cerrar" % label_interact()
	return "Clic o [E] para cerrar"


func adapt_pickup_prompt(prompt: String) -> String:
	if prompt.is_empty():
		return prompt
	if not is_gamepad():
		return prompt
	return prompt.replace("[E]", label_pickup())


func adapt_prompt(prompt: String) -> String:
	if prompt.is_empty() or not is_gamepad():
		return prompt
	var adapted := prompt
	adapted = adapted.replace("[Q]", label_drop())
	adapted = adapted.replace("[F]", label_flashlight())
	adapted = adapted.replace("[E]", label_interact())
	return adapted


func instructions_body() -> String:
	if is_gamepad():
		return """Controles (mando)

• Stick izquierdo — caminar y moverte por el entorno.
• L3 — correr.
• A — saltar.
• B — interactuar (puertas, NPCs, leer el libro en la mano).
• Y — recoger objetos / usar lo que llevas en la mano.
• X — soltar lo que llevas en la mano.
• Stick derecho — mirar.
• Start — pausa.

Explora la zona: debería haber una linterna cerca.
Recógela con %s y cámbiala con %s cuando la lleves en la mano.""" % [label_pickup(), label_flashlight()]
	return """Controles

• WASD — caminar y moverte por el entorno.
• Mantén SHIFT — correr.
• Espacio — saltar.

• E — interactuar y recoger objetos.
• Q — soltar lo que llevas en la mano.
• F — usar / cambiar lo que llevas en la mano (linterna).

Explora la zona: debería haber una linterna cerca.
Recógela con [E] y cámbiala con [F] cuando la lleves en la mano."""


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
