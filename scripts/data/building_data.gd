extends Resource
class_name BuildingData

## Building Data Resource
##
## Defines a building type with its properties, costs, and unlock requirements.
## Education points from quizzes are used as the building resource.

## Display name of the building
@export var display_name: String = "Building"

## Description shown to player
@export_multiline var description: String = ""

## Building category for organization
@export_enum("residential", "commercial", "education", "industry", "decoration") var category: String = "residential"

## Size in voxel units (width, height, depth)
@export var size: Vector3i = Vector3i(1, 1, 1)

## Cost in education points to build
@export var cost: int = 10

## Required quiz category to unlock (empty = any category)
@export var required_category: String = ""

## Minimum quiz questions answered correctly to unlock
@export var required_correct_answers: int = 0

## Building color (primary)
@export var color: Color = Color.CORNFLOWER_BLUE

## Optional secondary color for details
@export var secondary_color: Color = Color.WHITE

## Icon for UI display (optional)
@export var icon: Texture2D

## Whether this building can be stacked vertically
@export var stackable: bool = true

## Population capacity (for residential buildings)
@export var population: int = 0

## Education bonus (for education buildings like schools)
@export var education_bonus: float = 0.0

## Income generated per cycle (for commercial buildings)
@export var income: int = 0


## Check if player meets unlock requirements
func is_unlocked(stats: Dictionary) -> bool:
	# Check category requirement
	if required_category != "":
		var category_correct: int = stats.get("correct_" + required_category, 0)
		if category_correct < required_correct_answers:
			return false
	else:
		# Any category counts
		var total_correct: int = stats.get("total_correct", 0)
		if total_correct < required_correct_answers:
			return false
	return true


## Check if player can afford this building
func can_afford(education_points: int) -> bool:
	return education_points >= cost


## Get unlock progress as percentage (0.0 to 1.0)
func get_unlock_progress(stats: Dictionary) -> float:
	if required_correct_answers <= 0:
		return 1.0
	
	var current: int = 0
	if required_category != "":
		current = stats.get("correct_" + required_category, 0)
	else:
		current = stats.get("total_correct", 0)
	
	return clampf(float(current) / float(required_correct_answers), 0.0, 1.0)

