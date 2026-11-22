extends Control
class_name SettingsDialog

## Settings Dialog
## Allows editing player profile: name, grade, categories
## Uses SelectionButtons for reusable button creation

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

	# Use SelectionButtons helper for consistent button creation
	_avatar_buttons = SelectionButtons.create_avatar_buttons(
		avatar_container, _on_avatar_selected, _selected_avatar,
		Vector2(44, 44) # Slightly smaller for settings
	)
	_grade_buttons = SelectionButtons.create_grade_buttons(
		grade_container, _on_grade_selected, _selected_grade,
		SelectionButtons.GRADE_BUTTON_SIZE_SMALL
	)
	_category_checkboxes = SelectionButtons.create_category_checkboxes(
		category_container, _on_category_toggled_with_id
	)

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

	SelectionButtons.update_avatar_selection(_avatar_buttons, _selected_avatar)
	SelectionButtons.update_grade_selection(_grade_buttons, _selected_grade)

	# Update category checkboxes
	var enabled: Array = profile.get_enabled_categories()
	for cat_id: String in _category_checkboxes:
		var checkbox: CheckBox = _category_checkboxes[cat_id]
		checkbox.button_pressed = cat_id in enabled


func _on_avatar_selected(av_id: String) -> void:
	_selected_avatar = av_id
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	SelectionButtons.update_avatar_selection(_avatar_buttons, _selected_avatar)


func _on_grade_selected(grade: int) -> void:
	_selected_grade = grade
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	SelectionButtons.update_grade_selection(_grade_buttons, _selected_grade)
	_validate_input()


func _on_category_toggled_with_id(_pressed: bool, _cat_id: String) -> void:
	_validate_input()


func _on_input_changed(_text: String) -> void:
	_validate_input()


func _get_selected_categories() -> Array:
	return SelectionButtons.get_selected_categories(_category_checkboxes)


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


## ESC closes the dialog. Consumes the event so an underlying menu
## (e.g. pause menu) does not react to it.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
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
