extends Label
class_name HintDisplay

## Contextual Hint Display
##
## Shows pulsing hints based on player progress.
## Automatically hides when all hints have been shown.

signal all_hints_completed

## Tracking which hints have been triggered
var has_clicked_npc: bool = false
var has_placed_building: bool = false
var has_answered_quiz: bool = false

var _hint_tween: Tween = null


func _ready() -> void:
	visible = false


## Mark NPC interaction as completed
func mark_npc_clicked() -> void:
	has_clicked_npc = true
	_update_hint()


## Mark quiz answer as completed
func mark_quiz_answered() -> void:
	has_answered_quiz = true
	_update_hint()


## Mark building placement as completed
func mark_building_placed() -> void:
	has_placed_building = true
	_update_hint()


## Start showing hints (call after a delay)
func start_hints() -> void:
	_update_hint()


## Update displayed hint based on progress
func _update_hint() -> void:
	var hint_text := ""
	
	if not has_clicked_npc:
		hint_text = "💡 Klicke auf einen bunten NPC um ein Quiz zu starten!"
	elif not has_answered_quiz:
		hint_text = "💡 Beantworte Fragen richtig um Punkte zu sammeln!"
	elif not has_placed_building:
		hint_text = "💡 Wähle unten ein Gebäude und klicke auf die Wiese zum Bauen!"
	else:
		visible = false
		all_hints_completed.emit()
		_stop_pulse()
		return
	
	text = hint_text
	visible = true
	_start_pulse()


## Start pulsing animation
func _start_pulse() -> void:
	_stop_pulse()
	_hint_tween = create_tween()
	_hint_tween.set_loops()
	_hint_tween.tween_property(self, "modulate:a", 0.6, 1.0)
	_hint_tween.tween_property(self, "modulate:a", 1.0, 1.0)


## Stop pulsing animation
func _stop_pulse() -> void:
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null

