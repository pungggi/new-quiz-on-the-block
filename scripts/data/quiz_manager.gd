extends Node

## Quiz Manager
##
## Manages loading, filtering, and serving quiz questions.
## Singleton pattern - add to Autoloads as "QuizManager".

signal question_answered(question: QuizQuestion, was_correct: bool)
signal quiz_completed(total_correct: int, total_questions: int)

## All loaded questions
var _questions: Array[QuizQuestion] = []

## Current quiz session
var _current_session: Array[QuizQuestion] = []
var _session_index: int = 0
var _session_correct: int = 0


func _ready() -> void:
	_load_questions()


## Load all quiz questions from resources
func _load_questions() -> void:
	var questions_path := "res://data/questions/"
	var dir := DirAccess.open(questions_path)
	
	if not dir:
		push_warning("QuizManager: Questions directory not found at %s" % questions_path)
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource := load(questions_path + file_name)
			if resource is QuizQuestion:
				_questions.append(resource)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("QuizManager: Loaded %d questions" % _questions.size())


## Get questions filtered by category and difficulty
func get_questions(category: String = "", min_difficulty: int = 1, max_difficulty: int = 5) -> Array[QuizQuestion]:
	var filtered: Array[QuizQuestion] = []
	
	for q in _questions:
		if category != "" and q.category != category:
			continue
		if q.difficulty < min_difficulty or q.difficulty > max_difficulty:
			continue
		filtered.append(q)
	
	return filtered


## Get a random question matching criteria
func get_random_question(category: String = "", max_difficulty: int = 5) -> QuizQuestion:
	var pool := get_questions(category, 1, max_difficulty)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


## Start a new quiz session with N questions
func start_session(count: int, category: String = "", max_difficulty: int = 5) -> void:
	var pool := get_questions(category, 1, max_difficulty)
	pool.shuffle()
	
	_current_session.clear()
	_session_index = 0
	_session_correct = 0
	
	for i in range(mini(count, pool.size())):
		_current_session.append(pool[i])


## Get the current question in the session
func get_current_question() -> QuizQuestion:
	if _session_index < _current_session.size():
		return _current_session[_session_index]
	return null


## Submit an answer for the current question
func submit_answer(answer_index: int) -> bool:
	var question := get_current_question()
	if not question:
		return false
	
	var correct := question.is_correct(answer_index)
	if correct:
		_session_correct += 1
	
	question_answered.emit(question, correct)
	_session_index += 1
	
	# Check if session is complete
	if _session_index >= _current_session.size():
		quiz_completed.emit(_session_correct, _current_session.size())
	
	return correct


## Check if there are more questions in the session
func has_next_question() -> bool:
	return _session_index < _current_session.size()


## Get session progress as percentage (0.0 - 1.0)
func get_session_progress() -> float:
	if _current_session.is_empty():
		return 0.0
	return float(_session_index) / float(_current_session.size())
