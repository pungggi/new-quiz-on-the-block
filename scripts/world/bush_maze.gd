class_name BushMaze
extends Node3D

## Hedge labyrinth west of spawn: a deterministic (fixed seed) maze from
## a recursive backtracker. Hedges are HEDGE_H high - low enough that
## impatient kids simply jump over them (player jump apex is ~0.9). The
## hedge grid is a STATIC query so prop scatter and the build cursor
## keep the footprint clear without needing a live instance.

## Footprint min corner (block coordinates)
const ORIGIN: Vector2i = Vector2i(-46, -38)
const CELLS_X: int = 9
const CELLS_Z: int = 7
const GRID_W: int = CELLS_X * 2 + 1
const GRID_H: int = CELLS_Z * 2 + 1
## Must stay below the player's jump apex (~0.9)
const HEDGE_H: float = 0.75
const SEED: int = 20261123

const LEAF := Color(0.27, 0.49, 0.2)
const LEAF_TOP := Color(0.38, 0.63, 0.26)

## Local block -> true when a hedge bush stands there (lazily built)
static var _hedges: Dictionary = {}


static func is_in_maze(world_x: int, world_z: int) -> bool:
	var lx: int = world_x - ORIGIN.x
	var lz: int = world_z - ORIGIN.y
	return lx >= 0 and lx < GRID_W and lz >= 0 and lz < GRID_H


static func is_hedge_at(world_x: int, world_z: int) -> bool:
	if not is_in_maze(world_x, world_z):
		return false
	_ensure_grid()
	return _hedges.has(Vector2i(world_x - ORIGIN.x, world_z - ORIGIN.y))


## Build the hedge grid once: start fully walled, carve passages cell to
## cell with a seeded recursive backtracker, then punch entrance and
## exit through the west/east boundary.
static func _ensure_grid() -> void:
	if not _hedges.is_empty():
		return
	var grid: Dictionary = {}
	for x: int in range(GRID_W):
		for z: int in range(GRID_H):
			grid[Vector2i(x, z)] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var visited: Dictionary = {Vector2i(0, 0): true}
	grid.erase(Vector2i(1, 1))
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	while not stack.is_empty():
		var cell: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + d
			if n.x >= 0 and n.x < CELLS_X and n.y >= 0 and n.y < CELLS_Z and not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		visited[next] = true
		stack.append(next)
		# Clear the target cell block and the wall in between (one block
		# towards the neighbor in block coordinates)
		var cell_block: Vector2i = Vector2i(cell.x * 2 + 1, cell.y * 2 + 1)
		var step: Vector2i = next - cell
		grid.erase(cell_block + step)
		grid.erase(Vector2i(next.x * 2 + 1, next.y * 2 + 1))
	# Entrance (west) and exit (east) through the middle of the boundary
	grid.erase(Vector2i(0, CELLS_Z))
	grid.erase(Vector2i(GRID_W - 1, CELLS_Z))
	_hedges = grid


func _ready() -> void:
	_ensure_grid()
	_build_mesh()


## Visual: one leafy box per hedge block with color jitter. Colliders:
## one box per horizontal hedge run so the shape stays cheap.
func _build_mesh() -> void:
	var body := StaticBody3D.new()
	body.name = "Hedges"
	body.collision_layer = Config.PROP_COLLISION_LAYER
	add_child(body)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	for lz: int in range(GRID_H):
		var run_start: int = -1
		for lx: int in range(GRID_W + 1):
			var hedge: bool = lx < GRID_W and _hedges.has(Vector2i(lx, lz))
			if hedge and run_start < 0:
				run_start = lx
			elif not hedge and run_start >= 0:
				_add_run(st, body, run_start, lx - 1, lz, rng)
				run_start = -1
	var mi := MeshInstance3D.new()
	mi.name = "HedgeMesh"
	mi.mesh = st.commit()
	mi.material_override = VertexColorMaterial.make()
	add_child(mi)


func _add_run(st: SurfaceTool, body: StaticBody3D, lx0: int, lx1: int, lz: int, rng: RandomNumberGenerator) -> void:
	var wx0: float = float(ORIGIN.x + lx0)
	var wz: float = float(ORIGIN.y + lz)
	var length: float = float(lx1 - lx0 + 1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, HEDGE_H, 1.0)
	shape.shape = box
	shape.position = Vector3(wx0 + length * 0.5, Config.GROUND_Y + HEDGE_H * 0.5, wz + 0.5)
	body.add_child(shape)
	for lx: int in range(lx0, lx1 + 1):
		var j: float = rng.randf_range(-0.05, 0.05)
		var c := Color(LEAF.r + j, LEAF.g + j, LEAF.b + j * 0.5)
		SurfaceBoxes.add_box(st,
			Vector3(float(ORIGIN.x + lx), Config.GROUND_Y, wz),
			Vector3(float(ORIGIN.x + lx) + 1.0, Config.GROUND_Y + HEDGE_H, wz + 1.0),
			c, LEAF_TOP.lerp(c, 0.4), false)
