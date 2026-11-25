extends Control
class_name HUD

## HUD - Heads Up Display
##
## Main gameplay UI orchestrator. Delegates to specialized components:
## - ToastManager (%ToastContainer) for notifications
## - %HintLabel for contextual hints
## - points/shell counters and the day/night clock

signal quiz_requested
## The HUD only asks: main.gd opens the dialogs (on the UI layer, where
## nothing of the HUD can cover them)
signal settings_requested
signal stats_requested
signal achievements_requested


## Height of the HUD chips strip at the top of the in-game screen.
## The quiz window keeps this clear as well.
const TOP_STRIP: float = 64.0

# UI Elements
@onready var quiz_button: Button = %QuizButton
@onready var settings_button: Button = %SettingsButton
@onready var stats_button: Button = %StatsButton
@onready var achievements_button: Button = %AchievementsButton
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var points_label: Label = %PointsLabel
@onready var stats_label: Label = %StatsLabel
@onready var toast_container: ToastManager = %ToastContainer
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
var _day_night: DayNightCycle = null
var _planet_picker: PlanetPicker = null
@onready var _shell_label: Label = %ShellLabel
## Wired by main.gd (see set_bottom_bar / set_day_night)
var _building_bar: BuildingPanel = null

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
	_connect_buttons()
	_connect_managers()

	# Clicking the clock opens the planet picker
	if time_label:
		time_label.mouse_filter = Control.MOUSE_FILTER_STOP
		time_label.gui_input.connect(_on_time_label_gui_input)

	# Shell/coin counter under the points display
	_setup_shell_display()

	# Start showing hints after a short delay (a toast's lifetime)
	await get_tree().create_timer(ToastManager.DEFAULT_DURATION).timeout
	_update_hint()


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


## Wired by main.gd: the day/night cycle drives the clock and the
## planet picker.
func set_day_night(cycle: DayNightCycle) -> void:
	_day_night = cycle
	if not cycle.time_changed.is_connected(_on_time_changed):
		cycle.time_changed.connect(_on_time_changed)
	_update_time_display()


## Wired by main.gd: the building bar at the bottom edge. Popups are
## re-centred into the space above it.
func set_bottom_bar(bar: BuildingPanel) -> void:
	_building_bar = bar


func _on_quiz_button_pressed() -> void:
	quiz_requested.emit()


func _on_settings_button_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	settings_requested.emit()


## Called once the settings dialog closed: name or grade may have changed
func refresh_stats() -> void:
	_update_stats()


func _on_stats_button_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	stats_requested.emit()


func _on_achievements_button_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	achievements_requested.emit()


func _on_points_changed(new_total: int) -> void:
	_animate_points(new_total)
	_update_stats()
	_update_progress()


func _on_building_unlocked(building: BuildingData) -> void:
	show_toast("🎉 %s freigeschaltet!" % building.display_name, Color.GOLD)
	_pulse_stats_panel()


func _on_achievement_unlocked(achievement: AchievementData) -> void:
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
			var profile: PlayerProfile = profile_mgr.current_profile
			player_name = profile.player_name
			avatar_emoji = profile.get_avatar_emoji()
		points_label.text = "%s %s\n📚 %d Punkte" % [avatar_emoji, player_name, value]


## Pulse animation for stats panel
func _pulse_stats_panel() -> void:
	if not stats_panel:
		return
	# Grow from the centre, not from the top-left corner
	stats_panel.pivot_offset = stats_panel.size * 0.5
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
		var profile: PlayerProfile = profile_mgr.current_profile
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
	var emoji: String = "🌞"

	match _day_night.current_phase:
		DayNightCycle.DayPhase.DAWN:
			emoji = "🌅"
		DayNightCycle.DayPhase.DAY:
			emoji = "🌞"
		DayNightCycle.DayPhase.DUSK:
			emoji = "🌇"
		DayNightCycle.DayPhase.NIGHT:
			emoji = "🌙"

	time_label.text = "%s %s" % [emoji, time_str]

#endregion


#region Planet Picker

func _on_time_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_planet_picker()


func _toggle_planet_picker() -> void:
	if _planet_picker == null:
		_planet_picker = PlanetPicker.new()
		add_child(_planet_picker)
		_planet_picker.planet_selected.connect(_on_planet_selected)
	if _planet_picker.visible:
		_planet_picker.hide()
		return
	if _day_night == null:
		return # no day/night cycle to re-tune
	_lift_above_building_bar(_planet_picker)
	_planet_picker.open(_day_night)


func _on_planet_selected(planet: Dictionary) -> void:
	var suns: int = maxi(1, int(round(float(planet["sun_intensity"]) / 0.4)))
	show_toast("🪐 %s: Tag = %d Minuten, Sonne %s" % [planet["name"], int(planet["day_minutes"]), "☀️".repeat(suns)])

#endregion


#region Shell Counter

func _setup_shell_display() -> void:
	if not _shell_label:
		return
	ShellManager.shells_changed.connect(_on_shells_changed)
	ShellManager.coins_changed.connect(_on_coins_changed)
	_update_shell_display()


func _update_shell_display() -> void:
	if _shell_label:
		_shell_label.text = "🐚 %d   💰 %d" % [ShellManager.get_shells(), ShellManager.get_coins()]


func _on_shells_changed(_count: int) -> void:
	_update_shell_display()


func _on_coins_changed(_amount: int) -> void:
	_update_shell_display()

#endregion


## Show a toast notification with slide-in animation
func show_toast(message: String, color: Color = Color.WHITE) -> void:
	if toast_container:
		toast_container.show_toast(message, color)


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
		hint_text = "💡 Klicke auf einen bunten NPC, um ein Quiz zu starten!"
	elif not _has_answered_quiz:
		hint_text = "💡 Beantworte Fragen richtig, um Punkte zu sammeln!"
	elif not _has_placed_building:
		hint_text = "💡 Wähle unten ein Gebäude und klicke auf die Wiese zum Bauen!"
	else:
		# All done - hide the hint and stop its pulse
		if _hint_tween:
			_hint_tween.kill()
			_hint_tween = null
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
		# Light chip with a coloured border: blue = walking, red = building
		var accent: Color = UITheme.BLUE if is_walk else UITheme.RED
		mode_panel.add_theme_stylebox_override("panel", UITheme.hud_chip_style(accent))
		mode_label.remove_theme_font_size_override("font_size")
		mode_label.remove_theme_color_override("font_color")

#endregion


## Centre a popup in the window space left between the HUD strip at
## the top and the building bar at the bottom (wired via
## set_bottom_bar), instead of letting it disappear behind the bar.
func _lift_above_building_bar(popup: Control) -> void:
	var bar_height: float = _building_bar.occupied_height() if _building_bar else 0.0
	var lift: float = maxf(0.0, (bar_height - TOP_STRIP) * 0.5)
	# Centre explicitly: the preset helper works off the popup's current
	# size, which is stale while the popup is still hidden.
	popup.set_anchors_preset(Control.PRESET_CENTER)
	var size: Vector2 = popup.get_combined_minimum_size()
	popup.offset_left = -size.x * 0.5
	popup.offset_right = size.x * 0.5
	popup.offset_top = -size.y * 0.5 - lift
	popup.offset_bottom = size.y * 0.5 - lift
