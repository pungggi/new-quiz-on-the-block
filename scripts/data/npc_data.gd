extends Resource
class_name NPCData

## NPC Data Resource
##
## Defines an NPC type with its quiz category and rewards.
## NPCs teach players through quizzes - each NPC specializes in a category.

## Unique identifier for this NPC type
@export var id: String = ""

## Display name shown to player
@export var display_name: String = "Lehrer"

## Quiz category this NPC asks questions from (e.g., "math", "science", "geography")
@export var category: String = ""

## Education points rewarded for correct answer
@export var reward_points: int = 10

## Visual color for the NPC mesh
@export var color: Color = Color.CORNFLOWER_BLUE

## Optional: Icon or sprite for UI
@export var icon: Texture2D

## Description shown in tooltip
@export var description: String = "Ein freundlicher Lehrer."


## Get a formatted reward string
func get_reward_text() -> String:
	return "+%d 📚" % reward_points


## Get category display name (German)
func get_category_display_name() -> String:
	match category:
		"math":
			return "Mathematik"
		"science":
			return "Naturwissenschaft"
		"geography":
			return "Geografie"
		"history":
			return "Geschichte"
		_:
			return category.capitalize()

