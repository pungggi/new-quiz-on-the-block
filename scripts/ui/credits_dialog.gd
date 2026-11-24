class_name CreditsDialog
extends MenuDialog

## Credits Dialog - shows game credits and information.
## Layout and ESC come from MenuDialog.

@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)


func _on_close_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	_close()
