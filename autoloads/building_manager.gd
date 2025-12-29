extends Node

## Building Manager
##
## Manages building types, player resources, and placement validation.
## Works with BuildCursor for actual placement.

signal education_points_changed(new_total: int)
signal building_unlocked(building: BuildingData)
signal building_placed_event(building: BuildingData, position: Vector3i)

## Player's education points - now proxied through ProfileManager
## BALANCE: Start=100, House=10, NPC reward=10-15
var education_points: int:
	get:
		var profile_mgr: Node = get_node_or_null("/root/ProfileManager")
		if profile_mgr:
			return profile_mgr.get_points()
		return 100
	set(value):
		var profile_mgr: Node = get_node_or_null("/root/ProfileManager")
		if profile_mgr and profile_mgr.current_profile:
			var diff: int = value - profile_mgr.get_points()
			if diff > 0:
				profile_mgr.add_points(diff)
			elif diff < 0:
				profile_mgr.spend_points(-diff)
		education_points_changed.emit(value)

## Player stats for unlock tracking
var player_stats: Dictionary = {
	"total_correct": 0,
	"correct_math": 0,
	"correct_science": 0,
	"correct_geography": 0,
	"correct_history": 0,
	"buildings_placed": 0
}

## All available building types
var _building_types: Array[BuildingData] = []

## Currently selected building for placement
var selected_building: BuildingData = null


func _ready() -> void:
	_load_building_types()
	# Connect to quiz results
	if QuizManager:
		QuizManager.question_answered.connect(_on_question_answered)

	# Connect to profile changes to sync stats
	var profile_mgr: Node = get_node_or_null("/root/ProfileManager")
	if profile_mgr:
		profile_mgr.profile_updated.connect(_on_profile_updated)
		profile_mgr.profile_loaded.connect(_on_profile_loaded)
		profile_mgr.profile_switched.connect(_on_profile_loaded) # Sync on switch too
		# Initial sync if profile is already loaded
		call_deferred("_sync_stats_from_profile")


## Sync player_stats from PlayerProfile
func _sync_stats_from_profile() -> void:
	var profile_mgr: Node = get_node_or_null("/root/ProfileManager")
	if not profile_mgr or not profile_mgr.current_profile:
		return

	var profile: PlayerProfile = profile_mgr.current_profile
	player_stats["total_correct"] = profile.total_correct_answers
	player_stats["buildings_placed"] = profile.buildings_placed

	# Sync category correct counts
	player_stats["correct_math"] = profile.category_correct.get("math", 0)
	player_stats["correct_science"] = profile.category_correct.get("science", 0)
	player_stats["correct_geography"] = profile.category_correct.get("geography", 0)
	player_stats["correct_history"] = profile.category_correct.get("history", 0)


func _on_profile_updated(_profile: PlayerProfile) -> void:
	_sync_stats_from_profile()


func _on_profile_loaded(_profile: PlayerProfile) -> void:
	_sync_stats_from_profile()


## Load all building definitions from resources
func _load_building_types() -> void:
	var buildings_path := "res://data/buildings/"
	var dir := DirAccess.open(buildings_path)
	
	if not dir:
		push_warning("BuildingManager: Buildings directory not found, creating default buildings")
		_create_default_buildings()
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource := load(buildings_path + file_name)
			if resource is BuildingData:
				_building_types.append(resource)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if _building_types.is_empty():
		_create_default_buildings()
	
	print("BuildingManager: Loaded %d building types" % _building_types.size())


## Create default buildings if none exist
func _create_default_buildings() -> void:
	# Basic House
	var house := BuildingData.new()
	house.display_name = "Haus"
	house.description = "Ein einfaches Wohnhaus."
	house.category = "residential"
	house.cost = 10
	house.color = Color.CORAL
	house.population = 4
	_building_types.append(house)
	
	# School
	var school := BuildingData.new()
	school.display_name = "Schule"
	school.description = "Bildung für alle!"
	school.category = "education"
	school.cost = 30
	school.color = Color.MEDIUM_PURPLE
	school.required_correct_answers = 5
	school.education_bonus = 1.5
	_building_types.append(school)
	
	# Shop
	var shop := BuildingData.new()
	shop.display_name = "Laden"
	shop.description = "Kaufe und verkaufe Waren."
	shop.category = "commercial"
	shop.cost = 20
	shop.color = Color.GOLD
	shop.required_correct_answers = 3
	shop.income = 5
	_building_types.append(shop)


## Get all building types
func get_all_buildings() -> Array[BuildingData]:
	return _building_types


## Get buildings filtered by category
func get_buildings_by_category(category: String) -> Array[BuildingData]:
	var filtered: Array[BuildingData] = []
	for b in _building_types:
		if b.category == category:
			filtered.append(b)
	return filtered


## Get only unlocked buildings
func get_unlocked_buildings() -> Array[BuildingData]:
	var unlocked: Array[BuildingData] = []
	for b in _building_types:
		if b.is_unlocked(player_stats):
			unlocked.append(b)
	return unlocked


## Select a building for placement
func select_building(building: BuildingData) -> bool:
	if not building.is_unlocked(player_stats):
		return false
	selected_building = building
	return true


## Deselect current building (exit build mode)
func deselect_building() -> void:
	selected_building = null


## Try to place the selected building (called by BuildCursor)
func try_place_building(position: Vector3i) -> bool:
	if not selected_building:
		return false
	if not selected_building.can_afford(education_points):
		return false
	
	education_points -= selected_building.cost
	player_stats["buildings_placed"] += 1
	building_placed_event.emit(selected_building, position)
	return true


## Award points from quiz answer
func _on_question_answered(question: QuizQuestion, was_correct: bool) -> void:
	var profile_mgr: Node = get_node_or_null("/root/ProfileManager")

	if was_correct:
		# Update PlayerProfile
		if profile_mgr and profile_mgr.current_profile:
			var profile: PlayerProfile = profile_mgr.current_profile
			profile.record_correct(question.category, question.reward_points)
			profile_mgr.save_profile()

		# Update local stats for building unlock checks
		player_stats["total_correct"] += 1
		var category_key := "correct_" + question.category
		if player_stats.has(category_key):
			player_stats[category_key] += 1

		# Points are handled by profile now, but education_points_changed needs to fire
		education_points_changed.emit(education_points)

		# Check for newly unlocked buildings
		for b in _building_types:
			if b.get_unlock_progress(player_stats) == 1.0:
				var prev_stats := player_stats.duplicate()
				prev_stats["total_correct"] -= 1
				if b.get_unlock_progress(prev_stats) < 1.0:
					building_unlocked.emit(b)
	else:
		# Record wrong answer in profile
		if profile_mgr and profile_mgr.current_profile:
			var profile: PlayerProfile = profile_mgr.current_profile
			profile.record_wrong(question.category)
			profile_mgr.save_profile()
