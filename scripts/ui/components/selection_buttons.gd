extends RefCounted
class_name SelectionButtons

## Reusable selection button factory
##
## Creates the avatar, grade and category pickers used by the profile
## dialogs. All of them are toggle "chips" (theme variation ChipButton): the
## selected entry shows the green selected state, so selection is always
## visible. Sizes scale with the current reading level (see UITheme).
##
## Usage:
##   SelectionButtons.create_avatar_buttons(container, callback)
##   SelectionButtons.create_grade_buttons(container, callback)
##   SelectionButtons.create_category_checkboxes(container, callback)

const AVATAR_BUTTON_SIZE := Vector2(48, 48)
const GRADE_BUTTON_SIZE := Vector2(100, 36)
const GRADE_BUTTON_SIZE_SMALL := Vector2(90, 34)


## Create avatar selection buttons
## Returns Dictionary[String, Button] mapping avatar_id to button
static func create_avatar_buttons(
	container: Container,
	callback: Callable,
	selected_avatar: String = "fox",
	button_size: Vector2 = AVATAR_BUTTON_SIZE
) -> Dictionary:
	_clear(container)

	var buttons: Dictionary = {}

	for av_id: String in PlayerProfile.ALL_AVATARS:
		var btn := Button.new()
		btn.text = PlayerProfile.AVATAR_EMOJIS.get(av_id, "?")
		btn.custom_minimum_size = button_size * UITheme.scale_factor()
		btn.theme_type_variation = &"IconChip"
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


## Create grade selection buttons. Put them in an HFlowContainer so they
## wrap when the bigger reading levels make them wider.
## Returns Array[Button] of grade buttons (index = grade level)
static func create_grade_buttons(
	container: Container,
	callback: Callable,
	selected_grade: int = -1,
	button_size: Vector2 = GRADE_BUTTON_SIZE
) -> Array[Button]:
	_clear(container)

	var buttons: Array[Button] = []

	for grade: int in range(0, 11):
		var btn := Button.new()
		btn.text = PlayerProfile.get_grade_name(grade)
		btn.custom_minimum_size = button_size * UITheme.scale_factor()
		btn.theme_type_variation = &"ChipButton"
		btn.toggle_mode = true
		btn.button_pressed = (grade == selected_grade)
		btn.pressed.connect(callback.bind(grade))
		container.add_child(btn)
		buttons.append(btn)

	return buttons


## Update grade button selection state
static func update_grade_selection(buttons: Array[Button], selected_grade: int) -> void:
	for i: int in range(buttons.size()):
		buttons[i].button_pressed = (i == selected_grade)


## Create the quiz category pickers as toggle chips.
## Returns Dictionary[String, Button] mapping category_id to button
static func create_category_checkboxes(
	container: Container,
	callback: Callable,
	enabled_categories: Array = []
) -> Dictionary:
	# Clear old chips (a label placed in the container stays)
	for child in container.get_children():
		if child is Button:
			child.queue_free()

	var checkboxes: Dictionary = {}
	var all_enabled: bool = enabled_categories.is_empty()

	for cat_id: String in PlayerProfile.ALL_CATEGORIES:
		var chip := Button.new()
		chip.text = PlayerProfile.CATEGORY_NAMES.get(cat_id, cat_id)
		chip.theme_type_variation = &"ChipButton"
		chip.toggle_mode = true
		chip.button_pressed = all_enabled or (cat_id in enabled_categories)
		chip.toggled.connect(callback.bind(cat_id))
		container.add_child(chip)
		checkboxes[cat_id] = chip

	return checkboxes


## Get selected categories from the chips
static func get_selected_categories(checkboxes: Dictionary) -> Array:
	var selected: Array = []
	for cat_id: String in checkboxes:
		if checkboxes[cat_id].button_pressed:
			selected.append(cat_id)
	return selected


static func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()
