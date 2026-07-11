extends Node


func grab_first_focus(root: Control) -> void:
	if root == null or not root.is_inside_tree():
		return
	call_deferred("_deferred_grab_first_focus", root)


func ensure_focus(root: Control) -> void:
	if root == null or not root.is_inside_tree():
		return
	var viewport := root.get_viewport()
	if viewport == null:
		return
	var owner := viewport.gui_get_focus_owner() as Control
	if owner != null and owner.is_visible_in_tree() and _is_within(owner, root):
		return
	grab_first_focus(root)


func _deferred_grab_first_focus(root: Control) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	var target := _find_first_focusable(root)
	if target != null:
		target.grab_focus()


func _find_first_focusable(node: Node) -> Control:
	if node is Control:
		var control := node as Control
		if control.visible and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
			if node is BaseButton and (node as BaseButton).disabled:
				pass
			else:
				return control
	for child in node.get_children():
		var found := _find_first_focusable(child)
		if found != null:
			return found
	return null


func _is_within(control: Control, ancestor: Control) -> bool:
	var current: Node = control
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
