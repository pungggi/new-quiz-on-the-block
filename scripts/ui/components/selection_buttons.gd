extends RefCounted
class_name SelectionButtons

## Reusable Selection Button Factory
##
## Creates avatar and grade selection buttons for profile dialogs.
## Usage:
##   SelectionButtons.create_avatar_buttons(container, callback)
##   SelectionButtons.create_grade_buttons(container, callback)

const AVATAR_BUTTON_SIZE := Vector2(48, 48)
const GRADE_BUTTON_SIZE := Vector2(100, 40)
const GRADE_BUTTON_SIZE_SMALL := Vector2(90, 36)


## Create avatar selection buttons
## Returns Dictionary[String, Button] mapping avatar_id to button
static func create_avatar_buttons(
	container: HBoxContainer,
	callback: Callable,
	selected_avatar: String = "fox",
	button_size: Vector2 = AVATAR_BUTTON_SIZE
) -> Dictionary:
	# Clear existing
	for child in container.get_children():
		child.queue_free()
	
	var buttons: Dictionary = {}
	
	for av_id in PlayerProfile.ALL_AVATARS:
		var btn := Button.new()
		btn.text = PlayerProfile.AVATAR_EMOJIS.get(av_id, "?")
		btn.custom_minimum_size = button_size
		btn.toggle_mode = true
		btn.button_pressed = (av_id == selected_avatar)
		btn.pressed.connect(callback.bind(av_id))
		container.add_child(btn)
		buttons[av_id] = btn
	
	return buttons


## Update avatar button selection state
static func update_avatar_selection(buttons: Dictionary, selected_avatar: String) -> void:
	for av_id: String in buttons:
		buttons[av_id].button_pressed = (av_id == selected_avatar)


## Create grade selection buttons
## Returns Array[Button] of grade buttons (index = grade level)
static func create_grade_buttons(
	container: GridContainer,
	callback: Callable,
	selected_grade: int = -1,
	button_size: Vector2 = GRADE_BUTTON_SIZE
) -> Array[Button]:
	# Clear existing
	for child in container.get_children():
		child.queue_free()
	
	var buttons: Array[Button] = []
	
	for grade in range(0, 11):
		var btn := Button.new()
		btn.text = PlayerProfile.get_grade_name(grade)
		btn.custom_minimum_size = button_size
		btn.toggle_mode = true
		btn.button_pressed = (grade == selected_grade)
		btn.pressed.connect(callback.bind(grade))
		container.add_child(btn)
		buttons.append(btn)
	
	return buttons


## Update grade button selection state
static func update_grade_selection(buttons: Array[Button], selected_grade: int) -> void:
	for i in range(buttons.size()):
		buttons[i].button_pressed = (i == selected_grade)


## Create category checkboxes
## Returns Dictionary[String, CheckBox] mapping category_id to checkbox
static func create_category_checkboxes(
	container: VBoxContainer,
	callback: Callable,
	enabled_categories: Array = []
) -> Dictionary:
	# Clear existing checkboxes (preserve labels)
	for child in container.get_children():
		if child is CheckBox:
			child.queue_free()
	
	var checkboxes: Dictionary = {}
	var all_enabled := enabled_categories.is_empty()
	
	for cat_id in PlayerProfile.ALL_CATEGORIES:
		var checkbox := CheckBox.new()
		checkbox.text = PlayerProfile.CATEGORY_NAMES.get(cat_id, cat_id)
		checkbox.button_pressed = all_enabled or (cat_id in enabled_categories)
		checkbox.toggled.connect(callback.bind(cat_id))
		container.add_child(checkbox)
		checkboxes[cat_id] = checkbox
	
	return checkboxes


## Get selected categories from checkboxes
static func get_selected_categories(checkboxes: Dictionary) -> Array:
	var selected: Array = []
	for cat_id: String in checkboxes:
		if checkboxes[cat_id].button_pressed:
			selected.append(cat_id)
	return selected

