extends Control
class_name BuildingPanel

## Building Selection Panel
##
## Displays available buildings in a horizontal bar at the bottom.
## Shows unlock status, costs, and allows selection for placement.

signal building_selected(building: BuildingData)
signal panel_toggled(is_open: bool)

@onready var toggle_button: Button = %ToggleButton
@onready var points_label: Label = %PointsLabel
@onready var building_container: HBoxContainer = %BuildingContainer
@onready var panel: PanelContainer = %Panel
@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var tooltip_name: Label = %TooltipName
@onready var tooltip_desc: Label = %TooltipDesc
@onready var tooltip_cost: Label = %TooltipCost
@onready var tooltip_unlock: Label = %TooltipUnlock

const BUILDING_BUTTON_SCENE := preload("res://scenes/ui/building_button.tscn")

var _is_open: bool = true
var _building_buttons: Dictionary = {} # BuildingData -> Button
var _building_manager: Node


func _ready() -> void:
	toggle_button.pressed.connect(_on_toggle_pressed)
	tooltip_panel.visible = false

	# Get BuildingManager autoload
	_building_manager = get_node_or_null("/root/BuildingManager")
	if not _building_manager:
		push_error("BuildingPanel: BuildingManager autoload not found!")
		return

	# Connect to BuildingManager signals
	_building_manager.education_points_changed.connect(_on_points_changed)
	_building_manager.building_unlocked.connect(_on_building_unlocked)

	_update_points_display()
	_populate_buildings()


func _populate_buildings() -> void:
	# Clear existing buttons
	for child in building_container.get_children():
		child.queue_free()
	_building_buttons.clear()
	
	# Create button for each building
	var buildings: Array[BuildingData] = _building_manager.get_all_buildings()
	for building: BuildingData in buildings:
		var btn: Button = BUILDING_BUTTON_SCENE.instantiate()
		btn.text = building.display_name.substr(0, 1) # First letter
		btn.tooltip_text = building.display_name
		
		# Store reference
		_building_buttons[building] = btn
		
		# Set color based on building
		var style := StyleBoxFlat.new()
		style.bg_color = building.color
		style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style)
		
		# Hover style
		var hover_style := style.duplicate()
		hover_style.bg_color = building.color.lightened(0.2)
		btn.add_theme_stylebox_override("hover", hover_style)
		
		# Pressed style
		var pressed_style := style.duplicate()
		pressed_style.bg_color = building.color.darkened(0.2)
		pressed_style.border_width_bottom = 4
		pressed_style.border_color = Color.WHITE
		btn.add_theme_stylebox_override("pressed", pressed_style)
		
		# Connect signals
		btn.pressed.connect(_on_building_button_pressed.bind(building))
		btn.mouse_entered.connect(_on_building_hover.bind(building))
		btn.mouse_exited.connect(_on_building_hover_exit)
		
		building_container.add_child(btn)
		_update_button_state(building)


func _update_button_state(building: BuildingData) -> void:
	var btn: Button = _building_buttons.get(building)
	if not btn:
		return
	
	var is_unlocked := building.is_unlocked(_building_manager.player_stats)
	var can_afford := building.can_afford(_building_manager.education_points)
	
	btn.disabled = not is_unlocked
	
	if not is_unlocked:
		btn.modulate = Color(0.5, 0.5, 0.5, 0.8)
		btn.text = "🔒"
	elif not can_afford:
		btn.modulate = Color(1.0, 0.7, 0.7, 1.0)
		btn.text = building.display_name.substr(0, 1)
	else:
		btn.modulate = Color.WHITE
		btn.text = building.display_name.substr(0, 1)


func _update_points_display() -> void:
	if _building_manager:
		points_label.text = "📚 %d" % _building_manager.education_points


func _on_toggle_pressed() -> void:
	_is_open = not _is_open
	panel.visible = _is_open
	toggle_button.text = "▼ Bauen" if _is_open else "▲ Bauen"
	panel_toggled.emit(_is_open)


func _on_building_button_pressed(building: BuildingData) -> void:
	if not building.is_unlocked(_building_manager.player_stats):
		return

	if _building_manager.select_building(building):
		building_selected.emit(building)
		# Visual feedback - highlight selected
		for b in _building_buttons:
			var btn: Button = _building_buttons[b]
			btn.button_pressed = (b == building)


func _on_building_hover(building: BuildingData) -> void:
	var is_unlocked := building.is_unlocked(_building_manager.player_stats)

	tooltip_name.text = building.display_name
	tooltip_desc.text = building.description
	tooltip_cost.text = "Kosten: %d 📚" % building.cost

	if not is_unlocked:
		var progress := building.get_unlock_progress(_building_manager.player_stats)
		var needed := building.required_correct_answers
		var current := int(progress * needed)
		if building.required_category != "":
			tooltip_unlock.text = "🔒 %d/%d %s Fragen" % [current, needed, building.required_category]
		else:
			tooltip_unlock.text = "🔒 %d/%d Fragen richtig" % [current, needed]
		tooltip_unlock.visible = true
	else:
		tooltip_unlock.visible = false
	
	tooltip_panel.visible = true


func _on_building_hover_exit() -> void:
	tooltip_panel.visible = false


func _on_points_changed(_new_total: int) -> void:
	_update_points_display()
	# Update all button states
	for building in _building_buttons:
		_update_button_state(building)


func _on_building_unlocked(building: BuildingData) -> void:
	_update_button_state(building)
	# TODO: Play unlock animation/sound
