@tool
class_name AnimalDefinition
extends Resource

## Registriertes Wildtier fuer Spawn/Admin. Keine Gameplay-Logik.

@export var id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
@export var data: AnimalData
@export var icon: Texture2D
