extends CanvasLayer

@onready var _fps_label: Label = $TopRight/FpsLabel

var _fps_visible := false
var _dev_hint_visible := false
var _gamepad_fps_combo_was_pressed := false

const _TRIGGER_THRESHOLD := 0.45


func _ready() -> void:
	_fps_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			GameManager.reset_scene4_bathroom_dev_state()
			_dev_hint_visible = true
			_fps_label.visible = true
			_fps_label.text = "Flags escena 4 reseteadas (F9)"
			get_tree().create_timer(2.5).timeout.connect(func() -> void:
				if not _fps_visible:
					_fps_label.visible = false
				_dev_hint_visible = false
			)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("toggle_fps"):
		_set_fps_visible(not _fps_visible)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_gamepad_fps_combo()
	if _fps_visible and not _dev_hint_visible:
		_fps_label.text = "%d FPS" % int(Performance.get_monitor(Performance.TIME_FPS))


func _update_gamepad_fps_combo() -> void:
	if not InputHints.is_gamepad():
		_gamepad_fps_combo_was_pressed = false
		return
	var combo_pressed := _is_all_shoulder_triggers_pressed()
	if combo_pressed and not _gamepad_fps_combo_was_pressed:
		_set_fps_visible(not _fps_visible)
	_gamepad_fps_combo_was_pressed = combo_pressed


func _is_all_shoulder_triggers_pressed() -> bool:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return false
	var device_id := int(pads[0])
	var lb := Input.is_joy_button_pressed(device_id, JoyButton.JOY_BUTTON_LEFT_SHOULDER)
	var rb := Input.is_joy_button_pressed(device_id, JoyButton.JOY_BUTTON_RIGHT_SHOULDER)
	var lt := Input.get_joy_axis(device_id, JoyAxis.JOY_AXIS_TRIGGER_LEFT) > _TRIGGER_THRESHOLD
	var rt := Input.get_joy_axis(device_id, JoyAxis.JOY_AXIS_TRIGGER_RIGHT) > _TRIGGER_THRESHOLD
	return lb and rb and lt and rt


func _set_fps_visible(visible: bool) -> void:
	_fps_visible = visible
	if not _dev_hint_visible:
		_fps_label.visible = visible
