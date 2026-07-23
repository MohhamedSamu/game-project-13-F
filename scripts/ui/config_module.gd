extends VBoxContainer

signal back_pressed

@onready var btn_back: Button = $VScrollBar/btnBack
@onready var _scroll_root: Control = $VScrollBar
@onready var _title: Label = $VScrollBar/Label
@onready var _lbl_master: Label = $VScrollBar/lblMaster
@onready var _lbl_music: Label = $VScrollBar/lblMusic
@onready var _lbl_sfx: Label = $VScrollBar/SFXMaster
@onready var _fullscreen: CheckButton = $VScrollBar/FullscreenControl
@onready var _lbl_mouse: Label = $VScrollBar/lblMouseSens
@onready var _lbl_fov: Label = $VScrollBar/lblFOV
@onready var _lbl_graphics: Label = $VScrollBar/lblGraphics
@onready var _graphics_control: OptionButton = $VScrollBar/GraphicsControl


func _ready() -> void:
	btn_back.pressed.connect(func(): back_pressed.emit())
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_localized_texts()
	if not Settings.locale_changed.is_connected(_on_locale_changed):
		Settings.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	refresh_localized_texts()


func refresh_localized_texts() -> void:
	if _title:
		_title.text = tr("UI_OPT_TITLE")
	if _lbl_master:
		_lbl_master.text = tr("UI_OPT_MASTER_VOL")
	if _lbl_music:
		_lbl_music.text = tr("UI_OPT_MUSIC_VOL")
	if _lbl_sfx:
		_lbl_sfx.text = tr("UI_OPT_SFX_VOL")
	if _fullscreen:
		_fullscreen.text = tr("UI_OPT_FULLSCREEN")
	if _lbl_mouse:
		_lbl_mouse.text = tr("UI_OPT_MOUSE_SENS")
	if _lbl_fov:
		_lbl_fov.text = tr("UI_OPT_FOV")
	if _lbl_graphics:
		_lbl_graphics.text = tr("UI_OPT_GRAPHICS")
	if btn_back:
		btn_back.text = tr("UI_COMMON_BACK")
	if _graphics_control != null and _graphics_control.has_method("refresh_localized_items"):
		_graphics_control.refresh_localized_items()


func grab_menu_focus() -> void:
	GamepadUINav.grab_menu_focus_if_needed(_scroll_root)
