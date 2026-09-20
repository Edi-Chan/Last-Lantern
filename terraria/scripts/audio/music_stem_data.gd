@tool
class_name MusicStemData
extends Resource

## Optionaler Einzel-Layer (Floete, Gitarre, Pad). Leer lassen, wenn nur Mixdown genutzt wird.

@export var id: StringName = &""
@export var stream: AudioStream
@export var volume_db: float = 0.0
