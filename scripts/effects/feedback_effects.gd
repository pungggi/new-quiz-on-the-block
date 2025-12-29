extends Node

## Feedback Effects Manager (Autoload)
##
## Provides visual feedback for game events like building placement,
## quiz answers, and NPC interactions.
## Add to Autoloads as "Effects"


## Spawn confetti particles at position (for building placement)
func spawn_confetti(world_pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 20
	particles.lifetime = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.2
	mat.color = Color(1, 0.8, 0.2)
	particles.process_material = mat

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	particles.draw_pass_1 = mesh

	particles.position = world_pos + Vector3(0.5, 0.5, 0.5)
	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(2.0).timeout.connect(particles.queue_free)


## Spawn success particles (green stars for correct answer)
func spawn_success(world_pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 15
	particles.lifetime = 0.8

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.15
	mat.scale_max = 0.25
	mat.color = Color(0.2, 1.0, 0.3)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh

	particles.position = world_pos + Vector3(0, 1, 0)
	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)


## Spawn failure particles (red X for wrong answer)
func spawn_failure(world_pos: Vector3) -> void:
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
