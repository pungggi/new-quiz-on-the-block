extends RefCounted
class_name BlockyCharacterBuilder

## Unified Blocky Character Builder
##
## Creates blocky Minecraft-style character meshes for Player, NPC, and Preview.
## Uses shared static meshes and materials for performance.

#region Body Part Dimensions (shared constants)
const HEAD_SIZE := Vector3(0.35, 0.35, 0.35)
const BODY_SIZE := Vector3(0.4, 0.5, 0.25)
const ARM_SIZE := Vector3(0.15, 0.45, 0.15)
const LEG_SIZE := Vector3(0.18, 0.4, 0.18)

const HEAD_POS := Vector3(0, 0.9, 0)
const BODY_POS := Vector3(0, 0.45, 0)
const LEFT_ARM_POS := Vector3(-0.275, 0.45, 0)
const RIGHT_ARM_POS := Vector3(0.275, 0.45, 0)
const LEFT_LEG_POS := Vector3(-0.1, 0, 0)
const RIGHT_LEG_POS := Vector3(0.1, 0, 0)

## Hair style dimensions
const HAIR_SHORT_SIZE := Vector3(0.37, 0.12, 0.37)
const HAIR_SHORT_POS := Vector3(0, 0.17, 0)
const HAIR_LONG_SIZE := Vector3(0.38, 0.25, 0.38)
const HAIR_LONG_POS := Vector3(0, 0.12, 0)
const HAIR_SPIKY_SIZE := Vector3(0.32, 0.18, 0.32)
const HAIR_SPIKY_POS := Vector3(0, 0.20, 0)

## Glasses dimensions
const GLASSES_ROUND_SIZE := Vector3(0.36, 0.08, 0.05)
const GLASSES_SQUARE_SIZE := Vector3(0.38, 0.10, 0.05)
const GLASSES_POS := Vector3(0, 0.02, 0.16)

## Hat dimensions
const CAP_SIZE := Vector3(0.40, 0.10, 0.42)
const CAP_POS := Vector3(0, 0.20, 0.02)
const CAP_VISOR_SIZE := Vector3(0.30, 0.03, 0.15)
const CAP_VISOR_POS := Vector3(0, -0.03, 0.22)
const BEANIE_SIZE := Vector3(0.38, 0.15, 0.38)
const BEANIE_POS := Vector3(0, 0.22, 0)
#endregion

#region Shared Static Meshes (created once, reused for all characters)
static var _head_mesh: BoxMesh
static var _body_mesh: BoxMesh
static var _arm_mesh: BoxMesh
static var _leg_mesh: BoxMesh
static var _hair_short_mesh: BoxMesh
static var _hair_long_mesh: BoxMesh
static var _hair_spiky_mesh: BoxMesh
static var _glasses_round_mesh: BoxMesh
static var _glasses_square_mesh: BoxMesh
static var _meshes_initialized: bool = false

static func _ensure_meshes() -> void:
	if _meshes_initialized:
		return
	# Body meshes
	_head_mesh = BoxMesh.new()
	_head_mesh.size = HEAD_SIZE
	_body_mesh = BoxMesh.new()
	_body_mesh.size = BODY_SIZE
	_arm_mesh = BoxMesh.new()
	_arm_mesh.size = ARM_SIZE
	_leg_mesh = BoxMesh.new()
	_leg_mesh.size = LEG_SIZE
	# Hair meshes
	_hair_short_mesh = BoxMesh.new()
	_hair_short_mesh.size = HAIR_SHORT_SIZE
	_hair_long_mesh = BoxMesh.new()
	_hair_long_mesh.size = HAIR_LONG_SIZE
	_hair_spiky_mesh = BoxMesh.new()
	_hair_spiky_mesh.size = HAIR_SPIKY_SIZE
	# Glasses meshes
	_glasses_round_mesh = BoxMesh.new()
	_glasses_round_mesh.size = GLASSES_ROUND_SIZE
	_glasses_square_mesh = BoxMesh.new()
	_glasses_square_mesh.size = GLASSES_SQUARE_SIZE
	_meshes_initialized = true
#endregion


## Build result containing body parts for animation
class BuildResult:
	var body_parts: Dictionary = {}
	var materials: Dictionary = {}


## Build a character from PlayerCustomization
static func build_from_customization(root: Node3D, customization: PlayerCustomization) -> BuildResult:
	_ensure_meshes()
	var result := BuildResult.new()
	
	# Clear existing mesh children
	for child in root.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	
	# Create materials
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = customization.skin_color
	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = customization.hair_color
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = customization.shirt_color
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = customization.pants_color
	var glasses_mat := StandardMaterial3D.new()
	glasses_mat.albedo_color = customization.glasses_color
	var hat_mat := StandardMaterial3D.new()
	hat_mat.albedo_color = customization.hat_color
	
	result.materials = {
		"skin": skin_mat, "hair": hair_mat, "body": body_mat,
		"leg": leg_mat, "glasses": glasses_mat, "hat": hat_mat
	}
	
	# HEAD
	var head := _create_mesh_instance(_head_mesh, HEAD_POS, skin_mat)
	root.add_child(head)
	result.body_parts["head"] = head
	
	# HAIR
	if customization.hair_style != PlayerCustomization.HairStyle.BALD:
		var hair := _create_hair(customization.hair_style, hair_mat)
		head.add_child(hair)
	
	# GLASSES
	if customization.glasses_type != PlayerCustomization.GlassesType.NONE:
		var glasses := _create_glasses(customization.glasses_type, glasses_mat)
		head.add_child(glasses)
	
	# HAT
	if customization.hat_type != PlayerCustomization.HatType.NONE:
		var hat := _create_hat(customization.hat_type, hat_mat)
		head.add_child(hat)
	
	# BODY
	var body := _create_mesh_instance(_body_mesh, BODY_POS, body_mat)
	root.add_child(body)
	result.body_parts["body"] = body
	
	# ARMS
	var left_arm := _create_mesh_instance(_arm_mesh, LEFT_ARM_POS, skin_mat)
	var right_arm := _create_mesh_instance(_arm_mesh, RIGHT_ARM_POS, skin_mat)
	root.add_child(left_arm)
	root.add_child(right_arm)
	result.body_parts["left_arm"] = left_arm
	result.body_parts["right_arm"] = right_arm
	
	# LEGS
	var left_leg := _create_mesh_instance(_leg_mesh, LEFT_LEG_POS, leg_mat)
	var right_leg := _create_mesh_instance(_leg_mesh, RIGHT_LEG_POS, leg_mat)
	root.add_child(left_leg)
	root.add_child(right_leg)
	result.body_parts["left_leg"] = left_leg
	result.body_parts["right_leg"] = right_leg
	
	return result


## Build a simple NPC character (uses body color instead of customization)
static func build_npc(root: Node3D, body_color: Color, hair_color: Color) -> BuildResult:
	_ensure_meshes()
	var result := BuildResult.new()

	# Clear existing mesh children
	for child in root.get_children():
		if child is MeshInstance3D:
			child.queue_free()

	# Create materials
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.96, 0.84, 0.73) # Default skin
	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = hair_color
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = body_color.darkened(0.3)

	result.materials = {
		"skin": skin_mat, "hair": hair_mat, "body": body_mat, "leg": leg_mat
	}

	# HEAD
	var head := _create_mesh_instance(_head_mesh, HEAD_POS, skin_mat)
	root.add_child(head)
	result.body_parts["head"] = head

	# HAIR (always short for NPCs)
	var hair := _create_hair(PlayerCustomization.HairStyle.SHORT, hair_mat)
	head.add_child(hair)

	# BODY
	var body := _create_mesh_instance(_body_mesh, BODY_POS, body_mat)
	root.add_child(body)
	result.body_parts["body"] = body

	# ARMS
	var left_arm := _create_mesh_instance(_arm_mesh, LEFT_ARM_POS, skin_mat)
	var right_arm := _create_mesh_instance(_arm_mesh, RIGHT_ARM_POS, skin_mat)
	root.add_child(left_arm)
	root.add_child(right_arm)
	result.body_parts["left_arm"] = left_arm
	result.body_parts["right_arm"] = right_arm

	# LEGS
	var left_leg := _create_mesh_instance(_leg_mesh, LEFT_LEG_POS, leg_mat)
	var right_leg := _create_mesh_instance(_leg_mesh, RIGHT_LEG_POS, leg_mat)
	root.add_child(left_leg)
	root.add_child(right_leg)
	result.body_parts["left_leg"] = left_leg
	result.body_parts["right_leg"] = right_leg

	return result


#region Private Helper Functions
static func _create_mesh_instance(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = mat
	return instance


static func _create_hair(style: PlayerCustomization.HairStyle, mat: Material) -> MeshInstance3D:
	var hair := MeshInstance3D.new()
	hair.name = "Hair"

	# Use shared meshes
	match style:
		PlayerCustomization.HairStyle.SHORT:
			hair.mesh = _hair_short_mesh
			hair.position = HAIR_SHORT_POS
		PlayerCustomization.HairStyle.LONG:
			hair.mesh = _hair_long_mesh
			hair.position = HAIR_LONG_POS
		PlayerCustomization.HairStyle.SPIKY:
			hair.mesh = _hair_spiky_mesh
			hair.position = HAIR_SPIKY_POS

	hair.material_override = mat
	return hair


static func _create_glasses(gtype: PlayerCustomization.GlassesType, mat: Material) -> MeshInstance3D:
	var glasses := MeshInstance3D.new()
	glasses.name = "Glasses"

	# Use shared meshes
	match gtype:
		PlayerCustomization.GlassesType.ROUND:
			glasses.mesh = _glasses_round_mesh
		PlayerCustomization.GlassesType.SQUARE:
			glasses.mesh = _glasses_square_mesh

	glasses.position = GLASSES_POS
	glasses.material_override = mat
	return glasses


static func _create_hat(htype: PlayerCustomization.HatType, mat: Material) -> MeshInstance3D:
	var hat := MeshInstance3D.new()
	hat.name = "Hat"
	var hat_mesh := BoxMesh.new()

	match htype:
		PlayerCustomization.HatType.CAP:
			hat_mesh.size = CAP_SIZE
			hat.position = CAP_POS
			# Add visor
			var visor := MeshInstance3D.new()
			var visor_mesh := BoxMesh.new()
			visor_mesh.size = CAP_VISOR_SIZE
			visor.mesh = visor_mesh
			visor.position = CAP_VISOR_POS
			visor.material_override = mat
			hat.add_child(visor)
		PlayerCustomization.HatType.BEANIE:
			hat_mesh.size = BEANIE_SIZE
			hat.position = BEANIE_POS

	hat.mesh = hat_mesh
	hat.material_override = mat
	return hat
#endregion
