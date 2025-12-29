extends Control
class_name ProfileCreation

## Profile Creation Screen
## Shown on first launch to get player name and grade level

signal profile_completed(profile: PlayerProfile)

@onready var name_input: LineEdit = $Panel/VBox/NameInput
@onready var avatar_container: HBoxContainer = $Panel/VBox/AvatarContainer
@onready var grade_container: GridContainer = $Panel/VBox/GradeContainer
@onready var category_container: VBoxContainer = $Panel/VBox/CategoryContainer
@onready var start_button: Button = $Panel/VBox/StartButton
@onready var error_label: Label = $Panel/VBox/ErrorLabel

var _selected_grade: int = -1
var _selected_avatar: String = "fox"
var _grade_buttons: Array[Button] = []
var _avatar_buttons: Dictionary = {}
var _category_checkboxes: Dictionary = {}


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	name_input.text_changed.connect(_on_name_changed)

	error_label.visible = false
	start_button.disabled = true

	_create_avatar_buttons()
	_create_grade_buttons()
	_create_category_checkboxes()

	# Pause game while creating profile
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _create_avatar_buttons() -> void:
	for child in avatar_container.get_children():
		child.queue_free()
	_avatar_buttons.clear()

	for av_id in PlayerProfile.ALL_AVATARS:
		var btn := Button.new()
		btn.text = PlayerProfile.AVATAR_EMOJIS.get(av_id, "?")
		btn.custom_minimum_size = Vector2(48, 48)
		btn.toggle_mode = true
		btn.button_pressed = (av_id == _selected_avatar)
		btn.pressed.connect(_on_avatar_selected.bind(av_id))
		avatar_container.add_child(btn)
		_avatar_buttons[av_id] = btn


func _on_avatar_selected(av_id: String) -> void:
	_selected_avatar = av_id
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	for key: String in _avatar_buttons:
		_avatar_buttons[key].button_pressed = (key == av_id)


func _create_grade_buttons() -> void:
	# Clear existing
	for child in grade_container.get_children():
		child.queue_free()
	_grade_buttons.clear()

	# Create button for each grade level (0-9 = school, 10 = adults)
	for grade in range(0, 11):
		var btn := Button.new()
		btn.text = PlayerProfile.get_grade_name(grade)
		btn.custom_minimum_size = Vector2(100, 40)
		btn.toggle_mode = true
		btn.pressed.connect(_on_grade_selected.bind(grade))

		grade_container.add_child(btn)
		_grade_buttons.append(btn)


func _create_category_checkboxes() -> void:
	# Clear existing
	for child in category_container.get_children():
		if child is CheckBox:
			child.queue_free()
	_category_checkboxes.clear()

	# Create checkbox for each category
	for cat_id in PlayerProfile.ALL_CATEGORIES:
		var checkbox := CheckBox.new()
		checkbox.text = PlayerProfile.CATEGORY_NAMES.get(cat_id, cat_id)
		checkbox.button_pressed = true # All enabled by default
		checkbox.toggled.connect(_on_category_toggled.bind(cat_id))

		category_container.add_child(checkbox)
		_category_checkboxes[cat_id] = checkbox


func _on_category_toggled(_pressed: bool, _cat_id: String) -> void:
	_validate_input()


func _on_grade_selected(grade: int) -> void:
	_selected_grade = grade
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	
	# Update button states - only one can be selected
	for i in range(_grade_buttons.size()):
		_grade_buttons[i].button_pressed = (i == grade)
	
	_validate_input()


func _on_name_changed(_new_text: String) -> void:
	_validate_input()


func _get_selected_categories() -> Array:
	var selected: Array = []
	for cat_id: String in _category_checkboxes:
		var checkbox: CheckBox = _category_checkboxes[cat_id]
		if checkbox.button_pressed:
			selected.append(cat_id)
	return selected


func _validate_input() -> void:
	var name_valid := name_input.text.strip_edges().length() >= 2
	var grade_valid := _selected_grade >= 0
	var categories_valid := _get_selected_categories().size() > 0

	start_button.disabled = not (name_valid and grade_valid and categories_valid)

	if not name_valid and name_input.text.length() > 0:
		error_label.text = "Name muss mindestens 2 Zeichen haben"
		error_label.visible = true
	elif not grade_valid:
		error_label.text = "Bitte wähle deine Klassenstufe"
		error_label.visible = true
	elif not categories_valid:
		error_label.text = "Wähle mindestens eine Kategorie"
		error_label.visible = true
	else:
		error_label.visible = false


func _on_start_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	var selected_cats := _get_selected_categories()

	if player_name.length() < 2:
		error_label.text = "Name muss mindestens 2 Zeichen haben"
		error_label.visible = true
		return

	if _selected_grade < 0:
		error_label.text = "Bitte wähle deine Klassenstufe"
		error_label.visible = true
		return

	if selected_cats.is_empty():
		error_label.text = "Wähle mindestens eine Kategorie"
		error_label.visible = true
		return

	AudioManager.play_sfx(AudioManager.SFX.UNLOCK)

	# Create profile with avatar and categories
	var profile := ProfileManager.create_profile(player_name, _selected_grade, selected_cats, _selected_avatar)

	# Unpause and close
	get_tree().paused = false
	profile_completed.emit(profile)
	queue_free()
