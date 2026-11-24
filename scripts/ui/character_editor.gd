class_name CharacterEditor
extends MenuDialog

## Character Editor - customise the player character.
## Left: live 3D preview. Right: swatches and style chips, each an exclusive
## toggle group, so the current choice is always visible (and synced when
## the editor opens or "Zufällig" is pressed).
## Layout and ESC come from MenuDialog.

signal editor_closed
signal customization_saved(customization: PlayerCustomization)

@onready var preview_viewport: SubViewport = %SubViewport
@onready var preview_character: Node3D = %PreviewCharacter

@onready var skin_colors: HFlowContainer = %SkinColors
@onready var hair_colors: HFlowContainer = %HairColors
@onready var shirt_colors: HFlowContainer = %ShirtColors
@onready var pants_colors: HFlowContainer = %PantsColors

@onready var hair_styles: HFlowContainer = %HairStyles
@onready var glasses_types: HFlowContainer = %GlassesTypes
@onready var hat_types: HFlowContainer = %HatTypes

@onready var randomize_button: Button = %RandomizeButton
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton

var _customization: PlayerCustomization
var _preview_builder: CharacterPreviewBuilder

## group name -> buttons, in the order of the preset arrays / style indexes
var _swatch_groups: Dictionary = {}
var _style_groups: Dictionary = {}


func _ready() -> void:
	visible = false
	_preview_builder = CharacterPreviewBuilder.new()

	# Swatches show their colour; the selected one gets a thick dark border
	_swatch_groups["skin"] = _create_swatch_buttons(skin_colors, PlayerCustomization.SKIN_PRESETS, _on_skin_color_selected)
	_swatch_groups["hair"] = _create_swatch_buttons(hair_colors, PlayerCustomization.HAIR_PRESETS, _on_hair_color_selected)
	_swatch_groups["shirt"] = _create_swatch_buttons(shirt_colors, PlayerCustomization.SHIRT_PRESETS, _on_shirt_color_selected)
	_swatch_groups["pants"] = _create_swatch_buttons(pants_colors, PlayerCustomization.PANTS_PRESETS, _on_pants_color_selected)

	# Styles are text chips
	_style_groups["hair_style"] = _create_style_buttons(hair_styles, ["Kurz", "Lang", "Stachelig", "Glatze"], _on_hair_style_selected)
	_style_groups["glasses"] = _create_style_buttons(glasses_types, ["Keine", "Rund", "Eckig"], _on_glasses_selected)
	_style_groups["hat"] = _create_style_buttons(hat_types, ["Kein", "Kappe", "Mütze"], _on_hat_selected)

	randomize_button.pressed.connect(_on_randomize_pressed)
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)


## A new editor instance is created for every open (see MainMenu)
func open() -> void:
	if ProfileManager.current_profile:
		_customization = ProfileManager.current_profile.get_customization().duplicate()
	else:
		_customization = PlayerCustomization.create_default()

	_update_preview()
	_update_button_selections()
	visible = true


func close() -> void:
	editor_closed.emit()
	queue_free()


func _on_escape() -> bool:
	close()
	return true


# --- buttons -------------------------------------------------------------

func _create_swatch_buttons(
	container: Container, presets: Array, callback: Callable
) -> Array[Button]:
	var buttons: Array[Button] = []
	var group := ButtonGroup.new()
	for i: int in range(presets.size()):
		var color: Color = presets[i]
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.tooltip_text = "Farbe %d" % (i + 1)
		btn.custom_minimum_size = Vector2(UITheme.px(40), UITheme.px(40))
		btn.add_theme_stylebox_override("normal", _swatch_style(color, false))
		btn.add_theme_stylebox_override("hover", _swatch_style(color.lightened(0.12), false))
		btn.add_theme_stylebox_override("pressed", _swatch_style(color, true))
		btn.add_theme_stylebox_override("hover_pressed", _swatch_style(color.lightened(0.08), true))
		btn.pressed.connect(callback.bind(color))
		container.add_child(btn)
		buttons.append(btn)
	return buttons


func _swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(UITheme.px(4) if selected else UITheme.px(2))
	if not selected:
		sb.border_color = color.darkened(0.35)
	else:
		# A dark ring is invisible on a dark swatch: pick by luminance
		sb.border_color = UITheme.WHITE if color.get_luminance() < 0.3 else UITheme.INK
	return sb


func _create_style_buttons(
	container: Container, labels: Array, callback: Callable
) -> Array[Button]:
	var buttons: Array[Button] = []
	var group := ButtonGroup.new()
	for i: int in range(labels.size()):
		var btn := Button.new()
		btn.text = labels[i]
		btn.theme_type_variation = &"ChipButton"
		btn.toggle_mode = true
		btn.button_group = group
		btn.pressed.connect(callback.bind(i))
		container.add_child(btn)
		buttons.append(btn)
	return buttons


## Mark the preset that matches the colour, or the closest one (a saved
## colour may lie between presets)
func _select_swatch(group: String, presets: Array, color: Color) -> void:
	var buttons: Array[Button] = _swatch_groups[group]
	var best: int = -1
	var best_distance: float = INF
	for i: int in range(buttons.size()):
		var preset: Color = presets[i]
		var delta: Color = preset - color
		var distance: float = delta.r * delta.r + delta.g * delta.g + delta.b * delta.b
		if distance < best_distance:
			best_distance = distance
			best = i
	for i: int in range(buttons.size()):
		var matches: bool = (i == best)
		if buttons[i].button_pressed != matches:
			buttons[i].set_pressed_no_signal(matches)


func _select_style(group: String, index: int) -> void:
	var buttons: Array[Button] = _style_groups[group]
	for i: int in range(buttons.size()):
		var matches: bool = (i == index)
		if buttons[i].button_pressed != matches:
			buttons[i].set_pressed_no_signal(matches)


## Show the current choice on every button (no_signal: nothing changes)
func _update_button_selections() -> void:
	if not _customization:
		return
	_select_swatch("skin", PlayerCustomization.SKIN_PRESETS, _customization.skin_color)
	_select_swatch("hair", PlayerCustomization.HAIR_PRESETS, _customization.hair_color)
	_select_swatch("shirt", PlayerCustomization.SHIRT_PRESETS, _customization.shirt_color)
	_select_swatch("pants", PlayerCustomization.PANTS_PRESETS, _customization.pants_color)
	_select_style("hair_style", _customization.hair_style)
	_select_style("glasses", _customization.glasses_type)
	_select_style("hat", _customization.hat_type)


# --- preview -------------------------------------------------------------

func _update_preview() -> void:
	if not preview_character:
		return
	if _preview_builder:
		_preview_builder.build_character(preview_character, _customization)


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


func _on_glasses_selected(type: int) -> void:
	_customization.glasses_type = type as PlayerCustomization.GlassesType
	_update_preview()


func _on_hat_selected(type: int) -> void:
	_customization.hat_type = type as PlayerCustomization.HatType
	_update_preview()


# --- footer --------------------------------------------------------------

func _on_randomize_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	_customization.randomize_appearance()
	_update_preview()
	_update_button_selections()


func _on_save_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	if ProfileManager.current_profile:
		ProfileManager.current_profile.customization = _customization
		ProfileManager.save_profile()

	customization_saved.emit(_customization)

	# Update player in game if it exists
	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if player:
		player.apply_customization(_customization)

	queue_free()


func _on_cancel_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	close()
