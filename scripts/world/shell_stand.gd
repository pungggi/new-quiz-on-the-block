extends Node3D
class_name ShellStand

## 🐚 Tauschbude on the beach: trade every collected shell for coins
## (E to interact, same key as NPCs). Standalone by design - it shows
## its own prompt and handles its own input, so neither Player nor HUD
## need to know it exists.

const STAND_POS := Vector3(119.5, 1.0, -16.0)
const INTERACT_RADIUS: float = 2.6
const WOOD := Color(0.55, 0.39, 0.23)
const WOOD_DARK := Color(0.42, 0.29, 0.17)
const CLOTH := Color(0.85, 0.35, 0.4)

var _prompt: Label3D = null


func _ready() -> void:
	position = STAND_POS
	_build_mesh()
	_setup_interaction()


## Counter + top plate + four posts + striped roof
func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SurfaceBoxes.add_box(st, Vector3(-0.8, 0.0, -0.4), Vector3(0.8, 0.9, 0.4), WOOD, WOOD.lightened(0.08))
	SurfaceBoxes.add_box(st, Vector3(-0.95, 0.9, -0.5), Vector3(0.95, 1.0, 0.5), WOOD_DARK)
	for px: float in [-0.85, 0.85]:
		for pz: float in [-0.45, 0.45]:
			SurfaceBoxes.add_box(st, Vector3(px - 0.06, 0.0, pz - 0.06), Vector3(px + 0.06, 2.1, pz + 0.06), WOOD_DARK)
	SurfaceBoxes.add_box(st, Vector3(-1.1, 2.1, -0.65), Vector3(1.1, 2.24, 0.65), CLOTH, CLOTH.darkened(0.1))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)

	# Solid counter so nobody walks through it
	var body := StaticBody3D.new()
	body.collision_layer = Config.PROP_COLLISION_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.0, 1.0)
	shape.shape = box
	shape.position = Vector3(0.0, 0.5, 0.0)
	body.add_child(shape)
	add_child(body)

	var sign := Label3D.new()
	sign.text = "🐚 Tauschbude"
	sign.position = Vector3(0.0, 2.8, 0.0)
	sign.font_size = 40
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)


func _setup_interaction() -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = INTERACT_RADIUS
	shape.shape = sphere
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

	_prompt = Label3D.new()
	_prompt.text = "E: Muscheln tauschen 🐚 ➜ 💰"
	_prompt.position = Vector3(0.0, 1.7, 0.0)
	_prompt.font_size = 28
	_prompt.modulate = Color(1.0, 0.9, 0.4)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.visible = false
	add_child(_prompt)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and _prompt:
		_prompt.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body is Player and _prompt:
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (_prompt and _prompt.visible):
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_exchange()


func _exchange() -> void:
	var payout: int = ShellManager.exchange_all()
	if payout <= 0:
		Effects.spawn_floating_text(global_position + Vector3.UP * 1.8, "Erst Muscheln sammeln! 🐚", Color(1.0, 0.7, 0.3))
		return
	Effects.spawn_confetti(global_position + Vector3.UP * 1.4)
	Effects.spawn_floating_text(global_position + Vector3.UP * 1.8, "+%d 💰" % payout, Color(1.0, 0.85, 0.2))
	AudioManager.play_sfx(AudioManager.SFX.POINTS_GAIN)
