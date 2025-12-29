extends Control
class_name MainMenu

## Main Menu Screen
## Entry point for the game with play, settings, and quit options

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
		var dialog: Control = PROFILE_CREATION_SCENE.instantiate()
		dialog.profile_completed.connect(_on_new_profile_created)
		add_child(dialog)
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
		var dialog: Control = PROFILE_CREATION_SCENE.instantiate()
		dialog.profile_completed.connect(_on_profile_changed)
		add_child(dialog)
	else:
		var dialog: Control = PROFILE_SELECTION_SCENE.instantiate()
		add_child(dialog)


func _on_character_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)

	if ProfileManager.needs_profile_creation():
		# Need a profile first
		var dialog: Control = PROFILE_CREATION_SCENE.instantiate()
		dialog.profile_completed.connect(_on_profile_changed)
		add_child(dialog)
	else:
		var editor: Control = CHARACTER_EDITOR_SCENE.instantiate()
		add_child(editor)
		editor.open()


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	var dialog: Control = SETTINGS_DIALOG_SCENE.instantiate()
	add_child(dialog)


func _on_credits_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	var dialog: Control = CREDITS_DIALOG_SCENE.instantiate()
	add_child(dialog)


func _on_quit_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	get_tree().quit()
