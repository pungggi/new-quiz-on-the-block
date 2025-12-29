extends Node

## GameMode Autoload
##
## Manages game modes: WALK (player movement) and BUILD (camera + building).
## Emits signals when mode changes so other systems can react.

signal mode_changed(new_mode: Mode)

enum Mode {
	WALK,  ## Player walks around, third-person camera
	BUILD  ## Free camera, building enabled
}

## Current active mode
var current_mode: Mode = Mode.WALK:
	set(value):
		if current_mode != value:
			current_mode = value
			mode_changed.emit(current_mode)
			print("GameMode: Switched to %s" % Mode.keys()[current_mode])

## Reference to player (set by player on ready)
var player: CharacterBody3D = null


func _ready() -> void:
	print("GameMode: Initialized in WALK mode")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mode"):
		toggle_mode()


## Toggle between WALK and BUILD modes
func toggle_mode() -> void:
	if current_mode == Mode.WALK:
		current_mode = Mode.BUILD
	else:
		current_mode = Mode.WALK


## Check if currently in walk mode
func is_walk_mode() -> bool:
	return current_mode == Mode.WALK


## Check if currently in build mode
func is_build_mode() -> bool:
	return current_mode == Mode.BUILD

