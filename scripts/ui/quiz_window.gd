extends Control
class_name QuizWindow

signal answer_submitted(was_correct: bool)

@onready var close_button: Button = %CloseButton
@onready var question_label: Label = %QuestionLabel
@onready var hint_label: Label = %HintLabel
@onready var answer1_button: Button = %Answer1Button
@onready var answer2_button: Button = %Answer2Button
@onready var answer3_button: Button = %Answer3Button
@onready var explanation_label: Label = %ExplanationLabel
@onready var reward_label: Label = %RewardLabel
@onready var panel: PanelContainer = $Panel

var _current_question: Resource # QuizQuestion type
var _answer_buttons: Array[Button] = []
var _current_category: String = ""
var _npc_manager: Node = null
var _quiz_manager: Node = null
var _used_second_chance: bool = false
var _is_closing: bool = false


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
	_is_closing = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_build_cursor_blocking(true)
	_load_random_question()
	AudioManager.play_sfx(AudioManager.SFX.PANEL_OPEN)
	_animate_panel_open()


func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	AudioManager.play_sfx(AudioManager.SFX.PANEL_CLOSE)
	await _animate_panel_close()
	visible = false
	_current_category = ""
	_reset_button_colors()
	_set_build_cursor_blocking(false)
	_is_closing = false


## ESC closes the quiz. Runs before main.gd's _input (deeper nodes first)
## and consumes the event, so the pause menu does NOT open on top.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		accept_event()
		close()


func _animate_panel_open() -> void:
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)


func _animate_panel_close() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	await tween.finished


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

	# Reset state for new question
	_used_second_chance = false
	hint_label.visible = false
	hint_label.text = ""
	explanation_label.visible = false
	explanation_label.text = ""
	reward_label.visible = false
	reward_label.text = ""

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

	# Keyboard focus on the first answer so questions can be answered
	# with arrows + Enter immediately (deferred until visibility settles)
	_focus_first_answer.call_deferred()


## Give keyboard focus to the first selectable answer button.
## Falls back to the close button when no answers are available.
func _focus_first_answer() -> void:
	for btn in _answer_buttons:
		if btn.visible and not btn.disabled:
			btn.grab_focus()
			return
	close_button.grab_focus()


func _on_answer_pressed(answer_index: int) -> void:
	if not _current_question:
		return

	var is_correct: bool = _current_question.is_correct(answer_index)

	# Play sound
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)

	# Visual feedback with animations
	if is_correct:
		# Disable all buttons and highlight correct
		for i in range(_answer_buttons.size()):
			_answer_buttons[i].disabled = true
			if i == _current_question.correct_answer_index:
				_animate_correct_button(_answer_buttons[i])
	else:
		# Animate wrong button
		_animate_wrong_button(_answer_buttons[answer_index])

		# Show hint on first wrong answer if available
		if not _used_second_chance and _current_question.hint != "":
			_used_second_chance = true
			hint_label.text = "💡 " + _current_question.hint
			hint_label.visible = true

			# Second chance only for grade ≤ 4
			var grade: int = 0
			if ProfileManager and ProfileManager.current_profile:
				grade = ProfileManager.current_profile.grade_level
			if grade <= 4:
				# Disable only the wrong button, let player retry
				_answer_buttons[answer_index].disabled = true
				_focus_first_answer()
				return

		# No second chance (or already used): disable all, highlight correct
		for i in range(_answer_buttons.size()):
			_answer_buttons[i].disabled = true
			if i == _current_question.correct_answer_index:
				_animate_correct_button(_answer_buttons[i])

	# Show explanation if available
	if _current_question.explanation != "":
		explanation_label.text = _current_question.explanation
		explanation_label.visible = true

	# Show reward on correct answer
	if is_correct:
		_show_reward_label()

	# Emit question_answered signal for BuildingManager and AchievementManager
	if _quiz_manager and _current_question:
		_quiz_manager.question_answered.emit(_current_question, is_correct)
		_quiz_manager.record_answer(_current_category, is_correct)

	# Notify NPCManager (which notifies the NPC)
	if _npc_manager:
		_npc_manager.on_quiz_answer(is_correct)

	answer_submitted.emit(is_correct)

	# Auto-close after delay (longer when explanation shown)
	var delay := 2.5 if explanation_label.visible else 1.5
	await get_tree().create_timer(delay).timeout
	close()


func _show_reward_label() -> void:
	if not _current_question:
		return
	var earned: int = _current_question.get_reward()
	if ProfileManager and ProfileManager.current_profile:
		earned = ProfileManager.current_profile.calculate_points(
			_current_question.reward_points, _current_question.difficulty
		)
	reward_label.text = "+%d 📚" % earned
	reward_label.visible = true
	reward_label.scale = Vector2(0.5, 0.5)
	# Wait one frame for layout to update so size is valid for pivot calculation
	await get_tree().process_frame
	reward_label.pivot_offset = reward_label.size / 2.0
	var tween := create_tween()
	tween.tween_property(reward_label, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _animate_correct_button(btn: Button) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "modulate", Color.GREEN, 0.2)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)


func _animate_wrong_button(btn: Button) -> void:
	btn.modulate = Color.RED
	var original_pos := btn.position.x
	var tween := create_tween()
	tween.tween_property(btn, "position:x", original_pos - 10, 0.05)
	tween.tween_property(btn, "position:x", original_pos + 10, 0.1)
	tween.tween_property(btn, "position:x", original_pos - 5, 0.05)
	tween.tween_property(btn, "position:x", original_pos, 0.05)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.3)


func _reset_button_colors() -> void:
	for btn in _answer_buttons:
		btn.modulate = Color.WHITE
		btn.disabled = false


func _on_close_button_pressed() -> void:
	close()
