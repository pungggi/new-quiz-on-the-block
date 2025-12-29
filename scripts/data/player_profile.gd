extends Resource
class_name PlayerProfile

## Player Profile Data
## Stores player name, grade level, and progression

## Grade level constants
const GRADE_KINDERGARTEN: int = 0
const GRADE_MIN: int = 1
const GRADE_MAX: int = 9
const GRADE_ADULT: int = 10 # Erwachsene

## Grade level display names (German)
const GRADE_NAMES: Dictionary = {
	0: "Kindergarten",
	1: "1. Klasse",
	2: "2. Klasse",
	3: "3. Klasse",
	4: "4. Klasse",
	5: "5. Klasse",
	6: "6. Klasse",
	7: "7. Klasse",
	8: "8. Klasse",
	9: "9. Klasse",
	10: "Erwachsene",
}

## Available quiz categories
const ALL_CATEGORIES: Array = ["math", "science", "geography", "history"]
const CATEGORY_NAMES: Dictionary = {
	"math": "🔢 Mathematik",
	"science": "🔬 Naturwissenschaft",
	"geography": "🌍 Geografie",
	"history": "📜 Geschichte",
}

## Available avatars
const ALL_AVATARS: Array = ["fox", "bear", "lion", "panda", "unicorn", "frog", "owl", "koala", "butterfly", "octopus"]
const AVATAR_EMOJIS: Dictionary = {
	"fox": "🦊",
	"bear": "🐻",
	"lion": "🦁",
	"panda": "🐼",
	"unicorn": "🦄",
	"frog": "🐸",
	"owl": "🦉",
	"koala": "🐨",
	"butterfly": "🦋",
	"octopus": "🐙",
}

## Difficulty mapping - which question difficulties are appropriate for each grade
## difficulty 1 = easy, 2 = medium, 3 = hard
const GRADE_DIFFICULTY_MAP: Dictionary = {
	0: [1], # Kindergarten: only easy
	1: [1], # 1st grade: only easy
	2: [1], # 2nd grade: only easy
	3: [1, 2], # 3rd grade: easy + medium
	4: [1, 2], # 4th grade: easy + medium
	5: [1, 2], # 5th grade: easy + medium
	6: [1, 2, 3], # 6th grade: all
	7: [2, 3], # 7th grade: medium + hard
	8: [2, 3], # 8th grade: medium + hard
	9: [2, 3], # 9th grade: medium + hard
	10: [3], # Adults: only hard
}

## Point multiplier per grade level
const GRADE_POINT_MULTIPLIER: Dictionary = {
	0: 1.0,
	1: 1.0,
	2: 1.1,
	3: 1.2,
	4: 1.3,
	5: 1.4,
	6: 1.5,
	7: 1.6,
	8: 1.7,
	9: 1.8,
	10: 2.0, # Adults get double points
}

## Player's display name
@export var player_name: String = ""

## Player's avatar id
@export var avatar_id: String = "fox"

## Grade level (0 = Kindergarten, 1-9 = school grades, 10 = Adults)
@export_range(0, 10) var grade_level: int = 0

## Enabled quiz categories (empty = all enabled)
@export var enabled_categories: Array = []

## Total education points earned
@export var total_points: int = 100 # Start with 100 points

## Statistics
@export var total_correct_answers: int = 0
@export var total_wrong_answers: int = 0
@export var total_quizzes_completed: int = 0
@export var buildings_placed: int = 0

## Per-category stats
@export var category_correct: Dictionary = {}
@export var category_wrong: Dictionary = {}

## Unlocked achievements
@export var unlocked_achievements: Array = []

## Profile creation timestamp
@export var created_at: String = ""

## Character customization data
var customization: PlayerCustomization = null


## Get or create customization
func get_customization() -> PlayerCustomization:
	if customization == null:
		customization = PlayerCustomization.create_default()
	return customization


## Get display name for grade level
static func get_grade_name(grade: int) -> String:
	return GRADE_NAMES.get(grade, "Unbekannt")


## Get allowed difficulty levels for a grade
static func get_allowed_difficulties(grade: int) -> Array:
	return GRADE_DIFFICULTY_MAP.get(grade, [1])


## Get point multiplier for a grade
static func get_point_multiplier(grade: int) -> float:
	return GRADE_POINT_MULTIPLIER.get(grade, 1.0)


## Calculate points for a correct answer
func calculate_points(base_points: int, question_difficulty: int) -> int:
	var multiplier := get_point_multiplier(grade_level)
	var difficulty_bonus := 1.0 + (question_difficulty - 1) * 0.25 # +25% per difficulty level
	return int(base_points * multiplier * difficulty_bonus)


## Record a correct answer (points are handled separately by BuildingManager)
func record_correct(category: String, _points_earned: int = 0) -> void:
	total_correct_answers += 1
	# Note: points are added via BuildingManager.education_points setter

	if not category_correct.has(category):
		category_correct[category] = 0
	category_correct[category] += 1


## Record a wrong answer
func record_wrong(category: String) -> void:
	total_wrong_answers += 1
	
	if not category_wrong.has(category):
		category_wrong[category] = 0
	category_wrong[category] += 1


## Get accuracy percentage
func get_accuracy() -> float:
	var total := total_correct_answers + total_wrong_answers
	if total == 0:
		return 0.0
	return float(total_correct_answers) / float(total) * 100.0


## Check if a category is enabled
func is_category_enabled(category: String) -> bool:
	# Empty array means all categories enabled
	if enabled_categories.is_empty():
		return true
	return category in enabled_categories


## Get list of enabled categories
func get_enabled_categories() -> Array:
	if enabled_categories.is_empty():
		return ALL_CATEGORIES.duplicate()
	return enabled_categories.duplicate()


## Get avatar emoji
func get_avatar_emoji() -> String:
	return AVATAR_EMOJIS.get(avatar_id, "🦊")


## Convert to dictionary for saving
func to_dict() -> Dictionary:
	var result := {
		"player_name": player_name,
		"avatar_id": avatar_id,
		"grade_level": grade_level,
		"enabled_categories": enabled_categories,
		"total_points": total_points,
		"total_correct_answers": total_correct_answers,
		"total_wrong_answers": total_wrong_answers,
		"total_quizzes_completed": total_quizzes_completed,
		"buildings_placed": buildings_placed,
		"category_correct": category_correct,
		"category_wrong": category_wrong,
		"unlocked_achievements": unlocked_achievements,
		"created_at": created_at,
	}
	if customization:
		result["customization"] = customization.to_dict()
	return result


## Load from dictionary
func from_dict(data: Dictionary) -> void:
	player_name = data.get("player_name", "")
	avatar_id = data.get("avatar_id", "fox")
	grade_level = data.get("grade_level", 0)
	enabled_categories = data.get("enabled_categories", [])
	total_points = data.get("total_points", 100)
	total_correct_answers = data.get("total_correct_answers", 0)
	total_wrong_answers = data.get("total_wrong_answers", 0)
	total_quizzes_completed = data.get("total_quizzes_completed", 0)
	buildings_placed = data.get("buildings_placed", 0)
	category_correct = data.get("category_correct", {})
	category_wrong = data.get("category_wrong", {})
	unlocked_achievements = data.get("unlocked_achievements", [])
	created_at = data.get("created_at", "")

	# Load customization
	if data.has("customization"):
		customization = PlayerCustomization.create_default()
		customization.from_dict(data["customization"])
