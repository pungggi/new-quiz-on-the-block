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

## One-shot listener for the building quiz that is open right now (see
## interact_with_building)
var _building_quiz_answer: Callable = Callable()

## The game scene's "Buildings" node (bind_scene); what the lights iterate
var _buildings_root: Node3D = null
## The game scene's day/night cycle (bind_scene); re-applied after an upgrade
var _cycle: DayNightCycle = null


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

	# The day/night cycle and the player live in the game scene, which does
	# not exist yet (the main menu is showing). main.gd calls bind_scene()
	# as soon as the world is in the tree.


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
		# Exported builds remap resources to "*.tres.remap" inside the PCK;
		# load() resolves the trimmed path transparently in both modes.
		if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
			var resource := load(buildings_path + file_name.trim_suffix(".remap"))
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


## Called by the game scene (main.gd) once it is in the tree: connects
## the day/night cycle (window and lamp lights) and the player (building
## prompts). A one-shot lookup at start-up found neither, because the main
## menu was the current scene back then.
func bind_scene(scene: Node) -> void:
	_buildings_root = scene.get_node_or_null("Buildings") as Node3D
	var cycle: DayNightCycle = scene.get_node_or_null("DayNightCycle") as DayNightCycle
	_cycle = cycle
	if cycle and not cycle.day_phase_changed.is_connected(_on_day_phase_changed):
		cycle.day_phase_changed.connect(_on_day_phase_changed)
		# Apply the state right away (the game may start at dusk or night)
		_on_day_phase_changed(cycle.current_phase)
	var player: Player = scene.get_node_or_null("Player") as Player
	if player and not player.nearest_building_changed.is_connected(_on_nearest_building_changed):
		player.nearest_building_changed.connect(_on_nearest_building_changed)


## Handle day phase changes - toggle window emission and lamp lights
func _on_day_phase_changed(phase: DayNightCycle.DayPhase) -> void:
	var lights_on: bool = (phase == DayNightCycle.DayPhase.DUSK or phase == DayNightCycle.DayPhase.NIGHT)
	_set_window_emission(lights_on)
	_set_lamp_lights(phase == DayNightCycle.DayPhase.NIGHT)


## Set window emission on all buildings
func _set_window_emission(enabled: bool) -> void:
	for building in _placed_buildings():
		var mesh_inst: MeshInstance3D = building.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_inst and mesh_inst.has_meta("has_window_surface"):
			var win_mat: StandardMaterial3D = mesh_inst.get_surface_override_material(1) as StandardMaterial3D
			if win_mat:
				win_mat.emission_enabled = enabled


## Set street lamp lights on/off
func _set_lamp_lights(enabled: bool) -> void:
	for building in _placed_buildings():
		var lamp: OmniLight3D = building.get_node_or_null("LampLight") as OmniLight3D
		if lamp:
			lamp.visible = enabled


## Placed (or restored) buildings of the current world
func _placed_buildings() -> Array[Node]:
	var out: Array[Node] = []
	if _buildings_root == null or not is_instance_valid(_buildings_root):
		return out
	for building: Node in _buildings_root.get_children():
		if building.is_in_group("placed_buildings"):
			out.append(building)
	return out


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


## Handle building interaction when player presses E near a building: a
## quiz from the building's category; a correct answer raises its level.
func interact_with_building(building: StaticBody3D) -> void:
	if not building:
		return

	# Get building data
	var building_id: String = building.get_meta("building_id", "") as String
	if building_id.is_empty():
		return

	var building_data: BuildingData = get_building_data(building_id)
	if not building_data:
		return

	# The quiz window registers itself with the NPCManager
	var quiz_window: QuizWindow = NPCManager.quiz_window
	if quiz_window == null:
		push_warning("BuildingManager: no quiz window available for a building quiz")
		return

	# A quiz left open from an earlier interaction must not upgrade anything
	_forget_building_quiz()
	_building_quiz_answer = _on_building_quiz_answered.bind(building, building_data)
	quiz_window.answer_submitted.connect(_building_quiz_answer, CONNECT_ONE_SHOT)
	if not quiz_window.quiz_closed.is_connected(_forget_building_quiz):
		quiz_window.quiz_closed.connect(_forget_building_quiz, CONNECT_ONE_SHOT)
	quiz_window.open_with_category(building_data.quiz_category)


## The quiz was closed without an answer: nothing is upgraded, and a later
## answer (e.g. to an NPC quiz) must not count for this building.
func _forget_building_quiz() -> void:
	var quiz_window: QuizWindow = NPCManager.quiz_window
	if quiz_window and _building_quiz_answer.is_valid() \
			and quiz_window.answer_submitted.is_connected(_building_quiz_answer):
		quiz_window.answer_submitted.disconnect(_building_quiz_answer)
	_building_quiz_answer = Callable()


## Handle building quiz answer. The signal's `was_correct` comes first,
## the building is bound to the listener (signal arguments precede bound ones).
func _on_building_quiz_answered(was_correct: bool, building: StaticBody3D, building_data: BuildingData) -> void:
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

		# The fresh window material starts switched off: keep the lights as
		# the current time of day wants them
		if _cycle:
			_on_day_phase_changed(_cycle.current_phase)

		# Emit signal
		building_level_changed.emit(building, new_level)


## Helper to get building type by display name
func get_building_data(display_name: String) -> BuildingData:
	for b in _building_types:
		if b.display_name == display_name:
			return b
	return null
