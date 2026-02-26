extends Control
class_name HUD

## HUD - Heads Up Display
##
## Main gameplay UI orchestrator. Delegates to specialized components:
## - ToastManager for notifications
## - HintDisplay for contextual hints (via Label with script)
## - Points/Stats display

signal quiz_requested

const SETTINGS_DIALOG_SCENE := preload("res://scenes/ui/settings_dialog.tscn")
const STATS_DIALOG_SCENE := preload("res://scenes/ui/stats_dialog.tscn")
const ACHIEVEMENTS_DIALOG_SCENE := preload("res://scenes/ui/achievements_dialog.tscn")

# UI Elements
@onready var quiz_button: Button = %QuizButton
@onready var settings_button: Button = %SettingsButton
@onready var stats_button: Button = %StatsButton
@onready var achievements_button: Button = %AchievementsButton
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var points_label: Label = %PointsLabel
@onready var stats_label: Label = %StatsLabel
@onready var toast_container: VBoxContainer = %ToastContainer
@onready var hint_label: Label = %HintLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var progress_label: Label = %ProgressLabel
@onready var time_label: Label = %TimeLabel
@onready var mode_panel: PanelContainer = %ModePanel
@onready var mode_label: Label = %ModeLabel

# Manager references
var _building_manager: Node = null
var _game_mode: Node = null
var _quiz_manager: Node = null
var _npc_manager: Node = null
var _day_night: Node = null

# Toast manager (created dynamically or use existing container)
var _toast_manager: ToastManager = null

# Animated points display
var _displayed_points: int = 0
var _target_points: int = 0
var _points_tween: Tween = null

# Hint tracking
var _hint_tween: Tween = null
var _has_clicked_npc: bool = false
var _has_placed_building: bool = false
var _has_answered_quiz: bool = false


func _ready() -> void:
	_setup_toast_manager()
	_connect_buttons()
	_connect_managers()

	# Start showing hints after a short delay
	await get_tree().create_timer(UIThemeConstants.TOAST_DURATION).timeout
	_update_hint()


func _setup_toast_manager() -> void:
	# Convert toast_container to ToastManager if it exists
	if toast_container:
		_toast_manager = ToastManager.new()
		_toast_manager.name = "ToastManager"
		# Copy properties from existing container
		_toast_manager.size_flags_horizontal = toast_container.size_flags_horizontal
		_toast_manager.size_flags_vertical = toast_container.size_flags_vertical
		# Replace container
		var parent := toast_container.get_parent()
		var idx := toast_container.get_index()
		parent.remove_child(toast_container)
		toast_container.queue_free()
		parent.add_child(_toast_manager)
		parent.move_child(_toast_manager, idx)


func _connect_buttons() -> void:
	quiz_button.pressed.connect(_on_quiz_button_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
	if stats_button:
		stats_button.pressed.connect(_on_stats_button_pressed)
	if achievements_button:
		achievements_button.pressed.connect(_on_achievements_button_pressed)


func _connect_managers() -> void:
	_building_manager = get_node_or_null("/root/BuildingManager")
	_quiz_manager = get_node_or_null("/root/QuizManager")
	_npc_manager = get_node_or_null("/root/NPCManager")
	_game_mode = get_node_or_null("/root/GameMode")

	if _building_manager:
		_building_manager.education_points_changed.connect(_on_points_changed)
		_building_manager.building_unlocked.connect(_on_building_unlocked)
		_building_manager.building_placed_event.connect(_on_building_placed_hint)
		_update_stats()

	if _npc_manager:
		_npc_manager.npc_quiz_completed.connect(_on_quiz_completed_hint)

	if _game_mode:
		_game_mode.mode_changed.connect(_on_mode_changed)
		_update_mode_display()

	var ach_mgr: Node = get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.achievement_unlocked.connect(_on_achievement_unlocked)

	# Connect to day/night cycle (needs frame delay)
	_connect_day_night_deferred()


func _connect_day_night_deferred() -> void:
	await get_tree().process_frame
	_day_night = get_tree().current_scene.get_node_or_null("DayNightCycle")
	if _day_night:
		_day_night.time_changed.connect(_on_time_changed)
		_update_time_display()


func _on_quiz_button_pressed() -> void:
	quiz_requested.emit()


func _on_settings_button_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	var dialog: Control = SETTINGS_DIALOG_SCENE.instantiate()
	dialog.closed.connect(_on_settings_closed)
	get_tree().root.add_child(dialog)


func _on_settings_closed() -> void:
	_update_stats() # Refresh stats after settings changed


func _on_stats_button_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	var dialog: Control = STATS_DIALOG_SCENE.instantiate()
	get_tree().root.add_child(dialog)


func _on_achievements_button_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	var dialog: Control = ACHIEVEMENTS_DIALOG_SCENE.instantiate()
	get_tree().root.add_child(dialog)


func _on_points_changed(new_total: int) -> void:
	_animate_points(new_total)
	_update_stats()
	_update_progress()


func _on_building_unlocked(building: BuildingData) -> void:
	show_toast("🎉 %s freigeschaltet!" % building.display_name, Color.GOLD)
	_pulse_stats_panel()


func _on_achievement_unlocked(achievement: Resource) -> void:
	show_toast("🏆 %s %s!" % [achievement.icon, achievement.title], Color(1.0, 0.85, 0.3))
	AudioManager.play_sfx(AudioManager.SFX.UNLOCK)


## Animate points counting up
func _animate_points(new_total: int) -> void:
	_target_points = new_total

	if _points_tween:
		_points_tween.kill()

	_points_tween = create_tween()
	_points_tween.tween_method(_update_points_display, _displayed_points, _target_points, 0.5)
	_points_tween.set_ease(Tween.EASE_OUT)


func _update_points_display(value: int) -> void:
	_displayed_points = value
	if points_label:
		var profile_mgr: Node = get_node_or_null("/root/ProfileManager")
		var player_name := "Spieler"
		var avatar_emoji := "👤"
		if profile_mgr and profile_mgr.current_profile:
			var profile: Resource = profile_mgr.current_profile
			player_name = profile.player_name
			avatar_emoji = profile.get_avatar_emoji()
		points_label.text = "%s %s\n📚 %d Punkte" % [avatar_emoji, player_name, value]


## Pulse animation for stats panel
func _pulse_stats_panel() -> void:
	if not stats_panel:
		return
	var tween := create_tween()
	tween.tween_property(stats_panel, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(stats_panel, "scale", Vector2(1.0, 1.0), 0.1)


## Update progress bar towards next unlock
func _update_progress() -> void:
	if not progress_bar or not _building_manager:
		return

	var points: int = _building_manager.education_points
	var next_unlock_cost: int = _get_next_unlock_cost()

	if next_unlock_cost > 0:
		progress_bar.max_value = next_unlock_cost
		progress_bar.value = mini(points, next_unlock_cost)
		if progress_label:
			progress_label.text = "Nächstes: %d/%d 📚" % [mini(points, next_unlock_cost), next_unlock_cost]
		progress_bar.visible = true
		if progress_label:
			progress_label.visible = true
	else:
		progress_bar.visible = false
		if progress_label:
			progress_label.visible = false


func _get_next_unlock_cost() -> int:
	if not _building_manager:
		return 0
	var buildings: Array = _building_manager.get_all_buildings()
	var current_points: int = _building_manager.education_points
	var next_cost: int = 0

	for building: BuildingData in buildings:
		if building.cost > current_points:
			if next_cost == 0 or building.cost < next_cost:
				next_cost = building.cost
	return next_cost


func _update_stats() -> void:
	if not _building_manager:
		return

	# Get profile info
	var profile_mgr: Node = get_node_or_null("/root/ProfileManager")
	var player_name := "Spieler"
	var grade_name := ""

	var avatar_emoji := "👤"
	if profile_mgr and profile_mgr.current_profile:
		var profile: Resource = profile_mgr.current_profile
		player_name = profile.player_name
		grade_name = profile.get_grade_name(profile.grade_level)
		avatar_emoji = profile.get_avatar_emoji()

	# Update points display with player name and avatar (only if not animating)
	if points_label and _displayed_points == 0:
		_displayed_points = _building_manager.education_points
		_target_points = _displayed_points
		points_label.text = "%s %s\n📚 %d Punkte" % [avatar_emoji, player_name, _displayed_points]

	# Update stats
	if stats_label:
		var stats: Dictionary = _building_manager.player_stats
		var text := "📖 %s" % grade_name if grade_name else ""
		text += "\n✅ %d richtig" % stats.get("total_correct", 0)
		text += "\n🏠 %d Gebäude" % stats.get("buildings_placed", 0)
		stats_label.text = text


#region Time Display

func _on_time_changed(_hour: float) -> void:
	_update_time_display()


func _update_time_display() -> void:
	if not time_label or not _day_night:
		return

	var time_str: String = _day_night.get_time_string()
	var phase: int = _day_night.current_phase
	var emoji := "🌞"

	match phase:
		0: # DAWN
			emoji = "🌅"
		1: # DAY
			emoji = "🌞"
		2: # DUSK
			emoji = "🌇"
		3: # NIGHT
			emoji = "🌙"

	time_label.text = "%s %s" % [emoji, time_str]

#endregion


## Show a toast notification with slide-in animation
func show_toast(message: String, color: Color = Color.WHITE) -> void:
	if _toast_manager:
		_toast_manager.show_toast(message, color)
	elif toast_container:
		# Fallback if ToastManager setup failed
		_show_toast_fallback(message, color)


## Fallback toast implementation
func _show_toast_fallback(message: String, color: Color) -> void:
	var panel := PanelContainer.new()
	var style := UIThemeConstants.create_bordered_panel_style(
		UIThemeConstants.PANEL_BG_COLOR,
		color,
		UIThemeConstants.BORDER_WIDTH_THICK
	)
	panel.add_theme_stylebox_override("panel", style)

	var toast := Label.new()
	toast.text = message
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", color)
	toast.add_theme_font_size_override("font_size", UIThemeConstants.FONT_SIZE_LARGE)
	toast.add_theme_color_override("font_shadow_color", UIThemeConstants.SHADOW_COLOR)
	toast.add_theme_constant_override("shadow_offset_x", 1)
	toast.add_theme_constant_override("shadow_offset_y", 1)

	panel.add_child(toast)
	toast_container.add_child(panel)

	panel.modulate.a = 0.0
	panel.position.y = -30
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, UIThemeConstants.FADE_DURATION_NORMAL).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", 0.0, UIThemeConstants.FADE_DURATION_NORMAL).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_interval(UIThemeConstants.TOAST_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, UIThemeConstants.FADE_DURATION_SLOW)
	tween.tween_property(panel, "position:y", -20.0, UIThemeConstants.FADE_DURATION_SLOW)
	tween.tween_callback(panel.queue_free)


#region Hint System

func _on_building_placed_hint(_building: BuildingData, _pos: Vector3i) -> void:
	_has_placed_building = true
	_update_hint()


func _on_quiz_completed_hint(_npc: NPC, was_correct: bool) -> void:
	_has_clicked_npc = true
	if was_correct:
		_has_answered_quiz = true
	_update_hint()


func _update_hint() -> void:
	if not hint_label:
		return

	var hint_text := ""

	# Determine what hint to show based on player progress
	if not _has_clicked_npc:
		hint_text = "💡 Klicke auf einen bunten NPC um ein Quiz zu starten!"
	elif not _has_answered_quiz:
		hint_text = "💡 Beantworte Fragen richtig um Punkte zu sammeln!"
	elif not _has_placed_building:
		hint_text = "💡 Wähle unten ein Gebäude und klicke auf die Wiese zum Bauen!"
	else:
		# All done - hide hint
		hint_label.visible = false
		return

	hint_label.text = hint_text
	hint_label.visible = true

	# Pulse animation
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.set_loops()
	_hint_tween.tween_property(hint_label, "modulate:a", 0.6, 1.0)
	_hint_tween.tween_property(hint_label, "modulate:a", 1.0, 1.0)

#endregion


#region Game Mode Display

func _on_mode_changed(_new_mode: int) -> void:
	_update_mode_display()


func _update_mode_display() -> void:
	if not mode_label or not _game_mode:
		return

	var is_walk: bool = _game_mode.is_walk_mode() as bool
	mode_label.text = "🚶 LAUFEN [Tab]" if is_walk else "🏗️ BAUEN [Tab]"
	
	if mode_panel:
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		
		if is_walk:
			style.bg_color = Color(0.15, 0.25, 0.45, 0.85)
			style.border_color = Color(0.3, 0.5, 0.9, 0.8)
		else:
			style.bg_color = Color(0.45, 0.25, 0.15, 0.85)
			style.border_color = Color(0.9, 0.5, 0.3, 0.8)
			
		mode_panel.add_theme_stylebox_override("panel", style)
		
		# Set bolder font for better readability
		mode_label.add_theme_font_size_override("font_size", 14)
		mode_label.add_theme_color_override("font_color", Color.WHITE)

#endregion
