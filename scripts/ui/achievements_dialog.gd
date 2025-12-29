extends Control
class_name AchievementsDialog

## Achievements Gallery Dialog
## Shows all achievements and their unlock status

signal closed

@onready var close_button: Button = $Panel/VBox/CloseButton
@onready var achievements_container: GridContainer = $Panel/VBox/ScrollContainer/AchievementsContainer
@onready var progress_label: Label = $Panel/VBox/ProgressLabel


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	_populate_achievements()
	
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _populate_achievements() -> void:
	# Clear existing
	for child in achievements_container.get_children():
		child.queue_free()
	
	var ach_mgr: Node = get_node_or_null("/root/AchievementManager")
	if not ach_mgr:
		return

	var unlocked_count: int = 0
	var total_count: int = ach_mgr.all_achievements.size()

	for achievement in ach_mgr.all_achievements:
		var is_unlocked: bool = ach_mgr.is_unlocked(achievement.id)
		if is_unlocked:
			unlocked_count += 1
		
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(180, 100)
		
		var style := StyleBoxFlat.new()
		if is_unlocked:
			style.bg_color = Color(0.2, 0.35, 0.25, 0.9)
		else:
			style.bg_color = Color(0.15, 0.15, 0.2, 0.7)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", style)
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		
		var icon_label := Label.new()
		icon_label.text = achievement.icon if is_unlocked else "🔒"
		icon_label.add_theme_font_size_override("font_size", 32)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(icon_label)
		
		var title_label := Label.new()
		title_label.text = achievement.title
		title_label.add_theme_font_size_override("font_size", 14)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not is_unlocked:
			title_label.modulate = Color(0.6, 0.6, 0.6)
		vbox.add_child(title_label)
		
		var desc_label := Label.new()
		desc_label.text = achievement.description
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		if not is_unlocked:
			desc_label.modulate = Color(0.5, 0.5, 0.5)
		vbox.add_child(desc_label)
		
		panel.add_child(vbox)
		achievements_container.add_child(panel)
	
	# Update progress
	progress_label.text = "🏆 %d / %d freigeschaltet" % [unlocked_count, total_count]


func _on_close_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	get_tree().paused = false
	closed.emit()
	queue_free()
