extends Control
class_name HUD

signal quiz_requested

const SETTINGS_DIALOG_SCENE := preload("res://scenes/ui/settings_dialog.tscn")
const STATS_DIALOG_SCENE := preload("res://scenes/ui/stats_dialog.tscn")
const ACHIEVEMENTS_DIALOG_SCENE := preload("res://scenes/ui/achievements_dialog.tscn")

@onready var quiz_button: Button = %QuizButton
@onready var settings_button: Button = %SettingsButton
@onready var stats_button: Button = %StatsButton
@onready var achievements_button: Button = %AchievementsButton
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var points_label: Label = %PointsLabel
@onready var stats_label: Label = %StatsLabel
@onready var toast_container: VBoxContainer = %ToastContainer
@onready var hint_label: Label = %HintLabel

var _building_manager: Node = null
var _quiz_manager: Node = null
var _npc_manager: Node = null
var _hint_tween: Tween = null

## Hint tracking
var _has_clicked_npc: bool = false
var _has_placed_building: bool = false
var _has_answered_quiz: bool = false


func _ready() -> void:
	quiz_button.pressed.connect(_on_quiz_button_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
	if stats_button:
		stats_button.pressed.connect(_on_stats_button_pressed)
	if achievements_button:
		achievements_button.pressed.connect(_on_achievements_button_pressed)

	# Get managers
	_building_manager = get_node_or_null("/root/BuildingManager")
	_quiz_manager = get_node_or_null("/root/QuizManager")
	_npc_manager = get_node_or_null("/root/NPCManager")

	# Connect to signals
	if _building_manager:
		_building_manager.education_points_changed.connect(_on_points_changed)
		_building_manager.building_unlocked.connect(_on_building_unlocked)
		_building_manager.building_placed_event.connect(_on_building_placed_hint)
		_update_stats()

	if _npc_manager:
		_npc_manager.npc_quiz_completed.connect(_on_quiz_completed_hint)

	# Connect to achievement unlocks
	var ach_mgr: Node = get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.achievement_unlocked.connect(_on_achievement_unlocked)

	# Start showing hints after a short delay
	await get_tree().create_timer(2.0).timeout
	_update_hint()


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


func _on_points_changed(_new_total: int) -> void:
	_update_stats()


func _on_building_unlocked(building: BuildingData) -> void:
	show_toast("🎉 %s freigeschaltet!" % building.display_name, Color.GOLD)


func _on_achievement_unlocked(achievement: Resource) -> void:
	show_toast("🏆 %s %s!" % [achievement.icon, achievement.title], Color(1.0, 0.85, 0.3))
	AudioManager.play_sfx(AudioManager.SFX.UNLOCK)


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

	# Update points display with player name and avatar
	if points_label:
		points_label.text = "%s %s\n📚 %d Punkte" % [avatar_emoji, player_name, _building_manager.education_points]

	# Update stats
	if stats_label:
		var stats: Dictionary = _building_manager.player_stats
		var text := "📖 %s" % grade_name if grade_name else ""
		text += "\n✅ %d richtig" % stats.get("total_correct", 0)
		text += "\n🏠 %d Gebäude" % stats.get("buildings_placed", 0)
		stats_label.text = text


## Show a toast notification
func show_toast(message: String, color: Color = Color.WHITE) -> void:
	if not toast_container:
		return

	# Create toast label
	var toast := Label.new()
	toast.text = message
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", color)
	toast.add_theme_font_size_override("font_size", 20)

	# Add shadow for readability
	toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("shadow_offset_x", 2)
	toast.add_theme_constant_override("shadow_offset_y", 2)

	toast_container.add_child(toast)

	# Animate in and out
	toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)


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