class_name VertexColorMaterial
extends RefCounted

## Shared recipe for code-built vertex-colored meshes (bridge, hedge
## labyrinth): flat colors, roughness only, no backface culling so box
## winding never matters.

static func make() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
