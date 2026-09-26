@tool
class_name WeaponAssetGenerator
extends RefCounted

## 16x16 HD-Pixelart fuer Waffen. Gleiche Groesse wie Spitzhacken-Icons.

const SIZE := 16
const OUT := "res://assets/items/weapons"


func run() -> void:
	_save(_draw_sword(_pal_wood(), 1), "res://assets/items/weapons/swords/wood_sword.png")
	_save(_draw_sword(_pal_stone(), 1), "res://assets/items/weapons/swords/stone_sword.png")
	_save(_draw_pickaxe(_pal_wood()), "res://assets/items/tools/mining/pickaxes/wood_pickaxe.png")
	_save(_draw_axe(_pal_wood()), "res://assets/items/tools/woodcutting/wood_axe.png")
	_save(_draw_sword(_pal_copper(), 2), "res://assets/items/weapons/swords/copper_sword.png")
	_save(_draw_sword(_pal_ferrite(), 3), "res://assets/items/weapons/swords/ferrite_sword.png")
	_save(_draw_sword(_pal_cobalt(), 4), "res://assets/items/weapons/swords/cobalt_sword.png")
	_save(_draw_sword(_pal_cryonite(), 5), "res://assets/items/weapons/swords/cryonite_sword.png")
	_save(_draw_sword(_pal_voidium(), 6), "res://assets/items/weapons/swords/voidium_sword.png")
	_save(_draw_sword(_pal_astralith(), 7), "res://assets/items/weapons/swords/astralith_sword.png")
	_save(_draw_spear(_pal_wood(), 1), "res://assets/items/weapons/spears/wood_spear.png")
	_save(_draw_spear(_pal_copper(), 2), "res://assets/items/weapons/spears/copper_spear.png")
	_save(_draw_spear(_pal_cobalt(), 4), "res://assets/items/weapons/spears/cobalt_spear.png")
	_save(_draw_spear(_pal_voidium(), 6), "res://assets/items/weapons/spears/voidium_spear.png")
	_save(_draw_bow(_pal_wood(), 1), "res://assets/items/weapons/bows/wood_bow.png")
	_save(_draw_bow(_pal_cobalt(), 4), "res://assets/items/weapons/bows/cobalt_bow.png")
	_save(_draw_bow(_pal_astralith(), 7), "res://assets/items/weapons/bows/astralith_bow.png")
	_save(_draw_arrow(), "res://assets/items/ammunition/wood_arrow.png")
	_save(_draw_lantern(), "res://assets/items/weapons/lanterns/old_combat_lantern.png")
	_save(_draw_light(), "res://assets/items/weapons/lanterns/combat_light.png")


func _pal_stone() -> Dictionary:
	return {"blade": Color("8b9098"), "hi": Color("c4c8ce"), "sh": Color("4e535a"), "edge": Color("2c3036"), "guard": Color("6a6258"), "grip": Color("6b4a2a"), "wrap": Color("3a2814")}


func _pal_copper() -> Dictionary:
	return {"blade": Color("c66c2a"), "hi": Color("efb06a"), "sh": Color("7a3a12"), "edge": Color("4a2208"), "guard": Color("a85a20"), "grip": Color("6b4a2a"), "wrap": Color("3a2814")}


func _pal_ferrite() -> Dictionary:
	return {"blade": Color("b04030"), "hi": Color("e07860"), "sh": Color("6a2018"), "edge": Color("3a100c"), "guard": Color("8a3a28"), "grip": Color("5a3a22"), "wrap": Color("2e1c10")}


func _pal_cobalt() -> Dictionary:
	return {"blade": Color("3060d4"), "hi": Color("78a8ff"), "sh": Color("183078"), "edge": Color("0c1848"), "guard": Color("c4a24a"), "grip": Color("4a3220"), "wrap": Color("24180c")}


func _pal_cryonite() -> Dictionary:
	return {"blade": Color("48d4e0"), "hi": Color("c8f8ff"), "sh": Color("1a6a78"), "edge": Color("0a3840"), "guard": Color("8ee8f0"), "grip": Color("3a4a55"), "wrap": Color("1c2830")}


func _pal_voidium() -> Dictionary:
	return {"blade": Color("3a1850"), "hi": Color("8a48b8"), "sh": Color("180828"), "edge": Color("080410"), "guard": Color("5a2878"), "grip": Color("241428"), "wrap": Color("100810")}


func _pal_astralith() -> Dictionary:
	return {"blade": Color("b88cff"), "hi": Color("f0e8ff"), "sh": Color("5a38a8"), "edge": Color("2a1860"), "guard": Color("e6c45a"), "grip": Color("4a3060"), "wrap": Color("201430")}


func _pal_wood() -> Dictionary:
	return {"blade": Color("c4a060"), "hi": Color("e8d090"), "sh": Color("6a4820"), "edge": Color("3a2410"), "guard": Color("8a6230"), "grip": Color("6b4a2a"), "wrap": Color("3a2814")}


func _draw_sword(pal: Dictionary, tier: int) -> Image:
	var img := _blank()
	var blade: Color = pal["blade"]
	var hi: Color = pal["hi"]
	var sh: Color = pal["sh"]
	var edge: Color = pal["edge"]
	var guard: Color = pal["guard"]
	var grip: Color = pal["grip"]
	var wrap: Color = pal["wrap"]
	_px(img, 3, 13, wrap)
	_px(img, 3, 14, wrap)
	_px(img, 4, 12, grip)
	_px(img, 4, 13, grip)
	_px(img, 4, 14, wrap)
	_px(img, 5, 11, grip)
	_px(img, 5, 12, grip)
	_px(img, 5, 13, wrap)
	_px(img, 4, 10, guard)
	_px(img, 5, 10, guard)
	_px(img, 6, 10, guard)
	_px(img, 3, 10, edge)
	_px(img, 7, 10, edge)
	if tier >= 3:
		_px(img, 2, 10, guard)
		_px(img, 8, 10, guard)
	if tier >= 5:
		_px(img, 3, 9, hi)
		_px(img, 7, 9, hi)
	var blade_pixels := [
		Vector2i(6, 9), Vector2i(7, 8), Vector2i(8, 7), Vector2i(9, 6),
		Vector2i(10, 5), Vector2i(11, 4), Vector2i(12, 3),
		Vector2i(6, 8), Vector2i(7, 7), Vector2i(8, 6), Vector2i(9, 5),
		Vector2i(10, 4), Vector2i(11, 3),
	]
	if tier >= 4:
		blade_pixels.append_array([Vector2i(12, 2), Vector2i(13, 3), Vector2i(11, 2)])
	if tier >= 6:
		blade_pixels.append_array([Vector2i(13, 2), Vector2i(14, 3), Vector2i(12, 1)])
	if tier >= 7:
		blade_pixels.append_array([Vector2i(13, 1), Vector2i(14, 2), Vector2i(8, 9), Vector2i(9, 8)])
	for p in blade_pixels:
		_px(img, p.x, p.y, blade)
	_px(img, 6, 8, hi)
	_px(img, 8, 6, hi)
	_px(img, 10, 4, hi)
	_px(img, 7, 9, sh)
	_px(img, 9, 7, sh)
	_px(img, 11, 5, sh)
	_px(img, 12, 3, edge)
	if tier >= 6:
		_px(img, 13, 2, Color(0.55, 0.2, 0.75, 1))
	if tier >= 7:
		_px(img, 14, 1, Color(1, 0.95, 0.7, 1))
		_px(img, 4, 11, Color("e6c45a"))
	return img


func _draw_pickaxe(pal: Dictionary) -> Image:
	## Gleiche Silhouette wie die Steinspitzhacke: T-Kopf, schraeger Holzgriff.
	var img := _blank()
	var outline: Color = pal["edge"]
	var head: Color = pal["blade"]
	var hi: Color = pal["hi"]
	var sh: Color = pal["sh"]
	var grip: Color = pal["grip"]
	var wrap: Color = pal["wrap"]
	for p in [
		Vector2i(9, 3), Vector2i(10, 3),
		Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(11, 4), Vector2i(12, 4), Vector2i(13, 4),
		Vector2i(5, 5), Vector2i(14, 5),
		Vector2i(6, 6), Vector2i(7, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6),
		Vector2i(8, 7), Vector2i(9, 7),
		Vector2i(7, 8), Vector2i(8, 8),
		Vector2i(6, 9), Vector2i(8, 9),
		Vector2i(5, 10), Vector2i(7, 10),
		Vector2i(5, 11), Vector2i(6, 11),
		Vector2i(4, 12), Vector2i(6, 12),
		Vector2i(3, 13), Vector2i(5, 13),
		Vector2i(3, 14), Vector2i(4, 14),
		Vector2i(3, 15),
	]:
		_px(img, p.x, p.y, outline)
	for x in range(6, 14):
		_px(img, x, 5, head)
	_px(img, 9, 4, hi)
	_px(img, 10, 4, hi)
	_px(img, 8, 6, sh)
	_px(img, 9, 6, sh)
	_px(img, 7, 9, grip)
	_px(img, 6, 10, wrap)
	_px(img, 5, 12, grip)
	_px(img, 4, 13, wrap)
	return img


func _draw_axe(pal: Dictionary) -> Image:
	var img := _blank()
	var wood: Color = pal["grip"]
	var wrap: Color = pal["wrap"]
	var head: Color = pal["blade"]
	var hi: Color = pal["hi"]
	var edge: Color = pal["edge"]
	for i in range(3, 13):
		_px(img, i, 12 - i + 3, wood)
		_px(img, i + 1, 12 - i + 3, wrap if i % 2 == 0 else wood)
	for y in range(2, 8):
		_px(img, 10, y, head)
		_px(img, 11, y, head)
	_px(img, 12, 3, head)
	_px(img, 12, 4, head)
	_px(img, 12, 5, head)
	_px(img, 13, 4, edge)
	_px(img, 11, 3, hi)
	_px(img, 10, 4, hi)
	return img


func _draw_spear(pal: Dictionary, tier: int) -> Image:
	var img := _blank()
	var shaft: Color = pal["grip"]
	var wrap: Color = pal["wrap"]
	var tip: Color = pal["blade"]
	var hi: Color = pal["hi"]
	var edge: Color = pal["edge"]
	for x in range(2, 11 if tier < 4 else 12):
		_px(img, x, 8, shaft)
		_px(img, x, 9, wrap if x % 2 == 0 else shaft)
	_px(img, 1, 8, wrap)
	_px(img, 1, 9, wrap)
	var head := [
		Vector2i(11, 7), Vector2i(12, 7), Vector2i(13, 8),
		Vector2i(12, 8), Vector2i(11, 8), Vector2i(12, 9), Vector2i(11, 9),
	]
	if tier >= 4:
		head.append_array([Vector2i(14, 8), Vector2i(13, 7), Vector2i(13, 9)])
	if tier >= 6:
		head.append_array([Vector2i(14, 7), Vector2i(14, 9), Vector2i(15, 8)])
	for p in head:
		_px(img, p.x, p.y, tip)
	_px(img, 12, 7, hi)
	_px(img, 13, 8, edge)
	if tier >= 4:
		_px(img, 10, 7, pal["guard"])
		_px(img, 10, 9, pal["guard"])
	return img


func _draw_bow(pal: Dictionary, tier: int) -> Image:
	var img := _blank()
	var limb: Color = pal["blade"]
	var hi: Color = pal["hi"]
	var wrap: Color = pal["wrap"]
	var string_c := Color("e8e0d0")
	var arc := [
		Vector2i(5, 1), Vector2i(4, 2), Vector2i(3, 3), Vector2i(3, 4),
		Vector2i(3, 5), Vector2i(3, 6), Vector2i(3, 7), Vector2i(3, 8),
		Vector2i(3, 9), Vector2i(3, 10), Vector2i(3, 11), Vector2i(4, 12),
		Vector2i(5, 13), Vector2i(6, 2), Vector2i(6, 12), Vector2i(5, 2), Vector2i(5, 12),
	]
	if tier >= 4:
		arc.append_array([Vector2i(2, 5), Vector2i(2, 9), Vector2i(7, 1), Vector2i(7, 13)])
	if tier >= 7:
		arc.append_array([Vector2i(1, 6), Vector2i(1, 8), Vector2i(8, 2), Vector2i(8, 12)])
	for p in arc:
		_px(img, p.x, p.y, limb)
	_px(img, 4, 3, hi)
	_px(img, 4, 11, hi)
	_px(img, 5, 6, wrap)
	_px(img, 5, 7, wrap)
	_px(img, 5, 8, wrap)
	for y in range(3, 12):
		_px(img, 10 if tier < 4 else 11, y, string_c)
	if tier >= 7:
		_px(img, 6, 7, Color("e6c45a"))
	return img


func _draw_arrow() -> Image:
	var img := _blank()
	var shaft := Color("8a6230")
	var tip := Color("b8bcc4")
	var fletch := Color("c45a32")
	for x in range(3, 13):
		_px(img, x, 7, shaft)
	_px(img, 13, 7, tip)
	_px(img, 14, 7, tip)
	_px(img, 12, 6, tip)
	_px(img, 12, 8, tip)
	_px(img, 3, 6, fletch)
	_px(img, 4, 6, fletch)
	_px(img, 3, 8, fletch)
	_px(img, 4, 8, fletch)
	_px(img, 2, 7, Color("6a3a18"))
	return img


func _draw_lantern() -> Image:
	var img := _blank()
	var frame := Color("5a4630")
	var gold := Color("e0a030")
	var glow := Color("ffd060")
	var core := Color("fff2b0")
	var dark := Color("2a1c10")
	for x in range(5, 11):
		_px(img, x, 4, frame)
		_px(img, x, 12, frame)
	for y in range(5, 12):
		_px(img, 5, y, frame)
		_px(img, 10, y, frame)
	for x in range(6, 10):
		for y in range(5, 12):
			_px(img, x, y, glow if y < 9 else gold)
	_px(img, 7, 7, core)
	_px(img, 8, 7, core)
	_px(img, 7, 8, gold)
	_px(img, 6, 3, dark)
	_px(img, 7, 2, dark)
	_px(img, 8, 2, dark)
	_px(img, 9, 3, dark)
	_px(img, 7, 3, gold)
	_px(img, 8, 3, gold)
	_px(img, 7, 13, frame)
	_px(img, 8, 13, frame)
	_px(img, 6, 6, Color("ffb040"))
	_px(img, 9, 6, Color("ffb040"))
	return img


func _blank() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	img.set_pixel(x, y, color)


func _draw_light() -> Image:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) / radius
			var a := clampf(1.0 - d, 0.0, 1.0)
			a *= a
			img.set_pixel(x, y, Color(1, 0.92, 0.7, a))
	return img


func _save(img: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("WeaponAssetGenerator: could not save %s (%s)" % [path, str(err)])
