class_name PlayerAudio
extends Node

## Gehoert an: Player/Audio in res://scenes/player/player.tscn
##
## Pro Kategorie ein eigener AudioStreamPlayer. Ein einzelner Player wuerde
## sich sonst selbst abschneiden, sobald z.B. waehrend des Minings ein Item
## aufgesammelt wird. Die Streams und Lautstaerken haengen in der Szene.

## Zufaellige Tonhoehen-Streuung, damit Wiederholungen nicht mechanisch klingen.
@export var pitch_variation: float = 0.08

## Lautstaerke aus der Szene. Ohne die Kopie wuerde ein einmaliger Offset
## (z.B. leisere Schleichschritte) den Szenenwert dauerhaft verschieben.
var _base_volume_db: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		var player := child as AudioStreamPlayer
		if player != null:
			_base_volume_db[player.name] = player.volume_db


func play(sound: StringName, volume_offset_db: float = 0.0) -> void:
	var player := get_node_or_null(NodePath(String(sound))) as AudioStreamPlayer
	if player == null or player.stream == null:
		return
	player.volume_db = float(_base_volume_db.get(player.name, 0.0)) + volume_offset_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
