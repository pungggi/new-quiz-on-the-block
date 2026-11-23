class_name SurfaceBoxes
extends RefCounted

## Static helper for code-built meshes: flat-colored quads and
## axis-aligned boxes added to a SurfaceTool (used by the bridge and the
## hedge labyrinth). Pair with VertexColorMaterial - it disables
## backface culling, so the winding order is irrelevant.

static func add_quad(st: SurfaceTool, v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3, normal: Vector3, color: Color) -> void:
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v3)
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(v1)
	st.add_vertex(v3)
	st.add_vertex(v4)


## One box between mn and mx. The bottom face (mn.y) is optional:
## hedges sit on the ground, bridge planks are visible from below.
static func add_box(st: SurfaceTool, mn: Vector3, mx: Vector3, color: Color, top_color: Color = color, include_bottom: bool = false) -> void:
	# Top (+y)
	add_quad(st, Vector3(mn.x, mx.y, mn.z), Vector3(mn.x, mx.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mx.x, mx.y, mn.z), Vector3.UP, top_color)
	# Sides
	add_quad(st, Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mx.x, mx.y, mn.z), Vector3.RIGHT, color)
	add_quad(st, Vector3(mn.x, mn.y, mx.z), Vector3(mn.x, mn.y, mn.z), Vector3(mn.x, mx.y, mn.z), Vector3(mn.x, mx.y, mx.z), Vector3.LEFT, color)
	add_quad(st, Vector3(mx.x, mn.y, mx.z), Vector3(mn.x, mn.y, mx.z), Vector3(mn.x, mx.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3.BACK, color)
	add_quad(st, Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mn.x, mx.y, mn.z), Vector3.FORWARD, color)
	if include_bottom:
		add_quad(st, Vector3(mn.x, mn.y, mx.z), Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mn.y, mx.z), Vector3.DOWN, color)
