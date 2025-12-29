extends RefCounted
class_name CharacterPreviewBuilder

## Builds a 3D character preview for the editor

func build_character(root: Node3D, customization: PlayerCustomization) -> void:
	# Clear existing children
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
	
	# HEAD
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.35, 0.35, 0.35)
	head.mesh = head_mesh
	head.position = Vector3(0, 0.9, 0)
	head.material_override = skin_mat
	root.add_child(head)
	
	# HAIR
	if customization.hair_style != PlayerCustomization.HairStyle.BALD:
		var hair := MeshInstance3D.new()
		var hair_mesh := BoxMesh.new()
		
		match customization.hair_style:
			PlayerCustomization.HairStyle.SHORT:
				hair_mesh.size = Vector3(0.37, 0.12, 0.37)
				hair.position = Vector3(0, 0.17, 0)
			PlayerCustomization.HairStyle.LONG:
				hair_mesh.size = Vector3(0.38, 0.25, 0.38)
				hair.position = Vector3(0, 0.12, 0)
			PlayerCustomization.HairStyle.SPIKY:
				hair_mesh.size = Vector3(0.32, 0.18, 0.32)
				hair.position = Vector3(0, 0.20, 0)
		
		hair.mesh = hair_mesh
		hair.material_override = hair_mat
		head.add_child(hair)
	
	# GLASSES
	if customization.glasses_type != PlayerCustomization.GlassesType.NONE:
		var glasses := MeshInstance3D.new()
		var glasses_mesh := BoxMesh.new()
		
		match customization.glasses_type:
			PlayerCustomization.GlassesType.ROUND:
				glasses_mesh.size = Vector3(0.36, 0.08, 0.05)
			PlayerCustomization.GlassesType.SQUARE:
				glasses_mesh.size = Vector3(0.38, 0.10, 0.05)
		
		glasses.mesh = glasses_mesh
		glasses.position = Vector3(0, 0.02, 0.16)
		glasses.material_override = glasses_mat
		head.add_child(glasses)
	
	# HAT
	if customization.hat_type != PlayerCustomization.HatType.NONE:
		var hat := MeshInstance3D.new()
		var hat_mesh := BoxMesh.new()
		
		match customization.hat_type:
			PlayerCustomization.HatType.CAP:
				hat_mesh.size = Vector3(0.40, 0.10, 0.42)
				hat.position = Vector3(0, 0.20, 0.02)
				var visor := MeshInstance3D.new()
				var visor_mesh := BoxMesh.new()
				visor_mesh.size = Vector3(0.30, 0.03, 0.15)
				visor.mesh = visor_mesh
				visor.position = Vector3(0, -0.03, 0.22)
				visor.material_override = hat_mat
				hat.add_child(visor)
			PlayerCustomization.HatType.BEANIE:
				hat_mesh.size = Vector3(0.38, 0.15, 0.38)
				hat.position = Vector3(0, 0.22, 0)
		
		hat.mesh = hat_mesh
		hat.material_override = hat_mat
		head.add_child(hat)
	
	# BODY
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.4, 0.5, 0.25)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.45, 0)
	body.material_override = body_mat
	root.add_child(body)
	
	# ARMS
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.15, 0.45, 0.15)
	
	var left_arm := MeshInstance3D.new()
	left_arm.mesh = arm_mesh
	left_arm.position = Vector3(-0.275, 0.45, 0)
	left_arm.material_override = skin_mat
	root.add_child(left_arm)
	
	var right_arm := MeshInstance3D.new()
	right_arm.mesh = arm_mesh
	right_arm.position = Vector3(0.275, 0.45, 0)
	right_arm.material_override = skin_mat
	root.add_child(right_arm)
	
	# LEGS
	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.18, 0.4, 0.18)
	
	var left_leg := MeshInstance3D.new()
	left_leg.mesh = leg_mesh
	left_leg.position = Vector3(-0.1, 0, 0)
	left_leg.material_override = leg_mat
	root.add_child(left_leg)
	
	var right_leg := MeshInstance3D.new()
	right_leg.mesh = leg_mesh
	right_leg.position = Vector3(0.1, 0, 0)
	right_leg.material_override = leg_mat
	root.add_child(right_leg)

