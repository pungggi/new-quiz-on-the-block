extends Control
class_name HUD

signal quiz_requested

@onready var quiz_button: Button = %QuizButton


func _ready() -> void:
	quiz_button.pressed.connect(_on_quiz_button_pressed)


func _on_quiz_button_pressed() -> void:
	quiz_requested.emit()
