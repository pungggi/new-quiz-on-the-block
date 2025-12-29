extends RefCounted
class_name CharacterPreviewBuilder

## Builds a 3D character preview for the editor
## Now delegates to BlockyCharacterBuilder for unified character creation

func build_character(root: Node3D, customization: PlayerCustomization) -> void:
	# Delegate to BlockyCharacterBuilder
	BlockyCharacterBuilder.build_from_customization(root, customization)
