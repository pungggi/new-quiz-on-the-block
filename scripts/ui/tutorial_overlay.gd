extends Control
class_name TutorialOverlay

## First-run tutorial overlay
## Shows a series of steps to introduce the game to new players

signal tutorial_completed

const TUTORIAL_STEPS: Array[Dictionary] = [
	{
		"title": "🏙️ Willkommen bei New Quiz on the Block!",
		"text": "Baue deine eigene Stadt, indem du Quizfragen beantwortest!",
		"icon": "🎮"
	},
	{
		"title": "👨‍🏫 NPCs & Quizze",
		"text": "Klicke auf die bunten NPCs, um Quizfragen zu beantworten.\nRichtige Antworten geben dir Bildungspunkte!",
		"icon": "❓"
	},
	{
		"title": "🏗️ Gebäude bauen",
		"text": "Wähle unten ein Gebäude aus und klicke auf die Wiese.\nManche Gebäude musst du erst freischalten!",
		"icon": "🏠"
	},
	{
		"title": "🎯 Dein Ziel",
		"text": "Sammle Punkte, schalte alle Gebäude frei und\nbaue die schönste Stadt!",
		"icon": "⭐"
	}
]

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var icon_label: Label = $Panel/VBox/IconLabel
@onready var text_label: Label = $Panel/VBox/TextLabel
@onready var progress_label: Label = $Panel/VBox/ProgressLabel
@onready var next_button: Button = $Panel/VBox/HBox/NextButton
@onready var skip_button: Button = $Panel/VBox/HBox/SkipButton

var _current_step: int = 0


func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	
	# Check if tutorial was already completed
	if _was_tutorial_completed():
		_close_tutorial()
		return
	
	_show_step(0)
	
	# Pause game tree while tutorial is shown
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _was_tutorial_completed() -> bool:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		return config.get_value("tutorial", "completed", false)
	return false


func _mark_tutorial_completed() -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")  # Load existing or create new
	config.set_value("tutorial", "completed", true)
	config.save("user://settings.cfg")


func _show_step(step_index: int) -> void:
	if step_index >= TUTORIAL_STEPS.size():
		_complete_tutorial()
		return
	
	_current_step = step_index
	var step: Dictionary = TUTORIAL_STEPS[step_index]
	
	title_label.text = step["title"]
	icon_label.text = step["icon"]
	text_label.text = step["text"]
	progress_label.text = "%d / %d" % [step_index + 1, TUTORIAL_STEPS.size()]
	
	# Update button text
	if step_index == TUTORIAL_STEPS.size() - 1:
		next_button.text = "Los geht's! 🚀"
	else:
		next_button.text = "Weiter →"
	
	# Animate in
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)


func _on_next_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	_show_step(_current_step + 1)


func _on_skip_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	_complete_tutorial()


func _complete_tutorial() -> void:
	_mark_tutorial_completed()
	_close_tutorial()


func _close_tutorial() -> void:
	get_tree().paused = false
	tutorial_completed.emit()
	queue_free()

