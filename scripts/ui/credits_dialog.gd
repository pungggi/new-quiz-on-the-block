extends Control
class_name CreditsDialog

## Credits Dialog
## Shows game credits and information

signal closed

@onready var close_button: Button = $Panel/VBox/CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)


## ESC closes the dialog. Consumes the event so an underlying menu
## (e.g. pause menu) does not react to it.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_close_pressed()


func _on_close_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	closed.emit()
	queue_free()

