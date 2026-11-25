extends RefCounted
class_name PropMeshGenerator

## Procedural Prop Mesh Generator
##
## Creates voxel-style meshes for props (trees, benches, etc.)
## using SurfaceTool. One ArrayMesh per prop – no Node-per-block.


#region Core Box Helper (same signature as BuildingMeshGenerator)
static func _add_box(st: SurfaceTool, o: Vector3, s: Vector3) -> void:
	var x1: float = o.x; var y1: float = o.y; var z1: float = o.z
	var x2: float = o.x + s.x; var y2: float = o.y + s.y; var z2: float = o.z + s.z
	# Top
	st.add_vertex(Vector3(x1, y2, z1)); st.add_vertex(Vector3(x2, y2, z1)); st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x1, y2, z1)); st.add_vertex(Vector3(x2, y2, z2)); st.add_vertex(Vector3(x1, y2, z2))
	# Bottom
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x1, y1, z1)); st.add_vertex(Vector3(x1, y1, z2))
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x1, y1, z2)); st.add_vertex(Vector3(x2, y1, z2))
	# Front (+Z)
	st.add_vertex(Vector3(x1, y1, z2)); st.add_vertex(Vector3(x1, y2, z2)); st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x1, y1, z2)); st.add_vertex(Vector3(x2, y2, z2)); st.add_vertex(Vector3(x2, y1, z2))
	# Back (-Z)
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x2, y2, z1)); st.add_vertex(Vector3(x1, y2, z1))
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x1, y2, z1)); st.add_vertex(Vector3(x1, y1, z1))
	# Right (+X)
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x2, y1, z2)); st.add_vertex(Vector3(x2, y2, z2))
	st.add_vertex(Vector3(x2, y1, z1)); st.add_vertex(Vector3(x2, y2, z2)); st.add_vertex(Vector3(x2, y2, z1))
	# Left (-X)
	st.add_vertex(Vector3(x1, y1, z2)); st.add_vertex(Vector3(x1, y1, z1)); st.add_vertex(Vector3(x1, y2, z1))
	st.add_vertex(Vector3(x1, y1, z2)); st.add_vertex(Vector3(x1, y2, z1)); st.add_vertex(Vector3(x1, y2, z2))
#endregion


#region Main Generator
static func generate(prop: PropData) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var primary: Color = prop.primary_color
	var secondary: Color = prop.secondary_color

	match prop.prop_type:
		PropData.PropType.TREE:
			_generate_tree(st, prop.size, primary, secondary, prop.display_name)
		PropData.PropType.BENCH:
			_generate_bench(st, prop.size, primary, secondary)
		PropData.PropType.TRASH_CAN:
			_generate_trash_can(st, prop.size, primary, secondary)
		PropData.PropType.BUSH:
			_generate_bush(st, prop.size, primary, secondary)
		PropData.PropType.FLOWER_BED:
			_generate_flower_bed(st, prop.size, primary, secondary)
		PropData.PropType.FOUNTAIN:
			_generate_fountain(st, prop.size, primary, secondary)
		PropData.PropType.BIKE_RACK:
			_generate_bike_rack(st, prop.size, primary, secondary)
		PropData.PropType.MAILBOX:
			_generate_mailbox(st, prop.size, primary, secondary)
		PropData.PropType.PHONE_BOOTH:
			_generate_phone_booth(st, prop.size, primary, secondary)
		PropData.PropType.FIRE_HYDRANT:
			_generate_fire_hydrant(st, prop.size, primary, secondary)
		PropData.PropType.ROAD_SIGN:
			_generate_road_sign(st, prop.size, primary, secondary)
		PropData.PropType.TRAFFIC_LIGHT:
			_generate_traffic_light(st, prop.size, primary, secondary)
		PropData.PropType.ROAD_MARKING:
			_generate_road_marking(st, prop.size, primary, secondary)
		PropData.PropType.BLACKBOARD:
			_generate_blackboard(st, prop.size, primary, secondary)
		PropData.PropType.BOOK_STACK:
			_generate_book_stack(st, prop.size, primary, secondary)
		PropData.PropType.GLOBE_PEDESTAL:
			_generate_globe_pedestal(st, prop.size, primary, secondary)
		PropData.PropType.PARK_LAMP:
			_generate_park_lamp(st, prop.size, primary, secondary)
		PropData.PropType.PICNIC_TABLE:
			_generate_picnic_table(st, prop.size, primary, secondary)
		PropData.PropType.SANDBOX:
			_generate_sandbox(st, prop.size, primary, secondary)
		PropData.PropType.SWING_SET:
			_generate_swing_set(st, prop.size, primary, secondary)
		PropData.PropType.SMALL_FOUNTAIN:
			_generate_small_fountain(st, prop.size, primary, secondary)

	st.generate_normals()

	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh
#endregion


#region Prop Type Generators

## 🌳 Tree – dispatches to variant-specific generator by display name
static func _generate_tree(st: SurfaceTool, size: Vector3, trunk_col: Color, leaf_col: Color, display_name: String = "") -> void:
	match display_name:
		"Birke":
			_generate_birch(st, size, trunk_col, leaf_col)
		"Tanne":
			_generate_pine(st, size, trunk_col, leaf_col)
		_:  # "Eiche" and any unknown tree
			_generate_oak(st, size, trunk_col, leaf_col)


## 🌳 Oak (Eiche) – wide rounded crown, 4 offset layers + root flare
static func _generate_oak(st: SurfaceTool, size: Vector3, trunk_col: Color, leaf_col: Color) -> void:
	var height: float = size.y
	var trunk_h: float = height * 0.35
	var trunk_w: float = 0.18

	# Root flare (slightly wider base)
	st.set_color(trunk_col.darkened(0.15))
	_add_box(st, Vector3(-0.14, 0.0, -0.14), Vector3(0.28, 0.12, 0.28))

	# Trunk
	st.set_color(trunk_col)
	_add_box(st, Vector3(-trunk_w * 0.5, 0.08, -trunk_w * 0.5), Vector3(trunk_w, trunk_h - 0.08, trunk_w))

	# Crown – 4 wide overlapping layers with alternating offsets for roundness
	var crown_start: float = trunk_h * 0.65
	var crown_total: float = height - crown_start
	var layer_h: float = crown_total / 4.0
	var widths: Array[float] = [0.55, 0.65, 0.5, 0.3]
	var offsets: Array[Vector2] = [
		Vector2(0.0,   0.0),
		Vector2(0.04, -0.04),
		Vector2(-0.03, 0.03),
		Vector2(0.02,  0.01),
	]
	for i in range(4):
		var w: float = widths[i]
		var y: float = crown_start + layer_h * float(i)
		var off: Vector2 = offsets[i]
		st.set_color(leaf_col.lightened(0.04 * float(i)))
		_add_box(st, Vector3(-w * 0.5 + off.x, y, -w * 0.5 + off.y), Vector3(w, layer_h + 0.08, w))


## 🌿 Birch (Birke) – slender white trunk with dark marks + narrow drooping crown
static func _generate_birch(st: SurfaceTool, size: Vector3, trunk_col: Color, leaf_col: Color) -> void:
	var height: float = size.y
	var trunk_h: float = height * 0.55
	var trunk_w: float = 0.10

	# Trunk (pale)
	st.set_color(trunk_col)
	_add_box(st, Vector3(-trunk_w * 0.5, 0.0, -trunk_w * 0.5), Vector3(trunk_w, trunk_h, trunk_w))

	# Bark marks – 3 dark horizontal bands
	var mark_col: Color = trunk_col.darkened(0.45)
	for i in range(3):
		var mark_y: float = trunk_h * (0.2 + 0.25 * float(i))
		st.set_color(mark_col)
		_add_box(st, Vector3(-trunk_w * 0.5 - 0.005, mark_y, -trunk_w * 0.5 - 0.005),
			Vector3(trunk_w + 0.01, 0.04, trunk_w + 0.01))

	# Crown – 3 narrow layers, wider at base, drooping outward
	var crown_start: float = trunk_h * 0.75
	var crown_total: float = height - crown_start
	var layer_h: float = crown_total / 3.0
	var widths: Array[float] = [0.45, 0.35, 0.18]
	var droop_offsets: Array[Vector2] = [
		Vector2(-0.05, 0.05),
		Vector2(0.04, -0.03),
		Vector2(-0.02, 0.0),
	]
	for i in range(3):
		var w: float = widths[i]
		var y: float = crown_start + layer_h * float(i)
		var droop: Vector2 = droop_offsets[i]
		st.set_color(leaf_col.lightened(0.06 * float(i)))
		_add_box(st, Vector3(-w * 0.5 + droop.x, y, -w * 0.5 + droop.y), Vector3(w, layer_h + 0.05, w))

	# Hanging twigs – small thin downward extensions at the crown base
	st.set_color(leaf_col.darkened(0.1))
	var twig_positions: Array[Vector2] = [Vector2(-0.18, 0.0), Vector2(0.18, 0.0), Vector2(0.0, -0.18), Vector2(0.0, 0.18)]
	for tp in twig_positions:
		_add_box(st, Vector3(tp.x - 0.025, crown_start - 0.08, tp.y - 0.025), Vector3(0.05, 0.12, 0.05))


## 🎄 Pine (Tanne) – tall conical Christmas-tree silhouette, 5 layers
static func _generate_pine(st: SurfaceTool, size: Vector3, trunk_col: Color, needle_col: Color) -> void:
	var height: float = size.y
	var trunk_h: float = height * 0.2
	var trunk_w: float = 0.12

	# Trunk
	st.set_color(trunk_col)
	_add_box(st, Vector3(-trunk_w * 0.5, 0.0, -trunk_w * 0.5), Vector3(trunk_w, trunk_h, trunk_w))

	# Conical crown – 5 layers, each smaller and offset upward, widest at base
	var crown_start: float = trunk_h * 0.5
	var crown_total: float = height - crown_start
	var layer_count: int = 5
	var layer_h: float = crown_total / float(layer_count)

	for i in range(layer_count):
		# Each layer gets narrower toward the top (linear taper)
		var t: float = float(i) / float(layer_count - 1)
		var w: float = lerp(0.7, 0.12, t)
		var y: float = crown_start + layer_h * float(i)
		# Slight alternating offset to break up the silhouette
		var off: float = 0.02 * float(i % 2) * (1.0 - 2.0 * float(i % 2 == 0))
		st.set_color(needle_col.lightened(0.03 * float(i)))
		_add_box(st, Vector3(-w * 0.5 + off, y, -w * 0.5 - off), Vector3(w, layer_h + 0.06, w))

	# Tip
	st.set_color(needle_col.lightened(0.15))
	_add_box(st, Vector3(-0.04, height - 0.1, -0.04), Vector3(0.08, 0.15, 0.08))


## 🪵 Bench – 4 legs + 3 seat slats + back rest slats + armrests
static func _generate_bench(st: SurfaceTool, size: Vector3, frame_col: Color, wood_col: Color) -> void:
	var w: float = size.x   # 1.2
	var h: float = size.y   # 0.6
	var d: float = size.z   # 0.5
	var leg_w: float = 0.06
	var seat_h: float = h * 0.55
	var cx: float = -w * 0.5
	var cz: float = -d * 0.5

	# Side frames – two L-shaped end pieces (leg pair + support bar)
	st.set_color(frame_col)
	# Left side: front leg, back leg, horizontal support
	_add_box(st, Vector3(cx, 0.0, cz), Vector3(leg_w, seat_h, leg_w))
	_add_box(st, Vector3(cx, 0.0, cz + d - leg_w), Vector3(leg_w, seat_h, leg_w))
	_add_box(st, Vector3(cx, seat_h * 0.35, cz), Vector3(leg_w, 0.04, d))
	# Right side: front leg, back leg, horizontal support
	_add_box(st, Vector3(cx + w - leg_w, 0.0, cz), Vector3(leg_w, seat_h, leg_w))
	_add_box(st, Vector3(cx + w - leg_w, 0.0, cz + d - leg_w), Vector3(leg_w, seat_h, leg_w))
	_add_box(st, Vector3(cx + w - leg_w, seat_h * 0.35, cz), Vector3(leg_w, 0.04, d))

	# 3 seat slats (evenly spaced along depth)
	var slat_t: float = 0.04
	var slat_h: float = 0.045
	var gap: float = (d - 3.0 * slat_t) / 4.0
	for i in range(3):
		var sz: float = cz + gap + float(i) * (slat_t + gap)
		st.set_color(wood_col.lightened(0.05 * float(i % 2)))
		_add_box(st, Vector3(cx, seat_h, sz), Vector3(w, slat_h, slat_t))

	# Back rest – 2 vertical slats, slightly darker
	var back_slat_h: float = h - seat_h - 0.02
	st.set_color(wood_col.darkened(0.08))
	_add_box(st, Vector3(cx, seat_h + 0.04, cz + 0.01), Vector3(w, 0.04, slat_t))
	_add_box(st, Vector3(cx, seat_h + 0.04 + back_slat_h * 0.55, cz + 0.01), Vector3(w, 0.04, slat_t))
	# Vertical back supports at the ends
	st.set_color(frame_col.darkened(0.05))
	_add_box(st, Vector3(cx + leg_w, seat_h, cz), Vector3(0.04, back_slat_h + 0.04, slat_t + 0.01))
	_add_box(st, Vector3(cx + w - leg_w - 0.04, seat_h, cz), Vector3(0.04, back_slat_h + 0.04, slat_t + 0.01))

	# Armrests – flat caps on top of each end frame
	st.set_color(wood_col.lightened(0.1))
	_add_box(st, Vector3(cx - 0.01, seat_h + back_slat_h * 0.5, cz - 0.02), Vector3(leg_w + 0.02, 0.04, d * 0.55))
	_add_box(st, Vector3(cx + w - leg_w - 0.01, seat_h + back_slat_h * 0.5, cz - 0.02), Vector3(leg_w + 0.02, 0.04, d * 0.55))


## 🗑️ Trash can – tapered body + lid with handle + colored band + base ring
static func _generate_trash_can(st: SurfaceTool, size: Vector3, body_col: Color, lid_col: Color) -> void:
	var w: float = size.x  # 0.3
	var h: float = size.y  # 0.5
	var cx: float = -w * 0.5

	# Base ring (slightly wider, dark)
	st.set_color(body_col.darkened(0.25))
	_add_box(st, Vector3(cx - 0.01, 0.0, cx - 0.01), Vector3(w + 0.02, 0.04, w + 0.02))

	# Body – slightly tapered effect with two stacked boxes (bottom wider)
	st.set_color(body_col)
	_add_box(st, Vector3(cx, 0.04, cx), Vector3(w, (h - 0.08) * 0.5, w))
	st.set_color(body_col.lightened(0.05))
	_add_box(st, Vector3(cx + 0.01, 0.04 + (h - 0.08) * 0.5, cx + 0.01),
		Vector3(w - 0.02, (h - 0.08) * 0.5, w - 0.02))

	# Colored recycling band (green stripe)
	st.set_color(Color(0.2, 0.6, 0.25))
	_add_box(st, Vector3(cx - 0.005, h * 0.38, cx - 0.005), Vector3(w + 0.01, 0.035, w + 0.01))

	# Lid (slightly wider with overhang)
	var lid_extra: float = 0.025
	st.set_color(lid_col)
	_add_box(st, Vector3(cx - lid_extra, h - 0.04, cx - lid_extra),
		Vector3(w + lid_extra * 2, 0.04, w + lid_extra * 2))

	# Handle nub on lid center
	st.set_color(lid_col.darkened(0.15))
	_add_box(st, Vector3(-0.03, h, -0.03), Vector3(0.06, 0.04, 0.06))


## 🌿 Bush – 3 overlapping lobes + small berry clusters
static func _generate_bush(st: SurfaceTool, size: Vector3, dark_col: Color, light_col: Color) -> void:
	var w: float = size.x  # 0.6
	var h: float = size.y  # 0.4
	var cx: float = -w * 0.5

	# Main body
	st.set_color(dark_col)
	_add_box(st, Vector3(cx, 0, cx), Vector3(w, h * 0.75, w))

	# Top-center lobe
	st.set_color(light_col)
	var lobe_w: float = w * 0.65
	_add_box(st, Vector3(-lobe_w * 0.5 + 0.03, h * 0.45, -lobe_w * 0.5 - 0.02), Vector3(lobe_w, h * 0.55, lobe_w))

	# Left-side lobe
	st.set_color(light_col.darkened(0.08))
	_add_box(st, Vector3(cx - 0.04, 0.02, cx + 0.05), Vector3(w * 0.5, h * 0.65, w * 0.48))

	# Right-back lobe
	st.set_color(light_col.darkened(0.05))
	_add_box(st, Vector3(cx + w * 0.35, 0.03, cx + 0.04), Vector3(w * 0.45, h * 0.55, w * 0.45))

	# Berry clusters – 4 small colored dots scattered across the top
	var berry_col: Color = Color(0.7, 0.15, 0.15)
	for i in range(4):
		var bx: float = cx + w * (0.2 + 0.18 * float(i))
		var bz: float = cx + w * (0.15 + 0.22 * float((i + 1) % 3))
		var by: float = h * 0.85 + 0.02 * float(i % 2)
		st.set_color(berry_col.lightened(0.1 * float(i % 2)))
		_add_box(st, Vector3(bx, by, bz), Vector3(0.045, 0.045, 0.045))


## 🌸 Flower bed – soil base + small colorful flower stems
static func _generate_flower_bed(st: SurfaceTool, size: Vector3, soil_col: Color, _flower_col: Color) -> void:
	var w: float = size.x  # 1.0
	var h: float = size.y  # 0.2
	var cx: float = -w * 0.5

	# Soil base
	st.set_color(soil_col)
	_add_box(st, Vector3(cx, 0, cx), Vector3(w, h * 0.5, w))

	# Border rim
	st.set_color(soil_col.darkened(0.3))
	var rim: float = 0.04
	_add_box(st, Vector3(cx, 0, cx), Vector3(w, h * 0.7, rim))
	_add_box(st, Vector3(cx, 0, cx + w - rim), Vector3(w, h * 0.7, rim))
	_add_box(st, Vector3(cx, 0, cx), Vector3(rim, h * 0.7, w))
	_add_box(st, Vector3(cx + w - rim, 0, cx), Vector3(rim, h * 0.7, w))

	# Flowers – small colored boxes on stems
	var flower_colors: Array[Color] = [
		Color(0.9, 0.3, 0.4),   # Pink
		Color(1.0, 0.85, 0.2),  # Yellow
		Color(0.95, 0.95, 0.9), # White
		Color(0.6, 0.3, 0.7),   # Purple
		Color(1.0, 0.5, 0.2),   # Orange
	]

	var stem_w: float = 0.03
	var flower_w: float = 0.08
	var margin: float = 0.12

	# Place flowers in a grid pattern within the bed
	var cols: int = maxi(2, int(w / 0.25))
	var rows: int = maxi(2, int(w / 0.25))
	var spacing_x: float = (w - margin * 2) / float(cols)
	var spacing_z: float = (w - margin * 2) / float(rows)

	var color_idx: int = 0
	for row in range(rows):
		for col in range(cols):
			var fx: float = cx + margin + spacing_x * (float(col) + 0.5)
			var fz: float = cx + margin + spacing_z * (float(row) + 0.5)
			var stem_h: float = h * 0.5 + h * 0.4 * (0.7 + 0.3 * float((col + row) % 2))

			# Stem
			st.set_color(Color(0.2, 0.45, 0.15))
			_add_box(st, Vector3(fx - stem_w * 0.5, h * 0.4, fz - stem_w * 0.5), Vector3(stem_w, stem_h, stem_w))

			# Flower head
			st.set_color(flower_colors[color_idx % flower_colors.size()])
			_add_box(st,
				Vector3(fx - flower_w * 0.5, h * 0.4 + stem_h, fz - flower_w * 0.5),
				Vector3(flower_w, flower_w, flower_w))

			color_idx += 1


## ⛲ Fountain – basin walls + center pillar + water surface
static func _generate_fountain(st: SurfaceTool, size: Vector3, stone_col: Color, water_col: Color) -> void:
	var w: float = size.x  # 2.0
	var h: float = size.y  # 1.0
	var cx: float = -w * 0.5
	var wall: float = 0.15
	var basin_h: float = h * 0.4

	# Base platform
	st.set_color(stone_col.darkened(0.2))
	_add_box(st, Vector3(cx - 0.05, 0, cx - 0.05), Vector3(w + 0.1, 0.08, w + 0.1))

	# Basin walls (4 sides, forming a hollow square)
	st.set_color(stone_col)
	_add_box(st, Vector3(cx, 0.08, cx), Vector3(w, basin_h, wall))                         # Back wall
	_add_box(st, Vector3(cx, 0.08, cx + w - wall), Vector3(w, basin_h, wall))               # Front wall
	_add_box(st, Vector3(cx, 0.08, cx + wall), Vector3(wall, basin_h, w - wall * 2))        # Left wall
	_add_box(st, Vector3(cx + w - wall, 0.08, cx + wall), Vector3(wall, basin_h, w - wall * 2))  # Right wall

	# Rim on top of basin walls
	st.set_color(stone_col.lightened(0.1))
	var rim_h: float = 0.06
	var rim_extra: float = 0.04
	_add_box(st, Vector3(cx - rim_extra, 0.08 + basin_h, cx - rim_extra),
		Vector3(w + rim_extra * 2, rim_h, wall + rim_extra))
	_add_box(st, Vector3(cx - rim_extra, 0.08 + basin_h, cx + w - wall - rim_extra),
		Vector3(w + rim_extra * 2, rim_h, wall + rim_extra * 2))
	_add_box(st, Vector3(cx - rim_extra, 0.08 + basin_h, cx + wall),
		Vector3(wall + rim_extra, rim_h, w - wall * 2))
	_add_box(st, Vector3(cx + w - wall - rim_extra, 0.08 + basin_h, cx + wall),
		Vector3(wall + rim_extra * 2, rim_h, w - wall * 2))

	# Center pillar
	var pillar_w: float = 0.2
	st.set_color(stone_col.lightened(0.05))
	_add_box(st,
		Vector3(-pillar_w * 0.5, 0.08, -pillar_w * 0.5),
		Vector3(pillar_w, h * 0.85, pillar_w))

	# Pillar top ornament
	st.set_color(stone_col.lightened(0.15))
	_add_box(st,
		Vector3(-pillar_w * 0.8, h * 0.85, -pillar_w * 0.8),
		Vector3(pillar_w * 1.6, 0.06, pillar_w * 1.6))

	# Water surface base
	var water_inset: float = wall + 0.02
	var water_y: float = 0.08 + basin_h * 0.6
	st.set_color(water_col)
	_add_box(st,
		Vector3(cx + water_inset, water_y, cx + water_inset),
		Vector3(w - water_inset * 2, 0.02, w - water_inset * 2))

	# Water ripple rings – 2 concentric thin raised boxes
	var ripple_inset_1: float = water_inset + 0.06
	st.set_color(water_col.lightened(0.12))
	_add_box(st,
		Vector3(cx + ripple_inset_1, water_y + 0.015, cx + ripple_inset_1),
		Vector3(w - ripple_inset_1 * 2, 0.01, 0.025))  # Front ring segment
	_add_box(st,
		Vector3(cx + ripple_inset_1, water_y + 0.015, cx + w - ripple_inset_1 - 0.025),
		Vector3(w - ripple_inset_1 * 2, 0.01, 0.025))  # Back ring segment
	_add_box(st,
		Vector3(cx + ripple_inset_1, water_y + 0.015, cx + ripple_inset_1),
		Vector3(0.025, 0.01, w - ripple_inset_1 * 2))  # Left ring segment
	_add_box(st,
		Vector3(cx + w - ripple_inset_1 - 0.025, water_y + 0.015, cx + ripple_inset_1),
		Vector3(0.025, 0.01, w - ripple_inset_1 * 2))  # Right ring segment

	# Spray droplets above center pillar
	st.set_color(water_col.lightened(0.25))
	var spray_positions: Array[Vector2] = [
		Vector2(-0.08, 0.0), Vector2(0.08, 0.0), Vector2(0.0, -0.08), Vector2(0.0, 0.08)
	]
	for sp in spray_positions:
		_add_box(st, Vector3(sp.x - 0.02, h * 0.88, sp.y - 0.02), Vector3(0.04, 0.06, 0.04))


## 🚲 Bike Rack (Fahrradständer) – low metal bars against walls
static func _generate_bike_rack(st: SurfaceTool, size: Vector3, metal_col: Color, _accent_col: Color) -> void:
	var w: float = size.x  # 1.0
	var h: float = size.y  # 0.3
	var d: float = size.z  # 0.5
	var cx: float = -w * 0.5
	var cz: float = -d * 0.5

	st.set_color(metal_col.darkened(0.1))
	# Base rails (two parallel bars)
	var rail_h: float = 0.08
	var rail_d: float = 0.06
	_add_box(st, Vector3(cx, 0.02, cz + d * 0.2), Vector3(w, rail_h, rail_d))
	_add_box(st, Vector3(cx, 0.02, cz + d * 0.8 - rail_d), Vector3(w, rail_h, rail_d))

	# Vertical loops every 0.25 units
	st.set_color(metal_col)
	var loop_count: int = int(w / 0.25)
	for i in range(loop_count):
		var lx: float = cx + 0.15 + float(i) * (w - 0.3) / float(loop_count - 1)
		# U-shaped loop
		_add_box(st, Vector3(lx - 0.02, 0.02, cz + d * 0.15), Vector3(0.04, h * 0.7, 0.04))
		_add_box(st, Vector3(lx - 0.02, h * 0.7, cz + d * 0.15), Vector3(0.04, 0.04, d * 0.7))
		_add_box(st, Vector3(lx - 0.02, 0.02, cz + d * 0.85 - 0.04), Vector3(0.04, h * 0.7, 0.04))


## 📮 Mailbox (Briefkasten) – bright red/yellow post box
static func _generate_mailbox(st: SurfaceTool, size: Vector3, box_col: Color, post_col: Color) -> void:
	var w: float = size.x  # 0.25
	var h: float = size.y  # 0.6
	var cx: float = -w * 0.5

	st.set_color(post_col)
	# Post
	_add_box(st, Vector3(cx + w * 0.3, 0.0, cx + w * 0.3), Vector3(w * 0.4, h * 0.55, w * 0.4))

	st.set_color(box_col)
	# Main box body
	var box_h: float = h * 0.45
	var box_y: float = h * 0.55
	_add_box(st, Vector3(cx, box_y, cx), Vector3(w, box_h, w * 0.7))

	# Slot opening (dark inset)
	st.set_color(box_col.darkened(0.4))
	_add_box(st, Vector3(cx + w * 0.15, box_y + box_h * 0.65, cx + w * 0.7), Vector3(w * 0.7, 0.04, 0.02))

	# Little flag indicator
	st.set_color(Color(1.0, 0.9, 0.1))
	_add_box(st, Vector3(cx + w * 0.7, box_y + box_h * 0.3, cx + w * 0.2), Vector3(0.03, 0.15, 0.03))


## ☎️ Phone Booth (Telefonzelle) – tall glass + metal structure
static func _generate_phone_booth(st: SurfaceTool, size: Vector3, frame_col: Color, glass_col: Color) -> void:
	var w: float = size.x  # 0.5
	var h: float = size.y  # 1.8
	var cx: float = -w * 0.5

	st.set_color(frame_col)
	# Corner posts
	var post_w: float = 0.04
	_add_box(st, Vector3(cx, 0.0, cx), Vector3(post_w, h, post_w))
	_add_box(st, Vector3(cx + w - post_w, 0.0, cx), Vector3(post_w, h, post_w))
	_add_box(st, Vector3(cx, 0.0, cx + w - post_w), Vector3(post_w, h, post_w))
	_add_box(st, Vector3(cx + w - post_w, 0.0, cx + w - post_w), Vector3(post_w, h, post_w))

	# Top cap
	_add_box(st, Vector3(cx - 0.02, h - 0.08, cx - 0.02), Vector3(w + 0.04, 0.08, w + 0.04))

	# Roof overhang
	st.set_color(frame_col.darkened(0.1))
	_add_box(st, Vector3(cx - 0.04, h, cx - 0.04), Vector3(w + 0.08, 0.06, w + 0.08))

	# Glass panels (slightly transparent look via lighter color)
	st.set_color(glass_col.lightened(0.3))
	var glass_inset: float = post_w + 0.01
	var glass_h: float = h * 0.88
	# Front glass
	_add_box(st, Vector3(cx + glass_inset, post_w, cx + w - 0.015), Vector3(w - glass_inset * 2, glass_h, 0.015))
	# Back glass
	_add_box(st, Vector3(cx + glass_inset, post_w, cx), Vector3(w - glass_inset * 2, glass_h, 0.015))
	# Side glasses
	_add_box(st, Vector3(cx, post_w, cx + glass_inset), Vector3(0.015, glass_h, w - glass_inset * 2))
	_add_box(st, Vector3(cx + w - 0.015, post_w, cx + glass_inset), Vector3(0.015, glass_h, w - glass_inset * 2))


## 🔥 Fire Hydrant (Hydrant) – small red water fixture
static func _generate_fire_hydrant(st: SurfaceTool, size: Vector3, body_col: Color, cap_col: Color) -> void:
	var w: float = size.x  # 0.2
	var h: float = size.y  # 0.35
	var cx: float = -w * 0.5

	st.set_color(body_col)
	# Base flange
	_add_box(st, Vector3(cx - 0.02, 0.0, cx - 0.02), Vector3(w + 0.04, 0.04, w + 0.04))

	# Main body (slightly tapered)
	_add_box(st, Vector3(cx, 0.04, cx), Vector3(w, h * 0.7, w))

	# Top dome
	st.set_color(body_col.lightened(0.08))
	_add_box(st, Vector3(cx + w * 0.1, h * 0.7, cx + w * 0.1), Vector3(w * 0.8, h * 0.15, w * 0.8))

	# Side nozzles
	st.set_color(cap_col)
	_add_box(st, Vector3(cx + w, h * 0.4, cx + w * 0.3), Vector3(0.04, 0.06, 0.08))
	_add_box(st, Vector3(cx - 0.04, h * 0.4, cx + w * 0.3), Vector3(0.04, 0.06, 0.08))

	# Top nut
	_add_box(st, Vector3(cx + w * 0.35, h * 0.85, cx + w * 0.35), Vector3(w * 0.3, 0.06, w * 0.3))


## 🚧 Road Sign (Verkehrsschild) – post with octagonal sign
static func _generate_road_sign(st: SurfaceTool, size: Vector3, post_col: Color, sign_col: Color) -> void:
	var w: float = size.x  # 0.15
	var h: float = size.y  # 1.2
	var cx: float = -w * 0.5

	st.set_color(post_col)
	# Post
	_add_box(st, Vector3(cx + w * 0.3, 0.0, cx + w * 0.3), Vector3(w * 0.4, h * 0.6, w * 0.4))

	# Crossbar for sign
	_add_box(st, Vector3(cx - w * 0.5, h * 0.55, cx + w * 0.3), Vector3(w * 2.0, 0.04, w * 0.4))

	st.set_color(sign_col)
	# Octagonal stop sign approximation (square with corners)
	var sign_y: float = h * 0.65
	var sign_w: float = w * 3.0
	_add_box(st, Vector3(-sign_w * 0.4, sign_y, cx + w * 0.1), Vector3(sign_w * 0.8, sign_w * 0.8, 0.04))

	# White border stripe
	st.set_color(sign_col.lightened(0.6))
	_add_box(st, Vector3(-sign_w * 0.35, sign_y + sign_w * 0.05, cx + w * 0.1 + 0.01), Vector3(sign_w * 0.7, 0.03, 0.02))
	_add_box(st, Vector3(-sign_w * 0.35, sign_y + sign_w * 0.75, cx + w * 0.1 + 0.01), Vector3(sign_w * 0.7, 0.03, 0.02))
	_add_box(st, Vector3(-sign_w * 0.4, sign_y + sign_w * 0.05, cx + w * 0.1 + 0.01), Vector3(0.03, sign_w * 0.73, 0.02))
	_add_box(st, Vector3(sign_w * 0.37, sign_y + sign_w * 0.05, cx + w * 0.1 + 0.01), Vector3(0.03, sign_w * 0.73, 0.02))


## 🚦 Traffic Light (Ampel) – post with 3 colored boxes
static func _generate_traffic_light(st: SurfaceTool, size: Vector3, post_col: Color, housing_col: Color) -> void:
	var w: float = size.x  # 0.25
	var h: float = size.y  # 2.2
	var cx: float = -w * 0.5

	st.set_color(post_col)
	# Tall post
	_add_box(st, Vector3(cx + w * 0.3, 0.0, cx + w * 0.3), Vector3(w * 0.4, h * 0.7, w * 0.4))

	# Horizontal arm
	_add_box(st, Vector3(cx, h * 0.65, cx + w * 0.3), Vector3(w * 2.5, 0.06, w * 0.4))

	st.set_color(housing_col.darkened(0.2))
	# Light housing box
	var housing_y: float = h * 0.65
	var housing_h: float = h * 0.3
	_add_box(st, Vector3(cx + w * 1.5, housing_y, cx), Vector3(w * 0.8, housing_h, w * 0.5))

	# Three lights (red, yellow, green)
	var light_size: float = w * 0.5
	var light_spacing: float = housing_h / 3.0
	st.set_color(Color(0.8, 0.1, 0.1))  # Red
	_add_box(st, Vector3(cx + w * 1.65, housing_y + light_spacing * 2.2, cx + w * 0.5), Vector3(light_size, light_size * 0.8, 0.04))
	st.set_color(Color(0.9, 0.8, 0.1))  # Yellow
	_add_box(st, Vector3(cx + w * 1.65, housing_y + light_spacing * 1.2, cx + w * 0.5), Vector3(light_size, light_size * 0.8, 0.04))
	st.set_color(Color(0.1, 0.7, 0.2))  # Green
	_add_box(st, Vector3(cx + w * 1.65, housing_y + light_spacing * 0.2, cx + w * 0.5), Vector3(light_size, light_size * 0.8, 0.04))


## ⬜ Road Marking (Zebrastreifen) – flat painted strips
static func _generate_road_marking(st: SurfaceTool, size: Vector3, marking_col: Color, _bg_col: Color) -> void:
	var w: float = size.x  # 0.5
	var d: float = size.z  # 0.5
	var cx: float = -w * 0.5
	var cz: float = -d * 0.5

	st.set_color(marking_col)
	# Flat strip (very thin)
	_add_box(st, Vector3(cx, 0.0, cz), Vector3(w, 0.02, d))

	# Striped pattern for crosswalk
	var stripe_w: float = w / 5.0
	for i in range(5):
		var stripe_col: Color = marking_col.lightened(0.15) if i % 2 == 0 else marking_col.darkened(0.1)
		st.set_color(stripe_col)
		_add_box(st, Vector3(cx + float(i) * stripe_w, 0.005, cz), Vector3(stripe_w * 0.8, 0.025, d))


## 🎓 Blackboard (Tafel/Kreidetafel) – small blackboard on post
static func _generate_blackboard(st: SurfaceTool, size: Vector3, frame_col: Color, board_col: Color) -> void:
	var w: float = size.x  # 0.5
	var h: float = size.y  # 0.8
	var cx: float = -w * 0.5

	st.set_color(frame_col)
	# Stand legs (A-frame)
	var leg_w: float = 0.04
	_add_box(st, Vector3(cx + w * 0.1, 0.0, cx + w * 0.2), Vector3(leg_w, h * 0.6, leg_w))
	_add_box(st, Vector3(cx + w * 0.9 - leg_w, 0.0, cx + w * 0.2), Vector3(leg_w, h * 0.6, leg_w))
	_add_box(st, Vector3(cx + w * 0.1, 0.0, cx + w * 0.8 - leg_w), Vector3(leg_w, h * 0.6, leg_w))
	_add_box(st, Vector3(cx + w * 0.9 - leg_w, 0.0, cx + w * 0.8 - leg_w), Vector3(leg_w, h * 0.6, leg_w))

	# Crossbar at top
	_add_box(st, Vector3(cx + w * 0.1, h * 0.5, cx + w * 0.2), Vector3(w * 0.8, leg_w, w * 0.6))

	st.set_color(board_col)
	# Blackboard surface
	_add_box(st, Vector3(cx + w * 0.05, h * 0.15, cx + w * 0.1), Vector3(w * 0.9, h * 0.5, 0.03))

	# Chalk tray
	st.set_color(frame_col.darkened(0.1))
	_add_box(st, Vector3(cx + w * 0.05, h * 0.12, cx + w * 0.1), Vector3(w * 0.9, 0.03, w * 0.15))


## 📚 Book Stack (Bücherstapel) – small decorative books
static func _generate_book_stack(st: SurfaceTool, size: Vector3, _cover_col: Color, page_col: Color) -> void:
	var w: float = size.x  # 0.3
	var d: float = size.z  # 0.4
	var h: float = size.y  # 0.25
	var cx: float = -w * 0.5
	var cz: float = -d * 0.5

	# Stack of 3 books
	var book_colors: Array[Color] = [
		Color(0.6, 0.2, 0.2),  # Red
		Color(0.2, 0.4, 0.6),  # Blue
		Color(0.3, 0.5, 0.3),  # Green
	]

	var current_h: float = 0.0
	for i in range(3):
		var book_h: float = h / 3.0 * (0.9 + randf() * 0.2)
		var book_w: float = w * (0.95 + randf() * 0.1)
		var book_d: float = d * (0.95 + randf() * 0.1)
		var offset_x: float = (w - book_w) * 0.5 + (randf() - 0.5) * 0.02
		var offset_z: float = (d - book_d) * 0.5 + (randf() - 0.5) * 0.02

		st.set_color(book_colors[i])
		_add_box(st, Vector3(cx + offset_x, current_h, cz + offset_z), Vector3(book_w, book_h, book_d))

		# Page edges (lighter strip)
		st.set_color(page_col)
		_add_box(st, Vector3(cx + offset_x + book_w - 0.01, current_h + book_h * 0.1, cz + offset_z + 0.02),
			Vector3(0.015, book_h * 0.8, book_d - 0.04))

		current_h += book_h


## 🌍 Globe on Pedestal (Globus auf Sockel) – landmark prop
static func _generate_globe_pedestal(st: SurfaceTool, size: Vector3, stone_col: Color, globe_col: Color) -> void:
	var w: float = size.x  # 1.0
	var h: float = size.y  # 1.5
	var cx: float = -w * 0.5

	st.set_color(stone_col)
	# Base platform
	_add_box(st, Vector3(cx - 0.05, 0.0, cx - 0.05), Vector3(w + 0.1, 0.08, w + 0.1))

	# Pedestal column
	var col_w: float = w * 0.35
	_add_box(st, Vector3(-col_w * 0.5, 0.08, -col_w * 0.5), Vector3(col_w, h * 0.4, col_w))

	# Capital
	_add_box(st, Vector3(cx, h * 0.4, cx), Vector3(w * 0.5, 0.06, w * 0.5))

	# Globe sphere approximation (stacked boxes)
	var globe_y: float = h * 0.5
	var globe_r: float = w * 0.35
	st.set_color(globe_col)
	_add_box(st, Vector3(-globe_r, globe_y, -globe_r), Vector3(globe_r * 2, globe_r * 1.8, globe_r * 2))

	# Continents (darker patches)
	st.set_color(globe_col.darkened(0.3))
	_add_box(st, Vector3(-globe_r * 0.5, globe_y + globe_r * 0.5, globe_r - 0.02), Vector3(globe_r, globe_r * 0.6, 0.03))
	_add_box(st, Vector3(globe_r * 0.2, globe_y + globe_r * 0.3, -globe_r + 0.02), Vector3(globe_r * 0.7, globe_r * 0.4, 0.03))

	# Axis rod
	st.set_color(stone_col.lightened(0.2))
	_add_box(st, Vector3(-0.015, globe_y + globe_r * 1.8, -0.015), Vector3(0.03, globe_r * 0.4, 0.03))


## 💡 Park Lamp (Laterne) – shorter decorative lamp
static func _generate_park_lamp(st: SurfaceTool, size: Vector3, post_col: Color, lantern_col: Color) -> void:
	var w: float = size.x  # 0.25
	var h: float = size.y  # 1.4
	var cx: float = -w * 0.5

	st.set_color(post_col)
	# Decorative base
	_add_box(st, Vector3(cx - 0.02, 0.0, cx - 0.02), Vector3(w + 0.04, 0.06, w + 0.04))

	# Ornate post
	var post_w: float = w * 0.5
	_add_box(st, Vector3(-post_w * 0.5, 0.06, -post_w * 0.5), Vector3(post_w, h * 0.7, post_w))

	# Curved arm
	_add_box(st, Vector3(cx, h * 0.65, cx), Vector3(w * 1.5, 0.04, w * 0.5))

	st.set_color(lantern_col)
	# Lantern housing
	var lantern_y: float = h * 0.75
	var lantern_h: float = h * 0.25
	_add_box(st, Vector3(cx + w * 0.5, lantern_y, cx), Vector3(w * 0.6, lantern_h, w * 0.6))

	# Lantern top
	st.set_color(post_col)
	_add_box(st, Vector3(cx + w * 0.45, lantern_y + lantern_h, cx - 0.02), Vector3(w * 0.7, 0.04, w * 0.64))

	# Light source (glow)
	st.set_color(Color(1.0, 0.95, 0.7))
	_add_box(st, Vector3(cx + w * 0.6, lantern_y + lantern_h * 0.2, cx + w * 0.15), Vector3(w * 0.3, lantern_h * 0.6, w * 0.3))


## 🍽️ Picnic Table (Picknicktisch) – table with two benches
static func _generate_picnic_table(st: SurfaceTool, size: Vector3, wood_col: Color, bench_col: Color) -> void:
	var w: float = size.x  # 1.2
	var h: float = size.y  # 0.75
	var d: float = size.z  # 1.0
	var cx: float = -w * 0.5
	var cz: float = -d * 0.5

	st.set_color(wood_col)
	# Table top
	var table_h: float = h * 0.7
	_add_box(st, Vector3(cx + w * 0.1, table_h, cz + d * 0.3), Vector3(w * 0.8, 0.05, d * 0.4))

	# A-frame legs for table
	var leg_w: float = 0.04
	_add_box(st, Vector3(cx + w * 0.2, 0.0, cz + d * 0.35), Vector3(leg_w, table_h, leg_w))
	_add_box(st, Vector3(cx + w * 0.8 - leg_w, 0.0, cz + d * 0.35), Vector3(leg_w, table_h, leg_w))
	_add_box(st, Vector3(cx + w * 0.2, 0.0, cz + d * 0.65 - leg_w), Vector3(leg_w, table_h, leg_w))
	_add_box(st, Vector3(cx + w * 0.8 - leg_w, 0.0, cz + d * 0.65 - leg_w), Vector3(leg_w, table_h, leg_w))

	st.set_color(bench_col)
	# Two benches
	var bench_h: float = h * 0.4
	var bench_d: float = d * 0.2
	# Left bench
	_add_box(st, Vector3(cx + w * 0.1, bench_h, cz + d * 0.05), Vector3(w * 0.8, 0.04, bench_d))
	# Right bench
	_add_box(st, Vector3(cx + w * 0.1, bench_h, cz + d * 0.75), Vector3(w * 0.8, 0.04, bench_d))

	# Bench supports
	_add_box(st, Vector3(cx + w * 0.25, 0.0, cz + d * 0.1), Vector3(leg_w, bench_h, leg_w))
	_add_box(st, Vector3(cx + w * 0.75, 0.0, cz + d * 0.1), Vector3(leg_w, bench_h, leg_w))
	_add_box(st, Vector3(cx + w * 0.25, 0.0, cz + d * 0.9 - leg_w), Vector3(leg_w, bench_h, leg_w))
	_add_box(st, Vector3(cx + w * 0.75, 0.0, cz + d * 0.9 - leg_w), Vector3(leg_w, bench_h, leg_w))


## 🏖️ Sandbox (Sandkasten) – low box with sand
static func _generate_sandbox(st: SurfaceTool, size: Vector3, frame_col: Color, sand_col: Color) -> void:
	var w: float = size.x  # 0.8
	var h: float = size.y  # 0.15
	var cx: float = -w * 0.5

	st.set_color(frame_col)
	# Wooden frame (4 sides)
	var frame_thick: float = 0.04
	_add_box(st, Vector3(cx, 0.0, cx), Vector3(w, frame_thick, frame_thick))
	_add_box(st, Vector3(cx, 0.0, cx + w - frame_thick), Vector3(w, frame_thick, frame_thick))
	_add_box(st, Vector3(cx, 0.0, cx + frame_thick), Vector3(frame_thick, frame_thick, w - frame_thick * 2))
	_add_box(st, Vector3(cx + w - frame_thick, 0.0, cx + frame_thick), Vector3(frame_thick, frame_thick, w - frame_thick * 2))

	# Corner posts
	var post_h: float = h * 1.5
	_add_box(st, Vector3(cx, frame_thick, cx), Vector3(frame_thick, post_h, frame_thick))
	_add_box(st, Vector3(cx + w - frame_thick, frame_thick, cx), Vector3(frame_thick, post_h, frame_thick))
	_add_box(st, Vector3(cx, frame_thick, cx + w - frame_thick), Vector3(frame_thick, post_h, frame_thick))
	_add_box(st, Vector3(cx + w - frame_thick, frame_thick, cx + w - frame_thick), Vector3(frame_thick, post_h, frame_thick))

	st.set_color(sand_col)
	# Sand fill
	_add_box(st, Vector3(cx + frame_thick, frame_thick, cx + frame_thick),
		Vector3(w - frame_thick * 2, h * 0.7, w - frame_thick * 2))


## 🎠 Swing Set (Schaukel) – A-frame with hanging seats
static func _generate_swing_set(st: SurfaceTool, size: Vector3, frame_col: Color, seat_col: Color) -> void:
	var w: float = size.x  # 1.5
	var h: float = size.y  # 1.8
	var d: float = size.z  # 0.8
	var cx: float = -w * 0.5
	var cz: float = -d * 0.5

	st.set_color(frame_col)
	# A-frame legs (left side)
	var leg_w: float = 0.05
	_add_box(st, Vector3(cx, 0.0, cz), Vector3(leg_w, h, leg_w))
	_add_box(st, Vector3(cx + w * 0.15, 0.0, cz + d - leg_w), Vector3(leg_w, h, leg_w))

	# A-frame legs (right side)
	_add_box(st, Vector3(cx + w - leg_w, 0.0, cz), Vector3(leg_w, h, leg_w))
	_add_box(st, Vector3(cx + w * 0.85, 0.0, cz + d - leg_w), Vector3(leg_w, h, leg_w))

	# Crossbar at top
	_add_box(st, Vector3(cx, h * 0.95, cz + d * 0.1), Vector3(w, leg_w, leg_w))

	# Support struts
	_add_box(st, Vector3(cx + w * 0.08, h * 0.3, cz + d * 0.4), Vector3(leg_w, leg_w, d * 0.5))
	_add_box(st, Vector3(cx + w * 0.92 - leg_w, h * 0.3, cz + d * 0.4), Vector3(leg_w, leg_w, d * 0.5))

	st.set_color(Color(0.4, 0.4, 0.4))
	# Chains (thin vertical lines)
	var chain_x: float = cx + w * 0.35
	_add_box(st, Vector3(chain_x, h * 0.4, cz + d * 0.5), Vector3(0.01, h * 0.55, 0.01))
	_add_box(st, Vector3(chain_x + 0.05, h * 0.4, cz + d * 0.5), Vector3(0.01, h * 0.55, 0.01))
	var chain_x2: float = cx + w * 0.65
	_add_box(st, Vector3(chain_x2, h * 0.4, cz + d * 0.5), Vector3(0.01, h * 0.55, 0.01))
	_add_box(st, Vector3(chain_x2 + 0.05, h * 0.4, cz + d * 0.5), Vector3(0.01, h * 0.55, 0.01))

	st.set_color(seat_col)
	# Swing seats
	_add_box(st, Vector3(chain_x - 0.02, h * 0.4, cz + d * 0.5 - 0.08), Vector3(0.09, 0.03, 0.16))
	_add_box(st, Vector3(chain_x2 - 0.02, h * 0.4, cz + d * 0.5 - 0.08), Vector3(0.09, 0.03, 0.16))


## 💧 Small Fountain (Springbrunnen klein) – tiered fountain
static func _generate_small_fountain(st: SurfaceTool, size: Vector3, stone_col: Color, water_col: Color) -> void:
	var w: float = size.x  # 1.0
	var h: float = size.y  # 0.6
	var cx: float = -w * 0.5

	st.set_color(stone_col.darkened(0.1))
	# Base platform
	_add_box(st, Vector3(cx - 0.03, 0.0, cx - 0.03), Vector3(w + 0.06, 0.06, w + 0.06))

	st.set_color(stone_col)
	# Lower basin
	var basin_h: float = h * 0.35
	var wall_thick: float = 0.06
	_add_box(st, Vector3(cx, 0.06, cx), Vector3(w, basin_h, wall_thick))
	_add_box(st, Vector3(cx, 0.06, cx + w - wall_thick), Vector3(w, basin_h, wall_thick))
	_add_box(st, Vector3(cx, 0.06, cx + wall_thick), Vector3(wall_thick, basin_h, w - wall_thick * 2))
	_add_box(st, Vector3(cx + w - wall_thick, 0.06, cx + wall_thick), Vector3(wall_thick, basin_h, w - wall_thick * 2))

	# Center pedestal
	var ped_w: float = w * 0.25
	_add_box(st, Vector3(-ped_w * 0.5, 0.06, -ped_w * 0.5), Vector3(ped_w, h * 0.7, ped_w))

	# Upper basin
	var upper_y: float = h * 0.55
	var upper_w: float = w * 0.6
	var upper_h: float = h * 0.25
	_add_box(st, Vector3(-upper_w * 0.5, upper_y, -upper_w * 0.5), Vector3(upper_w, upper_h, upper_w * 0.15))
	_add_box(st, Vector3(-upper_w * 0.5, upper_y, upper_w * 0.5 - upper_w * 0.15), Vector3(upper_w, upper_h, upper_w * 0.15))
	_add_box(st, Vector3(-upper_w * 0.5, upper_y, -upper_w * 0.5 + upper_w * 0.15), Vector3(upper_w * 0.15, upper_h, upper_w * 0.7))
	_add_box(st, Vector3(upper_w * 0.5 - upper_w * 0.15, upper_y, -upper_w * 0.5 + upper_w * 0.15), Vector3(upper_w * 0.15, upper_h, upper_w * 0.7))

	st.set_color(water_col)
	# Water surface in lower basin
	_add_box(st, Vector3(cx + wall_thick + 0.02, 0.06 + basin_h * 0.6, cx + wall_thick + 0.02),
		Vector3(w - wall_thick * 2 - 0.04, 0.015, w - wall_thick * 2 - 0.04))

	# Water in upper basin
	_add_box(st, Vector3(-upper_w * 0.5 + upper_w * 0.15 + 0.02, upper_y + upper_h * 0.6, -upper_w * 0.5 + upper_w * 0.15 + 0.02),
		Vector3(upper_w * 0.7 - 0.04, 0.015, upper_w * 0.7 - 0.04))

	# Water spout
	st.set_color(water_col.lightened(0.2))
	_add_box(st, Vector3(-0.02, upper_y + upper_h, -0.02), Vector3(0.04, h * 0.08, 0.04))

#endregion
