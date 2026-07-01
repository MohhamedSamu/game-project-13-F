extends CanvasLayer

@onready var _fps_label: Label = $TopRight/FpsLabel

var _fps_visible := false
var _dev_hint_visible := false


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
		_fps_visible = not _fps_visible
		_fps_label.visible = _fps_visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _fps_visible and not _dev_hint_visible:
		_fps_label.text = "%d FPS" % int(Performance.get_monitor(Performance.TIME_FPS))
