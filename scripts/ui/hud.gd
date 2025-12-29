extends Control
class_name HUD

signal quiz_requested

@onready var quiz_button: Button = %QuizButton
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var points_label: Label = %PointsLabel
@onready var stats_label: Label = %StatsLabel
@onready var toast_container: VBoxContainer = %ToastContainer

var _building_manager: Node = null
var _quiz_manager: Node = null


func _ready() -> void:
	quiz_button.pressed.connect(_on_quiz_button_pressed)

	# Get managers
	_building_manager = get_node_or_null("/root/BuildingManager")
	_quiz_manager = get_node_or_null("/root/QuizManager")

	# Connect to signals
	if _building_manager:
		_building_manager.education_points_changed.connect(_on_points_changed)
		_building_manager.building_unlocked.connect(_on_building_unlocked)
		_update_stats()


func _on_quiz_button_pressed() -> void:
	quiz_requested.emit()


func _on_points_changed(_new_total: int) -> void:
	_update_stats()


func _on_building_unlocked(building: BuildingData) -> void:
	show_toast("🎉 %s freigeschaltet!" % building.display_name, Color.GOLD)


func _update_stats() -> void:
	if not _building_manager:
		return

	# Update points display
	if points_label:
		points_label.text = "📚 %d Punkte" % _building_manager.education_points

	# Update stats
	if stats_label:
		var stats: Dictionary = _building_manager.player_stats
		var text := "✅ %d richtig" % stats.get("total_correct", 0)
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
