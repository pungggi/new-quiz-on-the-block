class_name MainMenu
extends MenuDialog

## Main Menu - the entry screen with play, profiles, character, settings,
## credits and quit. Same card skeleton as every dialog (MenuDialog), just
## without a dimmed background: sky and a strip of voxel ground instead.

const GAME_SCENE := "res://scenes/main.tscn"
const PROFILE_SELECTION_SCENE := preload("res://scenes/ui/profile_selection.tscn")
const PROFILE_CREATION_SCENE := preload("res://scenes/ui/profile_creation.tscn")
const SETTINGS_DIALOG_SCENE := preload("res://scenes/ui/settings_dialog.tscn")
const CREDITS_DIALOG_SCENE := preload("res://scenes/ui/credits_dialog.tscn")
const CHARACTER_EDITOR_SCENE := preload("res://scenes/ui/character_editor.tscn")

@onready var play_button: Button = %PlayButton
@onready var profiles_button: Button = %ProfilesButton
@onready var character_button: Button = %CharacterButton
@onready var settings_button: Button = %SettingsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton
@onready var version_label: Label = %VersionLabel
@onready var profile_info_label: Label = %ProfileInfoLabel


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	profiles_button.pressed.connect(_on_profiles_pressed)
	character_button.pressed.connect(_on_character_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	version_label.text = "v0.6.0"

	# Load profiles
	ProfileManager.load_all_profiles()
	_update_profile_info()
	UITheme.refresh()

	# Connect to profile changes
	ProfileManager.profile_switched.connect(_on_profile_changed)
	ProfileManager.profile_created.connect(_on_profile_changed)

	# Start music
	AudioManager.start_ambient_music()


func _update_profile_info() -> void:
	if ProfileManager.current_profile:
		var p: PlayerProfile = ProfileManager.current_profile
		profile_info_label.text = "%s %s | %s | %d 🎓" % [
			p.get_avatar_emoji(),
			p.player_name,
			PlayerProfile.get_grade_name(p.grade_level),
			p.total_points
		]
	else:
		profile_info_label.text = "Kein Profil ausgewählt"


func _on_profile_changed(_profile: PlayerProfile) -> void:
	_update_profile_info()


func _on_play_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)

	if ProfileManager.needs_profile_creation():
		# No profile exists - create one first
		_open_profile_creation(_on_new_profile_created)
	else:
		# Start game
		_start_game()


func _on_new_profile_created(_profile: PlayerProfile) -> void:
	_update_profile_info()
	_start_game()


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_profiles_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)

	if ProfileManager.needs_profile_creation():
		_open_profile_creation(_on_profile_changed)
	else:
		var selection: ProfileSelection = PROFILE_SELECTION_SCENE.instantiate()
		selection.profile_selected.connect(_on_profile_changed)
		selection.create_new_requested.connect(_on_create_profile_from_selection)
		add_child(selection)


## "➕ Neues Profil erstellen" in the profile list. The list closes
## itself; the creation dialog opens in its place.
func _on_create_profile_from_selection() -> void:
	_open_profile_creation(_on_profile_changed)


func _open_profile_creation(on_completed: Callable) -> void:
	var creation: ProfileCreation = PROFILE_CREATION_SCENE.instantiate()
	creation.profile_completed.connect(on_completed)
	add_child(creation)


func _on_character_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)

	if ProfileManager.needs_profile_creation():
		# Need a profile first
		_open_profile_creation(_on_profile_changed)
	else:
		var editor: CharacterEditor = CHARACTER_EDITOR_SCENE.instantiate()
		add_child(editor)
		editor.open()


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	var dialog: SettingsDialog = SETTINGS_DIALOG_SCENE.instantiate()
	add_child(dialog)


func _on_credits_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	var dialog: CreditsDialog = CREDITS_DIALOG_SCENE.instantiate()
	add_child(dialog)


func _on_quit_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	get_tree().quit()
