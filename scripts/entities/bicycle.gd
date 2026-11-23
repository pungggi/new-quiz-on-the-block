class_name Bicycle
extends CharacterBody3D

## A rideable bicycle parked near the spawn lawn.
##
## Walk up, press E to mount: W/S pedal/brake, A/D steer, Space makes
## the bike hop (enough to clear hedge rows and bushes). The bike is a
## CharacterBody3D just like the player, so it rides the real terrain,
## rolls up the bridge ramps and stops at cliffs on its own. Deep water
## is refused with a splash hint so the bike never ends up on the sea
## bed. Dismount with E; the rider node is reparented onto the bike
## while riding, so the camera (which follows the player) comes along
## for free.

const MAX_SPEED: float = 9.0 ## top pedaling speed (walk = 5.0)
const ACCEL: float = 7.0
const BRAKE: float = 16.0
const DRAG: float = 5.0 ## coasting slowdown
const REVERSE_MAX: float = 2.0
const TURN_SLOW: float = 2.8 ## rad/s at standstill
const TURN_FAST: float = 2.4 ## rad/s at top speed (turning radius ~3.75 blocks at speed 9)
const LEAN_MAX: float = 0.16 ## visual lean into the curve
const HOP_VELOCITY: float = 6.5 ## clears the 0.75 hedges comfortably
const GRAVITY: float = 20.0
const WHEEL_RADIUS: float = 0.28

const PRICE: int = 50 ## one-time purchase price in education points (same currency as buildings)
const MOUNT_RANGE: float = 2.8
const BLOCK_WATER_DEPTH: int = 3 ## refuse to ride into water this deep
const HINT_COOLDOWN: float = 2.0

const RIDER_OFFSET: Vector3 = Vector3(0.0, 0.8, -0.05) ## standing on the pedals
const RIDER_LEAN: float = 0.1 ## slight forward lean while riding
const DISMOUNT_OFFSET: Vector3 = Vector3(-1.6, 0.25, 0.0) ## hop off to the left

var _speed: float = 0.0
var _steer: float = 0.0
var _jump_held: bool = false
var _air_time: float = 0.0
var _ramp_slope: float = 0.0 ## slope of the last ramp we were on (rise/run), kept briefly past the lip
var _ramp_fresh: float = 0.0 ## seconds the remembered slope stays valid
var _launched: bool = false ## ramp launch consumed for this airtime
var _hint_cooldown: float = 0.0
var _t: float = 0.0
var _rider: Node3D = null
var _unlocked: bool = false

var _tilt: Node3D = null
var _steer_pivot: Node3D = null
var _front_wheel: Node3D = null
var _rear_wheel: Node3D = null
var _prompt: Label3D = null
var _sign: Label3D = null

## Lights for the dark: headlight (spot) + tail light (omni) with
## glowing lamp meshes, switched by the day/night cycle
var _headlight: SpotLight3D = null
var _tail_light: OmniLight3D = null
var _headlamp_mesh: MeshInstance3D = null
var _taillamp_mesh: MeshInstance3D = null
var _day_night: DayNightCycle = null
var _lights_on: bool = false


func _ready() -> void:
	# Same collision family as the player: terrain, buildings, props,
	# bridge deck - so the bike rides up the bridge ramps by itself
	collision_layer = 1
	collision_mask = Config.TERRAIN_COLLISION_LAYER | Config.BUILDING_COLLISION_LAYER | Config.PROP_COLLISION_LAYER | Config.BRIDGE_COLLISION_LAYER
	platform_floor_layers = Config.TERRAIN_COLLISION_LAYER | Config.BRIDGE_COLLISION_LAYER

	# Capsule like the player's: round enough to slide UP the foot of a
	# ramp (a box collider catches on the vertical lip and stops dead)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.05
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.57, 0.0)
	add_child(shape)

	_build_bike()
	_build_lights()
	_build_prompt()
	_unlocked = ProfileManager.is_bike_unlocked()


func _unhandled_input(event: InputEvent) -> void:
	if not GameMode.is_walk_mode():
		return
	if event.is_action_pressed("interact"):
		if _rider:
			dismount()
			get_viewport().set_input_as_handled()
		elif _player_near():
			if _unlocked:
				mount(GameMode.player)
			else:
				try_buy()
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_t += delta
	_hint_cooldown -= delta

	# --- Gravity: zeroes the vertical velocity on the floor BEFORE the
	# controls run, so a hop set below survives into move_and_slide ---
	var was_on_floor: bool = is_on_floor()
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_air_time += delta
	else:
		# On the ground: the floor normal was captured right after the
		# previous move_and_slide (see below) - reading it here returns a
		# stale straight-up normal because Godot resets the floor state
		# before the next physics tick.
		velocity.y = 0.0

	# --- Controls (only while mounted) ---
	if _rider:
		var throttle: float = 0.0
		if Input.is_action_pressed("move_forward"):
			throttle += 1.0
		if Input.is_action_pressed("move_back"):
			throttle -= 1.0
		if throttle > 0.0:
			_speed = minf(_speed + ACCEL * delta, MAX_SPEED)
		elif throttle < 0.0:
			# Brakes first, then slow reverse
			_speed = maxf(_speed - BRAKE * delta, -REVERSE_MAX)
		else:
			# Coast down with drag
			var drag: float = DRAG * delta
			_speed = signf(_speed) * maxf(absf(_speed) - drag, 0.0)

		var steer_input: float = 0.0
		if Input.is_action_pressed("move_left"):
			steer_input += 1.0
		if Input.is_action_pressed("move_right"):
			steer_input -= 1.0
		_steer = lerpf(_steer, steer_input, delta * 10.0)

		# Turn rate fades with speed; half authority mid-air (fun, not
		# simulator)
		var speed_ratio: float = absf(_speed) / MAX_SPEED
		var turn_rate: float = lerpf(TURN_SLOW, TURN_FAST, speed_ratio)
		if not is_on_floor():
			turn_rate *= 0.5
		if absf(_speed) > 0.2:
			rotation.y += _steer * turn_rate * delta * signf(_speed)

		# Hop over hedges and bushes (own edge detection: is_action_pressed
		# also fires for synthetic test input, unlike just_pressed)
		var jump_now: bool = Input.is_action_pressed("jump")
		if is_on_floor() and jump_now and not _jump_held:
			velocity.y = HOP_VELOCITY
		_jump_held = jump_now

		var forward := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
		velocity.x = forward.x * _speed
		velocity.z = forward.z * _speed

		# Refuse deep water: probe a little ahead so the bike stops at
		# the shoreline instead of sinking to the sea bed
		var probe: Vector3 = global_position + forward * 1.5
		if _speed > 0.0 and WorldManager.water_depth(int(floor(probe.x)), int(floor(probe.z))) >= BLOCK_WATER_DEPTH:
			_speed = 0.0
			velocity.x = 0.0
			velocity.z = 0.0
			if _hint_cooldown <= 0.0:
				_hint_cooldown = HINT_COOLDOWN
				Effects.spawn_floating_text(global_position + Vector3.UP * 1.2, "🌊 Zu tief zum Fahren!", Color(0.55, 0.75, 1.0))

	move_and_slide()

	# Capture the floor normal NOW: Godot resets the floor state before
	# the next physics tick, so is_on_floor()/get_floor_normal() at the
	# top of _physics_process no longer reflect the ramp we're on.
	var fwd: Vector3 = Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	if is_on_floor():
		var n: Vector3 = get_floor_normal()
		var slope: float = 0.0 if n.y >= 0.999 else (sqrt(1.0 - n.y * n.y) / n.y)
		# Only an UPSLOPE ahead launches (the normal tilts back toward us)
		var s: float = slope if (slope > 0.02 and n.dot(fwd) < -0.05) else 0.0
		if s > 0.0:
			# Remember the slope briefly: the last grounded frame at the lip
			# can report a flat normal (snap onto the ramp box's top edge)
			_ramp_slope = s
			_ramp_fresh = 0.12

	# Just left the floor while on an upslope: launch with the ramp's
	# vertical component (kicker!). A hop (Space) already set velocity.y
	# higher, so only top up if the ramp would give more. The slope is
	# remembered from the last grounded frame, so a one-frame snap at
	# the lip doesn't lose the launch.
	if not is_on_floor() and _ramp_slope > 0.0 and not _launched:
		var launch: float = absf(_speed) * _ramp_slope
		velocity.y = maxf(velocity.y, launch)
		_launched = true
	_ramp_fresh -= delta
	if _ramp_fresh <= 0.0 and not is_on_floor():
		_ramp_slope = 0.0
	if is_on_floor():
		_launched = false

	# Landing puff after a real hop
	if was_on_floor == false and is_on_floor() and _air_time > 0.3:
		Effects.spawn_floating_text(global_position + Vector3.UP * 0.5, "💨", Color(0.9, 0.9, 0.9))
	_air_time = 0.0 if is_on_floor() else _air_time

	# Stay inside the world
	position.x = clampf(position.x, Config.WORLD_MIN_X, Config.WORLD_MAX_X)
	position.z = clampf(position.z, Config.WORLD_MIN_Z, Config.WORLD_MAX_Z)
	if position.y < 0.05:
		position.y = 0.05
		velocity.y = 0.0

	# --- Visuals: spinning wheels, steering bar, lean into curves ---
	var spin: float = _speed / WHEEL_RADIUS * delta
	if _front_wheel:
		_front_wheel.rotation.x += spin
	if _rear_wheel:
		_rear_wheel.rotation.x += spin
	if _steer_pivot:
		_steer_pivot.rotation.y = _steer * 0.35
	if _tilt:
		var ratio: float = clampf(absf(_speed) / MAX_SPEED, 0.0, 1.0)
		_tilt.rotation.z = -_steer * LEAN_MAX * ratio

	# --- Lights follow the day/night cycle (checked cheaply each frame) ---
	_update_lights()

	# --- Sign + prompt ---
	if _sign:
		_sign.visible = _rider == null
	if _prompt:
		if _rider:
			_prompt.text = "🚲 E: Absteigen"
			_prompt.visible = true
		elif _player_near():
			if _unlocked:
				_prompt.text = "🚲 E: Aufsteigen"
			else:
				_prompt.text = "🚲 E: Kaufen · %d 📚" % PRICE
			_prompt.visible = true
		else:
			_prompt.visible = false


func get_speed() -> float:
	return _speed


## Stop dead: zero speed, velocity and steering smoothing (used when
## the bike is parked by scripts/tests or placed somewhere)
func reset_motion() -> void:
	_speed = 0.0
	_steer = 0.0
	velocity = Vector3.ZERO
	_ramp_slope = 0.0
	_ramp_fresh = 0.0


func get_rider() -> Node3D:
	return _rider


func toggle_mount(rider: Node3D) -> void:
	if _rider:
		dismount()
	elif rider:
		mount(rider)


func is_unlocked() -> bool:
	return _unlocked


## One-time purchase: pays with education points (the quiz currency,
## same as buildings), unlocks permanently and hops right on. Not
## enough points gets a friendly hint naming the missing amount.
func try_buy() -> void:
	if _unlocked:
		return
	if ProfileManager.spend_points(PRICE):
		ProfileManager.set_bike_unlocked(true)
		_unlocked = true
		AudioManager.play_sfx(AudioManager.SFX.UNLOCK)
		Effects.spawn_confetti(global_position + Vector3.UP * 1.2)
		Effects.spawn_floating_text(global_position + Vector3.UP * 1.6, "🚲 Dein Fahrrad!", Color(1.0, 0.85, 0.3))
		mount(GameMode.player)
	elif _hint_cooldown <= 0.0:
		_hint_cooldown = HINT_COOLDOWN
		var missing: int = PRICE - ProfileManager.get_points()
		Effects.spawn_floating_text(global_position + Vector3.UP * 1.2, "🚲 Kostet %d 📚 - dir fehlen %d!" % [PRICE, missing], Color(1.0, 0.6, 0.55))


func mount(rider: Node3D) -> void:
	if _rider or rider == null or not _unlocked:
		return
	_rider = rider
	_speed = 0.0
	_steer = 0.0
	# Park any leftover motion so the bike doesn't drift while mounting
	velocity = Vector3.ZERO
	if _rider.has_method("set_riding"):
		_rider.set_riding(true)
	_rider.reparent(self, false)
	_rider.position = RIDER_OFFSET
	_rider.rotation = Vector3(RIDER_LEAN, 0.0, 0.0)
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)
	Effects.spawn_floating_text(global_position + Vector3.UP * 1.6, "🚴 Los geht's!", Color(1.0, 0.85, 0.3))


func dismount() -> void:
	if _rider == null:
		return
	_speed = 0.0
	velocity = Vector3.ZERO
	var rider: Node3D = _rider
	_rider = null
	rider.reparent(get_parent(), false)
	# Hop off to the left; if that lands in deep water take the right
	# side, else just drop next to the bike
	var left: Vector3 = global_position + global_transform.basis * DISMOUNT_OFFSET
	if WorldManager.water_depth(int(floor(left.x)), int(floor(left.z))) >= BLOCK_WATER_DEPTH:
		left = global_position + global_transform.basis * Vector3(1.6, 0.25, 0.0)
	rider.global_position = left
	rider.rotation = Vector3.ZERO
	if rider.has_method("set_riding"):
		rider.set_riding(false)
	AudioManager.play_sfx(AudioManager.SFX.BUTTON_CLICK)


func _player_near() -> bool:
	var player: Node3D = GameMode.player
	return player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < MOUNT_RANGE


## Blocky bike, faces +Z. Everything visual hangs under the "Tilt" node
## (lean into curves) with the front assembly on a steering pivot.
func _build_bike() -> void:
	_tilt = Node3D.new()
	_tilt.name = "Tilt"
	add_child(_tilt)

	var red: Color = Color(0.82, 0.25, 0.2)
	var dark: Color = Color(0.16, 0.16, 0.19)
	var metal: Color = Color(0.55, 0.55, 0.6)
	var brown: Color = Color(0.5, 0.35, 0.22)

	# Static frame: tubes, saddle, cranks and pedals
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Top tube (seat to head)
	SurfaceBoxes.add_box(st, Vector3(-0.05, 0.62, -0.28), Vector3(0.05, 0.7, 0.38), red)
	# Diagonal braces down to the crank
	SurfaceBoxes.add_box(st, Vector3(-0.05, 0.48, -0.08), Vector3(0.05, 0.62, 0.06), red)
	SurfaceBoxes.add_box(st, Vector3(-0.05, 0.44, 0.14), Vector3(0.05, 0.58, 0.3), red)
	# Chain stays out to the rear axle
	SurfaceBoxes.add_box(st, Vector3(-0.04, 0.26, -0.45), Vector3(0.04, 0.34, -0.05), red)
	# Seat post + saddle
	SurfaceBoxes.add_box(st, Vector3(-0.04, 0.7, -0.34), Vector3(0.04, 0.82, -0.24), metal)
	SurfaceBoxes.add_box(st, Vector3(-0.12, 0.82, -0.44), Vector3(0.12, 0.88, -0.2), brown)
	# Crank axle + pedals
	SurfaceBoxes.add_box(st, Vector3(-0.14, 0.34, -0.06), Vector3(0.14, 0.38, 0.02), metal)
	SurfaceBoxes.add_box(st, Vector3(0.1, 0.31, -0.11), Vector3(0.2, 0.34, 0.01), dark)
	SurfaceBoxes.add_box(st, Vector3(-0.2, 0.31, -0.11), Vector3(-0.1, 0.34, 0.01), dark)
	var frame := MeshInstance3D.new()
	frame.name = "FrameMesh"
	frame.mesh = st.commit()
	frame.material_override = VertexColorMaterial.make()
	_tilt.add_child(frame)

	# Rear wheel pivot
	_rear_wheel = _build_wheel("RearWheel")
	_rear_wheel.position = Vector3(0.0, 0.3, -0.45)
	_tilt.add_child(_rear_wheel)

	# Steering assembly at the head tube: fork, bars, grips, bell
	_steer_pivot = Node3D.new()
	_steer_pivot.name = "Steer"
	_steer_pivot.position = Vector3(0.0, 0.72, 0.38)
	_tilt.add_child(_steer_pivot)

	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Head tube
	SurfaceBoxes.add_box(st2, Vector3(-0.05, -0.08, -0.05), Vector3(0.05, 0.22, 0.05), red)
	# Fork legs down to the front axle
	SurfaceBoxes.add_box(st2, Vector3(-0.08, -0.46, 0.0), Vector3(-0.04, -0.06, 0.08), red)
	SurfaceBoxes.add_box(st2, Vector3(0.04, -0.46, 0.0), Vector3(0.08, -0.06, 0.08), red)
	# Handlebar + grips
	SurfaceBoxes.add_box(st2, Vector3(-0.28, 0.18, -0.03), Vector3(0.28, 0.24, 0.03), metal)
	SurfaceBoxes.add_box(st2, Vector3(-0.36, 0.17, -0.04), Vector3(-0.28, 0.25, 0.04), dark)
	SurfaceBoxes.add_box(st2, Vector3(0.28, 0.17, -0.04), Vector3(0.36, 0.25, 0.04), dark)
	# Little bell
	SurfaceBoxes.add_box(st2, Vector3(0.14, 0.24, -0.02), Vector3(0.21, 0.31, 0.05), Color(1.0, 0.85, 0.3))
	var head := MeshInstance3D.new()
	head.name = "SteerMesh"
	head.mesh = st2.commit()
	head.material_override = VertexColorMaterial.make()
	_steer_pivot.add_child(head)

	# Front wheel pivot (child of the steering so it turns with the bar)
	_front_wheel = _build_wheel("FrontWheel")
	_front_wheel.position = Vector3(0.0, -0.42, 0.06)
	_steer_pivot.add_child(_front_wheel)


func _build_wheel(wheel_name: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = wheel_name
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SurfaceBoxes.add_box(st, Vector3(-0.05, -0.28, -0.28), Vector3(0.05, 0.28, 0.28), Color(0.16, 0.16, 0.19))
	SurfaceBoxes.add_box(st, Vector3(-0.06, -0.07, -0.07), Vector3(0.06, 0.07, 0.07), Color(1.0, 0.85, 0.3))
	var mi := MeshInstance3D.new()
	mi.name = "WheelMesh"
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	pivot.add_child(mi)
	return pivot


func _build_prompt() -> void:
	# Always-visible shop sign so the bike is easy to spot from afar
	_sign = Label3D.new()
	_sign.name = "Sign"
	_sign.text = "🚲"
	_sign.position = Vector3(0.0, 1.75, 0.0)
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.font_size = 96
	_sign.outline_size = 14
	_sign.modulate = Color(1.0, 1.0, 1.0)
	_sign.no_depth_test = true
	add_child(_sign)

	_prompt = Label3D.new()
	_prompt.name = "Prompt"
	_prompt.text = "🚲 E: Aufsteigen"
	_prompt.position = Vector3(0.0, 1.35, 0.2)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 64
	_prompt.outline_size = 12
	_prompt.modulate = Color(1.0, 1.0, 0.8)
	_prompt.visible = false
	add_child(_prompt)

## Headlight + tail light with glowing lamp meshes. Lights are created
## once and only toggled by the day/night cycle (see _update_lights).
func _build_lights() -> void:
	# --- Headlamp on the handlebar: a bright little lamp housing that
	# throws a warm cone of light onto the path ahead
	var lamp_body: Color = Color(0.2, 0.2, 0.22)
	var lens: Color = Color(1.0, 0.97, 0.8)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Housing under the bar, slightly forward
	SurfaceBoxes.add_box(st, Vector3(-0.09, 0.06, 0.03), Vector3(0.09, 0.16, 0.14), lamp_body)
	# Lens facing forward (+Z)
	SurfaceBoxes.add_box(st, Vector3(-0.07, 0.08, 0.14), Vector3(0.07, 0.14, 0.16), lens)
	var mi := MeshInstance3D.new()
	mi.name = "Headlamp"
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	_steer_pivot.add_child(mi)
	_headlamp_mesh = mi

	_headlight = SpotLight3D.new()
	_headlight.name = "Headlight"
	# Spotlights emit along their local -Z. Build the basis so that -Z
	# points along the bike's forward (+Z) with a slight downward tilt.
	var aim: Vector3 = Vector3(0.0, -tan(deg_to_rad(12.0)), 1.0).normalized()
	_headlight.basis = Basis.looking_at(aim, Vector3.UP)
	_headlight.position = Vector3(0.0, 0.12, 0.18)
	_headlight.spot_range = 14.0
	_headlight.spot_angle = 38.0
	_headlight.spot_angle_attenuation = 1.2
	_headlight.light_energy = 2.6
	_headlight.light_color = Color(1.0, 0.95, 0.78)
	_headlight.shadow_enabled = true
	_headlight.visible = false
	_steer_pivot.add_child(_headlight)

	# --- Tail light at the back of the frame: a red lens + small glow
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	SurfaceBoxes.add_box(st2, Vector3(-0.06, 0.52, -0.33), Vector3(0.06, 0.62, -0.27), Color(0.55, 0.1, 0.1))
	SurfaceBoxes.add_box(st2, Vector3(-0.05, 0.53, -0.34), Vector3(0.05, 0.61, -0.33), Color(1.0, 0.2, 0.15))
	var mi2 := MeshInstance3D.new()
	mi2.name = "Taillamp"
	mi2.mesh = st2.commit()
	mi2.material_override = VertexColorMaterial.make()
	_tilt.add_child(mi2)
	_taillamp_mesh = mi2

	_tail_light = OmniLight3D.new()
	_tail_light.name = "TailLight"
	_tail_light.position = Vector3(0.0, 0.57, -0.4)
	_tail_light.omni_range = 2.2
	_tail_light.light_energy = 1.1
	_tail_light.light_color = Color(1.0, 0.18, 0.12)
	_tail_light.visible = false
	_tilt.add_child(_tail_light)


## Lights come on at dusk and go off at dawn - but only while someone
## is riding (a parked bike doesn't drain its battery).
func _update_lights() -> void:
	if _day_night == null:
		# Normal game: the cycle is a child of the current scene. In
		# headless tests the scene is instanced by hand (current_scene is
		# null), so fall back to the bike's own parent chain.
		if get_tree().current_scene:
			_day_night = get_tree().current_scene.get_node_or_null("DayNightCycle") as DayNightCycle
		if _day_night == null:
			var p: Node = get_parent()
			while p and _day_night == null:
				_day_night = p.get_node_or_null("DayNightCycle") as DayNightCycle
				p = p.get_parent()
	if _day_night == null:
		return
	var dark: bool = _day_night.current_phase == DayNightCycle.DayPhase.DUSK or _day_night.current_phase == DayNightCycle.DayPhase.NIGHT
	var want: bool = dark and _rider != null
	if want == _lights_on:
		return
	_lights_on = want
	if _headlight:
		_headlight.visible = want
	if _tail_light:
		_tail_light.visible = want
	if _headlamp_mesh:
		var m: StandardMaterial3D = _headlamp_mesh.material_override as StandardMaterial3D
		if m:
			m.emission_enabled = want
			m.emission = Color(1.0, 0.95, 0.75)
			m.emission_energy_multiplier = 1.6 if want else 0.0
	if _taillamp_mesh:
		var m2: StandardMaterial3D = _taillamp_mesh.material_override as StandardMaterial3D
		if m2:
			m2.emission_enabled = want
			m2.emission = Color(1.0, 0.2, 0.12)
			m2.emission_energy_multiplier = 1.4 if want else 0.0
