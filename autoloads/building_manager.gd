extends Node

## Building Manager
##
## Manages building types, player resources, and placement validation.
## Works with BuildCursor for actual placement.
## Uses ProfileManager as single source of truth for player data.

signal education_points_changed(new_total: int)
signal building_unlocked(building: BuildingData)
signal building_placed_event(building: BuildingData, position: Vector3i)
signal building_interaction_prompt_show(building: StaticBody3D)
signal building_interaction_prompt_hide()
signal building_level_changed(building: StaticBody3D, new_level: int)

## All available building types
var _building_types: Array[BuildingData] = []

## Currently selected building for placement
var selected_building: BuildingData = null

## Last building that had interaction prompt shown (for hiding)
var _last_prompted_building: StaticBody3D = null

## Tween for prompt animation
var _prompt_tween: Tween = null


## Player's education points - proxied through ProfileManager
var education_points: int:
	get:
		return ProfileManager.get_points() if ProfileManager else 100
	set(value):
		if ProfileManager and ProfileManager.current_profile:
			var diff: int = value - ProfileManager.get_points()
			if diff > 0:
				ProfileManager.add_points(diff)
			elif diff < 0:
				ProfileManager.spend_points(-diff)
		education_points_changed.emit(value)


## Player stats - computed property from ProfileManager (for backwards compatibility)
var player_stats: Dictionary:
	get:
		return _get_stats_from_profile()


func _get_stats_from_profile() -> Dictionary:
	if not ProfileManager or not ProfileManager.current_profile:
		return {"total_correct": 0, "buildings_placed": 0}

	var profile: PlayerProfile = ProfileManager.current_profile
	return {
		"total_correct": profile.total_correct_answers,
		"buildings_placed": profile.buildings_placed,
		"correct_math": profile.category_correct.get("math", 0),
		"correct_science": profile.category_correct.get("science", 0),
		"correct_geography": profile.category_correct.get("geography", 0),
		"correct_history": profile.category_correct.get("history", 0),
	}


func _ready() -> void:
	_load_building_types()

	# Connect to quiz results
	if QuizManager:
		QuizManager.question_answered.connect(_on_question_answered)

	# Connect to profile changes for UI updates
	if ProfileManager:
		ProfileManager.profile_updated.connect(_on_profile_changed)
		ProfileManager.profile_loaded.connect(_on_profile_changed)
		ProfileManager.profile_switched.connect(_on_profile_changed)

	# Connect to day/night cycle for lighting
	_connect_day_night_deferred()

	# Connect to player for building interactions (deferred)
	_connect_player_interaction_deferred()


func _on_profile_changed(_profile: PlayerProfile) -> void:
	# Notify UI that points may have changed
	education_points_changed.emit(education_points)


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
	var profile: PlayerProfile = _get_current_profile()

	for b in _building_types:
		if profile:
			if b.is_unlocked(profile):
				unlocked.append(b)
		elif b.is_unlocked(player_stats):
			unlocked.append(b)
	return unlocked


## Select a building for placement
func select_building(building: BuildingData) -> bool:
	var profile: PlayerProfile = _get_current_profile()
	var is_unlocked: bool = false
	if profile:
		is_unlocked = building.is_unlocked(profile)
	else:
		is_unlocked = building.is_unlocked(player_stats)

	if not is_unlocked:
		return false
	selected_building = building
	return true


## Helper to get current profile safely
func _get_current_profile() -> PlayerProfile:
	if ProfileManager and ProfileManager.current_profile:
		return ProfileManager.current_profile
	return null


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

	# Record building placement in profile
	if ProfileManager and ProfileManager.current_profile:
		ProfileManager.current_profile.buildings_placed += 1
		ProfileManager.save_profile()

	building_placed_event.emit(selected_building, position)
	return true


## Award points from quiz answer
func _on_question_answered(question: QuizQuestion, was_correct: bool) -> void:
	if not ProfileManager or not ProfileManager.current_profile:
		return

	var profile: PlayerProfile = ProfileManager.current_profile
	var prev_correct: int = profile.total_correct_answers

	# Every answered question counts as a completed quiz
	profile.total_quizzes_completed += 1

	if was_correct:
		# Calculate actual reward with grade multiplier
		var earned: int = profile.calculate_points(question.reward_points, question.difficulty)
		ProfileManager.add_points(earned)
		profile.record_correct(question.category, earned)
		ProfileManager.save_profile()

		# Notify UI
		education_points_changed.emit(education_points)

		# Check for newly unlocked buildings
		for b in _building_types:
			if b.get_unlock_progress(profile) == 1.0:
				if prev_correct < b.required_correct_answers and profile.total_correct_answers >= b.required_correct_answers:
					building_unlocked.emit(b)
	else:
		# Record wrong answer in profile
		profile.record_wrong(question.category)
		ProfileManager.save_profile()


## Connect to day/night cycle after scene load (deferred)
func _connect_day_night_deferred() -> void:
	await get_tree().process_frame
	var dnc = get_tree().current_scene.get_node_or_null("DayNightCycle") as DayNightCycle
	if not dnc:
		return
	dnc.day_phase_changed.connect(_on_day_phase_changed)
	# Apply initial state if game starts at night or dusk
	_on_day_phase_changed(dnc.current_phase)


## Handle day phase changes - toggle window emission and lamp lights
func _on_day_phase_changed(phase) -> void:
	var lights_on = (phase == DayNightCycle.DayPhase.DUSK or phase == DayNightCycle.DayPhase.NIGHT)
	_set_window_emission(lights_on)
	_set_lamp_lights(phase == DayNightCycle.DayPhase.NIGHT)


## Set window emission on all buildings
func _set_window_emission(enabled: bool) -> void:
	var buildings_root: Node = get_tree().current_scene.get_node_or_null("Buildings")
	if not buildings_root:
		return

	for building in buildings_root.get_children():
		if not building.is_in_group("placed_buildings"):
			continue

		var mesh_inst: MeshInstance3D = building.get_node_or_null("MeshInstance3D")
		if mesh_inst and mesh_inst.has_meta("has_window_surface"):
			var win_mat: StandardMaterial3D = mesh_inst.get_surface_override_material(1) as StandardMaterial3D
			if win_mat:
				win_mat.emission_enabled = enabled


## Set street lamp lights on/off
func _set_lamp_lights(enabled: bool) -> void:
	var buildings_root: Node = get_tree().current_scene.get_node_or_null("Buildings")
	if not buildings_root:
		return

	for building in buildings_root.get_children():
		var lamp: OmniLight3D = building.get_node_or_null("LampLight") as OmniLight3D
		if lamp:
			lamp.visible = enabled


## Connect to player nearest_building_changed signal (deferred)
func _connect_player_interaction_deferred() -> void:
	await get_tree().process_frame
	var player: Node = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		return
	player.nearest_building_changed.connect(_on_nearest_building_changed)


## Handle nearest building change - show/hide interaction prompt
func _on_nearest_building_changed(building: StaticBody3D) -> void:
	# Hide previous prompt
	if _last_prompted_building and is_instance_valid(_last_prompted_building):
		var prev_prompt: Label3D = _last_prompted_building.get_node_or_null("InteractionPrompt") as Label3D
		if prev_prompt:
			if _prompt_tween and _prompt_tween.is_valid():
				_prompt_tween.kill()
			_prompt_tween = create_tween()
			_prompt_tween.tween_property(prev_prompt, "modulate:a", 0.0, 0.15)

	# Show new prompt
	if building:
		var prompt: Label3D = building.get_node_or_null("InteractionPrompt") as Label3D
		if prompt:
			if _prompt_tween and _prompt_tween.is_valid():
				_prompt_tween.kill()
			_prompt_tween = create_tween()
			_prompt_tween.tween_property(prompt, "modulate:a", 1.0, 0.2)
		_last_prompted_building = building
		building_interaction_prompt_show.emit(building)
	else:
		_last_prompted_building = null
		building_interaction_prompt_hide.emit()


## Handle building interaction when player presses E near a building
func interact_with_building(building: StaticBody3D) -> void:
	if not building:
		return

	# Get building data
	var building_id: String = building.get_meta("building_id", "") as String
	if building_id.is_empty():
		return

	# Look up building data
	var building_data: BuildingData = null
	for b in _building_types:
		if b.display_name == building_id:
			building_data = b
			break

	if not building_data:
		return

	# Get quiz window
	var quiz_window = get_node_or_null("/root/UI/QuizWindow")
	if not quiz_window:
		return

	# Determine quiz category
	var category: String = building_data.quiz_category
	if category.is_empty():
		category = ""  # Empty = random category

	# Connect to answer result signal
	quiz_window.answer_submitted.connect(
		func(was_correct: bool):
			_on_building_quiz_answered(building, building_data, was_correct),
		CONNECT_ONE_SHOT
	)

	# Open quiz window
	quiz_window.open_with_category(category)


## Handle building quiz answer
func _on_building_quiz_answered(building: StaticBody3D, building_data: BuildingData, was_correct: bool) -> void:
	if not is_instance_valid(building):
		return

	# Only upgrade on correct answer
	if was_correct:
		var current_level: int = building.get_meta("building_level", 0) as int
		var new_level: int = mini(current_level + 1, building_data.max_level)

		# Update building level meta
		building.set_meta("building_level", new_level)

		# Regenerate mesh with new level (applies color tint)
		var mesh_inst: MeshInstance3D = building.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_inst:
			mesh_inst.mesh = BuildingMeshGenerator.generate(building_data, new_level)

			# Restore window emission material
			if building_data.category != "infrastructure":
				var win_mat := StandardMaterial3D.new()
				win_mat.vertex_color_use_as_albedo = true
				win_mat.emission_enabled = false
				win_mat.emission = building_data.secondary_color * 1.5
				win_mat.emission_energy_multiplier = 1.5
				mesh_inst.set_surface_override_material(1, win_mat)
				mesh_inst.set_meta("has_window_surface", true)

		# Emit signal
		building_level_changed.emit(building, new_level)


## Helper to get building type by display name
func get_building_data(display_name: String) -> BuildingData:
	for b in _building_types:
		if b.display_name == display_name:
			return b
	return null
