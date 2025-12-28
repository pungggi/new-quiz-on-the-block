extends Node

func _enter_tree() -> void:
    # The GDAI MCP runtime server is only needed for editor tooling.
    # Avoid starting it in exported/game/headless runs (e.g. CI smoke tests).
    if not Engine.is_editor_hint():
        return

    const RUNTIME_SERVER = "GDAIRuntimeServer"
    if ClassDB.class_exists(RUNTIME_SERVER) and ClassDB.can_instantiate(RUNTIME_SERVER):
        var runtime_server = ClassDB.instantiate(RUNTIME_SERVER)
        add_child(runtime_server)
