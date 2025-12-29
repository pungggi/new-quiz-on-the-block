extends Node

## Global event bus for decoupled communication between systems.
## Signals are organized by category for clarity.

# --- World Events ---
@warning_ignore("unused_signal")
signal chunk_data_changed(chunk_x: int, chunk_z: int)
@warning_ignore("unused_signal")
signal spawn_chunk_requested(chunk_x: int, chunk_z: int)

# --- Building Events (Multiplayer-ready) ---
@warning_ignore("unused_signal")
signal block_placed(position: Vector3i, block_type: int, player_id: int)
@warning_ignore("unused_signal")
signal block_removed(position: Vector3i, player_id: int)

# --- Quiz Events (Multiplayer-ready) ---
@warning_ignore("unused_signal")
signal quiz_question_requested(player_id: int, category: String)
@warning_ignore("unused_signal")
signal quiz_answer_submitted(player_id: int, question_id: String, answer_index: int)
@warning_ignore("unused_signal")
signal quiz_result_received(player_id: int, was_correct: bool, reward: int)

# --- Player Events ---
@warning_ignore("unused_signal")
signal player_joined(player_id: int, player_name: String)
@warning_ignore("unused_signal")
signal player_left(player_id: int)
