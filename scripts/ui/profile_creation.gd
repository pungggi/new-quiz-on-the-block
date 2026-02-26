extends Control
class_name ProfileCreation

## Profile Creation Screen
## Shown on first launch to get player name and grade level
## Uses SelectionButtons for reusable button creation

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

	# Use SelectionButtons helper for consistent button creation
	_avatar_buttons = SelectionButtons.create_avatar_buttons(
		avatar_container, _on_avatar_selected, _selected_avatar
	)
	_grade_buttons = SelectionButtons.create_grade_buttons(
		grade_container, _on_grade_selected, _selected_grade
	)
	_category_checkboxes = SelectionButtons.create_category_checkboxes(
		category_container, _on_category_toggled
	)

	# Pause game while creating profile
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_avatar_selected(av_id: String) -> void:
	_selected_avatar = av_id
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	SelectionButtons.update_avatar_selection(_avatar_buttons, _selected_avatar)


func _on_category_toggled(_pressed: bool, _cat_id: String) -> void:
	_validate_input()


func _on_grade_selected(grade: int) -> void:
	_selected_grade = grade
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	SelectionButtons.update_grade_selection(_grade_buttons, _selected_grade)
	_validate_input()


func _on_name_changed(_new_text: String) -> void:
	_validate_input()


func _get_selected_categories() -> Array:
	return SelectionButtons.get_selected_categories(_category_checkboxes)


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
