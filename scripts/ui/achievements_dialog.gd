class_name AchievementsDialog
extends MenuDialog

## Achievements Gallery - every achievement as a card in a 3-column grid.
## Unlocked cards are pale green, locked ones stay muted grey.
## Layout and ESC come from MenuDialog.

@onready var close_button: Button = %CloseButton
@onready var achievements_container: GridContainer = %AchievementsContainer
@onready var progress_label: Label = %ProgressLabel


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	_populate_achievements()


func _populate_achievements() -> void:
	var ach_mgr: Node = get_node_or_null("/root/AchievementManager")
	if not ach_mgr:
		return

	var unlocked_count: int = 0
	var total_count: int = ach_mgr.all_achievements.size()

	for achievement: AchievementData in ach_mgr.all_achievements:
		var is_unlocked: bool = ach_mgr.is_unlocked(achievement.id)
		if is_unlocked:
			unlocked_count += 1
		achievements_container.add_child(_make_card(achievement, is_unlocked))

	progress_label.text = "%d / %d freigeschaltet" % [unlocked_count, total_count]


func _make_card(achievement: AchievementData, is_unlocked: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"UnlockedCardPanel" if is_unlocked else &"LockedCardPanel"
	card.custom_minimum_size = Vector2(0, UITheme.px(112))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.px(2))
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_label := Label.new()
	icon_label.text = achievement.icon if is_unlocked else "🔒"
	icon_label.add_theme_font_size_override("font_size", UITheme.px(34))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	var title_label := Label.new()
	title_label.text = achievement.title
	title_label.theme_type_variation = &"CardTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = achievement.description
	desc_label.theme_type_variation = &"CaptionLabel"
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	card.add_child(vbox)
	return card


func _on_close_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	_close()
