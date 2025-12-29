extends Control
class_name CharacterEditor

## Character Editor UI
## Allows players to customize their character appearance

signal editor_closed
signal customization_saved(customization: PlayerCustomization)

## Preview character
@onready var preview_container: SubViewportContainer = $Panel/VBox/HBox/PreviewContainer
@onready var preview_viewport: SubViewport = $Panel/VBox/HBox/PreviewContainer/SubViewport
@onready var preview_character: Node3D = $Panel/VBox/HBox/PreviewContainer/SubViewport/PreviewCharacter

## Color buttons containers
@onready var skin_colors: HBoxContainer = $Panel/VBox/HBox/OptionsScroll/Options/SkinSection/SkinColors
@onready var hair_colors: HBoxContainer = $Panel/VBox/HBox/OptionsScroll/Options/HairSection/HairColors
@onready var shirt_colors: HBoxContainer = $Panel/VBox/HBox/OptionsScroll/Options/ShirtSection/ShirtColors
@onready var pants_colors: HBoxContainer = $Panel/VBox/HBox/OptionsScroll/Options/PantsSection/PantsColors

## Style buttons
@onready var hair_styles: HBoxContainer = $Panel/VBox/HBox/OptionsScroll/Options/HairStyleSection/HairStyles
@onready var glasses_types: HBoxContainer = $Panel/VBox/HBox/OptionsScroll/Options/GlassesSection/GlassesTypes
@onready var hat_types: HBoxContainer = $Panel/VBox/HBox/OptionsScroll/Options/HatSection/HatTypes

## Current customization being edited
var _customization: PlayerCustomization
var _preview_builder: CharacterPreviewBuilder


func _ready() -> void:
	visible = false
	_preview_builder = CharacterPreviewBuilder.new()
	_setup_color_buttons()
	_setup_style_buttons()

	# Connect buttons
	$Panel/VBox/ButtonRow/SaveButton.pressed.connect(_on_save_pressed)
	$Panel/VBox/ButtonRow/CancelButton.pressed.connect(_on_cancel_pressed)
	$Panel/VBox/ButtonRow/RandomizeButton.pressed.connect(_on_randomize_pressed)


func open() -> void:
	# Load current customization or create default
	if ProfileManager.current_profile:
		_customization = ProfileManager.current_profile.get_customization().duplicate()
	else:
		_customization = PlayerCustomization.create_default()

	_update_preview()
	_update_button_selections()
	visible = true

	# Animate in
	modulate.a = 0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): visible = false)
	editor_closed.emit()


func _setup_color_buttons() -> void:
	# Skin colors
	_create_color_buttons(skin_colors, PlayerCustomization.SKIN_PRESETS, _on_skin_color_selected)
	# Hair colors
	_create_color_buttons(hair_colors, PlayerCustomization.HAIR_PRESETS, _on_hair_color_selected)
	# Shirt colors
	_create_color_buttons(shirt_colors, PlayerCustomization.SHIRT_PRESETS, _on_shirt_color_selected)
	# Pants colors
	_create_color_buttons(pants_colors, PlayerCustomization.PANTS_PRESETS, _on_pants_color_selected)


func _create_color_buttons(container: HBoxContainer, colors: Array, callback: Callable) -> void:
	for child in container.get_children():
		child.queue_free()

	for i in range(colors.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(40, 40)
		btn.add_theme_stylebox_override("normal", _create_color_stylebox(colors[i]))
		btn.add_theme_stylebox_override("hover", _create_color_stylebox(colors[i].lightened(0.2)))
		btn.add_theme_stylebox_override("pressed", _create_color_stylebox(colors[i].darkened(0.2)))
		btn.pressed.connect(callback.bind(colors[i]))
		container.add_child(btn)


func _create_color_stylebox(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = color.darkened(0.3)
	return style


func _setup_style_buttons() -> void:
	# Hair styles
	var hair_labels := ["Kurz", "Lang", "Stachelig", "Glatze"]
	_create_style_buttons(hair_styles, hair_labels, _on_hair_style_selected)

	# Glasses
	var glasses_labels := ["Keine", "Rund", "Eckig"]
	_create_style_buttons(glasses_types, glasses_labels, _on_glasses_selected)

	# Hats
	var hat_labels := ["Kein", "Kappe", "Mütze"]
	_create_style_buttons(hat_types, hat_labels, _on_hat_selected)


func _create_style_buttons(container: HBoxContainer, labels: Array, callback: Callable) -> void:
	for child in container.get_children():
		child.queue_free()

	for i in range(labels.size()):
		var btn := Button.new()
		btn.text = labels[i]
		btn.custom_minimum_size = Vector2(70, 35)
		btn.pressed.connect(callback.bind(i))
		container.add_child(btn)


func _on_skin_color_selected(color: Color) -> void:
	_customization.skin_color = color
	_update_preview()

func _on_hair_color_selected(color: Color) -> void:
	_customization.hair_color = color
	_update_preview()

func _on_shirt_color_selected(color: Color) -> void:
	_customization.shirt_color = color
	_update_preview()

func _on_pants_color_selected(color: Color) -> void:
	_customization.pants_color = color
	_update_preview()

func _on_hair_style_selected(style: int) -> void:
	_customization.hair_style = style as PlayerCustomization.HairStyle
	_update_preview()


func _update_preview() -> void:
	if not preview_character:
		return
	# Rebuild preview character mesh
	if _preview_builder:
		_preview_builder.build_character(preview_character, _customization)


func _update_button_selections() -> void:
	# Visual feedback for selected options could be added here
	pass


func _on_save_pressed() -> void:
	# Save to profile
	if ProfileManager.current_profile:
		ProfileManager.current_profile.customization = _customization
		ProfileManager.save_profile()

	customization_saved.emit(_customization)

	# Update player in game if exists
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.apply_customization(_customization)

	close()


func _on_cancel_pressed() -> void:
	close()


func _on_randomize_pressed() -> void:
	_customization.randomize_appearance()
	_update_preview()


func _on_glasses_selected(type: int) -> void:
	_customization.glasses_type = type as PlayerCustomization.GlassesType
	_update_preview()

func _on_hat_selected(type: int) -> void:
	_customization.hat_type = type as PlayerCustomization.HatType
	_update_preview()
