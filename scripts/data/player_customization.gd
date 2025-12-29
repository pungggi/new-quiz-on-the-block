extends Resource
class_name PlayerCustomization

## Player Customization Data
## Stores all character appearance settings

## Preset skin tones
const SKIN_PRESETS: Array[Color] = [
	Color(0.96, 0.84, 0.73),  # Light
	Color(0.87, 0.72, 0.58),  # Medium Light
	Color(0.76, 0.57, 0.42),  # Medium
	Color(0.55, 0.38, 0.26),  # Medium Dark
	Color(0.36, 0.24, 0.15),  # Dark
]

## Preset hair colors
const HAIR_PRESETS: Array[Color] = [
	Color(0.1, 0.05, 0.02),   # Black
	Color(0.4, 0.25, 0.1),    # Brown
	Color(0.85, 0.65, 0.3),   # Blonde
	Color(0.7, 0.25, 0.1),    # Red
	Color(0.5, 0.5, 0.55),    # Gray
	Color(0.3, 0.5, 0.9),     # Blue (fun)
	Color(0.9, 0.4, 0.7),     # Pink (fun)
	Color(0.4, 0.8, 0.4),     # Green (fun)
]

## Preset shirt colors
const SHIRT_PRESETS: Array[Color] = [
	Color(0.2, 0.5, 0.9),     # Blue
	Color(0.9, 0.3, 0.3),     # Red
	Color(0.3, 0.8, 0.4),     # Green
	Color(0.9, 0.8, 0.2),     # Yellow
	Color(0.7, 0.4, 0.9),     # Purple
	Color(0.9, 0.5, 0.2),     # Orange
	Color(0.95, 0.95, 0.95),  # White
	Color(0.15, 0.15, 0.15),  # Black
]

## Preset pants colors
const PANTS_PRESETS: Array[Color] = [
	Color(0.2, 0.3, 0.5),     # Dark Blue (Jeans)
	Color(0.15, 0.15, 0.2),   # Black
	Color(0.5, 0.4, 0.3),     # Brown
	Color(0.4, 0.45, 0.4),    # Gray
	Color(0.3, 0.5, 0.3),     # Green
	Color(0.6, 0.3, 0.3),     # Maroon
]

## Hair style enum
enum HairStyle { SHORT, LONG, SPIKY, BALD }

## Hat type enum
enum HatType { NONE, CAP, BEANIE }

## Glasses type enum  
enum GlassesType { NONE, ROUND, SQUARE }

## Character colors
@export var skin_color: Color = Color(0.96, 0.84, 0.73)
@export var hair_color: Color = Color(0.4, 0.25, 0.1)
@export var shirt_color: Color = Color(0.2, 0.5, 0.9)
@export var pants_color: Color = Color(0.2, 0.3, 0.5)

## Styles
@export var hair_style: HairStyle = HairStyle.SHORT

## Accessories
@export var glasses_type: GlassesType = GlassesType.NONE
@export var glasses_color: Color = Color(0.1, 0.1, 0.1)
@export var hat_type: HatType = HatType.NONE
@export var hat_color: Color = Color(0.3, 0.3, 0.8)


## Create default customization
static func create_default() -> PlayerCustomization:
	var custom := PlayerCustomization.new()
	return custom


## Randomize appearance
func randomize_appearance() -> void:
	skin_color = SKIN_PRESETS[randi() % SKIN_PRESETS.size()]
	hair_color = HAIR_PRESETS[randi() % HAIR_PRESETS.size()]
	shirt_color = SHIRT_PRESETS[randi() % SHIRT_PRESETS.size()]
	pants_color = PANTS_PRESETS[randi() % PANTS_PRESETS.size()]
	hair_style = randi() % HairStyle.size() as HairStyle
	glasses_type = GlassesType.NONE if randf() > 0.3 else (randi() % 2 + 1) as GlassesType
	hat_type = HatType.NONE if randf() > 0.2 else (randi() % 2 + 1) as HatType


## Convert to dictionary for saving
func to_dict() -> Dictionary:
	return {
		"skin_color": skin_color.to_html(),
		"hair_color": hair_color.to_html(),
		"shirt_color": shirt_color.to_html(),
		"pants_color": pants_color.to_html(),
		"hair_style": hair_style,
		"glasses_type": glasses_type,
		"glasses_color": glasses_color.to_html(),
		"hat_type": hat_type,
		"hat_color": hat_color.to_html(),
	}


## Load from dictionary
func from_dict(data: Dictionary) -> void:
	if data.has("skin_color"):
		skin_color = Color.html(data["skin_color"])
	if data.has("hair_color"):
		hair_color = Color.html(data["hair_color"])
	if data.has("shirt_color"):
		shirt_color = Color.html(data["shirt_color"])
	if data.has("pants_color"):
		pants_color = Color.html(data["pants_color"])
	if data.has("hair_style"):
		hair_style = data["hair_style"] as HairStyle
	if data.has("glasses_type"):
		glasses_type = data["glasses_type"] as GlassesType
	if data.has("glasses_color"):
		glasses_color = Color.html(data["glasses_color"])
	if data.has("hat_type"):
		hat_type = data["hat_type"] as HatType
	if data.has("hat_color"):
		hat_color = Color.html(data["hat_color"])
