class_name TreeInstanceData
extends Resource

## Konkreter Baum in der Welt. Spaeter speicherbar, noch ohne Save-System.

@export var tree_type: StringName = &"oak"
@export var base_cell: Vector2i = Vector2i.ZERO
@export var height: int = 1
@export var target_height: int = 5
@export var trunk_cells: Array[Vector2i] = []
@export var leaf_cells: Array[Vector2i] = []
@export var growth_stage: int = 4
@export var damaged: bool = false
@export var planted: bool = false

var regrow_left: float = -1.0
var grow_left: float = -1.0
