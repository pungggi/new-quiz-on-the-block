extends VBoxContainer
class_name ToastManager

## Toast Notification Manager
##
## Displays temporary notification messages with animations.
## Usage: toast_manager.show("Message", Color.GREEN)

const DEFAULT_DURATION: float = 2.5
const FADE_IN_TIME: float = 0.25
const FADE_OUT_TIME: float = 0.4


## Show a toast notification with optional color
func show_toast(message: String, color: Color = Color.WHITE, duration: float = DEFAULT_DURATION) -> void:
	var panel := _create_toast_panel(message, color)
	add_child(panel)
	_animate_toast(panel, duration)


## Create styled toast panel
func _create_toast_panel(message: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	
	# Dark card with a coloured bar: readable over any part of the world
	panel.add_theme_stylebox_override("panel", UITheme.toast_stylebox(color))
	
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", UITheme.px(18))
	
	panel.add_child(label)
	return panel


## Animate toast in and out
func _animate_toast(panel: PanelContainer, duration: float) -> void:
	panel.modulate.a = 0.0
	panel.position.y = -30
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, FADE_IN_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", 0.0, FADE_IN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	tween.chain().tween_interval(duration)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_property(panel, "position:y", -20.0, FADE_OUT_TIME)
	tween.tween_callback(panel.queue_free)
