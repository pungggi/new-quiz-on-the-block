class_name ProfileSelection
extends MenuDialog

## Profile Selection - one row per profile, plus a way back.
## Layout and ESC come from MenuDialog.

signal profile_selected(profile: PlayerProfile)
signal create_new_requested

@onready var profiles_container: VBoxContainer = %ProfilesContainer
@onready var new_profile_button: Button = %NewProfileButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	new_profile_button.pressed.connect(_on_new_profile_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_populate_profiles()


func _populate_profiles() -> void:
	for child in profiles_container.get_children():
		child.queue_free()

	for i: int in range(ProfileManager.get_profile_count()):
		var profile: PlayerProfile = ProfileManager.get_profile(i)
		if not profile:
			continue

		var is_current: bool = i == ProfileManager.current_profile_index
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, UITheme.px(62))
		if is_current:
			btn.theme_type_variation = &"PrimaryButton"
		btn.text = "%s %s%s\n📚 %d Punkte · %s" % [
			"✅ " if is_current else "",
			profile.get_avatar_emoji(),
			profile.player_name,
			profile.total_points,
			PlayerProfile.get_grade_name(profile.grade_level)
		]
		btn.pressed.connect(_on_profile_selected.bind(i))
		profiles_container.add_child(btn)

	if ProfileManager.can_create_profile():
		new_profile_button.disabled = false
		new_profile_button.text = "➕ Neues Profil erstellen"
	else:
		new_profile_button.disabled = true
		new_profile_button.text = "Max. %d Profile erreicht" % ProfileManager.MAX_PROFILES


func _on_profile_selected(index: int) -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	ProfileManager.switch_profile(index)
	profile_selected.emit(ProfileManager.current_profile)
	queue_free()


func _on_new_profile_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	create_new_requested.emit()
	queue_free()


func _on_back_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	_close()
