extends Node
class_name ProfileManagerClass

## Profile Manager (Autoload)
## Manages player profile creation, loading, and saving

signal profile_created(profile: PlayerProfile)
signal profile_loaded(profile: PlayerProfile)
signal profile_updated(profile: PlayerProfile)
signal profile_switched(profile: PlayerProfile)
signal points_changed(new_total: int)

const PROFILES_SAVE_PATH := "user://profiles.json"
const MAX_PROFILES := 5

## All saved profiles
var all_profiles: Array[PlayerProfile] = []

## Current active profile index
var current_profile_index: int = -1

## Current active profile
var current_profile: PlayerProfile = null

## Is profile loaded and ready?
var is_ready: bool = false


func _ready() -> void:
	# Try to load existing profiles
	if _profiles_exist():
		load_all_profiles()
	else:
		# No profiles - will need to create one
		is_ready = false


## Check if profiles save file exists
func _profiles_exist() -> bool:
	return FileAccess.file_exists(PROFILES_SAVE_PATH)


## Get number of profiles
func get_profile_count() -> int:
	return all_profiles.size()


## Can create more profiles?
func can_create_profile() -> bool:
	return all_profiles.size() < MAX_PROFILES


## Check if profile needs to be created
func needs_profile_creation() -> bool:
	return current_profile == null or current_profile.player_name.is_empty()


## Create a new profile
func create_profile(player_name: String, grade_level: int, categories: Array = [], avatar: String = "fox") -> PlayerProfile:
	var new_profile := PlayerProfile.new()
	new_profile.player_name = player_name
	new_profile.avatar_id = avatar
	new_profile.grade_level = clampi(grade_level, 0, 10)
	new_profile.enabled_categories = categories
	new_profile.total_points = 100
	new_profile.created_at = Time.get_datetime_string_from_system()

	all_profiles.append(new_profile)
	current_profile_index = all_profiles.size() - 1
	current_profile = new_profile

	save_all_profiles()
	is_ready = true
	profile_created.emit(current_profile)

	var cats_str := "alle" if categories.is_empty() else ", ".join(categories)
	print("ProfileManager: Created profile for '%s' %s (Grade: %s, Categories: %s)" % [
		player_name,
		PlayerProfile.AVATAR_EMOJIS.get(avatar, ""),
		PlayerProfile.get_grade_name(grade_level),
		cats_str
	])

	return current_profile


## Save all profiles to file
func save_all_profiles() -> bool:
	var file := FileAccess.open(PROFILES_SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("ProfileManager: Failed to open save file")
		return false

	var profiles_data: Array = []
	for profile in all_profiles:
		profiles_data.append(profile.to_dict())

	var data := {
		"current_index": current_profile_index,
		"profiles": profiles_data
	}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## Save current profile (convenience wrapper)
func save_profile() -> bool:
	return save_all_profiles()


## Load all profiles from file
func load_all_profiles() -> bool:
	if not _profiles_exist():
		return false

	var file := FileAccess.open(PROFILES_SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("ProfileManager: Failed to open profiles file")
		return false

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_error("ProfileManager: Failed to parse profiles JSON")
		return false

	all_profiles.clear()
	var data: Dictionary = json.data
	var profiles_data: Array = data.get("profiles", [])

	for profile_dict in profiles_data:
		var profile := PlayerProfile.new()
		profile.from_dict(profile_dict)
		all_profiles.append(profile)

	current_profile_index = data.get("current_index", 0)
	if current_profile_index >= 0 and current_profile_index < all_profiles.size():
		current_profile = all_profiles[current_profile_index]
		is_ready = true
		profile_loaded.emit(current_profile)
		print("ProfileManager: Loaded %d profiles, active: '%s'" % [all_profiles.size(), current_profile.player_name])
	else:
		current_profile_index = -1
		current_profile = null
		is_ready = false

	return true


## Switch to a different profile by index
func switch_profile(index: int) -> bool:
	if index < 0 or index >= all_profiles.size():
		return false

	current_profile_index = index
	current_profile = all_profiles[index]
	save_all_profiles()
	profile_switched.emit(current_profile)
	print("ProfileManager: Switched to profile '%s'" % current_profile.player_name)
	return true


## Delete a profile by index
func delete_profile(index: int) -> bool:
	if index < 0 or index >= all_profiles.size():
		return false
	if all_profiles.size() <= 1:
		return false # Keep at least one profile

	var deleted_name: String = all_profiles[index].player_name
	all_profiles.remove_at(index)

	# Adjust current index
	if current_profile_index >= all_profiles.size():
		current_profile_index = all_profiles.size() - 1
	elif current_profile_index > index:
		current_profile_index -= 1

	current_profile = all_profiles[current_profile_index]
	save_all_profiles()
	profile_switched.emit(current_profile)
	print("ProfileManager: Deleted profile '%s'" % deleted_name)
	return true


## Get profile at index
func get_profile(index: int) -> PlayerProfile:
	if index >= 0 and index < all_profiles.size():
		return all_profiles[index]
	return null


## Get current grade level
func get_grade_level() -> int:
	if current_profile:
		return current_profile.grade_level
	return 0


## Get current points
func get_points() -> int:
	if current_profile:
		return current_profile.total_points
	return 100


## Add points to profile
func add_points(amount: int) -> void:
	if current_profile:
		current_profile.total_points += amount
		points_changed.emit(current_profile.total_points)
		profile_updated.emit(current_profile)
		save_profile()


## Spend points (returns false if not enough)
func spend_points(amount: int) -> bool:
	if not current_profile:
		return false
	if current_profile.total_points < amount:
		return false
	
	current_profile.total_points -= amount
	points_changed.emit(current_profile.total_points)
	profile_updated.emit(current_profile)
	save_profile()
	return true


## Get allowed difficulty levels for current profile
func get_allowed_difficulties() -> Array:
	if current_profile:
		return PlayerProfile.get_allowed_difficulties(current_profile.grade_level)
	return [1]


## Get enabled categories for current profile
func get_enabled_categories() -> Array:
	if current_profile:
		return current_profile.get_enabled_categories()
	return PlayerProfile.ALL_CATEGORIES.duplicate()


## Check if a category is enabled
func is_category_enabled(category: String) -> bool:
	if current_profile:
		return current_profile.is_category_enabled(category)
	return true


## Reset current profile stats (keeps name and grade)
func reset_current_profile() -> void:
	if not current_profile:
		return

	current_profile.total_points = 100
	current_profile.total_correct_answers = 0
	current_profile.total_wrong_answers = 0
	current_profile.total_quizzes_completed = 0
	current_profile.buildings_placed = 0
	current_profile.category_correct = {}
	current_profile.category_wrong = {}

	save_profile()
	profile_updated.emit(current_profile)
	points_changed.emit(current_profile.total_points)
	print("ProfileManager: Profile reset for '%s'" % current_profile.player_name)
