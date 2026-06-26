extends OptionButton


func _ready() -> void:
	clear()
	add_item("Production", Settings.MovementProfile.PRODUCTION)
	add_item("Develop", Settings.MovementProfile.DEVELOP)
	_load_saved_value()
	item_selected.connect(_on_item_selected)


func _load_saved_value() -> void:
	var profile := Settings.get_movement_profile()
	for i in range(get_item_count()):
		if get_item_id(i) == profile:
			select(i)
			return


func _on_item_selected(index: int) -> void:
	var profile: Settings.MovementProfile = get_item_id(index)
	Settings.set_movement_profile(profile)
	Settings.save_settings()
	Settings.apply_movement_to_player()
