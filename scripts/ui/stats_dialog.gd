class_name StatsDialog
extends MenuDialog

## Statistics Dialog - the player's numbers as a stack of theme cards:
## one card per key figure, one card with a progress bar per category.
## Layout and ESC come from MenuDialog.

@onready var close_button: Button = %CloseButton
@onready var heading_label: Label = %HeadingLabel
@onready var stats_container: VBoxContainer = %StatsContainer


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	_populate_stats()


func _populate_stats() -> void:
	var profile: PlayerProfile = ProfileManager.current_profile
	if not profile:
		return

	heading_label.text = "%s %s" % [profile.get_avatar_emoji(), profile.player_name]

	_add_stat_row("📚", "Gesamtpunkte", str(profile.total_points))
	_add_stat_row("✅", "Richtige Antworten", str(profile.total_correct_answers))
	_add_stat_row("❌", "Falsche Antworten", str(profile.total_wrong_answers))
	_add_stat_row("🏠", "Gebäude platziert", str(profile.buildings_placed))
	_add_stat_row("🎯", "Genauigkeit", _percent(profile.get_accuracy(), 1))

	_add_header("📊 Kategorien")

	var best_cat := ""
	var best_accuracy := -1.0
	var worst_cat := ""
	var worst_accuracy := 101.0

	for cat_id: String in PlayerProfile.ALL_CATEGORIES:
		var correct: int = profile.category_correct.get(cat_id, 0)
		var wrong: int = profile.category_wrong.get(cat_id, 0)
		var total: int = correct + wrong
		if total > 0:
			var cat_accuracy: float = float(correct) / float(total) * 100.0
			if cat_accuracy > best_accuracy:
				best_accuracy = cat_accuracy
				best_cat = cat_id
			if cat_accuracy < worst_accuracy:
				worst_accuracy = cat_accuracy
				worst_cat = cat_id
		_add_category_bar(cat_id, correct, total)

	_add_header("⭐ Auswertung")
	if best_cat != "":
		_add_stat_row("⭐", "Beste Kategorie", "%s (%s)" % [_category_name(best_cat), _percent(best_accuracy, 0)])
	if worst_cat != "" and worst_cat != best_cat:
		_add_stat_row("💪", "Übungsbedarf", "%s (%s)" % [_category_name(worst_cat), _percent(worst_accuracy, 0)])


static func _category_name(cat_id: String) -> String:
	return PlayerProfile.CATEGORY_NAMES.get(cat_id, cat_id)


## German formatting: decimal comma and a space before the percent sign
static func _percent(value: float, decimals: int) -> String:
	var text: String = "%.*f" % [decimals, value]
	return text.replace(".", ",") + " %"


func _add_header(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, UITheme.px(6))
	stats_container.add_child(spacer)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"SectionLabel"
	stats_container.add_child(label)


## One card: icon + label on the left, bold value on the right
func _add_stat_row(icon: String, label_text: String, value_text: String) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.px(10))
	var label := Label.new()
	label.text = "%s %s" % [icon, label_text]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var value := Label.new()
	value.text = value_text
	value.theme_type_variation = &"CardTitle"
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.add_child(value)
	card.add_child(row)
	stats_container.add_child(card)


## One card per category: name, hit rate and a bar from red (0 %) to green
func _add_category_bar(cat_id: String, correct: int, total: int) -> void:
	var ratio: float = float(correct) / float(maxi(total, 1))
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.px(4))

	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = _category_name(cat_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var count_label := Label.new()
	count_label.text = "%d / %d richtig" % [correct, total]
	count_label.theme_type_variation = &"CaptionLabel"
	row.add_child(name_label)
	row.add_child(count_label)
	box.add_child(row)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, UITheme.px(12))
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = ratio * 100.0
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The theme's fill is shared: tint a copy, green for a good hit rate
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill.bg_color = UITheme.GREEN.lerp(UITheme.RED, 1.0 - ratio)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)

	card.add_child(box)
	stats_container.add_child(card)


func _on_close_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	_close()
