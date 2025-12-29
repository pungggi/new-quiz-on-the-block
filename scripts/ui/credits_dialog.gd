extends Control
class_name CreditsDialog

## Credits Dialog
## Shows game credits and information

signal closed

@onready var close_button: Button = $Panel/VBox/CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)


func _on_close_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	closed.emit()
	queue_free()

