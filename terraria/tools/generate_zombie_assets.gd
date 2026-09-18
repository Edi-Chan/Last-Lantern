@tool
class_name ZombieAssetGenerator
extends RefCounted

## Einmaliger Generator fuer Zombie-Pixelart und SFX. Kein Anti-Aliasing.
## Wird aus den Zombie-Tests und bei Bedarf manuell aufgerufen.

const W := 48
const H := 64
const SPRITE_DIR := "res://assets/enemies/zombie"
const AUDIO_DIR := "res://audio/sfx"
const FRAMES_PATH := "res://resources/enemies/zombie_frames.tres"

var pal_normal: Dictionary
var pal_dark: Dictionary


func run() -> void:
	_init_palettes()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPRITE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUDIO_DIR))
	_write_all_frames()
	_write_particles()
	_write_sfx()
	_write_sprite_frames()
	print("[ZombieAssets] geschrieben.")


func _init_palettes() -> void:
	pal_normal = {
		"out": Color8(22, 17, 14),
		"skin": Color8(168, 170, 154),
		"skin_hi": Color8(196, 196, 180),
		"skin_sh": Color8(132, 136, 122),
		"skin_sick": Color8(150, 158, 138),
		"hair": Color8(46, 40, 34),
		"hair_d": Color8(28, 24, 20),
		"shirt": Color8(90, 82, 70),
		"shirt_hi": Color8(114, 104, 90),
		"shirt_sh": Color8(66, 60, 52),
		"shirt_dirt": Color8(74, 68, 54),
		"pants": Color8(50, 54, 60),
		"pants_hi": Color8(64, 68, 74),
		"pants_sh": Color8(36, 40, 46),
		"shoe": Color8(44, 38, 32),
		"shoe_d": Color8(30, 26, 22),
		"eye": Color8(26, 22, 20),
		"eye_in": Color8(40, 32, 30),
		"mouth": Color8(72, 44, 42),
		"wound": Color8(110, 78, 74),
		"nail": Color8(90, 84, 78),
	}
	pal_dark = {
		"out": Color8(6, 4, 8),
		"skin": Color8(46, 42, 54),
		"skin_hi": Color8(64, 56, 74),
		"skin_sh": Color8(28, 24, 36),
		"skin_sick": Color8(40, 32, 52),
		"hair": Color8(10, 8, 14),
		"hair_d": Color8(4, 3, 6),
		"shirt": Color8(20, 16, 26),
		"shirt_hi": Color8(34, 26, 42),
		"shirt_sh": Color8(12, 10, 16),
		"shirt_dirt": Color8(16, 12, 22),
		"pants": Color8(14, 12, 18),
		"pants_hi": Color8(24, 20, 30),
		"pants_sh": Color8(8, 6, 12),
		"shoe": Color8(8, 6, 10),
		"shoe_d": Color8(4, 3, 6),
		"eye": Color8(28, 8, 12),
		"eye_in": Color8(186, 36, 58),
		"mouth": Color8(48, 16, 28),
		"wound": Color8(72, 18, 32),
		"nail": Color8(70, 40, 52),
		"glow": Color8(210, 64, 88),
		"glow_core": Color8(255, 150, 164),
		"violet": Color8(48, 24, 64),
	}


func _anims() -> Array:
	return [
		{"name": "idle", "poses": [pose_idle(0), pose_idle(1), pose_idle(2), pose_idle(3)], "dark": false, "speed": 4.0, "loop": true},
		{"name": "walk", "poses": [pose_walk(0), pose_walk(1), pose_walk(2), pose_walk(3), pose_walk(4), pose_walk(5)], "dark": false, "speed": 5.0, "loop": true},
		{"name": "attack", "poses": [pose_attack(0), pose_attack(1), pose_attack(2), pose_attack(3), pose_attack(4), pose_attack(5)], "dark": false, "speed": 10.0, "loop": false},
		{"name": "hurt", "poses": [pose_hurt(0), pose_hurt(1), pose_hurt(2)], "dark": false, "speed": 14.0, "loop": false},
		{"name": "death", "poses": [pose_death(0), pose_death(1), pose_death(2), pose_death(3), pose_death(4), pose_death(5), pose_death(6), pose_death(7)], "dark": false, "speed": 8.0, "loop": false},
		{"name": "transform", "poses": [pose_transform(0), pose_transform(1), pose_transform(2), pose_transform(3), pose_transform(4)], "dark": false, "speed": 8.0, "loop": false},
		{"name": "dark_idle", "poses": [_with(pose_idle(0), {"hunch": 4}), _with(pose_idle(1), {"hunch": 4}), _with(pose_idle(2), {"hunch": 4}), _with(pose_idle(3), {"hunch": 4})], "dark": true, "speed": 5.0, "loop": true},
		{"name": "dark_walk", "poses": [pose_dark_walk(0), pose_dark_walk(1), pose_dark_walk(2), pose_dark_walk(3), pose_dark_walk(4), pose_dark_walk(5)], "dark": true, "speed": 8.0, "loop": true},
		{"name": "dark_attack", "poses": [pose_dark_attack(0), pose_dark_attack(1), pose_dark_attack(2), pose_dark_attack(3), pose_dark_attack(4), pose_dark_attack(5)], "dark": true, "speed": 13.0, "loop": false},
		{"name": "dark_hurt", "poses": [_with(pose_hurt(0), {"hunch": 3}), _with(pose_hurt(1), {"hunch": 3}), _with(pose_hurt(2), {"hunch": 3})], "dark": true, "speed": 14.0, "loop": false},
		{"name": "dark_death", "poses": [pose_death(0), pose_death(1), pose_death(2), pose_death(3), pose_death(4), pose_death(5), pose_death(6), pose_death(7)], "dark": true, "speed": 8.0, "loop": false},
	]


func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for key in extra.keys():
		out[key] = extra[key]
	return out


func _write_all_frames() -> void:
	for anim in _anims():
		var poses: Array = anim["poses"]
		for i in poses.size():
			var dark: bool = anim["dark"]
			if String(anim["name"]) == "transform":
				dark = i >= 3
			var img := draw_zombie(poses[i], dark)
			img.save_png("%s/%s_%d.png" % [SPRITE_DIR, String(anim["name"]), i])


func _write_particles() -> void:
	_smoke(16).save_png(SPRITE_DIR + "/smoke_puff.png")
	_ember(6).save_png(SPRITE_DIR + "/dark_ember.png")


func _write_sprite_frames() -> void:
	var lines: PackedStringArray = ["[gd_resource type=\"SpriteFrames\" load_steps=100 format=3]", ""]
	var ext_id := 1
	var ids: Dictionary = {}
	for anim in _anims():
		var poses: Array = anim["poses"]
		for i in poses.size():
			var key := "%s_%d" % [String(anim["name"]), i]
			var rid := "%d_%s" % [ext_id, key.replace("_", "")]
			ids[key] = rid
			lines.append('[ext_resource type="Texture2D" path="%s/%s.png" id="%s"]' % [SPRITE_DIR, key, rid])
			ext_id += 1
	lines.append("")
	lines.append("[resource]")
	lines.append("animations = [")
	var blocks: PackedStringArray = []
	for anim in _anims():
		var poses: Array = anim["poses"]
		var frames: PackedStringArray = []
		for i in poses.size():
			var key := "%s_%d" % [String(anim["name"]), i]
			frames.append("{\n\"duration\": 1.0,\n\"texture\": ExtResource(\"%s\")\n}" % ids[key])
		var loop_s := "true" if bool(anim["loop"]) else "false"
		blocks.append("{\n\"frames\": [%s],\n\"loop\": %s,\n\"name\": &\"%s\",\n\"speed\": %s\n}" % [", ".join(frames), loop_s, String(anim["name"]), str(anim["speed"])])
	lines.append(",\n".join(blocks))
	lines.append("]")
	var fh := FileAccess.open(FRAMES_PATH, FileAccess.WRITE)
	if fh != null:
		fh.store_string("\n".join(lines) + "\n")


func pset(img: Image, x: int, y: int, c: Color) -> void:
	if c.a <= 0.0 or x < 0 or y < 0 or x >= W or y >= H:
		return
	img.set_pixel(x, y, c)


func fill_rect(img: Image, x: int, y: int, w: int, h: int, fill: Color, outline: Color, hi: Color = Color(0, 0, 0, 0), sh: Color = Color(0, 0, 0, 0)) -> void:
	for dy in h:
		for dx in w:
			var col := fill
			if dx == 0 or dy == 0 or dx == w - 1 or dy == h - 1:
				col = outline
			elif hi.a > 0.0 and dx == 1 and dy > 0 and dy < h - 1:
				col = hi
			elif sh.a > 0.0 and dx == w - 2 and dy > 0 and dy < h - 1:
				col = sh
			pset(img, x + dx, y + dy, col)


func draw_zombie(pose: Dictionary, dark: bool) -> Image:
	var pal: Dictionary = pal_dark if dark else pal_normal
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fallen := int(pose.get("fallen", 0))
	if fallen >= 2:
		var y := 52 + mini(fallen, 3)
		fill_rect(img, 8, y + 6, 28, 6, pal["shirt"], pal["out"], pal["shirt_hi"], pal["shirt_sh"])
		fill_rect(img, 6, y + 7, 8, 5, pal["pants"], pal["out"], pal["pants_hi"], pal["pants_sh"])
		fill_rect(img, 4, y + 8, 6, 4, pal["shoe"], pal["out"])
		draw_head(img, 32, y, pal, dark, 1, 1, false, true)
		fill_rect(img, 20, y + 2, 10, 4, pal["skin"], pal["out"], pal["skin_hi"], pal["skin_sh"])
		return img
	var hunch := int(pose.get("hunch", 3))
	var bob := int(pose.get("bob", 0))
	var base_x := 24
	var foot_y := 63 + int(pose.get("sink", 0))
	draw_leg(img, base_x - 6 + int(hunch / 2), foot_y - 18 + bob, pal, int(pose.get("leg_back_lift", 0)), int(pose.get("leg_back_fwd", -1)), false)
	draw_leg(img, base_x + 1 + int(hunch / 2), foot_y - 18 + bob, pal, int(pose.get("leg_front_lift", 0)), int(pose.get("leg_front_fwd", 1)), true)
	var torso_x := base_x - 7 + hunch + int(pose.get("torso_x", 0))
	var torso_y := foot_y - 35 + bob + int(pose.get("torso_y", 0))
	draw_arm(img, torso_x - 2 + int(pose.get("arm_back_x", 0)), torso_y + 2 + int(pose.get("arm_back_y", 0)), int(pose.get("arm_back_swing", 1)), pal, false, false)
	draw_torso(img, torso_x, torso_y, pal, dark)
	draw_arm(img, torso_x + 12 + int(pose.get("arm_front_x", 0)), torso_y + 1 + int(pose.get("arm_front_y", 0)), int(pose.get("arm_front_swing", 2)), pal, true, bool(pose.get("grab", false)))
	var head_x := torso_x + 3 + hunch + int(pose.get("head_x", 0))
	var head_y := torso_y - 11 + int(pose.get("head_y", 0))
	draw_head(img, head_x, head_y, pal, dark, int(pose.get("tilt", 0)), int(pose.get("mouth", 0)), bool(pose.get("hurt", false)), bool(pose.get("dead", false)))
	return img


func draw_arm(img: Image, x: int, y: int, swing: int, pal: Dictionary, front: bool, grab: bool) -> void:
	var w := 4 if front else 3
	var hi: Color = pal["skin_hi"] if front else Color(0, 0, 0, 0)
	fill_rect(img, x, y, w, 7, pal["skin"], pal["out"], hi, pal["skin_sh"])
	if swing >= 4:
		fill_rect(img, x + 2, y + 5, 8, 4, pal["skin"], pal["out"], pal["skin_hi"], pal["skin_sh"])
		var hx := x + 7
		var hy := y + 4 if grab else y + 6
		fill_rect(img, hx, hy, 4, 4, pal["skin_sick"], pal["out"], pal["skin_hi"], pal["skin_sh"])
		pset(img, hx + 3, hy + 1, pal["nail"])
		pset(img, hx + 3, hy + 3, pal["nail"])
		return
	if swing <= -3:
		fill_rect(img, x - 5, y + 1, 6, 4, pal["skin"], pal["out"], pal["skin_hi"], pal["skin_sh"])
		fill_rect(img, x - 7, y + 2, 4, 4, pal["skin_sick"], pal["out"], pal["skin_hi"], pal["skin_sh"])
		return
	var ux := x + (2 if swing > 0 else (-1 if swing < 0 else 0))
	fill_rect(img, ux, y + 6, 3, 8, pal["skin"], pal["out"], hi, pal["skin_sh"])
	var hx2 := ux + (2 if swing >= 0 else -1)
	fill_rect(img, hx2, y + 11, 4, 4, pal["skin_sick"], pal["out"], pal["skin_hi"], pal["skin_sh"])
	pset(img, hx2 + 3, y + 12, pal["nail"])
	pset(img, hx2 + 3, y + 13, pal["nail"])


func draw_leg(img: Image, x: int, y: int, pal: Dictionary, lift: int, forward: int, front: bool) -> void:
	var h := 16 - maxi(0, lift)
	var ly := y + lift
	var lx := x + forward
	var hi: Color = pal["pants_hi"] if front else Color(0, 0, 0, 0)
	fill_rect(img, lx, ly, 6 if front else 5, h, pal["pants"], pal["out"], hi, pal["pants_sh"])
	pset(img, lx + 1, ly + h - 6, pal["shirt_dirt"])
	pset(img, lx + 3, ly + h - 5, pal["shirt_dirt"])
	fill_rect(img, lx - 1 + maxi(0, forward), ly + h - 4, 7, 4, pal["shoe"], pal["out"], Color(0, 0, 0, 0), pal["shoe_d"])


func draw_head(img: Image, x: int, y: int, pal: Dictionary, dark: bool, tilt: int, mouth_open: int, hurt: bool, dead: bool) -> void:
	fill_rect(img, x, y, 12, 12, pal["skin"], pal["out"], pal["skin_hi"], pal["skin_sh"])
	fill_rect(img, x - 1, y - 3, 14, 5, pal["hair"], pal["out"])
	for pt in [Vector2i(0, -1), Vector2i(2, -2), Vector2i(5, -3), Vector2i(8, -2), Vector2i(11, -1), Vector2i(12, 1), Vector2i(1, 2), Vector2i(10, 2)]:
		pset(img, x + pt.x, y + pt.y, pal["hair_d"])
	pset(img, x + 3, y + 1, pal["hair"])
	pset(img, x + 8, y, pal["hair_d"])
	var eye_y := y + 5 + tilt
	pset(img, x + 3, eye_y, pal["eye"])
	pset(img, x + 4, eye_y, pal["eye"])
	pset(img, x + 8, eye_y, pal["eye"])
	pset(img, x + 9, eye_y, pal["eye"])
	if dead:
		pset(img, x + 4, eye_y + 1, pal["eye"])
		pset(img, x + 8, eye_y + 1, pal["eye"])
	elif dark:
		pset(img, x + 3, eye_y, pal["eye_in"])
		pset(img, x + 4, eye_y, pal.get("glow", pal["eye_in"]))
		pset(img, x + 8, eye_y, pal["eye_in"])
		pset(img, x + 9, eye_y, pal.get("glow", pal["eye_in"]))
		pset(img, x + 4, eye_y - 1, pal.get("glow_core", pal["eye_in"]))
		pset(img, x + 9, eye_y - 1, pal.get("glow_core", pal["eye_in"]))
		pset(img, x + 2, eye_y, pal.get("violet", pal["out"]))
		pset(img, x + 10, eye_y, pal.get("violet", pal["out"]))
	else:
		pset(img, x + 4, eye_y, pal["eye_in"])
		pset(img, x + 9, eye_y, pal["eye_in"])
	pset(img, x + 2, y + 8, pal["skin_sick"])
	pset(img, x + 10, y + 7, pal["wound"])
	if hurt:
		pset(img, x + 6, y + 8, pal["wound"])
	var my := y + 9 + mouth_open
	pset(img, x + 5, my, pal["mouth"])
	pset(img, x + 6, my, pal["mouth"])
	pset(img, x + 7, my, pal["mouth"])
	if mouth_open > 0:
		pset(img, x + 6, my + 1, pal["out"])
	pset(img, x + 11, y + 8, pal["skin_sh"])


func draw_torso(img: Image, x: int, y: int, pal: Dictionary, dark: bool) -> void:
	fill_rect(img, x, y, 14, 17, pal["shirt"], pal["out"], pal["shirt_hi"], pal["shirt_sh"])
	fill_rect(img, x + 4, y, 6, 3, pal["skin_sick"], pal["out"], pal["skin_hi"], pal["skin_sh"])
	pset(img, x + 3, y + 2, pal["shirt_dirt"])
	pset(img, x + 10, y + 3, pal["shirt_dirt"])
	pset(img, x + 2, y + 8, pal["shirt_dirt"])
	pset(img, x + 11, y + 10, pal["shirt_sh"])
	pset(img, x + 5, y + 12, pal["out"])
	pset(img, x + 6, y + 13, pal["out"])
	pset(img, x + 7, y + 12, pal["shirt_dirt"])
	pset(img, x + 8, y + 15, pal["out"])
	pset(img, x + 1, y + 14, pal["shirt_dirt"])
	pset(img, x + 12, y + 7, pal["wound"])
	if dark:
		pset(img, x + 6, y + 6, pal.get("violet", pal["shirt_sh"]))
		pset(img, x + 7, y + 9, pal.get("violet", pal["shirt_sh"]))


func pose_idle(i: int) -> Dictionary:
	return {
		"hunch": 3,
		"bob": [0, 1, 0, 0][i],
		"head_y": [0, 1, 0, -1][i],
		"tilt": 1 if i == 2 else 0,
		"arm_front_swing": [2, 2, 1, 2][i],
		"arm_back_swing": 1,
		"mouth": 1 if i == 1 else 0,
	}


func pose_walk(i: int) -> Dictionary:
	var frames: Array = [
		{"leg_front_lift": 0, "leg_front_fwd": 3, "leg_back_lift": 2, "leg_back_fwd": -2, "bob": 1, "arm_front_swing": 3, "arm_back_swing": 0},
		{"leg_front_lift": 0, "leg_front_fwd": 4, "leg_back_lift": 1, "leg_back_fwd": -3, "bob": 0, "arm_front_swing": 2, "arm_back_swing": 1},
		{"leg_front_lift": 2, "leg_front_fwd": 0, "leg_back_lift": 0, "leg_back_fwd": 1, "bob": 1, "arm_front_swing": 1, "arm_back_swing": 2},
		{"leg_front_lift": 3, "leg_front_fwd": -1, "leg_back_lift": 0, "leg_back_fwd": 3, "bob": 0, "arm_front_swing": 0, "arm_back_swing": 2},
		{"leg_front_lift": 1, "leg_front_fwd": 1, "leg_back_lift": 0, "leg_back_fwd": 2, "bob": 1, "arm_front_swing": 2, "arm_back_swing": 1},
		{"leg_front_lift": 0, "leg_front_fwd": 2, "leg_back_lift": 1, "leg_back_fwd": -1, "bob": 0, "arm_front_swing": 3, "arm_back_swing": 0},
	]
	var cycle: Dictionary = frames[i]
	cycle["hunch"] = 4
	cycle["head_x"] = 1 if i % 2 == 0 else 0
	cycle["mouth"] = 1 if i == 1 or i == 4 else 0
	return cycle


func pose_attack(i: int) -> Dictionary:
	var frames: Array = [
		{"hunch": 3, "arm_front_swing": 1, "arm_back_swing": 1, "head_x": 0, "grab": false},
		{"hunch": 2, "arm_front_swing": -3, "arm_back_swing": -1, "head_x": -1, "torso_x": -1, "grab": false},
		{"hunch": 2, "arm_front_swing": -4, "arm_back_swing": -2, "head_x": -1, "torso_x": -2, "mouth": 1},
		{"hunch": 5, "arm_front_swing": 6, "arm_back_swing": 3, "head_x": 2, "torso_x": 2, "grab": true, "mouth": 1},
		{"hunch": 5, "arm_front_swing": 5, "arm_back_swing": 2, "head_x": 1, "torso_x": 1, "grab": true},
		{"hunch": 3, "arm_front_swing": 2, "arm_back_swing": 1, "head_x": 0, "torso_x": 0},
	]
	return frames[i]


func pose_hurt(i: int) -> Dictionary:
	var frames: Array = [
		{"hunch": 2, "torso_x": -2, "head_x": -1, "hurt": true, "arm_front_swing": -1, "bob": 0},
		{"hunch": 1, "torso_x": -3, "head_x": -2, "hurt": true, "arm_front_swing": -2, "bob": 1, "mouth": 1},
		{"hunch": 3, "torso_x": -1, "head_x": 0, "hurt": false, "arm_front_swing": 1, "bob": 0},
	]
	return frames[i]


func pose_death(i: int) -> Dictionary:
	if i >= 5:
		return {"fallen": 2 + (1 if i >= 6 else 0), "dead": true}
	var frames: Array = [
		{"hunch": 2, "torso_x": -2, "hurt": true, "mouth": 1, "arm_front_swing": -2},
		{"hunch": 4, "sink": 4, "torso_y": 2, "head_y": 2, "leg_front_lift": 3, "mouth": 1, "dead": false},
		{"hunch": 6, "sink": 8, "torso_y": 4, "head_x": 3, "head_y": 3, "leg_front_lift": 5, "mouth": 1, "dead": true},
		{"hunch": 7, "sink": 12, "torso_y": 6, "head_x": 4, "head_y": 5, "arm_front_swing": 4, "dead": true},
		{"hunch": 8, "sink": 16, "torso_y": 8, "head_x": 6, "head_y": 6, "dead": true, "fallen": 1},
	]
	return frames[i]


func pose_transform(i: int) -> Dictionary:
	var frames: Array = [
		{"hunch": 3, "mouth": 0, "arm_front_swing": 2},
		{"hunch": 4, "mouth": 1, "head_y": -1, "arm_front_swing": 1},
		{"hunch": 5, "mouth": 1, "head_y": 0, "torso_x": 1},
		{"hunch": 4, "mouth": 1, "arm_front_swing": 3},
		{"hunch": 4, "mouth": 0, "arm_front_swing": 3, "head_x": 1},
	]
	return frames[i]


func pose_dark_walk(i: int) -> Dictionary:
	var p := pose_walk(i)
	p["hunch"] = 5
	p["arm_front_swing"] = mini(4, int(p.get("arm_front_swing", 2)) + 1)
	p["head_x"] = 1
	return p


func pose_dark_attack(i: int) -> Dictionary:
	var p := pose_attack(i)
	p["hunch"] = int(p.get("hunch", 3)) + 1
	p["mouth"] = 1
	return p


func _smoke(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := (size - 1) * 0.5
	var cy := cx
	for y in size:
		for x in size:
			var d := Vector2(float(x) - cx, float(y) - cy).length() / (float(size) * 0.48)
			if d >= 1.0:
				continue
			var col := Color8(6, 4, 10, 40)
			if d < 0.28:
				col = Color8(18, 14, 22, 200)
			elif d < 0.52:
				col = Color8(12, 10, 16, 150)
			elif d < 0.78:
				col = Color8(8, 6, 12, 90)
			img.set_pixel(x, y, col)
	return img


func _ember(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	for y in size:
		for x in size:
			var d := Vector2(float(x), float(y)).distance_to(c)
			if d > 2.2:
				continue
			var col := Color8(40, 12, 50, 70)
			if d < 0.8:
				col = Color8(180, 40, 70, 220)
			elif d < 1.6:
				col = Color8(90, 20, 80, 140)
			img.set_pixel(x, y, col)
	return img


func _write_sfx() -> void:
	_save_wav(AUDIO_DIR + "/zombie_idle.wav", _tone(0.55, 92.0, 0.22, 0.35, -12.0, 3))
	_save_wav(AUDIO_DIR + "/zombie_detect.wav", _tone(0.4, 110.0, 0.28, 0.4, 40.0, 7))
	var atk: PackedFloat32Array = PackedFloat32Array()
	var n := int(0.28 * 22050.0)
	for i in n:
		var t := float(i) / 22050.0
		var s := _noise(i, 11) * 0.35 * _env(t, 0.01, 0.05, 0.2)
		s += sin(TAU * (70.0 - 80.0 * t) * t) * 0.3 * _env(t, 0.005, 0.04, 0.18)
		atk.append(s)
	_save_wav(AUDIO_DIR + "/zombie_attack.wav", atk)
	var hurt: PackedFloat32Array = PackedFloat32Array()
	n = int(0.18 * 22050.0)
	for i in n:
		var t := float(i) / 22050.0
		var s := _noise(i, 21) * 0.4 * _env(t, 0.005, 0.03, 0.12)
		s += sin(TAU * 180.0 * t) * 0.18 * _env(t, 0.005, 0.02, 0.1)
		hurt.append(s)
	_save_wav(AUDIO_DIR + "/zombie_hurt.wav", hurt)
	_save_wav(AUDIO_DIR + "/zombie_death.wav", _tone(0.85, 70.0, 0.3, 0.45, -50.0, 13))
	var rumble: PackedFloat32Array = PackedFloat32Array()
	n = int(1.8 * 22050.0)
	for i in n:
		var t := float(i) / 22050.0
		var s := sin(TAU * 38.0 * t) * 0.12 + sin(TAU * 52.0 * t) * 0.06 + _noise(i, 31) * 0.05
		rumble.append(s * 0.7)
	_save_wav(AUDIO_DIR + "/zombie_darkness.wav", rumble)


func _tone(dur: float, freq: float, amp: float, n_amt: float, slide: float, seed: int) -> PackedFloat32Array:
	var rate := 22050.0
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	for i in n:
		var t := float(i) / rate
		var f := freq + slide * t
		var s := sin(TAU * f * t) * amp
		s += _noise(i, seed) * n_amt * amp
		s *= _env(t, 0.02, dur * 0.45, dur * 0.5)
		out.append(s)
	return out


func _env(t: float, attack: float, hold: float, release: float) -> float:
	if t < attack:
		return t / maxf(attack, 0.0001)
	if t < attack + hold:
		return 1.0
	if t < attack + hold + release:
		return 1.0 - (t - attack - hold) / maxf(release, 0.0001)
	return 0.0


func _noise(i: int, seed: int) -> float:
	var x := (i * 1103515245 + 12345 + seed * 9973) & 0x7FFFFFFF
	return (float(x) / 2147483647.0) * 2.0 - 1.0


func _save_wav(path: String, samples: PackedFloat32Array) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	stream.data = bytes
	stream.save_to_wav(path)
