extends CanvasLayer
## Pantalla de instrucciones: fondo oscuro difuminado y texto. Cierra con clic o [E].

signal instructions_closed

const DEFAULT_CLOSE_HINT := "Clic o [E] para cerrar"

@export var close_hint: String = DEFAULT_CLOSE_HINT

@onready var _root: Control = %Root
@onready var _body_label: Label = %BodyLabel
@onready var _hint_label: Label = %HintLabel

var _is_open: bool = false
var _open_frame: int = -1


func _ready() -> void:
	layer = 115
	visible = false
	set_process(false)
	if _hint_label != null:
		_hint_label.text = close_hint
	if _root != null:
		_root.gui_input.connect(_on_root_gui_input)


func is_open() -> bool:
	return _is_open


func show_instructions(body_text: String, _refresh_on_scheme_change: bool = false) -> void:
	if body_text.is_empty():
		return
	if _is_open:
		return
	_is_open = true
	_open_frame = Engine.get_process_frames()
	if _body_label != null:
		_body_label.text = body_text
	if _hint_label != null:
		_hint_label.text = InputHints.close_instructions_hint()
	visible = true
	GameManager.instructions_overlay_active = true
	GameManager.lock_player_for_instructions()
	set_process(true)


func hide_instructions() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	set_process(false)
	GameManager.instructions_overlay_active = false
	GameManager.unlock_player_from_instructions()
	instructions_closed.emit()


func toggle_instructions(body_text: String, _refresh_on_scheme_change: bool = false) -> void:
	if _is_open:
		hide_instructions()
	else:
		show_instructions(body_text)


func _process(_delta: float) -> void:
	if not _is_open:
		return
	if _hint_label != null:
		_hint_label.text = InputHints.close_instructions_hint()
	if Engine.get_process_frames() <= _open_frame:
		return
	if _should_close():
		hide_instructions()


func _should_close() -> bool:
	if Input.is_action_just_pressed("interact") and not InputHints.is_gamepad():
		return true
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
		return true
	return false


func _on_root_gui_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if Engine.get_process_frames() <= _open_frame:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			hide_instructions()
