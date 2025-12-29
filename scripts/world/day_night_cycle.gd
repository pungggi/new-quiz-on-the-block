extends Node3D
class_name DayNightCycle

## Day/Night Cycle Controller
## Controls sun position, sky colors, and ambient lighting

signal time_changed(hour: float)
signal day_phase_changed(phase: DayPhase)

enum DayPhase {DAWN, DAY, DUSK, NIGHT}

## Time settings
@export var day_duration_minutes: float = 10.0 ## Real minutes for a full day
@export var start_hour: float = 8.0 ## Starting hour (0-24)

## References (set in _ready)
var _sun: DirectionalLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial

## Current time (0-24 hours)
var current_hour: float = 8.0
var current_phase: DayPhase = DayPhase.DAY

## Sky color presets
const SKY_COLORS := {
	DayPhase.DAWN: {
		"top": Color(0.4, 0.35, 0.55),
		"horizon": Color(1.0, 0.6, 0.4),
		"ground": Color(0.3, 0.25, 0.35),
		"ambient": Color(0.7, 0.5, 0.4),
		"sun_color": Color(1.0, 0.7, 0.5),
		"sun_energy": 0.6,
		"ambient_energy": 0.2,
	},
	DayPhase.DAY: {
		"top": Color(0.25, 0.45, 0.85),
		"horizon": Color(0.55, 0.7, 0.9),
		"ground": Color(0.4, 0.55, 0.75),
		"ambient": Color(0.7, 0.75, 0.8),
		"sun_color": Color(1.0, 0.98, 0.95),
		"sun_energy": 1.0,
		"ambient_energy": 0.3,
	},
	DayPhase.DUSK: {
		"top": Color(0.25, 0.2, 0.4),
		"horizon": Color(1.0, 0.45, 0.3),
		"ground": Color(0.25, 0.15, 0.25),
		"ambient": Color(0.8, 0.5, 0.35),
		"sun_color": Color(1.0, 0.5, 0.3),
		"sun_energy": 0.5,
		"ambient_energy": 0.15,
	},
	DayPhase.NIGHT: {
		"top": Color(0.05, 0.05, 0.12),
		"horizon": Color(0.1, 0.1, 0.2),
		"ground": Color(0.05, 0.05, 0.1),
		"ambient": Color(0.15, 0.18, 0.25),
		"sun_color": Color(0.4, 0.5, 0.7),
		"sun_energy": 0.15,
		"ambient_energy": 0.1,
	},
}


func _ready() -> void:
	current_hour = start_hour
	
	# Find sun and environment in parent scene
	_sun = get_parent().get_node_or_null("DirectionalLight3D")
	var world_env: WorldEnvironment = get_parent().get_node_or_null("WorldEnvironment")
	if world_env:
		_environment = world_env.environment
		if _environment and _environment.sky:
			_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial
	
	_update_visuals()


func _process(delta: float) -> void:
	# Calculate time progression
	var hours_per_second := 24.0 / (day_duration_minutes * 60.0)
	current_hour += hours_per_second * delta
	
	if current_hour >= 24.0:
		current_hour -= 24.0
	
	# Update sun position and colors
	_update_visuals()
	
	# Check phase change
	var new_phase := _get_phase_for_hour(current_hour)
	if new_phase != current_phase:
		current_phase = new_phase
		day_phase_changed.emit(current_phase)
	
	time_changed.emit(current_hour)


func _update_visuals() -> void:
	_update_sun_position()
	_update_sky_colors()


func _update_sun_position() -> void:
	if not _sun:
		return
	
	# Sun angle based on time (0h = midnight, 12h = noon)
	var sun_angle := (current_hour - 6.0) * 15.0 # 15 degrees per hour
	var sun_pitch := deg_to_rad(-sun_angle)
	var sun_yaw := deg_to_rad(-30.0) # Slight angle for nicer shadows
	
	_sun.rotation = Vector3(sun_pitch, sun_yaw, 0)


func _update_sky_colors() -> void:
	var phase := _get_phase_for_hour(current_hour)
	var next_phase := _get_next_phase(phase)
	var blend := _get_phase_blend(current_hour, phase)
	
	var current_colors: Dictionary = SKY_COLORS[phase]
	var next_colors: Dictionary = SKY_COLORS[next_phase]
	
	# Interpolate colors
	if _sky_material:
		_sky_material.sky_top_color = current_colors["top"].lerp(next_colors["top"], blend)
		_sky_material.sky_horizon_color = current_colors["horizon"].lerp(next_colors["horizon"], blend)
		_sky_material.ground_bottom_color = current_colors["ground"].lerp(next_colors["ground"], blend)
		_sky_material.ground_horizon_color = current_colors["horizon"].lerp(next_colors["horizon"], blend)
	
	if _environment:
		_environment.ambient_light_color = current_colors["ambient"].lerp(next_colors["ambient"], blend)
		_environment.ambient_light_energy = lerpf(current_colors["ambient_energy"], next_colors["ambient_energy"], blend)
	
	if _sun:
		_sun.light_color = current_colors["sun_color"].lerp(next_colors["sun_color"], blend)
		_sun.light_energy = lerpf(current_colors["sun_energy"], next_colors["sun_energy"], blend)


func _get_phase_for_hour(hour: float) -> DayPhase:
	if hour >= 5.0 and hour < 7.0:
		return DayPhase.DAWN
	elif hour >= 7.0 and hour < 18.0:
		return DayPhase.DAY
	elif hour >= 18.0 and hour < 20.0:
		return DayPhase.DUSK
	else:
		return DayPhase.NIGHT


func _get_next_phase(phase: DayPhase) -> DayPhase:
	match phase:
		DayPhase.DAWN: return DayPhase.DAY
		DayPhase.DAY: return DayPhase.DUSK
		DayPhase.DUSK: return DayPhase.NIGHT
		DayPhase.NIGHT: return DayPhase.DAWN
	return DayPhase.DAY


func _get_phase_blend(hour: float, phase: DayPhase) -> float:
	## Returns 0-1 blend towards next phase
	match phase:
		DayPhase.DAWN:
			return (hour - 5.0) / 2.0 # 5-7
		DayPhase.DAY:
			if hour < 16.0:
				return 0.0
			return (hour - 16.0) / 2.0 # Start blending at 16:00
		DayPhase.DUSK:
			return (hour - 18.0) / 2.0 # 18-20
		DayPhase.NIGHT:
			if hour >= 20.0:
				return (hour - 20.0) / 9.0 # 20-5 (next day)
			else:
				return (hour + 4.0) / 9.0 # 0-5 = 4-9
	return 0.0


## Get formatted time string
func get_time_string() -> String:
	var hours := int(current_hour)
	var minutes := int((current_hour - hours) * 60)
	return "%02d:%02d" % [hours, minutes]


## Get phase name in German
func get_phase_name() -> String:
	match current_phase:
		DayPhase.DAWN: return "Morgen"
		DayPhase.DAY: return "Tag"
		DayPhase.DUSK: return "Abend"
		DayPhase.NIGHT: return "Nacht"
	return "Tag"


## Set time immediately
func set_time(hour: float) -> void:
	current_hour = fmod(hour, 24.0)
	if current_hour < 0:
		current_hour += 24.0
	_update_visuals()
	current_phase = _get_phase_for_hour(current_hour)
	day_phase_changed.emit(current_phase)
	time_changed.emit(current_hour)
