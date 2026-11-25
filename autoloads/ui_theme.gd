extends Node
## UITheme (autoload)
##
## The one theme for the whole UI ("Hell & blockig": cream cards, thick
## borders, toy-block buttons) in three reading levels. The theme is put on
## the root window, so every Control inherits it, and it is swapped live
## when the profile (and with it the grade level) changes.
##
##   Kindergarten - 2. Klasse  : Andika (Leselernschrift), sizes x1.30
##   3. - 4. Klasse            : Nunito, sizes x1.12
##   ab 5. Klasse / Erwachsene : Nunito, sizes x1.00
##
## Runtime-built controls ask for the current sizes with px() so they scale
## with the level too. Never hard-code pixel sizes for text.

signal theme_changed(level: int)

const LEVEL_YOUNG: int = 0
const LEVEL_MEDIUM: int = 1
const LEVEL_TEEN: int = 2

## Grade level (0 = Kindergarten) from which the next level starts
const MEDIUM_FROM_GRADE: int = 3
const TEEN_FROM_GRADE: int = 5

const FONT_NUNITO: FontFile = preload("res://resources/fonts/Nunito-VariableFont_wght.ttf")
const FONT_ANDIKA: FontFile = preload("res://resources/fonts/Andika-Regular.ttf")
const FONT_ANDIKA_BOLD: FontFile = preload("res://resources/fonts/Andika-Bold.ttf")

# --- Palette ---
const INK: Color = Color("2b2a33") ## text on cards
const INK_SOFT: Color = Color("5d5a68")
const INK_MUTED: Color = Color("8a8593")
const CARD: Color = Color("fff9ec") ## dialog and menu background
const CARD_WHITE: Color = Color("ffffff")
const CARD_SUNKEN: Color = Color("f4ead2") ## wells, inputs
const CARD_BORDER: Color = Color("d8c294")
const CARD_EDGE: Color = Color("c4aa74") ## the darker "underside" of a block
const CARD_LINE: Color = Color("e2d3ad")
const BACKDROP: Color = Color(0.07, 0.09, 0.16, 0.72) ## dims the world behind a dialog
const WHITE: Color = Color.WHITE
const GREEN: Color = Color("2f9e46")
const GREEN_TOP: Color = Color("3cb455")
const GREEN_EDGE: Color = Color("1f7331")
const GREEN_PALE: Color = Color("e2f4e3")
const BLUE: Color = Color("2f7fd1")
const BLUE_TOP: Color = Color("3d8fe0")
const BLUE_EDGE: Color = Color("1f5c9c")
const RED: Color = Color("d94a3d")
const RED_TOP: Color = Color("e35c4f")
const RED_EDGE: Color = Color("a83328")
const NEUTRAL: Color = Color("f1e6cc")
const NEUTRAL_TOP: Color = Color("f8efdb")
const NEUTRAL_EDGE: Color = Color("cbb78f")
const DISABLED: Color = Color("e9e2d3")
const BAR_BG: Color = Color("e6dcc3")
const SELECTION: Color = Color("cfe3fa")
const AMBER: Color = Color("9a6200") ## hints, readable on cream
const HINT_YELLOW: Color = Color(1.0, 1.0, 0.8) ## hints floating over the world

## Thickness of a toy block's darker underside (px)
const BLOCK_LIP: int = 4
## The one corner radius: block edges only lightly broken
const RADIUS: int = 6

## Base sizes in px at level TEEN; scaled per level
const SIZE_CAPTION: int = 13
const SIZE_BODY: int = 16
const SIZE_SECTION: int = 15
const SIZE_BUTTON: int = 18
const SIZE_SUBTITLE: int = 18
const SIZE_TITLE: int = 30
const SIZE_HERO: int = 44

const _SCALES: Array[float] = [1.30, 1.12, 1.00]

var _level: int = LEVEL_TEEN
var _applied: bool = false ## apply_level() ran at least once
var _themes: Dictionary = {} ## level (int) -> Theme


## Controls outside the window's theme chain (see _on_node_added)
var _extra_roots: Array[Control] = []


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# ProfileManager is listed before us, so it is already in the tree.
	ProfileManager.profile_created.connect(_on_profile_changed)
	ProfileManager.profile_switched.connect(_on_profile_changed)
	ProfileManager.profile_updated.connect(_on_profile_changed)
	ProfileManager.profile_loaded.connect(_on_profile_changed)
	refresh()


func _exit_tree() -> void:
	if get_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_profile_changed(_profile: PlayerProfile) -> void:
	refresh()


## Re-read the grade of the current profile and switch the theme if needed.
## Call after anything that changes a grade without a profile signal.
func refresh() -> void:
	var grade: int = 0
	var profile: PlayerProfile = ProfileManager.current_profile
	if profile:
		grade = profile.grade_level
	apply_level(level_for_grade(grade))


func level_for_grade(grade: int) -> int:
	if grade >= TEEN_FROM_GRADE:
		return LEVEL_TEEN
	if grade >= MEDIUM_FROM_GRADE:
		return LEVEL_MEDIUM
	return LEVEL_YOUNG


func current_level() -> int:
	return _level


func scale_factor() -> float:
	return _SCALES[_level]


## Base size (px at TEEN level) in the current reading level
func px(base: int) -> int:
	return _scaled(_level, base)


static func _scaled(level: int, base: int) -> int:
	return int(round(float(base) * _SCALES[level]))


func _body_fonts() -> Array[Font]:
	var fonts: Array[Font] = [FONT_ANDIKA, _nunito(400), _nunito(400)]
	return fonts


func _strong_fonts() -> Array[Font]:
	var fonts: Array[Font] = [FONT_ANDIKA_BOLD, _nunito(700), _nunito(700)]
	return fonts


func _title_fonts() -> Array[Font]:
	var fonts: Array[Font] = [FONT_ANDIKA_BOLD, _nunito(800), _nunito(800)]
	return fonts


## The variable font's default instance is weight 200 (ExtraLight), so
## every Nunito use must name its weight explicitly. Created once per
## weight: each FontVariation owns a glyph cache in the text server, so
## building a new one on every call would throw that cache away.
static var _nunito_cache: Dictionary = {} ## weight (int) -> FontVariation


static func _nunito(weight: int) -> FontVariation:
	if not _nunito_cache.has(weight):
		var fv: FontVariation = FontVariation.new()
		fv.base_font = FONT_NUNITO
		fv.variation_opentype = {"wght": weight}
		_nunito_cache[weight] = fv
	return _nunito_cache[weight]


## Controls whose parent is neither a Control nor a Window - e.g. directly
## under a CanvasLayer, like the in-game HUD - do NOT inherit the window
## theme (Godot stops the theme chain there). They get ours explicitly.
func _on_node_added(node: Node) -> void:
	var control: Control = node as Control
	if control == null:
		return
	var parent: Node = control.get_parent()
	if parent is Control or parent is Window:
		return
	control.theme = get_theme(_level)
	_extra_roots.append(control)
	# Off the list as soon as it leaves the tree, so the list never
	# collects freed controls
	control.tree_exiting.connect(_forget_root.bind(control), CONNECT_ONE_SHOT)


func _forget_root(control: Control) -> void:
	_extra_roots.erase(control)


## Put the theme on the root window (menus inherit it) and on every extra
## root collected by _on_node_added (in-game UI).
func apply_level(level: int) -> void:
	level = clampi(level, LEVEL_YOUNG, LEVEL_TEEN)
	if _applied and level == _level:
		return # same reading level: leave the UI as it is
	_level = level
	_applied = true
	var theme: Theme = get_theme(_level)
	var window: Window = get_window()
	if window:
		window.theme = theme
	for control: Control in _extra_roots:
		control.theme = theme
	theme_changed.emit(_level)


func get_theme(level: int) -> Theme:
	level = clampi(level, LEVEL_YOUNG, LEVEL_TEEN)
	if not _themes.has(level):
		_themes[level] = _build(level)
	return _themes[level]


# =========================================================================
# Theme construction
# =========================================================================

func _build(level: int) -> Theme:
	var t: Theme = Theme.new()
	var body: Array[Font] = _body_fonts()
	var strong: Array[Font] = _strong_fonts()
	var title: Array[Font] = _title_fonts()

	t.default_font = body[level]
	t.default_font_size = _scaled(level, SIZE_BODY)

	# --- Containers: one default spacing everywhere ---
	t.set_constant("separation", "BoxContainer", _scaled(level, 6))
	t.set_constant("h_separation", "GridContainer", _scaled(level, 8))
	t.set_constant("v_separation", "GridContainer", _scaled(level, 8))
	t.set_constant("h_separation", "HFlowContainer", _scaled(level, 8))
	t.set_constant("v_separation", "HFlowContainer", _scaled(level, 8))

	# --- Labels ---
	t.set_color("font_color", "Label", INK)
	t.set_constant("line_spacing", "Label", _scaled(level, 2))
	_variation(t, "MenuTitle", "Label")
	t.set_font("font", "MenuTitle", title[level])
	t.set_font_size("font_size", "MenuTitle", _scaled(level, SIZE_TITLE))
	_variation(t, "MenuSubtitle", "Label")
	t.set_font("font", "MenuSubtitle", strong[level])
	t.set_font_size("font_size", "MenuSubtitle", _scaled(level, SIZE_SUBTITLE))
	t.set_color("font_color", "MenuSubtitle", INK_SOFT)
	_variation(t, "SectionLabel", "Label")
	t.set_font("font", "SectionLabel", strong[level])
	t.set_font_size("font_size", "SectionLabel", _scaled(level, SIZE_SECTION))
	_variation(t, "CardTitle", "Label")
	t.set_font("font", "CardTitle", strong[level])
	t.set_font_size("font_size", "CardTitle", _scaled(level, SIZE_SECTION))
	_variation(t, "CaptionLabel", "Label")
	t.set_font_size("font_size", "CaptionLabel", _scaled(level, SIZE_CAPTION))
	t.set_color("font_color", "CaptionLabel", INK_MUTED)
	_variation(t, "ErrorLabel", "Label")
	t.set_font("font", "ErrorLabel", strong[level])
	t.set_font_size("font_size", "ErrorLabel", _scaled(level, SIZE_SECTION))
	t.set_color("font_color", "ErrorLabel", RED_EDGE)
	_variation(t, "AmberLabel", "Label")
	t.set_font("font", "AmberLabel", strong[level])
	t.set_font_size("font_size", "AmberLabel", _scaled(level, SIZE_BODY))
	t.set_color("font_color", "AmberLabel", AMBER)
	_variation(t, "InfoLabel", "Label")
	t.set_font("font", "InfoLabel", strong[level])
	t.set_font_size("font_size", "InfoLabel", _scaled(level, SIZE_BODY))
	t.set_color("font_color", "InfoLabel", BLUE_EDGE)
	_variation(t, "RewardLabel", "Label")
	t.set_font("font", "RewardLabel", title[level])
	t.set_font_size("font_size", "RewardLabel", _scaled(level, SIZE_TITLE - 8))
	t.set_color("font_color", "RewardLabel", GREEN_EDGE)
	_variation(t, "HintLabel", "Label")
	t.set_font("font", "HintLabel", strong[level])
	t.set_font_size("font_size", "HintLabel", _scaled(level, SIZE_SECTION + 2))
	t.set_color("font_color", "HintLabel", HINT_YELLOW)
	t.set_color("font_outline_color", "HintLabel", Color(0.1, 0.12, 0.2, 1.0))
	t.set_constant("outline_size", "HintLabel", _scaled(level, 5))
	_variation(t, "OutlineTitle", "Label")
	t.set_font("font", "OutlineTitle", title[level])
	t.set_font_size("font_size", "OutlineTitle", _scaled(level, SIZE_HERO))
	t.set_color("font_color", "OutlineTitle", WHITE)
	t.set_color("font_outline_color", "OutlineTitle", Color(0.2, 0.42, 0.72, 1.0))
	t.set_constant("outline_size", "OutlineTitle", _scaled(level, 9))
	_variation(t, "OutlineLabel", "Label")
	t.set_font("font", "OutlineLabel", strong[level])
	t.set_font_size("font_size", "OutlineLabel", _scaled(level, SIZE_SUBTITLE))
	t.set_color("font_color", "OutlineLabel", WHITE)
	t.set_color("font_outline_color", "OutlineLabel", Color(0.2, 0.42, 0.72, 1.0))
	t.set_constant("outline_size", "OutlineLabel", _scaled(level, 6))
	_variation(t, "OutlineCaption", "Label")
	t.set_font_size("font_size", "OutlineCaption", _scaled(level, SIZE_CAPTION))
	t.set_color("font_color", "OutlineCaption", Color(1.0, 1.0, 1.0, 0.92))
	t.set_color("font_outline_color", "OutlineCaption", Color(0.1, 0.12, 0.2, 1.0))
	t.set_constant("outline_size", "OutlineCaption", _scaled(level, 4))

	# --- Panels ---
	var card: StyleBoxFlat = _card_style(level)
	t.set_stylebox("panel", "PanelContainer", card)
	t.set_stylebox("panel", "Panel", card)
	_variation(t, "CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", _flat(CARD_WHITE, RADIUS, CARD_LINE, 2, _margins(level, 12, 8, 12, 8), CARD_EDGE))
	_variation(t, "LockedCardPanel", "PanelContainer")
	t.set_stylebox("panel", "LockedCardPanel", _flat(DISABLED, RADIUS, NEUTRAL_EDGE, 2, _margins(level, 12, 8, 12, 8)))
	_variation(t, "UnlockedCardPanel", "PanelContainer")
	t.set_stylebox("panel", "UnlockedCardPanel", _flat(GREEN_PALE, RADIUS, GREEN, 2, _margins(level, 12, 8, 12, 8), GREEN_EDGE))
	_variation(t, "HudPanel", "PanelContainer")
	var hud: StyleBoxFlat = _flat(Color(CARD, 0.9), RADIUS, CARD_EDGE, 2, _margins(level, 10, 4, 10, 4), CARD_EDGE)
	t.set_stylebox("panel", "HudPanel", hud)
	_variation(t, "WellPanel", "PanelContainer")
	var well: StyleBoxFlat = _flat(CARD_SUNKEN, RADIUS, CARD_EDGE, 2, _margins(level, 8, 8, 8, 8))
	well.border_width_top = 4
	t.set_stylebox("panel", "WellPanel", well)

	# --- Buttons: neutral toy block by default ---
	var focus: StyleBoxFlat = _focus_ring(level)
	var neutral: Array[StyleBox] = _block_set(level, NEUTRAL_TOP, NEUTRAL, NEUTRAL_EDGE)
	_apply_button(t, "Button", neutral, focus, strong[level], level, INK, INK_MUTED)
	# Toggle "chips": the pressed state is the SELECTED state
	neutral[2] = _flat(GREEN_PALE, RADIUS, GREEN, 2, _margins(level, 16, 9, 16, 9))
	neutral[4] = _flat(GREEN_PALE.lightened(0.04), RADIUS, GREEN, 2, _margins(level, 16, 9, 16, 9))
	_apply_button(t, "ChipButton", neutral, focus, strong[level], level, INK, INK_MUTED)
	_variation(t, "ChipButton", "Button")
	# IconChip: the same chip with tight side padding, so an emoji-only chip
	# stays square (avatar picker) instead of growing wide
	var icon: Array[StyleBox] = []
	for style: StyleBox in neutral:
		var copy: StyleBoxFlat = (style.duplicate() as StyleBoxFlat)
		copy.content_margin_left = float(_scaled(level, 10))
		copy.content_margin_right = float(_scaled(level, 10))
		icon.append(copy)
	_apply_button(t, "IconChip", icon, focus, strong[level], level, INK, INK_MUTED)
	_variation(t, "IconChip", "Button")
	var primary: Array[StyleBox] = _block_set(level, GREEN_TOP, GREEN, GREEN_EDGE)
	_apply_button(t, "PrimaryButton", primary, focus, strong[level], level, WHITE, INK_MUTED)
	_variation(t, "PrimaryButton", "Button")
	var secondary: Array[StyleBox] = _block_set(level, BLUE_TOP, BLUE, BLUE_EDGE)
	_apply_button(t, "SecondaryButton", secondary, focus, strong[level], level, WHITE, INK_MUTED)
	_variation(t, "SecondaryButton", "Button")
	var danger: Array[StyleBox] = _block_set(level, RED_TOP, RED, RED_EDGE)
	_apply_button(t, "DangerButton", danger, focus, strong[level], level, WHITE, INK_MUTED)
	_variation(t, "DangerButton", "Button")

	# --- LineEdit ---
	var input: StyleBoxFlat = _flat(CARD_WHITE, 5, CARD_BORDER, 2, _margins(level, 12, 8, 12, 8))
	t.set_stylebox("normal", "LineEdit", input)
	var input_focus: StyleBoxFlat = _flat(CARD_WHITE, 5, BLUE, 2, _margins(level, 12, 8, 12, 8))
	t.set_stylebox("focus", "LineEdit", input_focus)
	t.set_stylebox("read_only", "LineEdit", _flat(CARD_SUNKEN, 5, CARD_BORDER, 2, _margins(level, 12, 8, 12, 8)))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_MUTED)
	t.set_color("font_uneditable_color", "LineEdit", INK_MUTED)
	t.set_color("font_selected_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", SELECTION)
	t.set_constant("caret_width", "LineEdit", 2)
	t.set_font_size("font_size", "LineEdit", _scaled(level, SIZE_BODY + 1))

	# --- CheckBox (only used if something still creates one) ---
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_hover_pressed_color", "CheckBox", INK)
	t.set_color("font_focus_color", "CheckBox", INK)
	t.set_font_size("font_size", "CheckBox", _scaled(level, SIZE_BODY))

	# --- Scrollbars: slim wooden grabber on a transparent track ---
	for bar_type: String in ["VScrollBar", "HScrollBar"]:
		var vertical: bool = bar_type == "VScrollBar"
		var track: StyleBoxEmpty = StyleBoxEmpty.new()
		track.content_margin_left = 2 if vertical else 0
		track.content_margin_right = 2 if vertical else 0
		track.content_margin_top = 0 if vertical else 2
		track.content_margin_bottom = 0 if vertical else 2
		t.set_stylebox("scroll", bar_type, track)
		t.set_stylebox("scroll_focus", bar_type, track)
		t.set_stylebox("grabber", bar_type, _grabber(level, vertical, CARD_EDGE))
		t.set_stylebox("grabber_highlight", bar_type, _grabber(level, vertical, CARD_BORDER.darkened(0.12)))
		t.set_stylebox("grabber_pressed", bar_type, _grabber(level, vertical, CARD_EDGE.darkened(0.3)))

	# --- ProgressBar ---
	t.set_stylebox("background", "ProgressBar", _flat(BAR_BG, 4, Color.TRANSPARENT, 0, Vector4.ZERO))
	t.set_stylebox("fill", "ProgressBar", _flat(GREEN, 4, Color.TRANSPARENT, 0, Vector4.ZERO))
	t.set_font_size("font_size", "ProgressBar", _scaled(level, SIZE_CAPTION))
	t.set_color("font_color", "ProgressBar", INK)

	# --- HSeparator ---
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = CARD_LINE
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", _scaled(level, 6))

	# --- Tooltips ---
	t.set_stylebox("panel", "TooltipPanel", _flat(INK, RADIUS, Color.TRANSPARENT, 0, _margins(level, 10, 6, 10, 6)))
	t.set_color("font_color", "TooltipLabel", WHITE)
	t.set_font_size("font_size", "TooltipLabel", _scaled(level, SIZE_CAPTION + 1))
	t.set_constant("outline_size", "TooltipLabel", 0)

	# --- Embedded windows (ConfirmationDialog for "reset profile") ---
	# Godot draws this stylebox on the window's CLIENT rect and then the
	# (opaque) window content over it. Only what sticks out through EXPAND
	# margins stays visible: the title band on top and a frame around the
	# rest. The default theme does the same (expand 8/32/8/6).
	var title_height: int = _scaled(level, 36)
	var frame: int = _scaled(level, 8)
	var window_panel: StyleBoxFlat = _card_style(level)
	window_panel.content_margin_left = float(frame)
	window_panel.content_margin_right = float(frame)
	window_panel.content_margin_top = float(title_height)
	window_panel.content_margin_bottom = float(frame)
	window_panel.set_expand_margin(SIDE_LEFT, float(frame))
	window_panel.set_expand_margin(SIDE_RIGHT, float(frame))
	window_panel.set_expand_margin(SIDE_TOP, float(title_height))
	window_panel.set_expand_margin(SIDE_BOTTOM, float(frame))
	t.set_stylebox("embedded_border", "Window", window_panel)
	t.set_stylebox("embedded_unfocused_border", "Window", window_panel)
	t.set_constant("title_height", "Window", title_height)
	t.set_color("title_color", "Window", INK)
	t.set_font("title_font", "Window", strong[level])
	t.set_font_size("title_font_size", "Window", _scaled(level, SIZE_SECTION + 2))
	# The stock close button is light grey (made for dark title bars)
	var close_size: int = _scaled(level, 16)
	t.set_icon("close", "Window", _close_icon(close_size, INK))
	t.set_icon("close_pressed", "Window", _close_icon(close_size, GREEN_EDGE))
	t.set_constant("close_h_offset", "Window", _scaled(level, 18))
	t.set_constant("close_v_offset", "Window", _scaled(level, 24))
	# Inside the frame: the same cream, with breathing room for text + buttons
	t.set_stylebox("panel", "AcceptDialog", _flat(CARD, RADIUS, Color.TRANSPARENT, 0, _margins(level, 14, 8, 14, 12)))
	t.set_constant("buttons_separation", "AcceptDialog", _scaled(level, 10))

	return t


static func _variation(t: Theme, variation: String, base_type: String) -> void:
	t.set_type_variation(StringName(variation), StringName(base_type))


static func _margins(level: int, left: int, top: int, right: int, bottom: int) -> Vector4:
	return Vector4(
		float(_scaled(level, left)), float(_scaled(level, top)),
		float(_scaled(level, right)), float(_scaled(level, bottom))
	)


## Rounded flat box. margins = (left, top, right, bottom) in base px.
## With an `edge` colour the box gets a block underside: the border takes
## the edge colour (a stylebox has only one border colour) and grows 4 px
## at the bottom.
static func _flat(
	bg: Color, radius: int, border_color: Color, border: int, margins: Vector4,
	edge: Color = Color.TRANSPARENT
) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	var has_edge: bool = edge.a > 0.0
	if border > 0 or has_edge:
		sb.set_border_width_all(maxi(border, 0))
		sb.border_color = edge if has_edge else border_color
		if has_edge:
			sb.border_width_bottom = maxi(border, 0) + BLOCK_LIP
	sb.content_margin_left = margins.x
	sb.content_margin_top = margins.y
	sb.content_margin_right = margins.z
	sb.content_margin_bottom = margins.w
	return sb



## The dialog card: cream, thick border, darker underside, soft shadow
static func _card_style(level: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = _flat(CARD, RADIUS, CARD_EDGE, 2, _margins(level, 24, 20, 24, 20), CARD_EDGE)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	return sb


## Blocky "X" for the close button of embedded windows, in one flat colour
static func _close_icon(size: int, color: Color) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var pad: int = maxi(1, size / 8)
	var half: int = maxi(1, size / 8)
	for y: int in range(pad, size - pad):
		for x: int in range(pad, size - pad):
			if mini(absi(x - y), absi(x - (size - 1 - y))) <= half:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


## A block face plus its darker underside, with press feedback: pressed
## drops the underside and moves the content down by the same amount.
## Returns [normal, hover, pressed, disabled, hover_pressed].
static func _block_set(level: int, top: Color, face: Color, edge: Color) -> Array[StyleBox]:
	var pad: float = float(_scaled(level, 16))
	var pad_v: float = float(_scaled(level, 9))
	var normal: StyleBoxFlat = _flat(top, RADIUS, Color.TRANSPARENT, 0, Vector4(pad, pad_v, pad, pad_v), edge)
	var hover: StyleBoxFlat = _flat(top.lightened(0.07), RADIUS, Color.TRANSPARENT, 0, Vector4(pad, pad_v, pad, pad_v), edge)
	var pressed: StyleBoxFlat = _flat(face, RADIUS, Color.TRANSPARENT, 0, Vector4(pad, pad_v + float(BLOCK_LIP), pad, pad_v))
	var disabled: StyleBoxFlat = _flat(DISABLED, RADIUS, Color.TRANSPARENT, 0, Vector4(pad, pad_v, pad, pad_v), NEUTRAL_EDGE)
	var hover_pressed: StyleBoxFlat = _flat(face.lightened(0.05), RADIUS, Color.TRANSPARENT, 0, Vector4(pad, pad_v + float(BLOCK_LIP), pad, pad_v))
	var out: Array[StyleBox] = [normal, hover, pressed, disabled, hover_pressed]
	return out


static func _focus_ring(level: int) -> StyleBoxFlat:
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_corner_radius_all(RADIUS)
	ring.set_border_width_all(2)
	ring.border_color = INK
	ring.set_expand_margin_all(float(_scaled(level, 3)))
	return ring


static func _apply_button(
	t: Theme, type_name: String, set: Array[StyleBox], focus: StyleBoxFlat,
	font: Font, level: int, text: Color, text_disabled: Color
) -> void:
	t.set_stylebox("normal", type_name, set[0])
	t.set_stylebox("hover", type_name, set[1])
	t.set_stylebox("pressed", type_name, set[2])
	t.set_stylebox("hover_pressed", type_name, set[4])
	t.set_stylebox("disabled", type_name, set[3])
	t.set_stylebox("focus", type_name, focus)
	t.set_font("font", type_name, font)
	t.set_font_size("font_size", type_name, _scaled(level, SIZE_BUTTON))
	t.set_color("font_color", type_name, text)
	t.set_color("font_hover_color", type_name, text)
	t.set_color("font_pressed_color", type_name, text)
	t.set_color("font_hover_pressed_color", type_name, text)
	t.set_color("font_focus_color", type_name, text)
	t.set_color("font_disabled_color", type_name, text_disabled)


static func _grabber(level: int, vertical: bool, color: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(3)
	var thin: float = 3.0
	var long: float = float(_scaled(level, 10))
	sb.content_margin_left = thin if vertical else long
	sb.content_margin_right = thin if vertical else long
	sb.content_margin_top = long if vertical else thin
	sb.content_margin_bottom = long if vertical else thin
	return sb


# =========================================================================
# Styleboxes for code-built controls (toasts, HUD chips)
# =========================================================================

## Dark toast sliding over the world: coloured bar on the left, readable
## whatever is behind it.
func toast_stylebox(accent: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = _flat(Color(INK, 0.94), RADIUS, Color.TRANSPARENT, 0, _margins(_level, 16, 8, 16, 8))
	sb.border_width_left = 5
	sb.border_color = accent
	return sb


## Light HUD chip with a coloured border (e.g. walk/build mode)
func hud_chip_style(accent: Color) -> StyleBoxFlat:
	return _flat(Color(CARD, 0.92), RADIUS, accent, 2, _margins(_level, 12, 6, 12, 6), accent.darkened(0.25))
