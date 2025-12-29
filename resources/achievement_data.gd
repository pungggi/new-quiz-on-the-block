extends Resource
class_name AchievementData

## Achievement Data Resource
## Defines a single achievement

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var icon: String = "🏆"  # Emoji icon
@export var points: int = 10  # Bonus points when unlocked

## Achievement types for automatic tracking
enum Type {
	MANUAL,           # Unlocked via code
	QUIZ_CORRECT,     # X correct answers
	QUIZ_STREAK,      # X correct in a row
	BUILDINGS_PLACED, # X buildings placed
	POINTS_EARNED,    # Reach X points
	CATEGORY_MASTER,  # X correct in specific category
	PROFILE_CREATED,  # Created a profile
}

@export var type: Type = Type.MANUAL
@export var target_value: int = 1
@export var target_category: String = ""  # For CATEGORY_MASTER


static func create(p_id: String, p_title: String, p_desc: String, p_icon: String, p_type: Type, p_target: int = 1, p_category: String = "") -> AchievementData:
	var data := AchievementData.new()
	data.id = p_id
	data.title = p_title
	data.description = p_desc
	data.icon = p_icon
	data.type = p_type
	data.target_value = p_target
	data.target_category = p_category
	return data

