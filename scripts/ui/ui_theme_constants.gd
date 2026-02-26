extends RefCounted
class_name UIThemeConstants

## UI Theme Constants
##
## Centralized styling constants for consistent UI appearance.
## Use these instead of hardcoded values in UI scripts.

# --- Colors ---

## Panel backgrounds
const PANEL_BG_COLOR := Color(0.1, 0.1, 0.15, 0.9)
const PANEL_BG_COLOR_LIGHT := Color(0.15, 0.15, 0.2, 0.9)
const PANEL_BG_COLOR_DARK := Color(0.08, 0.08, 0.12, 0.95)

## Achievement/Unlock states
const UNLOCKED_BG_COLOR := Color(0.2, 0.35, 0.25, 0.9)
const LOCKED_BG_COLOR := Color(0.15, 0.15, 0.2, 0.7)

## Feedback colors
const COLOR_SUCCESS := Color(0.3, 0.8, 0.4)
const COLOR_ERROR := Color(0.8, 0.4, 0.3)
const COLOR_WARNING := Color(0.9, 0.7, 0.2)
const COLOR_INFO := Color(0.4, 0.6, 0.9)
const COLOR_GOLD := Color(1.0, 0.85, 0.3)

## Text colors
const TEXT_COLOR_DEFAULT := Color.WHITE
const TEXT_COLOR_MUTED := Color(0.6, 0.6, 0.6)
const TEXT_COLOR_DISABLED := Color(0.5, 0.5, 0.5)

## Shadow
const SHADOW_COLOR := Color(0, 0, 0, 0.8)


# --- Dimensions ---

## Corner radius
const CORNER_RADIUS_SMALL := 4
const CORNER_RADIUS_MEDIUM := 8
const CORNER_RADIUS_LARGE := 12

## Content margins
const MARGIN_SMALL := 8
const MARGIN_MEDIUM := 16
const MARGIN_LARGE := 24

## Border widths
const BORDER_WIDTH_THIN := 1
const BORDER_WIDTH_MEDIUM := 2
const BORDER_WIDTH_THICK := 3

## Button sizes
const BUTTON_SIZE_SMALL := Vector2(40, 40)
const BUTTON_SIZE_MEDIUM := Vector2(70, 35)
const BUTTON_SIZE_LARGE := Vector2(100, 40)

## Font sizes
const FONT_SIZE_SMALL := 11
const FONT_SIZE_NORMAL := 14
const FONT_SIZE_LARGE := 18
const FONT_SIZE_TITLE := 22
const FONT_SIZE_ICON := 32


# --- Animation Timings ---

const FADE_DURATION_FAST := 0.15
const FADE_DURATION_NORMAL := 0.25
const FADE_DURATION_SLOW := 0.4

const TOAST_DURATION := 2.5
const HINT_PULSE_DURATION := 1.0


# --- StyleBox Factory Functions ---

## Create a standard panel stylebox
static func create_panel_style(
	bg_color: Color = PANEL_BG_COLOR,
	corner_radius: int = CORNER_RADIUS_MEDIUM,
	content_margin: int = MARGIN_MEDIUM
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	return style


## Create a bordered panel stylebox
static func create_bordered_panel_style(
	bg_color: Color = PANEL_BG_COLOR,
	border_color: Color = COLOR_INFO,
	border_width: int = BORDER_WIDTH_THICK
) -> StyleBoxFlat:
	var style := create_panel_style(bg_color)
	style.border_width_left = border_width
	style.border_color = border_color
	return style


## Create a color button stylebox (for color pickers)
static func create_color_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = CORNER_RADIUS_SMALL + 2
	style.corner_radius_top_right = CORNER_RADIUS_SMALL + 2
	style.corner_radius_bottom_left = CORNER_RADIUS_SMALL + 2
	style.corner_radius_bottom_right = CORNER_RADIUS_SMALL + 2
	style.border_width_bottom = BORDER_WIDTH_MEDIUM
	style.border_width_top = BORDER_WIDTH_MEDIUM
	style.border_width_left = BORDER_WIDTH_MEDIUM
	style.border_width_right = BORDER_WIDTH_MEDIUM
	style.border_color = color.darkened(0.3)
	return style
