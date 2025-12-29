extends Control
class_name SettingsDialog

## Settings Dialog
## Allows editing player profile: name, grade, categories

signal closed

@onready var name_input: LineEdit = $Panel/VBox/NameSection/NameInput
@onready var avatar_container: HBoxContainer = $Panel/VBox/AvatarSection/AvatarContainer
@onready var grade_container: GridContainer = $Panel/VBox/GradeSection/GradeContainer
@onready var category_container: VBoxContainer = $Panel/VBox/CategorySection/CategoryContainer
@onready var save_button: Button = $Panel/VBox/ButtonSection/SaveButton
@onready var cancel_button: Button = $Panel/VBox/ButtonSection/CancelButton
@onready var reset_button: Button = $Panel/VBox/ButtonSection/ResetButton
@onready var error_label: Label = $Panel/VBox/ErrorLabel

var _selected_grade: int = 0
var _selected_avatar: String = "fox"
var _grade_buttons: Array[Button] = []
var _avatar_buttons: Dictionary = {}
var _category_checkboxes: Dictionary = {}


func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	name_input.text_changed.connect(_on_input_changed)

	error_label.visible = false

	_create_avatar_buttons()
	_create_grade_buttons()
	_create_category_checkboxes()
	_load_current_profile()
	
	# Pause game while in settings
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _load_current_profile() -> void:
	var profile: Resource = ProfileManager.current_profile
	if not profile:
		return

	name_input.text = profile.player_name
	_selected_grade = profile.grade_level
	_selected_avatar = profile.avatar_id

	# Update avatar buttons
	for av_id: String in _avatar_buttons:
		_avatar_buttons[av_id].button_pressed = (av_id == _selected_avatar)

	# Update grade buttons
	for i in range(_grade_buttons.size()):
		_grade_buttons[i].button_pressed = (i == _selected_grade)

	# Update category checkboxes
	var enabled: Array = profile.get_enabled_categories()
	for cat_id: String in _category_checkboxes:
		var checkbox: CheckBox = _category_checkboxes[cat_id]
		checkbox.button_pressed = cat_id in enabled


func _create_avatar_buttons() -> void:
	for child in avatar_container.get_children():
		child.queue_free()
	_avatar_buttons.clear()

	for av_id in PlayerProfile.ALL_AVATARS:
		var btn := Button.new()
		btn.text = PlayerProfile.AVATAR_EMOJIS.get(av_id, "?")
		btn.custom_minimum_size = Vector2(44, 44)
		btn.toggle_mode = true
		btn.pressed.connect(_on_avatar_selected.bind(av_id))
		avatar_container.add_child(btn)
		_avatar_buttons[av_id] = btn


func _on_avatar_selected(av_id: String) -> void:
	_selected_avatar = av_id
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	for key: String in _avatar_buttons:
		_avatar_buttons[key].button_pressed = (key == av_id)


func _create_grade_buttons() -> void:
	for child in grade_container.get_children():
		child.queue_free()
	_grade_buttons.clear()
	
	for grade in range(0, 11):
		var btn := Button.new()
		btn.text = PlayerProfile.get_grade_name(grade)
		btn.custom_minimum_size = Vector2(90, 36)
		btn.toggle_mode = true
		btn.pressed.connect(_on_grade_selected.bind(grade))
		grade_container.add_child(btn)
		_grade_buttons.append(btn)


func _create_category_checkboxes() -> void:
	for child in category_container.get_children():
		child.queue_free()
	_category_checkboxes.clear()
	
	for cat_id in PlayerProfile.ALL_CATEGORIES:
		var checkbox := CheckBox.new()
		checkbox.text = PlayerProfile.CATEGORY_NAMES.get(cat_id, cat_id)
		checkbox.button_pressed = true
		checkbox.toggled.connect(_on_category_toggled)
		category_container.add_child(checkbox)
		_category_checkboxes[cat_id] = checkbox


func _on_grade_selected(grade: int) -> void:
	_selected_grade = grade
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	for i in range(_grade_buttons.size()):
		_grade_buttons[i].button_pressed = (i == grade)
	_validate_input()


func _on_category_toggled(_pressed: bool) -> void:
	_validate_input()


func _on_input_changed(_text: String) -> void:
	_validate_input()


func _get_selected_categories() -> Array:
	var selected: Array = []
	for cat_id: String in _category_checkboxes:
		if _category_checkboxes[cat_id].button_pressed:
			selected.append(cat_id)
	return selected


func _validate_input() -> void:
	var name_valid := name_input.text.strip_edges().length() >= 2
	var cats_valid := _get_selected_categories().size() > 0
	
	save_button.disabled = not (name_valid and cats_valid)
	
	if not name_valid and name_input.text.length() > 0:
		error_label.text = "Name muss mindestens 2 Zeichen haben"
		error_label.visible = true
	elif not cats_valid:
		error_label.text = "Wähle mindestens eine Kategorie"
		error_label.visible = true
	else:
		error_label.visible = false


func _on_save_pressed() -> void:
	var profile: Resource = ProfileManager.current_profile
	if not profile:
		return

	profile.player_name = name_input.text.strip_edges()
	profile.avatar_id = _selected_avatar
	profile.grade_level = _selected_grade
	profile.enabled_categories = _get_selected_categories()

	ProfileManager.save_profile()
	AudioManager.play_sfx(AudioManager.SFX.UNLOCK)

	_close()


func _on_cancel_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	_close()


func _on_reset_pressed() -> void:
	# Show confirmation
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Profil wirklich zurücksetzen?\nAlle Fortschritte gehen verloren!"
	confirm.confirmed.connect(_do_reset.bind(confirm))
	confirm.canceled.connect(func(): confirm.queue_free())
	add_child(confirm)
	confirm.popup_centered()


func _do_reset(dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	ProfileManager.reset_current_profile()
	AudioManager.play_sfx(AudioManager.SFX.QUIZ_WRONG)
	_load_current_profile()


func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
