extends PanelContainer
class_name PointsDisplay

## Animated Points Display
##
## Shows player name, avatar, and animated point counter.
## Pulses on value changes.

@onready var points_label: Label = $VBox/PointsLabel
@onready var stats_label: Label = $VBox/StatsLabel

var _displayed_points: int = 0
var _target_points: int = 0
var _points_tween: Tween = null

const ANIMATION_DURATION: float = 0.5


func _ready() -> void:
	# Will be initialized by HUD
	pass


## Set initial points without animation
func set_points_immediate(points: int, player_name: String, avatar_emoji: String) -> void:
	_displayed_points = points
	_target_points = points
	_update_label(player_name, avatar_emoji)


## Animate points change
func animate_points(new_total: int, player_name: String, avatar_emoji: String) -> void:
	_target_points = new_total
	
	if _points_tween:
		_points_tween.kill()
	
	_points_tween = create_tween()
	_points_tween.tween_method(
		func(value: int) -> void:
			_displayed_points = value
			_update_label(player_name, avatar_emoji),
		_displayed_points,
		_target_points,
		ANIMATION_DURATION
	)
	_points_tween.set_ease(Tween.EASE_OUT)


## Update stats text
func update_stats(grade_name: String, correct_answers: int, buildings_placed: int) -> void:
	if not stats_label:
		return
	var text := ""
	if grade_name:
		text = "📖 %s\n" % grade_name
	text += "✅ %d richtig\n🏠 %d Gebäude" % [correct_answers, buildings_placed]
	stats_label.text = text


## Pulse animation on unlock
func pulse() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)


func _update_label(player_name: String, avatar_emoji: String) -> void:
	if points_label:
		points_label.text = "%s %s\n📚 %d Punkte" % [avatar_emoji, player_name, _displayed_points]

