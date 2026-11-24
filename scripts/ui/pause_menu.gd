class_name PauseMenu
extends MenuDialog

## Pause Menu - shown when ESC is pressed during gameplay.
## Layout, pause handling and ESC come from MenuDialog.

const SETTINGS_DIALOG_SCENE := preload("res://scenes/ui/settings_dialog.tscn")
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	AudioManager.play_sfx(AudioManager.SFX.PANEL_OPEN)


func _on_escape() -> bool:
	_on_resume_pressed()
	return true


func _on_resume_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	queue_free()


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	var dialog: MenuDialog = SETTINGS_DIALOG_SCENE.instantiate()
	add_child(dialog)


func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)

	# Save before leaving
	SaveManager.save_game()

	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)

	# Save before quitting
	SaveManager.save_game()

	get_tree().quit()
