extends Control
class_name ProfileSelection

## Profile Selection Screen
## Shown when multiple profiles exist to select or create new

signal profile_selected(profile: PlayerProfile)
signal create_new_requested

@onready var profiles_container: VBoxContainer = $Panel/VBox/ScrollContainer/ProfilesContainer
@onready var new_profile_button: Button = $Panel/VBox/NewProfileButton

var _profile_buttons: Array[Button] = []


func _ready() -> void:
	new_profile_button.pressed.connect(_on_new_profile_pressed)
	_populate_profiles()
	
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _populate_profiles() -> void:
	# Clear existing
	for child in profiles_container.get_children():
		child.queue_free()
	_profile_buttons.clear()
	
	# Create button for each profile
	for i in range(ProfileManager.get_profile_count()):
		var profile: PlayerProfile = ProfileManager.get_profile(i)
		if not profile:
			continue
		
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		btn.text = "%s %s\n📚 %d Punkte | %s" % [
			profile.get_avatar_emoji(),
			profile.player_name,
			profile.total_points,
			PlayerProfile.get_grade_name(profile.grade_level)
		]
		btn.pressed.connect(_on_profile_selected.bind(i))
		
		# Highlight current profile
		if i == ProfileManager.current_profile_index:
			btn.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		
		profiles_container.add_child(btn)
		_profile_buttons.append(btn)
	
	# Update new profile button
	new_profile_button.disabled = not ProfileManager.can_create_profile()
	if not ProfileManager.can_create_profile():
		new_profile_button.text = "Max. %d Profile erreicht" % ProfileManager.MAX_PROFILES
	else:
		new_profile_button.text = "➕ Neues Profil erstellen"


func _on_profile_selected(index: int) -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	ProfileManager.switch_profile(index)
	get_tree().paused = false
	profile_selected.emit(ProfileManager.current_profile)
	queue_free()


func _on_new_profile_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	get_tree().paused = false
	create_new_requested.emit()
	queue_free()

