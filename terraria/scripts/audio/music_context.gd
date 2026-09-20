@tool
class_name MusicContext
extends RefCounted

## Aktueller Musikzustand. Neue Felder hier ergaenzen, dann Tracks im Catalog matchen.

var scene: StringName = &"menu"
var biome: StringName = &"grassland"
var day_phase: StringName = &"morning"
var depth_layer: StringName = &"surface"
var fog_state: StringName = &"clear"
var interior: StringName = &"WORLD"
var cue: StringName = &""


func to_debug_text() -> String:
	var parts: PackedStringArray = [
		str(scene),
		str(biome),
		str(day_phase),
		str(depth_layer),
		str(fog_state),
		str(interior),
	]
	if cue != &"":
		parts.append("cue:" + str(cue))
	return " / ".join(parts)
