extends Node

## Feedback Effects Manager (Autoload)
##
## Provides visual feedback for game events like building placement,
## quiz answers, and NPC interactions.
## Add to Autoloads as "Effects"


## Spawn colorful confetti particles at position (for building placement)
func spawn_confetti(world_pos: Vector3) -> void:
	AudioManager.play_sfx(AudioManager.SFX.BUILDING_PLACE)

	# Spawn multiple particle systems with different colors
	var colors: Array[Color] = [
		Color(1.0, 0.3, 0.3), # Red
		Color(0.3, 1.0, 0.3), # Green
		Color(0.3, 0.5, 1.0), # Blue
		Color(1.0, 0.9, 0.2), # Yellow
		Color(1.0, 0.5, 0.8), # Pink
	]

	for i in range(3):
		var particles := GPUParticles3D.new()
		particles.emitting = true
		particles.one_shot = true
		particles.explosiveness = 0.95
		particles.amount = 15
		particles.lifetime = 1.2

		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 60.0
		mat.initial_velocity_min = 4.0
		mat.initial_velocity_max = 8.0
		mat.gravity = Vector3(0, -12.0, 0)
		mat.scale_min = 0.08
		mat.scale_max = 0.15
		mat.color = colors[i % colors.size()]
		mat.damping_min = 2.0
		mat.damping_max = 4.0
		particles.process_material = mat

		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.12, 0.12)
		particles.draw_pass_1 = mesh

		particles.position = world_pos + Vector3(0.5, 0.5 + i * 0.1, 0.5)
		get_tree().current_scene.add_child(particles)
		get_tree().create_timer(2.5).timeout.connect(particles.queue_free)


## Spawn success particles (sparkles for correct answer)
func spawn_success(world_pos: Vector3) -> void:
	AudioManager.play_sfx(AudioManager.SFX.QUIZ_CORRECT)

	# Ring of sparkles
	for i in range(2):
		var particles := GPUParticles3D.new()
		particles.emitting = true
		particles.one_shot = true
		particles.explosiveness = 0.8 + i * 0.1
		particles.amount = 20
		particles.lifetime = 1.0

		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 80.0
		mat.initial_velocity_min = 3.0
		mat.initial_velocity_max = 5.0
		mat.gravity = Vector3(0, -4, 0)
		mat.scale_min = 0.1
		mat.scale_max = 0.2
		# Golden sparkles
		mat.color = Color(1.0, 0.85 + i * 0.1, 0.2)
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.3
		particles.process_material = mat

		var mesh := SphereMesh.new()
		mesh.radius = 0.08
		mesh.height = 0.16
		particles.draw_pass_1 = mesh

		particles.position = world_pos + Vector3(0, 1.2 + i * 0.2, 0)
		get_tree().current_scene.add_child(particles)
		get_tree().create_timer(2.0).timeout.connect(particles.queue_free)

	# Star burst effect
	_spawn_star_burst(world_pos + Vector3(0, 1.5, 0))


## Spawn failure particles (red X for wrong answer)
func spawn_failure(world_pos: Vector3) -> void:
	AudioManager.play_sfx(AudioManager.SFX.QUIZ_WRONG)
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 10
	particles.lifetime = 0.6

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.0
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.15
	mat.color = Color(1.0, 0.2, 0.2)
	particles.process_material = mat

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.1)
	particles.draw_pass_1 = mesh

	particles.position = world_pos + Vector3(0, 1, 0)
	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


## Spawn floating text (like "+10 points")
func spawn_floating_text(world_pos: Vector3, text: String, color: Color = Color.WHITE) -> void:
	AudioManager.play_sfx(AudioManager.SFX.POINTS_GAIN, 0.7)
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.outline_size = 6
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = world_pos + Vector3(0, 1.5, 0)

	get_tree().current_scene.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.5, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


## Spawn star burst effect
func _spawn_star_burst(world_pos: Vector3) -> void:
	var star := Label3D.new()
	star.text = "⭐"
	star.font_size = 64
	star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	star.position = world_pos
	star.modulate = Color(1.0, 0.9, 0.3)
	star.scale = Vector3.ZERO

	get_tree().current_scene.add_child(star)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(star, "scale", Vector3(1.5, 1.5, 1.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "position:y", world_pos.y + 0.5, 0.3)
	tween.chain()
	tween.tween_property(star, "scale", Vector3.ZERO, 0.2)
	tween.tween_property(star, "modulate:a", 0.0, 0.2)
	tween.tween_callback(star.queue_free)
