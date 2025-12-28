extends SceneTree

# Prints small API summaries to the output, then quits.
# Usage (from project root):
#   godot --headless --script res://scripts/tools/api_probe.gd

func _init() -> void:
	_print_class_summary(&"Camera3D")
	_print_class_summary(&"SpringArm3D")
	_print_class_summary(&"Input")
	_print_class_summary(&"Viewport")
	_print_class_summary(&"Node3D")

	print("\nMouse wheel constants:")
	print("  MOUSE_BUTTON_WHEEL_UP = %s" % str(MOUSE_BUTTON_WHEEL_UP))
	print("  MOUSE_BUTTON_WHEEL_DOWN = %s" % str(MOUSE_BUTTON_WHEEL_DOWN))

	quit(0)


func _print_class_summary(cn: StringName) -> void:
	var method_list: Array = ClassDB.class_get_method_list(cn)
	var property_list: Array = ClassDB.class_get_property_list(cn)

	print("\n=== %s ===" % String(cn))
	print("methods: %d" % method_list.size())
	print("properties: %d" % property_list.size())

	print("first methods:")
	for i in range(mini(20, method_list.size())):
		var m: Dictionary = method_list[i]
		print("  - %s" % str(m.get("name", "<unknown>")))

	print("first properties:")
	for i in range(mini(20, property_list.size())):
		var p: Dictionary = property_list[i]
		print("  - %s" % str(p.get("name", "<unknown>")))


func mini(a: int, b: int) -> int:
	return a if a < b else b
