extends Node

## Network Manager
##
## Handles multiplayer connection, hosting, and joining.
## Server-authoritative architecture for world state.
##
## Usage:
##   NetworkManager.host_game() - Start as server
##   NetworkManager.join_game("127.0.0.1") - Connect to server
##   NetworkManager.disconnect_game() - Leave/stop game

# Connection signals
signal connection_established()
signal connection_failed()
signal server_disconnected()
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)

# Game state signals (for future lobby system)
@warning_ignore("unused_signal")
signal game_started()
@warning_ignore("unused_signal")
signal game_ended()

# Network configuration
const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4
const _DEBUG := false # Set to true for network debugging

# Connection state
enum ConnectionState {DISCONNECTED, CONNECTING, CONNECTED, HOSTING}
var state: ConnectionState = ConnectionState.DISCONNECTED

# Player tracking
var players: Dictionary = {} # peer_id -> PlayerData
var local_peer_id: int = 0

# Internal references
var _peer: ENetMultiplayerPeer = null


func _ready() -> void:
	# Connect to MultiplayerAPI signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Host a new game server
func host_game(port: int = DEFAULT_PORT) -> Error:
	if state != ConnectionState.DISCONNECTED:
		push_warning("NetworkManager: Already connected or hosting")
		return ERR_ALREADY_IN_USE
	
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(port, MAX_PLAYERS)
	
	if error != OK:
		push_error("NetworkManager: Failed to create server: %s" % error_string(error))
		_peer = null
		return error
	
	multiplayer.multiplayer_peer = _peer
	state = ConnectionState.HOSTING
	local_peer_id = 1 # Server is always peer 1
	
	# Register host as player
	_register_player(local_peer_id)
	
	if _DEBUG:
		print("NetworkManager: Server started on port %d" % port)
	connection_established.emit()
	return OK


## Join an existing game
func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	if state != ConnectionState.DISCONNECTED:
		push_warning("NetworkManager: Already connected or hosting")
		return ERR_ALREADY_IN_USE
	
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address, port)
	
	if error != OK:
		push_error("NetworkManager: Failed to connect: %s" % error_string(error))
		_peer = null
		return error
	
	multiplayer.multiplayer_peer = _peer
	state = ConnectionState.CONNECTING

	if _DEBUG:
		print("NetworkManager: Connecting to %s:%d..." % [address, port])
	return OK


## Disconnect from current game
func disconnect_game() -> void:
	if state == ConnectionState.DISCONNECTED:
		return
	
	players.clear()
	local_peer_id = 0
	
	if _peer:
		_peer.close()
		_peer = null
	
	multiplayer.multiplayer_peer = null
	state = ConnectionState.DISCONNECTED

	if _DEBUG:
		print("NetworkManager: Disconnected")


## Check if this instance is the server/host
func is_server() -> bool:
	return state == ConnectionState.HOSTING


## Check if connected to a game (as client or host)
func is_connected_to_game() -> bool:
	return state == ConnectionState.CONNECTED or state == ConnectionState.HOSTING


## Get all connected peer IDs (including self)
func get_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	for id in players.keys():
		ids.append(id)
	return ids


# --- Internal Methods ---

func _register_player(peer_id: int) -> void:
	if not players.has(peer_id):
		players[peer_id] = {"peer_id": peer_id}
		if _DEBUG:
			print("NetworkManager: Player registered: %d" % peer_id)


func _unregister_player(peer_id: int) -> void:
	if players.has(peer_id):
		players.erase(peer_id)
		if _DEBUG:
			print("NetworkManager: Player unregistered: %d" % peer_id)


# --- Signal Callbacks ---

func _on_peer_connected(peer_id: int) -> void:
	if _DEBUG:
		print("NetworkManager: Peer connected: %d" % peer_id)
	_register_player(peer_id)
	player_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if _DEBUG:
		print("NetworkManager: Peer disconnected: %d" % peer_id)
	_unregister_player(peer_id)
	player_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	state = ConnectionState.CONNECTED
	local_peer_id = multiplayer.get_unique_id()
	_register_player(local_peer_id)
	if _DEBUG:
		print("NetworkManager: Connected to server as peer %d" % local_peer_id)
	connection_established.emit()


func _on_connection_failed() -> void:
	state = ConnectionState.DISCONNECTED
	_peer = null
	multiplayer.multiplayer_peer = null
	if _DEBUG:
		print("NetworkManager: Connection failed")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	var was_connected := state == ConnectionState.CONNECTED
	disconnect_game()
	if was_connected:
		if _DEBUG:
			print("NetworkManager: Server disconnected")
		server_disconnected.emit()
