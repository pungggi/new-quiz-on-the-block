extends Control
class_name StatsDialog

## Statistics Dialog
## Shows detailed player statistics with category breakdown

signal closed

@onready var close_button: Button = $Panel/VBox/CloseButton
@onready var stats_container: VBoxContainer = $Panel/VBox/ScrollContainer/StatsContainer

var _bar_color_good := Color(0.3, 0.8, 0.4)
var _bar_color_bad := Color(0.8, 0.4, 0.3)


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	_populate_stats()
	
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _populate_stats() -> void:
	var profile: Resource = ProfileManager.current_profile
	if not profile:
		return
	
	# Clear existing
	for child in stats_container.get_children():
		child.queue_free()
	
	# Header with avatar and name
	var header := Label.new()
	header.text = "%s %s - Statistiken" % [profile.get_avatar_emoji(), profile.player_name]
	header.add_theme_font_size_override("font_size", 22)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(header)
	
	_add_separator()
	
	# General stats
	_add_stat_row("📚 Gesamtpunkte", str(profile.total_points))
	_add_stat_row("✅ Richtige Antworten", str(profile.total_correct_answers))
	_add_stat_row("❌ Falsche Antworten", str(profile.total_wrong_answers))
	_add_stat_row("🏠 Gebäude platziert", str(profile.buildings_placed))
	
	var accuracy: float = profile.get_accuracy()
	_add_stat_row("🎯 Genauigkeit", "%.1f%%" % accuracy)
	
	_add_separator()
	
	# Category breakdown
	var cat_label := Label.new()
	cat_label.text = "📊 Kategorien"
	cat_label.add_theme_font_size_override("font_size", 18)
	stats_container.add_child(cat_label)
	
	var best_cat := ""
	var best_accuracy := -1.0
	var worst_cat := ""
	var worst_accuracy := 101.0
	
	for cat_id in PlayerProfile.ALL_CATEGORIES:
		var correct: int = profile.category_correct.get(cat_id, 0)
		var wrong: int = profile.category_wrong.get(cat_id, 0)
		var total := correct + wrong
		var cat_accuracy := 0.0
		if total > 0:
			cat_accuracy = float(correct) / float(total) * 100.0
			if cat_accuracy > best_accuracy:
				best_accuracy = cat_accuracy
				best_cat = cat_id
			if cat_accuracy < worst_accuracy:
				worst_accuracy = cat_accuracy
				worst_cat = cat_id
		
		_add_category_bar(cat_id, correct, wrong)
	
	_add_separator()
	
	# Best/Worst category
	if best_cat != "":
		var best_name: String = PlayerProfile.CATEGORY_NAMES.get(best_cat, best_cat)
		_add_stat_row("⭐ Beste Kategorie", "%s (%.0f%%)" % [best_name, best_accuracy])
	if worst_cat != "" and worst_cat != best_cat:
		var worst_name: String = PlayerProfile.CATEGORY_NAMES.get(worst_cat, worst_cat)
		_add_stat_row("💪 Übungsbedarf", "%s (%.0f%%)" % [worst_name, worst_accuracy])


func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 16)
	stats_container.add_child(sep)


func _add_stat_row(label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(label)
	hbox.add_child(value)
	stats_container.add_child(hbox)


func _add_category_bar(cat_id: String, correct: int, wrong: int) -> void:
	var total := correct + wrong
	var cat_name: String = PlayerProfile.CATEGORY_NAMES.get(cat_id, cat_id)
	
	var vbox := VBoxContainer.new()
	var label := Label.new()
	label.text = "%s: %d/%d" % [cat_name, correct, total]
	vbox.add_child(label)
	
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 20)
	bar_bg.color = Color(0.2, 0.2, 0.25)
	
	var bar_fill := ColorRect.new()
	bar_fill.custom_minimum_size = Vector2(0, 20)
	var fill_ratio := float(correct) / float(maxi(total, 1))
	bar_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_fill.color = _bar_color_good.lerp(_bar_color_bad, 1.0 - fill_ratio)
	
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(0, 20)
	bar_container.add_child(bar_bg)
	bar_container.add_child(bar_fill)
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_fill.anchor_right = fill_ratio
	bar_fill.anchor_bottom = 1.0
	
	vbox.add_child(bar_container)
	stats_container.add_child(vbox)


func _on_close_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	get_tree().paused = false
	closed.emit()
	queue_free()
