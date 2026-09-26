extends RefCounted

## Pixel-Art-Platzhalter im Last-Lantern-Stil: 1px Outline, keine Glaettung, Fuesse unten.


func draw(spec: Dictionary, anim: String, frame: int) -> Image:
	var size: Vector2i = spec["canvas"]
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pal: Dictionary = spec["pal"]
	var pose := _pose(spec, anim, frame)
	match String(spec.get("kind", "quad")):
		"hopper":
			_hopper(img, pal, pose, spec)
		"bird":
			_bird(img, pal, pose, spec)
		"insect":
			_insect(img, pal, pose, spec)
		"fish":
			_fish(img, pal, pose, spec)
		"frog":
			_frog(img, pal, pose, spec)
		"snail":
			_snail(img, pal, pose, spec)
		"bat":
			_bat(img, pal, pose, spec)
		_:
			_quad(img, pal, pose, spec)
	return img


func _pose(spec: Dictionary, anim: String, frame: int) -> Dictionary:
	var fallen := 0
	var bob := 0
	var stride := 0
	var wing := 0
	var squash := 0
	var stretch := 0
	var head_down := 0
	var curl := 0
	var lunge := 0
	var hurt := false
	match anim:
		"idle":
			bob = [0, 1, 0, -1][frame % 4]
		"walk", "swim":
			stride = [-2, -1, 1, 2][frame % 4]
			bob = [0, 1, 0, 1][frame % 4]
		"run":
			stride = [-3, -1, 3, 1][frame % 4]
			bob = [1, 0, 1, 0][frame % 4]
			stretch = 1
		"fly":
			wing = [0, 1, 2, 1][frame % 4]
			bob = [0, -1, 0, 1][frame % 4]
		"hurt":
			hurt = true
			bob = -1
			stride = 1 if frame == 0 else -1
		"death":
			fallen = mini(frame + 1, 3)
		"attack":
			lunge = [0, 3, 1][mini(frame, 2)]
			stride = 2
		"eat":
			head_down = 2
			bob = frame % 2
		"curl":
			curl = 1 + frame
		"jump":
			stretch = [2, 3, 1, 0][frame % 4]
			squash = 1 if frame == 0 else 0
			bob = -stretch
	if String(spec.get("id", "")) == "shadow_deer" and anim == "idle":
		bob += [0, -1, 0, 1][frame % 4]
	return {
		"fallen": fallen,
		"bob": bob,
		"stride": stride,
		"wing": wing,
		"squash": squash,
		"stretch": stretch,
		"head_down": head_down,
		"curl": curl,
		"lunge": lunge,
		"hurt": hurt,
	}


func _quad(img: Image, pal: Dictionary, pose: Dictionary, spec: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := w / 2
	var foot := h - 1 + int(pose["bob"])
	if int(pose["fallen"]) >= 2:
		_box(img, 3, h - 8, w - 6, 6, pal["body"], pal["out"], pal["hi"], pal["sh"])
		_eye(img, w - 8, h - 7, pal, true)
		return
	if int(pose["curl"]) > 0:
		var r := maxi(w / 3, 6)
		_box(img, cx - r / 2, foot - r, r, r, pal["body"], pal["out"], pal["hi"], pal["sh"])
		_eye(img, cx + 1, foot - r + 2, pal, false)
		return
	var stride: int = pose["stride"]
	var lunge: int = pose["lunge"]
	var body_w: int = spec.get("body_w", 14)
	var body_h: int = spec.get("body_h", 8)
	var leg_h: int = spec.get("leg_h", 6)
	var body_x := cx - body_w / 2 + lunge
	var body_y := foot - leg_h - body_h + int(pose["squash"]) - int(pose["stretch"])
	# Beine
	_box(img, body_x + 1, foot - leg_h - stride, 3, leg_h + stride, pal["leg"], pal["out"], pal["hi"], pal["sh"])
	_box(img, body_x + body_w - 4, foot - leg_h + stride, 3, leg_h - mini(stride, 0), pal["leg"], pal["out"], pal["hi"], pal["sh"])
	_box(img, body_x + 4, foot - leg_h + stride / 2, 3, leg_h, pal["leg"], pal["out"], pal["hi"], pal["sh"])
	_box(img, body_x + body_w - 7, foot - leg_h - stride / 2, 3, leg_h, pal["leg"], pal["out"], pal["hi"], pal["sh"])
	# Körper
	_box(img, body_x, body_y, body_w, body_h, pal["body"], pal["out"], pal["hi"], pal["sh"])
	# Kopf
	var head_w: int = spec.get("head_w", 7)
	var head_h: int = spec.get("head_h", 6)
	var head_x := body_x + body_w - 3 + lunge
	var head_y := body_y - 2 + int(pose["head_down"]) * 2
	_box(img, head_x, head_y, head_w, head_h, pal["head"], pal["out"], pal["hi"], pal["sh"])
	_eye(img, head_x + head_w - 3, head_y + 2, pal, pose["hurt"])
	# Schnauze / Hauer
	if spec.get("snout", false):
		_box(img, head_x + head_w - 1, head_y + 3, 3, 2, pal["head"], pal["out"])
	if spec.get("tusks", false):
		_px(img, head_x + head_w, head_y + 5, pal["bone"])
		_px(img, head_x + head_w + 1, head_y + 6, pal["bone"])
	# Ohren / Geweih
	if spec.get("ears", 0) > 0:
		_box(img, head_x + 1, head_y - spec["ears"], 2, spec["ears"] + 1, pal["ear"], pal["out"])
		_box(img, head_x + 4, head_y - spec["ears"] + 1, 2, spec["ears"], pal["ear"], pal["out"])
	if spec.get("antlers", false):
		_px(img, head_x + 1, head_y - 1, pal["bone"])
		_px(img, head_x, head_y - 2, pal["bone"])
		_px(img, head_x + 2, head_y - 3, pal["bone"])
		_px(img, head_x + 5, head_y - 1, pal["bone"])
		_px(img, head_x + 6, head_y - 3, pal["bone"])
		_px(img, head_x + 7, head_y - 2, pal["bone"])
	# Schwanz
	var tail: int = spec.get("tail", 0)
	if tail > 0:
		var up := 1 if spec.get("tail_up", false) else 0
		_box(img, body_x - tail + 1, body_y + 2 - up * 4, tail, 3 + up * 3, pal.get("tail", pal["body"]), pal["out"], pal["hi"], pal["sh"])
	if spec.get("spines", false):
		for sx in range(2, body_w - 2, 2):
			_px(img, body_x + sx, body_y - 1, pal["out"])
			_px(img, body_x + sx, body_y - 2, pal["hi"])


func _hopper(img: Image, pal: Dictionary, pose: Dictionary, spec: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := w / 2
	var foot := h - 1 + int(pose["bob"])
	if int(pose["fallen"]) >= 2:
		_box(img, 4, h - 7, w - 8, 5, pal["body"], pal["out"], pal["hi"], pal["sh"])
		return
	var squash: int = pose["squash"]
	var stretch: int = pose["stretch"]
	var bw: int = spec.get("body_w", 10)
	var bh: int = spec.get("body_h", 7) - squash + stretch / 2
	var body_x := cx - bw / 2 + int(pose["lunge"])
	var body_y := foot - 5 - bh + squash - stretch
	_box(img, body_x + 1, foot - 4 + int(pose["stride"]), 3, 4, pal["leg"], pal["out"])
	_box(img, body_x + bw - 4, foot - 3 - int(pose["stride"]), 3, 3, pal["leg"], pal["out"])
	_box(img, body_x, body_y, bw, bh, pal["body"], pal["out"], pal["hi"], pal["sh"])
	var ears: int = spec.get("ears", 4)
	if ears > 0:
		_box(img, body_x + 1, body_y - ears, 2, ears + 1, pal["ear"], pal["out"])
		_box(img, body_x + 4, body_y - ears + 1, 2, ears, pal["ear"], pal["out"])
	_eye(img, body_x + bw - 3, body_y + 2, pal, pose["hurt"])
	if spec.get("tail", 0) > 0:
		_px(img, body_x - 1, body_y + bh - 3, pal["body"])
		_px(img, body_x - 2, body_y + bh - 4, pal["hi"])


func _bird(img: Image, pal: Dictionary, pose: Dictionary, spec: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := w / 2
	var foot := h - 1 + int(pose["bob"])
	if int(pose["fallen"]) >= 2:
		_box(img, 3, h - 7, w - 6, 5, pal["body"], pal["out"])
		return
	var body_w: int = spec.get("body_w", 8)
	var body_h: int = spec.get("body_h", 6)
	var body_x := cx - body_w / 2
	var body_y := foot - 4 - body_h
	if int(pose["wing"]) == 0 and not bool(spec.get("always_fly_pose", false)):
		_box(img, cx - 1, foot - 4, 1, 4, pal["leg"], pal["out"])
		_box(img, cx + 1, foot - 4, 1, 4, pal["leg"], pal["out"])
	_box(img, body_x, body_y, body_w, body_h, pal["body"], pal["out"], pal["hi"], pal["sh"])
	var wing: int = pose["wing"]
	var wing_h := 2 + wing
	_box(img, body_x - 1, body_y + 1 - wing, 4, wing_h, pal.get("wing", pal["body"]), pal["out"])
	_box(img, body_x + body_w - 3, body_y + 1 - wing, 4, wing_h, pal.get("wing", pal["body"]), pal["out"])
	_box(img, body_x + body_w - 2, body_y - 1 + int(pose["head_down"]), 4, 4, pal["head"], pal["out"], pal["hi"], pal["sh"])
	_px(img, body_x + body_w + 2, body_y + 1 + int(pose["head_down"]), pal.get("beak", pal["bone"]))
	_px(img, body_x + body_w + 3, body_y + 1 + int(pose["head_down"]), pal.get("beak", pal["bone"]))
	_eye(img, body_x + body_w, body_y, pal, pose["hurt"])
	if spec.get("comb", false):
		_px(img, body_x + body_w, body_y - 2, pal.get("comb", pal["ear"]))
		_px(img, body_x + body_w + 1, body_y - 3, pal.get("comb", pal["ear"]))


func _insect(img: Image, pal: Dictionary, pose: Dictionary, spec: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := w / 2
	var cy := h / 2 + int(pose["bob"])
	if int(pose["fallen"]) >= 2:
		_box(img, cx - 4, h - 6, 8, 4, pal["body"], pal["out"])
		return
	var wing: int = pose["wing"]
	var ww := 4 + wing
	if spec.get("large_wings", false):
		_box(img, cx - ww - 2, cy - 3 - wing, ww, 5 + wing, pal.get("wing", pal["hi"]), pal["out"], pal["hi"], pal["sh"])
		_box(img, cx + 2, cy - 3 - wing, ww, 5 + wing, pal.get("wing2", pal.get("wing", pal["hi"])), pal["out"], pal["hi"], pal["sh"])
	else:
		_box(img, cx - 5, cy - 1 - wing, 4, 3 + wing, pal.get("wing", Color8(220, 220, 200, 180)), pal["out"])
		_box(img, cx + 1, cy - 1 - wing, 4, 3 + wing, pal.get("wing", Color8(220, 220, 200, 180)), pal["out"])
	_box(img, cx - 3, cy - 2, 6, 5, pal["body"], pal["out"], pal["hi"], pal["sh"])
	if spec.get("stripes", false):
		_px(img, cx - 1, cy, pal["out"])
		_px(img, cx, cy - 1, pal["out"])
		_px(img, cx + 1, cy, pal["out"])
	if spec.get("glow_body", false):
		_box(img, cx - 1, cy, 3, 3, pal.get("glow", pal["hi"]), pal["out"])
	_eye(img, cx + 1, cy - 1, pal, pose["hurt"])


func _fish(img: Image, pal: Dictionary, pose: Dictionary, spec: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cy := h / 2 + int(pose["bob"])
	var cx := w / 2 + int(pose["stride"])
	if int(pose["fallen"]) >= 2:
		cy = h - 5
	_box(img, cx - 5, cy - 3, 10, 6, pal["body"], pal["out"], pal["hi"], pal["sh"])
	_box(img, cx - 8, cy - 2 + int(pose["stride"]) / 2, 4, 4, pal["tail"], pal["out"])
	_px(img, cx + 3, cy - 1, pal["eye"])
	_px(img, cx + 4, cy - 1, pal.get("eye_in", pal["hi"]))
	_px(img, cx, cy - 4, pal["hi"])
	_px(img, cx, cy + 3, pal["sh"])


func _frog(img: Image, pal: Dictionary, pose: Dictionary, spec: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := w / 2
	var foot := h - 1 + int(pose["bob"])
	if int(pose["fallen"]) >= 2:
		_box(img, 4, h - 6, w - 8, 4, pal["body"], pal["out"])
		return
	var stretch: int = pose["stretch"]
	_box(img, cx - 6, foot - 3, 4, 3, pal["leg"], pal["out"])
	_box(img, cx + 2, foot - 3, 4, 3, pal["leg"], pal["out"])
	_box(img, cx - 5, foot - 8 - stretch, 10, 6 + stretch / 2, pal["body"], pal["out"], pal["hi"], pal["sh"])
	_box(img, cx - 4, foot - 11 - stretch, 3, 3, pal["head"], pal["out"])
	_box(img, cx + 1, foot - 11 - stretch, 3, 3, pal["head"], pal["out"])
	_eye(img, cx - 3, foot - 10 - stretch, pal, pose["hurt"])
	_eye(img, cx + 2, foot - 10 - stretch, pal, pose["hurt"])


func _snail(img: Image, pal: Dictionary, pose: Dictionary, spec: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var foot := h - 1
	var x := 3 + int(pose["stride"])
	if int(pose["fallen"]) >= 2:
		_box(img, 4, h - 6, 12, 5, pal["body"], pal["out"])
		return
	_box(img, x, foot - 4, 10, 4, pal["body"], pal["out"], pal["hi"], pal["sh"])
	_box(img, x + 4, foot - 10 + int(pose["bob"]), 8, 8, pal["shell"], pal["out"], pal["hi"], pal["sh"])
	_px(img, x + 7, foot - 7, pal["out"])
	_px(img, x + 8, foot - 8, pal["hi"])
	_px(img, x + 9, foot - 4, pal["body"])
	_px(img, x + 1, foot - 6, pal["body"])
	_px(img, x, foot - 8, pal["ear"])
	_px(img, x + 2, foot - 8, pal["ear"])


func _bat(img: Image, pal: Dictionary, pose: Dictionary, spec: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := w / 2
	var cy := h / 2 + int(pose["bob"])
	if int(pose["fallen"]) >= 2:
		_box(img, 4, h - 6, w - 8, 4, pal["body"], pal["out"])
		return
	var wing: int = pose["wing"]
	_box(img, cx - 8 - wing, cy - 1, 7 + wing, 4, pal.get("wing", pal["body"]), pal["out"])
	_box(img, cx + 1, cy - 1, 7 + wing, 4, pal.get("wing", pal["body"]), pal["out"])
	_px(img, cx - 8 - wing, cy - 2, pal["out"])
	_px(img, cx + 7 + wing, cy - 2, pal["out"])
	_box(img, cx - 3, cy - 2, 6, 5, pal["body"], pal["out"], pal["hi"], pal["sh"])
	_box(img, cx - 2, cy - 4, 4, 3, pal["head"], pal["out"])
	_eye(img, cx - 1, cy - 3, pal, pose["hurt"])
	_eye(img, cx + 1, cy - 3, pal, pose["hurt"])
	_px(img, cx - 2, cy - 5, pal["ear"])
	_px(img, cx + 2, cy - 5, pal["ear"])


func _eye(img: Image, x: int, y: int, pal: Dictionary, hurt: bool) -> void:
	if hurt:
		_px(img, x, y, pal["out"])
		_px(img, x + 1, y, pal["out"])
		return
	_px(img, x, y, pal["eye"])
	_px(img, x + 1, y, pal.get("eye_in", pal["hi"]))


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if c.a <= 0.0 or x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)


func _box(img: Image, x: int, y: int, w: int, h: int, fill: Color, outline: Color, hi: Color = Color(0, 0, 0, 0), sh: Color = Color(0, 0, 0, 0)) -> void:
	if w <= 0 or h <= 0:
		return
	for dy in h:
		for dx in w:
			var col := fill
			if dx == 0 or dy == 0 or dx == w - 1 or dy == h - 1:
				col = outline
			elif hi.a > 0.0 and dx == 1 and dy > 0 and dy < h - 1:
				col = hi
			elif sh.a > 0.0 and dx == w - 2 and dy > 0 and dy < h - 1:
				col = sh
			_px(img, x + dx, y + dy, col)
