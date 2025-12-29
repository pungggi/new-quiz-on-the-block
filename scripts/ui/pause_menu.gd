extends Control
class_name PauseMenu

## Pause Menu
## Shown when ESC is pressed during gameplay

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
	
	# Pause the game
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	AudioManager.play_sfx(AudioManager.SFX.PANEL_OPEN)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	get_tree().paused = false
	queue_free()


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	var dialog: Control = SETTINGS_DIALOG_SCENE.instantiate()
	add_child(dialog)


func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	
	# Save before leaving
	SaveManager.save_game()
	
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	
	# Save before quitting
	SaveManager.save_game()
	
	get_tree().quit()

