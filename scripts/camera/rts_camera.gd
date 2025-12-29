extends Node3D

## RTS Camera Controller
##
## Controls a strategy camera with pan, rotate, zoom, and edge-pan.
## Supports two modes: BUILD (free camera) and WALK (follows player).
##
## Camera Rig Structure:
## - CameraRig (this script)
##   - YawPivot (Node3D) - handles Y rotation
##     - PitchPivot (Node3D) - handles X/pitch rotation
##       - SpringArm3D - handles zoom distance
##         - Camera3D - actual camera

signal camera_moved(global_position: Vector3)

# Pan settings
@export var pan_speed: float = 20.0
@export var edge_pan_enabled: bool = false # Disabled - keyboard only
@export var edge_pan_margin: float = 20.0 # pixels from edge
@export var edge_pan_speed: float = 15.0

# Rotation settings
@export var rotation_speed: float = 90.0 # degrees per second
@export var pitch_degrees: float = -45.0 # initial pitch angle (negative looks down)
@export var min_pitch: float = -80.0 # max looking down
@export var max_pitch: float = -15.0 # max looking up (still angled down for RTS)

# Zoom settings
@export var min_zoom: float = 5.0
@export var max_zoom: float = 50.0
@export var zoom_speed: float = 10.0 # units per second

# World bounds (optional)
@export var use_world_bounds: bool = false
@export var world_min_x: float = -100.0
@export var world_max_x: float = 100.0
@export var world_min_z: float = -100.0
@export var world_max_z: float = 100.0

# Movement signal threshold
@export var movement_signal_threshold: float = 1.0 # emit signal after moving this much

# Node references
var yaw_pivot: Node3D
var pitch_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D

# Mouse drag settings
@export var mouse_pan_sensitivity: float = 0.08
@export var mouse_rotate_sensitivity: float = 0.15

# Internal state
var _viewport: Viewport
var _last_global_position: Vector3 = Vector3.ZERO
var _accumulated_movement: float = 0.0
var _yaw_rotation: float = 0.0 # Track Y rotation separately

# Mouse drag state
var _is_dragging_pan: bool = false
var _is_dragging_rotate: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO

# Third-person follow settings
@export var follow_lerp_speed: float = 5.0
@export var follow_distance: float = 12.0
@export var follow_height_offset: float = 0.0

# GameMode reference
var _game_mode: Node

func _ready() -> void:
	_viewport = get_viewport()

	# Wait for scene tree to be fully ready
	await get_tree().process_frame
	await get_tree().process_frame # Extra frame for transform stability

	# Find child nodes by name
	yaw_pivot = find_child("YawPivot", true, false)
	if yaw_pivot:
		pitch_pivot = yaw_pivot.find_child("PitchPivot", true, false)
		if pitch_pivot:
			spring_arm = pitch_pivot.find_child("SpringArm3D", true, false)
			if spring_arm:
				camera = spring_arm.find_child("Camera3D", true, false)

	# Validate nodes
	if not yaw_pivot or not pitch_pivot or not spring_arm or not camera:
		push_error("RTS Camera: Could not find required child nodes. Expected structure: CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D")
		return

	# Set initial pitch
	pitch_pivot.rotation_degrees.x = pitch_degrees

	# Make camera current
	camera.make_current()

	# Disable collision on spring arm for pure zoom control
	spring_arm.collision_mask = 0

	# Store initial position
	_last_global_position = global_position
	_yaw_rotation = yaw_pivot.rotation.y

	# Force transform update to avoid invert warnings
	force_update_transform()

	# Get GameMode reference
	_game_mode = get_node_or_null("/root/GameMode")

func _process(delta: float) -> void:
	if not _viewport or not yaw_pivot:
		return

	# Check if we should follow the player (WALK mode)
	if _game_mode and _game_mode.is_walk_mode():
		_follow_player(delta)
	else:
		# BUILD mode - free camera controls
		_handle_pan(delta)
		_handle_edge_pan(delta)

	# These work in both modes
	_handle_rotation(delta)
	_handle_zoom(delta)

	# Clamp to world bounds if enabled
	if use_world_bounds:
		_clamp_to_world_bounds()

	# Emit movement signal if threshold exceeded
	_check_movement_threshold()


func _follow_player(delta: float) -> void:
	if not _game_mode or not _game_mode.player:
		return

	var player: Node3D = _game_mode.player
	var target_pos := player.global_position
	target_pos.y += follow_height_offset

	# Smoothly follow the player
	global_position = global_position.lerp(target_pos, follow_lerp_speed * delta)

func _input(event: InputEvent) -> void:
	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by_delta(-zoom_speed * 0.5)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by_delta(zoom_speed * 0.5)
		# Middle mouse button - pan
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging_pan = mouse_event.pressed
			_last_mouse_position = mouse_event.position
		# Right mouse button - rotate
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging_rotate = mouse_event.pressed
			_last_mouse_position = mouse_event.position

	# Handle mouse motion for dragging
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion

		if _is_dragging_pan:
			_handle_mouse_pan(motion_event.relative)

		if _is_dragging_rotate:
			_handle_mouse_rotate(motion_event.relative)

func _handle_mouse_pan(relative: Vector2) -> void:
	# Pan camera based on mouse movement
	var yaw_rad := _yaw_rotation
	var forward := Vector3.FORWARD.rotated(Vector3.UP, yaw_rad)
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw_rad)

	# Invert for intuitive dragging (drag right = camera moves left)
	var movement := (-right * relative.x - forward * relative.y) * mouse_pan_sensitivity
	global_position += movement

func _handle_mouse_rotate(relative: Vector2) -> void:
	# Rotate camera yaw based on horizontal mouse movement
	if yaw_pivot:
		var rotation_delta := -relative.x * mouse_rotate_sensitivity * 0.01
		_yaw_rotation += rotation_delta
		_yaw_rotation = wrapf(_yaw_rotation, 0.0, TAU)
		yaw_pivot.rotation.y = _yaw_rotation

	# Adjust pitch based on vertical mouse movement
	if pitch_pivot:
		var pitch_delta := relative.y * mouse_rotate_sensitivity * 0.5
		pitch_degrees = clampf(pitch_degrees + pitch_delta, min_pitch, max_pitch)
		pitch_pivot.rotation_degrees.x = pitch_degrees

func _handle_pan(delta: float) -> void:
	# Get pan input vector (WASD or arrow keys)
	var pan_vector := Vector2.ZERO
	
	if Input.is_action_pressed(&"camera_pan_up"):
		pan_vector.y += 1.0
	if Input.is_action_pressed(&"camera_pan_down"):
		pan_vector.y -= 1.0
	if Input.is_action_pressed(&"camera_pan_left"):
		pan_vector.x -= 1.0
	if Input.is_action_pressed(&"camera_pan_right"):
		pan_vector.x += 1.0
	
	# Normalize diagonal movement
	if pan_vector.length_squared() > 0.0:
		pan_vector = pan_vector.normalized()
	
	# Apply pan in world space (XZ plane)
	# Pan direction is relative to camera's Y rotation
	var yaw_rad := _yaw_rotation
	var forward := Vector3.FORWARD.rotated(Vector3.UP, yaw_rad)
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw_rad)
	
	var movement := (forward * pan_vector.y + right * pan_vector.x) * pan_speed * delta
	global_position += movement

func _handle_rotation(delta: float) -> void:
	var rotation_input := 0.0
	
	if Input.is_action_pressed(&"camera_rotate_left"):
		rotation_input -= 1.0
	if Input.is_action_pressed(&"camera_rotate_right"):
		rotation_input += 1.0
	
	if rotation_input != 0.0 and yaw_pivot:
		var rotation_delta := deg_to_rad(rotation_speed) * rotation_input * delta
		_yaw_rotation += rotation_delta
		_yaw_rotation = wrapf(_yaw_rotation, 0.0, TAU)
		yaw_pivot.rotation.y = _yaw_rotation

func _handle_zoom(delta: float) -> void:
	# Zoom via spring arm length
	var zoom_input := 0.0
	
	if Input.is_action_pressed(&"camera_zoom_in"):
		zoom_input -= 1.0
	if Input.is_action_pressed(&"camera_zoom_out"):
		zoom_input += 1.0
	
	if zoom_input != 0.0:
		_zoom_by_delta(zoom_input * zoom_speed * delta)

func _zoom_by_delta(delta: float) -> void:
	if not spring_arm:
		return
	spring_arm.spring_length = clampf(
		spring_arm.spring_length + delta,
		min_zoom,
		max_zoom
	)

func _handle_edge_pan(delta: float) -> void:
	if not edge_pan_enabled or not _viewport:
		return

	var mouse_pos := _viewport.get_mouse_position()
	var viewport_size := _viewport.get_visible_rect().size

	# Don't edge pan if mouse is outside window
	if mouse_pos.x < 0 or mouse_pos.x > viewport_size.x:
		return
	if mouse_pos.y < 0 or mouse_pos.y > viewport_size.y:
		return

	var edge_pan_vector := Vector2.ZERO

	# Check left edge
	if mouse_pos.x < edge_pan_margin:
		edge_pan_vector.x -= 1.0
	# Check right edge
	elif mouse_pos.x > viewport_size.x - edge_pan_margin:
		edge_pan_vector.x += 1.0

	# Check top edge
	if mouse_pos.y < edge_pan_margin:
		edge_pan_vector.y -= 1.0
	# Check bottom edge
	elif mouse_pos.y > viewport_size.y - edge_pan_margin:
		edge_pan_vector.y += 1.0

	# Normalize if any edge is active
	if edge_pan_vector.length_squared() > 0.0:
		edge_pan_vector = edge_pan_vector.normalized()

		# Apply edge pan in world space
		var yaw_rad := _yaw_rotation
		var forward := Vector3.FORWARD.rotated(Vector3.UP, yaw_rad)
		var right := Vector3.RIGHT.rotated(Vector3.UP, yaw_rad)

		var movement := (forward * edge_pan_vector.y + right * edge_pan_vector.x) * edge_pan_speed * delta
		global_position += movement

func _clamp_to_world_bounds() -> void:
	var pos := global_position
	pos.x = clampf(pos.x, world_min_x, world_max_x)
	pos.z = clampf(pos.z, world_min_z, world_max_z)
	global_position = pos

func _check_movement_threshold() -> void:
	var distance := global_position.distance_to(_last_global_position)
	_accumulated_movement += distance

	if _accumulated_movement >= movement_signal_threshold:
		camera_moved.emit(global_position)
		_accumulated_movement = 0.0

	_last_global_position = global_position

## Smoothly pan camera towards a world position (horizontal)
func look_towards(target_pos: Vector3, lerp_speed: float = 3.0) -> void:
	var direction: Vector3 = target_pos - global_position
	direction.y = 0 # Only horizontal direction

	if direction.length_squared() < 0.01:
		return

	# Calculate target yaw angle
	var target_yaw: float = atan2(direction.x, direction.z)

	# Smoothly interpolate current yaw towards target
	var delta: float = get_process_delta_time()
	_yaw_rotation = lerp_angle(_yaw_rotation, target_yaw, lerp_speed * delta)

	if yaw_pivot:
		yaw_pivot.rotation.y = _yaw_rotation

## Smoothly adjust pitch to look at a certain height
func look_up_towards(target_height: float, lerp_speed: float = 2.0) -> void:
	if not pitch_pivot:
		return

	# Calculate desired pitch based on height difference
	# Higher target = look more up (less negative pitch)
	var height_diff: float = target_height - global_position.y

	# Map height to pitch adjustment (subtle effect)
	# Each block higher = ~3 degrees less negative pitch
	var target_pitch: float = pitch_degrees + (height_diff * 3.0)
	target_pitch = clampf(target_pitch, min_pitch, max_pitch)

	# Smoothly interpolate
	var delta: float = get_process_delta_time()
	pitch_degrees = lerpf(pitch_degrees, target_pitch, lerp_speed * delta)
	pitch_pivot.rotation_degrees.x = pitch_degrees
