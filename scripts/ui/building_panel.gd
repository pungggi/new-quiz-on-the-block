extends Control
class_name BuildingPanel

## Building Selection Panel
##
## Displays available buildings organized by category tabs.
## Shows unlock status, costs, and allows selection for placement.

signal building_selected(building: BuildingData)
signal prop_selected(prop: PropData)
signal panel_toggled(is_open: bool)

@onready var toggle_button: Button = %ToggleButton
@onready var points_label: Label = %PointsLabel
@onready var building_container: HBoxContainer = %BuildingContainer
@onready var category_tabs: HFlowContainer = %CategoryTabs
@onready var panel: PanelContainer = %Panel
@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var tooltip_name: Label = %TooltipName
@onready var tooltip_desc: Label = %TooltipDesc
@onready var tooltip_cost: Label = %TooltipCost
@onready var tooltip_unlock: Label = %TooltipUnlock

const BUILDING_BUTTON_SCENE := preload("res://scenes/ui/building_button.tscn")

## Category display names and icons
const CATEGORY_INFO: Dictionary = {
	"residential": {"name": "🏠 Wohnen", "order": 0},
	"commercial": {"name": "🏪 Gewerbe", "order": 1},
	"education": {"name": "🎓 Bildung", "order": 2},
	"industry": {"name": "🏭 Industrie", "order": 3},
	"infrastructure": {"name": "🛤️ Infrastruktur", "order": 4},
	"decoration": {"name": "🌳 Deko", "order": 5},
}

var _is_open: bool = true
var _building_buttons: Dictionary = {} # BuildingData -> Button
var _prop_buttons: Dictionary = {} # PropData -> Button
var _category_buttons: Dictionary = {} # category_name -> Button
var _current_category: String = "residential"
var _building_manager: Node
var _prop_manager: Node


func _ready() -> void:
	toggle_button.pressed.connect(_on_toggle_pressed)
	tooltip_panel.visible = false

	# Get BuildingManager autoload
	_building_manager = get_node_or_null("/root/BuildingManager")
	if not _building_manager:
		push_error("BuildingPanel: BuildingManager autoload not found!")
		return

	# Get PropManager autoload
	_prop_manager = get_node_or_null("/root/PropManager")

	# Connect to BuildingManager signals
	_building_manager.education_points_changed.connect(_on_points_changed)
	_building_manager.building_unlocked.connect(_on_building_unlocked)

	_update_points_display()
	_create_category_tabs()
	_populate_buildings()


func _create_category_tabs() -> void:
	# Clear existing tabs
	for child in category_tabs.get_children():
		child.queue_free()
	_category_buttons.clear()

	# Get available categories from buildings
	var available_categories: Array[String] = []
	for building: BuildingData in _building_manager.get_all_buildings():
		if building.category not in available_categories:
			available_categories.append(building.category)

	# Add decoration tab if PropManager has props
	if _prop_manager and not _prop_manager.get_all_props().is_empty():
		if "decoration" not in available_categories:
			available_categories.append("decoration")

	# Sort by order
	available_categories.sort_custom(func(a: String, b: String) -> bool:
		return CATEGORY_INFO.get(a, {"order": 99}).order < CATEGORY_INFO.get(b, {"order": 99}).order
	)

	# Create tab buttons
	for cat: String in available_categories:
		var info: Dictionary = CATEGORY_INFO.get(cat, {"name": cat.capitalize(), "order": 99})
		var btn := Button.new()
		btn.text = info.name
		btn.toggle_mode = true
		btn.button_pressed = (cat == _current_category)
		btn.theme_type_variation = &"ChipButton"
		btn.pressed.connect(_on_category_selected.bind(cat))
		category_tabs.add_child(btn)
		_category_buttons[cat] = btn


func _on_category_selected(category: String) -> void:
	_current_category = category
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)

	# Update tab visual state
	for cat: String in _category_buttons:
		_category_buttons[cat].button_pressed = (cat == category)

	# Refresh buildings display
	_populate_buildings()


func _populate_buildings() -> void:
	# Clear existing buttons
	for child in building_container.get_children():
		child.queue_free()
	_building_buttons.clear()
	_prop_buttons.clear()

	# Create button for each building in current category
	var buildings: Array[BuildingData] = _building_manager.get_buildings_by_category(_current_category)
	for building: BuildingData in buildings:
		_create_building_button(building)

	# If decoration category, also show props from PropManager
	if _current_category == "decoration" and _prop_manager:
		for prop: PropData in _prop_manager.get_all_props():
			_create_prop_button(prop)


func _create_building_button(building: BuildingData) -> void:
	var btn: Button = BUILDING_BUTTON_SCENE.instantiate()
	btn.text = building.display_name.substr(0, 1) # First letter
	btn.tooltip_text = building.display_name

	# Store reference
	_building_buttons[building] = btn

	_apply_block_style(btn, building.color)

	# Connect signals
	btn.pressed.connect(_on_building_button_pressed.bind(building))
	btn.mouse_entered.connect(_on_building_hover.bind(building))
	btn.mouse_exited.connect(_on_building_hover_exit)

	building_container.add_child(btn)
	_update_button_state(building)


func _create_prop_button(prop: PropData) -> void:
	var btn: Button = BUILDING_BUTTON_SCENE.instantiate()
	btn.text = prop.display_name.substr(0, 1)
	btn.tooltip_text = prop.display_name

	_prop_buttons[prop] = btn

	_apply_block_style(btn, prop.secondary_color)

	# Affordability check
	var can_afford: bool = prop.can_afford(_building_manager.education_points)
	if not can_afford:
		btn.modulate = Color(1.0, 0.7, 0.7, 1.0)

	btn.pressed.connect(_on_prop_button_pressed.bind(prop))
	btn.mouse_entered.connect(_on_prop_hover.bind(prop))
	btn.mouse_exited.connect(_on_building_hover_exit)

	building_container.add_child(btn)


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
	AudioManager.play_sfx(AudioManager.SFX.PANEL_OPEN if _is_open else AudioManager.SFX.PANEL_CLOSE)


func _on_building_button_pressed(building: BuildingData) -> void:
	if not building.is_unlocked(_building_manager.player_stats):
		return

	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	if _building_manager.select_building(building):
		building_selected.emit(building)
		# Visual feedback - highlight selected
		for b in _building_buttons:
			var btn: Button = _building_buttons[b]
			btn.button_pressed = (b == building)


func _on_building_hover(building: BuildingData) -> void:
	var is_unlocked := building.is_unlocked(_building_manager.player_stats)
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_HOVER, 0.5)

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


func _on_prop_button_pressed(prop: PropData) -> void:
	if not _prop_manager:
		return

	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)

	# Deselect any building first
	if _building_manager:
		_building_manager.deselect_building()

	prop_selected.emit(prop)

	# Visual feedback - highlight selected prop, deselect buildings
	for b in _building_buttons:
		_building_buttons[b].button_pressed = false
	for p in _prop_buttons:
		_prop_buttons[p].button_pressed = (p == prop)


func _on_prop_hover(prop: PropData) -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_HOVER, 0.5)

	tooltip_name.text = prop.display_name
	tooltip_desc.text = prop.description
	tooltip_cost.text = "Kosten: %d 📚" % prop.cost
	tooltip_unlock.visible = false
	tooltip_panel.visible = true


func _on_points_changed(_new_total: int) -> void:
	_update_points_display()
	# Update all button states
	for building in _building_buttons:
		_update_button_state(building)
	# Update prop affordability
	for prop: PropData in _prop_buttons:
		var btn: Button = _prop_buttons[prop]
		if prop.can_afford(_building_manager.education_points):
			btn.modulate = Color.WHITE
		else:
			btn.modulate = Color(1.0, 0.7, 0.7, 1.0)


func _on_building_unlocked(building: BuildingData) -> void:
	_update_button_state(building)
	AudioManager.play_sfx(AudioManager.SFX.UNLOCK)


## A coloured toy block for a building/prop, sized for the reading level.
## The selected block gets a dark ring.
func _apply_block_style(btn: Button, color: Color) -> void:
	var side: int = UITheme.px(48)
	btn.custom_minimum_size = Vector2(side, side)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(UITheme.RADIUS)
	normal.border_width_bottom = UITheme.BLOCK_LIP
	normal.border_color = color.darkened(0.4)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.15)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = color.lightened(0.08)
	pressed.set_corner_radius_all(UITheme.RADIUS)
	pressed.set_border_width_all(UITheme.px(3))
	pressed.border_color = UITheme.INK
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
