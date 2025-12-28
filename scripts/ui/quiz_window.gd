extends Control
class_name QuizWindow

@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	visible = false


func open() -> void:
	visible = true
	# In Godot 4, MOUSE_FILTER_STOP stops mouse events from propagating to underlying controls/3D world
	mouse_filter = Control.MOUSE_FILTER_STOP


func close() -> void:
	visible = false


func _on_close_button_pressed() -> void:
	close()
