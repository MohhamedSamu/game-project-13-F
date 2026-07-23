class_name LevelIntroController
extends CanvasLayer
## Pantalla negra: en cada página los párrafos se apilan; al completar la página, pasa a la siguiente.

signal intro_finished

const DEMO_COLOR := Color(0.92, 0.92, 0.9, 1.0)
const INNER_THOUGHT_COLOR := Color(0.796, 0.694, 0.404, 1.0)
const PARAGRAPH_SEPARATOR := "\n\n"

@export var sequence: LevelIntroSequence

@onready var _root: Control = %Root
@onready var _body_label: Label = %BodyLabel
@onready var _hint_label: Label = %HintLabel

var _page_index: int = 0
var _revealed_count: int = 0
var _active: bool = false
var _advancing: bool = false


func _ready() -> void:
	layer = 120
	visible = true
	_hint_label.text = tr("UI_INTRO_CONTINUE")
	_body_label.text = ""
	_lock_player()
	GameManager.level_intro_active = true
	call_deferred("_begin")


func _begin() -> void:
	if sequence == null or sequence.pages.is_empty():
		_finish_intro()
		return
	MusicDirector.play_intro_music_loop()
	_active = true
	_page_index = 0
	_revealed_count = 1
	_refresh_page_display()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _advancing:
		return
	if not _is_advance_input(event):
		return
	get_viewport().set_input_as_handled()
	_advance()


func _is_advance_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if event.is_action_pressed("ui_accept"):
		return true
	if event.is_action_pressed("interact"):
		return true
	return false


func _advance() -> void:
	if sequence == null or sequence.pages.is_empty():
		_finish_intro()
		return

	var page := _get_current_page()
	if page == null:
		_finish_intro()
		return

	if _revealed_count < _count_valid_paragraphs(page):
		_revealed_count += 1
		_refresh_page_display()
		return

	if _page_index + 1 < sequence.pages.size():
		_page_index += 1
		_revealed_count = 1
		_refresh_page_display()
		return

	_finish_intro()


func _get_current_page() -> LevelIntroPage:
	if sequence == null or _page_index < 0 or _page_index >= sequence.pages.size():
		return null
	return sequence.pages[_page_index]


func _count_valid_paragraphs(page: LevelIntroPage) -> int:
	var count := 0
	for paragraph in page.paragraphs:
		if paragraph != null and not paragraph.text.is_empty():
			count += 1
	return count


func _refresh_page_display() -> void:
	var page := _get_current_page()
	if page == null:
		return

	var lines: PackedStringArray = PackedStringArray()
	var style := LevelIntroParagraph.TextStyle.DEMO
	var shown := 0
	for paragraph in page.paragraphs:
		if paragraph == null or paragraph.text.is_empty():
			continue
		if shown >= _revealed_count:
			break
		lines.append(_format_paragraph_text(paragraph))
		style = paragraph.style
		shown += 1

	_apply_page_style(style)
	_body_label.text = PARAGRAPH_SEPARATOR.join(lines)


func _format_paragraph_text(paragraph: LevelIntroParagraph) -> String:
	var localized := tr(paragraph.text)
	if paragraph.style == LevelIntroParagraph.TextStyle.INNER_THOUGHT:
		return localized.to_lower()
	return localized


func _apply_page_style(style: LevelIntroParagraph.TextStyle) -> void:
	match style:
		LevelIntroParagraph.TextStyle.INNER_THOUGHT:
			_body_label.add_theme_color_override("font_color", INNER_THOUGHT_COLOR)
			_body_label.add_theme_font_size_override("font_size", 26)
		_:
			_body_label.add_theme_color_override("font_color", DEMO_COLOR)
			_body_label.add_theme_font_size_override("font_size", 24)


func _finish_intro() -> void:
	if _advancing:
		return
	_active = false
	_advancing = true
	var duration := sequence.fade_out_duration if sequence != null else 0.65
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	GameManager.level_intro_active = false
	_unlock_player()
	intro_finished.emit()
	queue_free()


func _lock_player() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player := GameManager.get_player()
	if player != null and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
	if player != null and player.has_method("stop_movement_immediately"):
		player.stop_movement_immediately()


func _unlock_player() -> void:
	var player := GameManager.get_player()
	if player != null and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)
	if player != null and player.has_method("capture_mouse"):
		player.capture_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
