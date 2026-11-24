class_name PlanetPicker
extends PanelContainer

## Opened by clicking the clock in the HUD: one colored ball per planet
## from PlanetCatalog. Choosing a ball retunes the day/night cycle (day
## length + sun intensity). Built entirely in code - no .tscn needed.

signal planet_selected(planet: Dictionary)

const BALL_SIZE: float = 78.0

var _day_night: DayNightCycle = null
var _selected_key: String = "earth"
var _ball_buttons: Dictionary = {} ## planet key -> Button


func _ready() -> void:
	visible = false
	_build()


func open(day_night: DayNightCycle) -> void:
	_day_night = day_night
	visible = true


func _build() -> void:
	# A compact theme card - no stylebox of its own
	custom_minimum_size = Vector2(660.0 * UITheme.scale_factor(), 0.0)
	theme_type_variation = &"CardPanel"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.px(12))
	add_child(vbox)

	var title := Label.new()
	title.text = "🪐 Wähle deinen Planeten!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"MenuSubtitle"
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.px(20))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)
	for p: Dictionary in PlanetCatalog.PLANETS:
		row.add_child(_make_card(p))

	var close := Button.new()
	close.text = "Schließen"
	close.pressed.connect(hide)
	vbox.add_child(close)
	_refresh_balls()


func _make_card(p: Dictionary) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	card.alignment = BoxContainer.ALIGNMENT_CENTER

	var ball := Button.new()
	ball.custom_minimum_size = Vector2(BALL_SIZE, BALL_SIZE) * UITheme.scale_factor()
	ball.tooltip_text = "%s: Tag = %d Minuten" % [p["name"], int(p["day_minutes"])]
	ball.pressed.connect(_on_ball_pressed.bind(p))
	_ball_buttons[p["key"]] = ball
	card.add_child(ball)

	var name_label := Label.new()
	name_label.text = p["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.theme_type_variation = &"CardTitle"
	card.add_child(name_label)

	var day_label := Label.new()
	day_label.text = "Tag: %d Min" % int(p["day_minutes"])
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.theme_type_variation = &"CaptionLabel"
	card.add_child(day_label)

	var suns: int = maxi(1, int(round(float(p["sun_intensity"]) / 0.4)))
	var sun_label := Label.new()
	sun_label.text = "☀️".repeat(suns)
	sun_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(sun_label)
	return card


func _on_ball_pressed(p: Dictionary) -> void:
	_selected_key = p["key"]
	if _day_night:
		_day_night.apply_planet(p)
	planet_selected.emit(p)
	_refresh_balls()


## Round styleboxes with the planet color; the selected ball gets a
## dark ring (a white one vanished on the cream card)
func _refresh_balls() -> void:
	for key: String in _ball_buttons:
		var planet: Dictionary = PlanetCatalog.by_key(key)
		var button: Button = _ball_buttons[key]
		var sb := StyleBoxFlat.new()
		sb.bg_color = planet["color"]
		sb.set_corner_radius_all(int(BALL_SIZE * 0.5))
		if key == _selected_key:
			sb.set_border_width_all(6)
			sb.border_color = UITheme.INK
		else:
			sb.set_border_width_all(4)
			sb.border_color = (planet["color"] as Color).darkened(0.45)
		button.add_theme_stylebox_override("normal", sb)

		var hover := sb.duplicate() as StyleBoxFlat
		hover.bg_color = (planet["color"] as Color).lightened(0.18)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
