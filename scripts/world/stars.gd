class_name Stars
extends MeshInstance3D

## Starry night sky: a huge inward-facing sphere with a generated
## starfield texture, centered on the world. The texture fades in at
## dusk (19:30-21:00), glows all night and fades out with the pre-dawn
## glow (03:30-05:00); rain clouds hide the stars via the DayNightCycle
## weather_dim. The dome rotates very slowly for a bit of life.

const STAR_COUNT: int = 380
const DOME_RADIUS: float = 480.0
const POLE_BAND: int = 40 ## keep stars away from the stretched poles
const TEX_W: int = 1024
const TEX_H: int = 512

var _t: float = 0.0
var _day_night: DayNightCycle = null
var _mat: StandardMaterial3D = null


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = _generate_texture()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_FRONT ## we look at the inside
	material_override = _mat

	var dome := SphereMesh.new()
	dome.radius = DOME_RADIUS
	dome.height = DOME_RADIUS * 2.0
	dome.radial_segments = 48
	dome.rings = 24
	mesh = dome

	# Cover the whole playable world from any corner
	position = Vector3(
		(float(Config.WORLD_MIN_BLOCK) + float(Config.WORLD_MAX_BLOCK)) * 0.5,
		0.0,
		(float(Config.WORLD_MIN_BLOCK) + float(Config.WORLD_MAX_BLOCK)) * 0.5
	)


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 0.004
	if _day_night == null and get_tree().current_scene:
		_day_night = get_tree().current_scene.get_node_or_null("DayNightCycle") as DayNightCycle
	if _day_night == null:
		return
	var alpha: float = star_visibility(_day_night.current_hour)
	# Rain clouds swallow the stars (weather_dim 1 = clear sky)
	alpha *= clampf(_day_night.weather_dim, 0.0, 1.0)
	_mat.albedo_color = Color(1.0, 1.0, 1.0, alpha)


## 0 = no stars (day), 1 = full starry sky: fades in 19:30-21:00, full
## until 03:30, fades out 03:30-05:00 (mirrors the pre-dawn glow)
static func star_visibility(hour: float) -> float:
	if hour >= 21.0 or hour < 3.5:
		return 1.0
	if hour >= 19.5:
		return (hour - 19.5) / 1.5
	if hour < 5.0:
		return 1.0 - (hour - 3.5) / 1.5
	return 0.0


## Random starfield: mostly white, a few warm and cool tints, some
## doubled pixels for slightly bigger stars
static func _generate_texture() -> ImageTexture:
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i: int in range(STAR_COUNT):
		var px: int = rng.randi_range(0, TEX_W - 1)
		var py: int = rng.randi_range(POLE_BAND, TEX_H - 1 - POLE_BAND)
		var bright: float = rng.randf_range(0.4, 1.0)
		var c := Color(bright, bright, bright, 1.0)
		var tint: float = rng.randf()
		if tint < 0.12:
			c = Color(bright, bright * 0.9, bright * 0.75, 1.0) ## warm
		elif tint < 0.24:
			c = Color(bright * 0.75, bright * 0.85, bright, 1.0) ## cool blue
		img.set_pixel(px, py, c)
		if rng.randf() < 0.3:
			img.set_pixel(clampi(px + 1, 0, TEX_W - 1), py, Color(c.r, c.g, c.b, 0.6))
	return ImageTexture.create_from_image(img)
