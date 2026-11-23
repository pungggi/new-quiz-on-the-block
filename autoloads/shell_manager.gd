extends Node

## Shell Manager (Autoload)
##
## Beachcombing economy: shells wash ashore on the beach as pickups,
## walking over them collects them into the player profile, and the
## shell stand trades them for coins. ProfileManager owns the numbers
## (they persist with the profile); this autoload owns the beach life.

signal shells_changed(count: int)
signal coins_changed(amount: int)

const SHELLS_ON_BEACH: int = 24 ## live pickups at any time
const RESPAWN_DELAY: float = 18.0 ## until a new shell washes ashore
const COINS_PER_SHELL: int = 2
## Beach scatter window along the coast (world z blocks)
const BEACH_Z_RANGE: Vector2i = Vector2i(-60, 60)

var _root: Node3D = null


func initialize(root: Node3D) -> void:
	if _root:
		return
	_root = root
	# One guaranteed shell right next to the stand so first-time
	# beachcombers discover the pickup mechanic immediately (the
	# Tauschbude lives at ~119.5 / -16)
	var first := ShellPickup.new()
	first.position = Vector3(117.5, 1.0, -14.5)
	first.collected.connect(_on_shell_collected)
	_root.add_child(first)
	for i: int in range(SHELLS_ON_BEACH):
		_spawn_shell()


func get_shells() -> int:
	return ProfileManager.get_shells()


func get_coins() -> int:
	return ProfileManager.get_coins()


## Trade every collected shell for coins; returns the payout (0 when
## the basket is empty)
func exchange_all() -> int:
	var shells: int = ProfileManager.get_shells()
	if shells <= 0:
		return 0
	var payout: int = shells * COINS_PER_SHELL
	ProfileManager.add_coins(payout)
	ProfileManager.add_shells(-shells)
	shells_changed.emit(get_shells())
	coins_changed.emit(get_coins())
	return payout


func _spawn_shell() -> void:
	if _root == null or not is_inside_tree():
		return
	var pickup := ShellPickup.new()
	pickup.position = _random_beach_position()
	pickup.collected.connect(_on_shell_collected)
	_root.add_child(pickup)


func _on_shell_collected(pos: Vector3) -> void:
	ProfileManager.add_shells(1)
	shells_changed.emit(get_shells())
	Effects.spawn_floating_text(pos + Vector3.UP * 0.8, "+1 🐚", Color(1.0, 0.7, 0.78))
	AudioManager.play_sfx(AudioManager.SFX.POINTS_GAIN)
	# A new shell washes ashore a little later
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_spawn_shell)


## Dry-sand block range between the meadow and the waterline (derived
## from the same constants the terrain uses)
func _dry_sand_x_range() -> Vector2i:
	var x_min: int = Config.WORLD_MAX_BLOCK - WorldManager.COAST_WIDTH
	var x_max: int = Config.WORLD_MAX_BLOCK - (WorldManager.COAST_WIDTH - WorldManager.BEACH_WIDTH) - 1
	return Vector2i(x_min, x_max)


## Random dry-sand spot on the beach
func _random_beach_position() -> Vector3:
	var x_range: Vector2i = _dry_sand_x_range()
	for i: int in range(12):
		var x: int = randi_range(x_range.x, x_range.y)
		var z: int = randi_range(BEACH_Z_RANGE.x, BEACH_Z_RANGE.y)
		var col: Dictionary = WorldManager.terrain_column(x, z)
		if col["top"] == Config.VoxelType.SAND and not col["water"]:
			return Vector3(float(x) + 0.5, 1.0, float(z) + 0.5)
	return Vector3(float(x_range.y) + 0.5, 1.0, 0.0)
