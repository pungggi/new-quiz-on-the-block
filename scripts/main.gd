extends Node3D

const TUTORIAL_SCENE := preload("res://scenes/ui/tutorial_overlay.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")

@onready var chunk_root: Node3D = $ChunkRoot
@onready var camera_rig: Node3D = $CameraRig
@onready var hud: HUD = $UI/HUD
@onready var quiz_window: QuizWindow = $UI/QuizWindow
@onready var build_cursor: Node3D = $BuildCursor
@onready var ui: CanvasLayer = $UI

var _npc_manager: Node = null
var _prop_manager: Node = null
var _effects: Node = null
var _pause_menu: Control = null


func _ready() -> void:
	# Initialize ChunkManager and load initial chunks
	ChunkManager.initialize(chunk_root)
	if camera_rig:
		ChunkManager.set_follow_target(camera_rig)
	ChunkManager.load_initial_chunks()

	hud.quiz_requested.connect(_on_hud_quiz_requested)

	# Get autoloads
	_npc_manager = get_node_or_null("/root/NPCManager")
	_effects = get_node_or_null("/root/Effects")

	if _npc_manager:
		_npc_manager.npc_quiz_completed.connect(_on_npc_quiz_completed)

	# Initialize PropManager
	_prop_manager = get_node_or_null("/root/PropManager")
	if _prop_manager:
		var props_root := Node3D.new()
		props_root.name = "Props"
		add_child(props_root)
		_prop_manager.initialize(props_root)
		_prop_manager.decorate_world()

	if build_cursor:
		build_cursor.building_placed.connect(_on_building_placed)

	# Ambient sea life over the ocean (gulls + jumping fish)
	var sea_wildlife := SeaWildlife.new()
	sea_wildlife.name = "SeaWildlife"
	add_child(sea_wildlife)

	# Wooden bridge across the river + hedge labyrinth west of spawn
	var bridge: Node3D = load("res://scripts/world/bridge.gd").new()
	bridge.name = "Bridge"
	add_child(bridge)

	var maze: Node3D = BushMaze.new()
	maze.name = "BushMaze"
	add_child(maze)

	# Ambient land + river wildlife (deer, rabbits, foxes, insects...)
	var land_wildlife := LandWildlife.new()
	land_wildlife.name = "LandWildlife"
	add_child(land_wildlife)
	if camera_rig:
		land_wildlife.initialize(camera_rig)

	# Occasional rain showers (particles + light dim + HUD toast)
	var weather := WeatherManager.new()
	weather.name = "WeatherManager"
	add_child(weather)
	if camera_rig:
		weather.initialize(camera_rig)
	weather.weather_changed.connect(_on_weather_changed)

	# A little boat drifting on the ocean current + stars at night
	var boat := DriftBoat.new()
	boat.name = "DriftBoat"
	if camera_rig:
		boat.initialize(camera_rig)
	add_child(boat)

	var stars := Stars.new()
	stars.name = "Stars"
	add_child(stars)

	# A rideable bicycle parked right in front of the player on the spawn
	# lawn (camera looks north/+Z over the player's shoulder, so the
	# bike sits squarely in the opening shot)
	var bike := Bicycle.new()
	bike.name = "Bicycle"
	bike.position = Vector3(2.0, 2.0, 11.0)
	bike.rotation.y = 0.6
	add_child(bike)

	# Beachcombing: shells on the beach + the exchange stand
	ShellManager.initialize(self)
	var stand: Node3D = load("res://scripts/world/shell_stand.gd").new()
	stand.name = "ShellStand"
	add_child(stand)

	# Start the game (profile is already loaded from main menu)
	_start_game()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _pause_menu:
		_show_pause_menu()


func _on_hud_quiz_requested() -> void:
	quiz_window.open()


func _on_weather_changed(raining: bool) -> void:
	if raining:
		hud.show_toast("🌧️ Es regnet!", Color(0.65, 0.78, 1.0))
	else:
		hud.show_toast("☀️ Die Sonne scheint wieder!", Color(1.0, 0.88, 0.5))


func _on_building_placed(grid_pos: Vector3i) -> void:
	if _effects:
		var world_pos := Vector3(grid_pos.x, grid_pos.y, grid_pos.z)
		_effects.spawn_confetti(world_pos)


func _on_npc_quiz_completed(npc: NPC, was_correct: bool) -> void:
	if not _effects:
		return
	var pos := npc.global_position
	if was_correct:
		_effects.spawn_success(pos)
		var points := npc.get_reward_points()
		_effects.spawn_floating_text(pos, "+%d 📚" % points, Color.GREEN)
	else:
		_effects.spawn_failure(pos)


func _show_pause_menu() -> void:
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	_pause_menu.tree_exited.connect(_on_pause_menu_closed)
	ui.add_child(_pause_menu)


func _on_pause_menu_closed() -> void:
	_pause_menu = null


func _start_game() -> void:
	# Start background music
	AudioManager.start_ambient_music()

	# Show tutorial if needed
	_show_tutorial_if_needed()


func _show_tutorial_if_needed() -> void:
	# Check if this is first run
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		if config.get_value("tutorial", "completed", false):
			return # Tutorial already completed

	# Show tutorial
	var tutorial: Control = TUTORIAL_SCENE.instantiate()
	ui.add_child(tutorial)
