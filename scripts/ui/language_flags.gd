extends Control
## Selector de idioma con banderas (SV / US) en la esquina superior derecha.

signal language_change_requested(locale: String)

const FLAG_ES := preload("res://assets/ui/flags/flag_es_sv.png")
const FLAG_EN := preload("res://assets/ui/flags/flag_en_us.png")

@onready var _btn_es: TextureButton = $FlagsRow/BtnES
@onready var _btn_en: TextureButton = $FlagsRow/BtnEN
@onready var _confirm: ConfirmationDialog = $ConfirmDialog

var _pending_locale: String = ""


func _ready() -> void:
	_btn_es.texture_normal = FLAG_ES
	_btn_en.texture_normal = FLAG_EN
	_btn_es.pressed.connect(_on_es_pressed)
	_btn_en.pressed.connect(_on_en_pressed)
	_confirm.confirmed.connect(_on_confirm_accepted)
	_refresh_selection()
	_refresh_confirm_texts()
	if not Settings.locale_changed.is_connected(_on_locale_changed):
		Settings.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	_refresh_selection()
	_refresh_confirm_texts()


func _refresh_selection() -> void:
	var locale := Settings.get_locale()
	_btn_es.modulate = Color(1, 1, 1, 1.0) if locale == "es" else Color(1, 1, 1, 0.45)
	_btn_en.modulate = Color(1, 1, 1, 1.0) if locale == "en" else Color(1, 1, 1, 0.45)
	_btn_es.disabled = locale == "es"
	_btn_en.disabled = locale == "en"


func _refresh_confirm_texts() -> void:
	_confirm.title = tr("UI_LANG_CONFIRM_TITLE")
	_confirm.dialog_text = tr("UI_LANG_CONFIRM_BODY")
	_confirm.ok_button_text = tr("UI_LANG_CONFIRM_YES")
	var cancel_btn := _confirm.get_cancel_button()
	if cancel_btn != null:
		cancel_btn.text = tr("UI_LANG_CONFIRM_NO")


func _on_es_pressed() -> void:
	_request_locale("es")


func _on_en_pressed() -> void:
	_request_locale("en")


func _request_locale(locale: String) -> void:
	if locale == Settings.get_locale():
		return
	_pending_locale = locale
	_refresh_confirm_texts()
	_confirm.popup_centered()


func _on_confirm_accepted() -> void:
	if _pending_locale.is_empty():
		return
	var locale := _pending_locale
	_pending_locale = ""
	Settings.set_locale(locale)
	Settings.save_settings()
	language_change_requested.emit(locale)
	_refresh_selection()
