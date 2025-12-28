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


func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)

	# Setup answer buttons
	_answer_buttons = [answer1_button, answer2_button, answer3_button]
	for i in range(_answer_buttons.size()):
		var btn := _answer_buttons[i]
		btn.pressed.connect(_on_answer_pressed.bind(i))

	visible = false


func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_random_question()


func close() -> void:
	visible = false
	_reset_button_colors()


func _load_random_question() -> void:
	var quiz_mgr = get_node_or_null("/root/QuizManager")
	if quiz_mgr:
		_current_question = quiz_mgr.get_random_question()
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

	# Visual feedback
	for i in range(_answer_buttons.size()):
		var btn := _answer_buttons[i]
		btn.disabled = true

		if i == _current_question.correct_answer_index:
			btn.modulate = Color.GREEN
		elif i == answer_index and not is_correct:
			btn.modulate = Color.RED

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
