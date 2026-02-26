extends Resource
class_name PropData

## Prop Data Resource
##
## Defines a prop type (tree, bench, trash can, etc.) with its visual
## properties and placement rules. Used by PropMeshGenerator for mesh
## creation and PropManager for placement logic.

## Prop categories
enum PropType {
	TREE,
	BENCH,
	TRASH_CAN,
	BUSH,
	FLOWER_BED,
	FOUNTAIN,
	BIKE_RACK,
	MAILBOX,
	PHONE_BOOTH,
	FIRE_HYDRANT,
	ROAD_SIGN,
	TRAFFIC_LIGHT,
	ROAD_MARKING,
	BLACKBOARD,
	BOOK_STACK,
	GLOBE_PEDESTAL,
	PARK_LAMP,
	PICNIC_TABLE,
	SANDBOX,
	SWING_SET,
	SMALL_FOUNTAIN,
}

## Where a prop prefers to be placed
enum PlacementRule {
	NEAR_BUILDING,
	ALONG_ROAD,
	NEAR_ROAD,
	ANY,
}

## Display name of the prop
@export var display_name: String = "Prop"

## Description shown to player
@export_multiline var description: String = ""

## What kind of prop this is (determines mesh generation)
@export var prop_type: PropType = PropType.TREE

## Bounding box size in world units
@export var size: Vector3 = Vector3(1, 1, 1)

## Primary color (trunk, frame, body)
@export var primary_color: Color = Color.SADDLE_BROWN

## Secondary color (leaves, seat, accent)
@export var secondary_color: Color = Color.DARK_GREEN

## Cost in education points to place manually
@export var cost: int = 2

## Where this prop prefers to be placed
@export var placement_rule: PlacementRule = PlacementRule.ANY

## Minimum distance from a building center for auto-placement
@export var min_distance_from_building: float = 1.5

## Whether multiple instances can be placed in a cluster
@export var can_cluster: bool = true

## Building category for the panel UI
@export_enum("decoration") var category: String = "decoration"

## Icon for UI display (optional)
@export var icon: Texture2D


## Check if player can afford this prop
func can_afford(points: int) -> bool:
	return points >= cost
