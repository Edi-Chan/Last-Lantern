@tool
class_name AmbientCatalog
extends Resource

@export var layers: Array[AmbientLayerData] = []


func matching(ctx: MusicContext) -> Array[AmbientLayerData]:
	var result: Array[AmbientLayerData] = []
	for layer in layers:
		if layer != null and layer.matches(ctx):
			result.append(layer)
	return result
