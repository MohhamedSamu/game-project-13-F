extends CanvasLayer
## Pensamientos internos del protagonista: subtítulos amarillos en la parte inferior.

signal thought_shown(text: String)
signal thought_hidden

const DEFAULT_DURATION := 5.0
const FADE_DURATION := 0.35

@export var lowercase_text: bool = true

@onready var _anchor: Control = $ThoughtAnchor
@onready var _label: Label = $ThoughtAnchor/ThoughtLabel

var _fade_tween: Tween
var _auto_hide_timer: Timer
var _current_text: String = ""


func _ready() -> void:
	layer = 95
	_auto_hide_timer = Timer.new()
	_auto_hide_timer.one_shot = true
	add_child(_auto_hide_timer)
	_auto_hide_timer.timeout.connect(_fade_out)
	hide_thought()


func show_thought(
	text: String,
	duration: float = DEFAULT_DURATION,
	allow_during_minigame: bool = false
) -> void:
	if text.is_empty():
		hide_thought()
		return
	if not allow_during_minigame and (
		GameManager.dialogue_active or GameManager.minigame_active or GameManager.level_intro_active
	):
		return
	if GameManager.instructions_overlay_active:
		return

	var display_text := tr(text)
	if lowercase_text:
		display_text = display_text.to_lower()
	if _anchor.visible and _current_text == display_text:
		if duration > 0.0:
			_auto_hide_timer.start(duration)
		return

	_current_text = display_text
	_label.text = display_text
	_kill_fade_tween()
	_anchor.visible = true
	_anchor.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_anchor, "modulate:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_auto_hide_timer.stop()
	if duration > 0.0:
		_auto_hide_timer.start(duration)
	thought_shown.emit(display_text)


func hide_thought() -> void:
	if not _anchor.visible:
		return
	_auto_hide_timer.stop()
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_anchor, "modulate:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(_finish_hide)


func is_showing() -> bool:
	return _anchor.visible and _anchor.modulate.a > 0.01


func get_current_text() -> String:
	return _current_text


func _fade_out() -> void:
	hide_thought()


func _finish_hide() -> void:
	_anchor.visible = false
	_current_text = ""
	thought_hidden.emit()


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
