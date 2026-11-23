class_name WeatherManager
extends Node3D

## Occasional rain showers. A small state machine alternates long dry
## stretches with short rain episodes ("gelegentlich Regen"):
## - rain renders as falling streak particles (GPUParticles3D) in a box
##   around the camera rig, so it only exists where the player looks
## - the DayNightCycle gets dimmed via weather_dim (sun, ambient and a
##   gray tint on the sky), fading smoothly in and out with the rain
## - weather_changed fires on every transition; main.gd shows the HUD
##   toast ("Es regnet!" / sunshine is back)

signal weather_changed(raining: bool)

enum State { SUNNY, RAINING }

const RAIN_PARTICLE_COUNT: int = 700
const RAIN_AREA: float = 30.0 ## half-extent of the rain box around the camera
const RAIN_FALL_HEIGHT: float = 16.0 ## emission height above the manager
const RAIN_FADE: float = 5.0 ## seconds for rain_amount to ramp 0 <-> 1
const RAIN_DIM: float = 0.55 ## sun/ambient factor at full rain
const FIRST_RAIN_MIN: float = 75.0 ## first shower arrives after 75-180 s
const FIRST_RAIN_MAX: float = 180.0
const DRY_GAP_MIN: float = 150.0 ## gaps between later showers
const DRY_GAP_MAX: float = 420.0
const RAIN_DURATION_MIN: float = 35.0
const RAIN_DURATION_MAX: float = 80.0

## 0 = bone dry, 1 = full shower (drives particles + light dim)
var rain_amount: float = 0.0

var _state: int = State.SUNNY
var _dry_left: float = 0.0
var _rain_left: float = 0.0
var _follow: Node3D = null
var _rng := RandomNumberGenerator.new()
var _day_night: DayNightCycle = null
var _rain_particles: GPUParticles3D = null


func _ready() -> void:
	_rng.randomize()
	_dry_left = _rng.randf_range(FIRST_RAIN_MIN, FIRST_RAIN_MAX)
	_build_rain_particles()


func initialize(follow: Node3D) -> void:
	_follow = follow


func _process(delta: float) -> void:
	# Weather state machine
	match _state:
		State.SUNNY:
			_dry_left -= delta
			if _dry_left <= 0.0:
				_state = State.RAINING
				_rain_left = _rng.randf_range(RAIN_DURATION_MIN, RAIN_DURATION_MAX)
				weather_changed.emit(true)
		State.RAINING:
			_rain_left -= delta
			if _rain_left <= 0.0:
				_state = State.SUNNY
				_dry_left = _rng.randf_range(DRY_GAP_MIN, DRY_GAP_MAX)
				weather_changed.emit(false)

	# Smooth rain intensity
	var target: float = 1.0 if _state == State.RAINING else 0.0
	rain_amount = move_toward(rain_amount, target, delta / RAIN_FADE)

	_update_particles()
	_update_position(delta)
	_update_lighting()


func _update_particles() -> void:
	if _rain_particles == null:
		return
	var active: bool = rain_amount > 0.02
	_rain_particles.emitting = active
	if active:
		_rain_particles.amount = clampi(int(float(RAIN_PARTICLE_COUNT) * rain_amount), 1, RAIN_PARTICLE_COUNT)


## Keep the rain box centered on the camera rig (only where the player is)
func _update_position(delta: float) -> void:
	if _follow == null or not is_instance_valid(_follow):
		return
	position.x = lerpf(position.x, _follow.global_position.x, delta * 3.0)
	position.z = lerpf(position.z, _follow.global_position.z, delta * 3.0)


## Dim sun + ambient while it rains (DayNightCycle multiplies this in
## every frame alongside its planet sun_intensity)
func _update_lighting() -> void:
	if _day_night == null and get_tree().current_scene:
		_day_night = get_tree().current_scene.get_node_or_null("DayNightCycle") as DayNightCycle
	if _day_night:
		_day_night.weather_dim = lerpf(1.0, RAIN_DIM, rain_amount)


## Falling streak particles: thin translucent boxes dropping from
## RAIN_FALL_HEIGHT across a RAIN_AREA box, lifetime tuned so they die
## right around ground level.
func _build_rain_particles() -> void:
	_rain_particles = GPUParticles3D.new()
	_rain_particles.name = "RainParticles"
	_rain_particles.position.y = RAIN_FALL_HEIGHT
	_rain_particles.amount = RAIN_PARTICLE_COUNT
	_rain_particles.lifetime = 1.2
	_rain_particles.explosiveness = 0.0
	_rain_particles.randomness = 1.0
	_rain_particles.emitting = false
	_rain_particles.visibility_aabb = AABB(
		Vector3(-RAIN_AREA - 2.0, -RAIN_FALL_HEIGHT - 6.0, -RAIN_AREA - 2.0),
		Vector3(2.0 * RAIN_AREA + 4.0, RAIN_FALL_HEIGHT + 8.0, 2.0 * RAIN_AREA + 4.0)
	)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 4.0
	mat.initial_velocity_min = 16.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3(0.0, -3.0, 0.0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(RAIN_AREA, 0.4, RAIN_AREA)
	_rain_particles.process_material = mat

	var drop := BoxMesh.new()
	drop.size = Vector3(0.03, 0.4, 0.03)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.albedo_color = Color(0.62, 0.72, 0.85, 0.45)
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_mat
	_rain_particles.draw_pass_1 = drop

	add_child(_rain_particles)
