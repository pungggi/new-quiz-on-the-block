extends Resource
class_name QuizQuestion

## Quiz Question Resource
##
## Represents a single quiz question with multiple choice answers.
## Used to store educational content for unlocking buildings and city growth.

## The question text displayed to the player
@export_multiline var question: String = ""

## Array of possible answers (typically 3-4 options)
@export var answers: PackedStringArray = PackedStringArray()

## Index of the correct answer (0-based)
@export_range(0, 3) var correct_answer_index: int = 0

## Educational category (e.g., "math", "science", "history", "geography")
@export var category: String = "general"

## Difficulty level from 1 (easy) to 5 (hard)
@export_range(1, 5) var difficulty: int = 1

## Optional hint text shown after first wrong answer
@export_multiline var hint: String = ""

## Optional explanation shown after answering (educational value)
@export_multiline var explanation: String = ""

## Reward points for correct answer (scales with difficulty)
@export var reward_points: int = 10

## Tags for filtering questions (e.g., ["addition", "single-digit"])
@export var tags: PackedStringArray = PackedStringArray()


## Returns true if the given answer index is correct
func is_correct(answer_index: int) -> bool:
	return answer_index == correct_answer_index


## Returns the correct answer text
func get_correct_answer() -> String:
	if correct_answer_index >= 0 and correct_answer_index < answers.size():
		return answers[correct_answer_index]
	return ""


## Returns calculated reward based on difficulty
func get_reward() -> int:
	return reward_points * difficulty

