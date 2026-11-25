class_name TutorialOverlay
extends MenuDialog

## First-run tutorial overlay - a few cards that introduce the game.
## Layout and pause handling come from MenuDialog; ESC is off so the
## introduction is not skipped by accident.

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

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var icon_label: Label = %IconLabel
@onready var text_label: Label = %TextLabel
@onready var progress_label: Label = %ProgressLabel
@onready var next_button: Button = %NextButton
@onready var skip_button: Button = %SkipButton

var _current_step: int = 0


func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	icon_label.add_theme_font_size_override("font_size", UITheme.px(44))

	# Check if tutorial was already completed
	if _was_tutorial_completed():
		queue_free()
		return

	_show_step(0)


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
	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)


func _on_next_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	_show_step(_current_step + 1)


func _on_skip_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	_complete_tutorial()


func _complete_tutorial() -> void:
	_mark_tutorial_completed()
	queue_free()
