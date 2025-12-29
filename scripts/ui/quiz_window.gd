extends Control
class_name QuizWindow

signal answer_submitted(was_correct: bool)

@onready var close_button: Button = %CloseButton
@onready var question_label: Label = %QuestionLabel
@onready var answer1_button: Button = %Answer1Button
@onready var answer2_button: Button = %Answer2Button
@onready var answer3_button: Button = %Answer3Button

var _current_question: Resource # QuizQuestion type
var _answer_buttons: Array[Button] = []
var _current_category: String = ""
var _npc_manager: Node = null
var _quiz_manager: Node = null


func _ready() -> void:
	_npc_manager = get_node_or_null("/root/NPCManager")
	_quiz_manager = get_node_or_null("/root/QuizManager")

	# Register with NPCManager
	if _npc_manager:
		_npc_manager.quiz_window = self
	close_button.pressed.connect(_on_close_button_pressed)

	# Setup answer buttons
	_answer_buttons = [answer1_button, answer2_button, answer3_button]
	for i in range(_answer_buttons.size()):
		var btn := _answer_buttons[i]
		btn.pressed.connect(_on_answer_pressed.bind(i))

	visible = false


func open() -> void:
	open_with_category("")


## Open quiz with optional category filter (used by NPCs)
func open_with_category(category: String) -> void:
	_current_category = category
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_build_cursor_blocking(true)
	_load_random_question()
	AudioManager.play_sfx(AudioManager.SFX.PANEL_OPEN)


func close() -> void:
	visible = false
	_current_category = ""
	_reset_button_colors()
	_set_build_cursor_blocking(false)
	AudioManager.play_sfx(AudioManager.SFX.PANEL_CLOSE)


func _set_build_cursor_blocking(blocking: bool) -> void:
	# Find BuildCursor in scene and block/unblock it
	var build_cursor := get_tree().get_first_node_in_group("build_cursor")
	if build_cursor and build_cursor.has_method("set_ui_blocking"):
		build_cursor.set_ui_blocking(blocking)


func _load_random_question() -> void:
	if _quiz_manager:
		_current_question = _quiz_manager.get_random_question(_current_category)
	else:
		_current_question = null

	if not _current_question:
		question_label.text = "Keine Fragen verfügbar!"
		for btn in _answer_buttons:
			btn.visible = false
		return

	# Display question
	question_label.text = _current_question.question

	# Display answers
	for i in range(_answer_buttons.size()):
		var btn := _answer_buttons[i]
		if i < _current_question.answers.size():
			btn.text = _current_question.answers[i]
			btn.visible = true
			btn.disabled = false
		else:
			btn.visible = false

	_reset_button_colors()


func _on_answer_pressed(answer_index: int) -> void:
	if not _current_question:
		return

	var is_correct: bool = _current_question.is_correct(answer_index)

	# Play sound
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)

	# Visual feedback
	for i in range(_answer_buttons.size()):
		var btn := _answer_buttons[i]
		btn.disabled = true

		if i == _current_question.correct_answer_index:
			btn.modulate = Color.GREEN
		elif i == answer_index and not is_correct:
			btn.modulate = Color.RED

	# Emit question_answered signal for BuildingManager and AchievementManager
	if _quiz_manager and _current_question:
		_quiz_manager.question_answered.emit(_current_question, is_correct)
		_quiz_manager.record_answer(_current_category, is_correct)

	# Notify NPCManager (which notifies the NPC)
	if _npc_manager:
		_npc_manager.on_quiz_answer(is_correct)

	answer_submitted.emit(is_correct)

	# Auto-close after delay
	await get_tree().create_timer(1.5).timeout
	close()


func _reset_button_colors() -> void:
	for btn in _answer_buttons:
		btn.modulate = Color.WHITE
		btn.disabled = false


func _on_close_button_pressed() -> void:
	close()
