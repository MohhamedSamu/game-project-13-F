extends CanvasLayer

@onready var _fps_label: Label = $TopRight/FpsLabel

var _fps_visible := false


func _ready() -> void:
	_fps_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fps"):
		_fps_visible = not _fps_visible
		_fps_label.visible = _fps_visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _fps_visible:
		_fps_label.text = "%d FPS" % int(Performance.get_monitor(Performance.TIME_FPS))
