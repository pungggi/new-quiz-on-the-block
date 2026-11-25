class_name SettingsDialog
extends MenuDialog

## Settings Dialog - edits the current profile: name, avatar, grade and
## quiz categories. Layout, pause handling and ESC (= cancel) come from
## MenuDialog. Avatar, grade and category pickers are built by
## SelectionButtons as toggle chips.

@onready var name_input: LineEdit = %NameInput
@onready var avatar_container: HFlowContainer = %AvatarContainer
@onready var grade_container: HFlowContainer = %GradeContainer
@onready var category_container: HFlowContainer = %CategoryContainer
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton
@onready var reset_button: Button = %ResetButton
@onready var error_label: Label = %ErrorLabel

var _selected_grade: int = 0
var _selected_avatar: String = "fox"
var _grade_buttons: Array[Button] = []
var _avatar_buttons: Dictionary = {}
var _category_checkboxes: Dictionary = {}
## Open while the user decides about "Profil zurücksetzen"
var _reset_confirm: ConfirmationDialog = null


func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	name_input.text_changed.connect(_on_input_changed)
	error_label.visible = false

	_avatar_buttons = SelectionButtons.create_avatar_buttons(
		avatar_container, _on_avatar_selected, _selected_avatar
	)
	_grade_buttons = SelectionButtons.create_grade_buttons(
		grade_container, _on_grade_selected, _selected_grade
	)
	_category_checkboxes = SelectionButtons.create_category_checkboxes(
		category_container, _on_category_toggled_with_id
	)

	_load_current_profile()


func _load_current_profile() -> void:
	var profile: PlayerProfile = ProfileManager.current_profile
	if not profile:
		return

	name_input.text = profile.player_name
	_selected_grade = profile.grade_level
	_selected_avatar = profile.avatar_id

	SelectionButtons.update_avatar_selection(_avatar_buttons, _selected_avatar)
	SelectionButtons.update_grade_selection(_grade_buttons, _selected_grade)

	var enabled: Array = profile.get_enabled_categories()
	for cat_id: String in _category_checkboxes:
		var chip: Button = _category_checkboxes[cat_id]
		chip.button_pressed = cat_id in enabled


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
	var name_valid: bool = name_input.text.strip_edges().length() >= 2
	var cats_valid: bool = _get_selected_categories().size() > 0

	save_button.disabled = not (name_valid and cats_valid)

	if not name_valid and name_input.text.length() > 0:
		error_label.text = "Name muss mindestens 2 Zeichen haben"
		error_label.visible = true
	elif not cats_valid:
		error_label.text = "Wähle mindestens eine Kategorie"
		error_label.visible = true
	else:
		error_label.visible = false


func _on_escape() -> bool:
	# ESC closes the top-most layer only: first the reset confirmation,
	# which would otherwise be freed along with the whole settings dialog
	if _reset_confirm and is_instance_valid(_reset_confirm) and _reset_confirm.visible:
		_reset_confirm.queue_free()
		_reset_confirm = null
		return true
	_on_cancel_pressed()
	return true


func _on_save_pressed() -> void:
	var profile: PlayerProfile = ProfileManager.current_profile
	if not profile:
		return

	profile.player_name = name_input.text.strip_edges()
	profile.avatar_id = _selected_avatar
	profile.grade_level = _selected_grade
	profile.enabled_categories = _get_selected_categories()

	ProfileManager.save_profile()
	AudioManager.play_sfx(AudioManager.SFX.UNLOCK)

	# The grade decides the reading level (font + size) of the whole UI
	UITheme.refresh()

	_close()


func _on_cancel_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	_close()


func _on_reset_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	# ConfirmationDialog is an embedded window. Windows do not inherit the
	# theme of the window they are embedded in, so it gets ours explicitly.
	var confirm := ConfirmationDialog.new()
	confirm.theme = UITheme.get_theme(UITheme.current_level())
	confirm.title = "Profil zurücksetzen"
	confirm.dialog_text = "Profil wirklich zurücksetzen?\nAlle Fortschritte gehen verloren!"
	confirm.ok_button_text = "Zurücksetzen"
	confirm.cancel_button_text = "Abbrechen"
	confirm.confirmed.connect(_do_reset.bind(confirm))
	confirm.canceled.connect(confirm.queue_free)
	_reset_confirm = confirm
	add_child(confirm)
	confirm.popup_centered()


func _do_reset(dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	_reset_confirm = null
	ProfileManager.reset_current_profile()
	AudioManager.play_sfx(AudioManager.SFX.QUIZ_WRONG)
	_load_current_profile()
	UITheme.refresh()
