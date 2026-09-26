@tool
class_name AnimalAssetGenerator
extends RefCounted

## Erzeugt Pixel-Art, SpriteFrames, AnimalData, Szenen und Placeholder-SFX fuer Wildlife.

const ASSET_ROOT := "res://assets/animals"
const RES_ROOT := "res://resources/animals"
const SCENE_ROOT := "res://scenes/animals"
const AUDIO_ROOT := "res://audio/sfx/animals"
const SCRIPT_ROOT := "res://scripts/animals"
const PIXEL_ART := preload("res://tools/animal_pixel_art.gd")


func run() -> void:
	_ensure_dir(ASSET_ROOT)
	_ensure_dir(RES_ROOT)
	_ensure_dir(SCENE_ROOT)
	_ensure_dir(AUDIO_ROOT)
	_write_sfx()
	_write_settings()
	var art: Object = PIXEL_ART.new()
	var catalog_ids: PackedStringArray = PackedStringArray()
	for spec_variant in specs():
		var spec: Dictionary = spec_variant
		var id: String = spec["id"]
		_ensure_dir("%s/%s" % [ASSET_ROOT, id])
		_ensure_dir("%s/%s" % [SCENE_ROOT, id])
		_write_frames(art, spec)
		_write_data(spec)
		_write_definition(spec)
		_write_scene(spec)
		catalog_ids.append(id)
	_write_catalog(catalog_ids)
	print("[AnimalAssets] %d Tiere geschrieben." % catalog_ids.size())


func specs() -> Array:
	return [
		_rabbit(), _deer(), _boar(), _wolf(), _fox(), _squirrel(), _rat(), _chicken(),
		_bird(), _duck(), _frog(), _fish(), _bee(), _butterfly(), _snail(), _hedgehog(),
		_raven(), _bat(), _shadow_deer(), _dark_wolf(), _moth(), _firefly(), _dark_frog(), _corrupted_boar(),
	]


func _c(r: int, g: int, b: int, a: int = 255) -> Color:
	return Color8(r, g, b, a)


func _pal(body: Color, hi: Color, sh: Color, extra: Dictionary = {}) -> Dictionary:
	var pal := {
		"out": _c(22, 17, 14),
		"body": body,
		"hi": hi,
		"sh": sh,
		"head": body,
		"leg": sh,
		"ear": hi,
		"tail": sh,
		"eye": _c(26, 22, 20),
		"eye_in": _c(240, 236, 210),
		"bone": _c(214, 206, 186),
		"shell": body,
		"wing": hi,
		"beak": _c(196, 140, 60),
	}
	for key in extra.keys():
		pal[key] = extra[key]
	return pal


func _dark_pal(body: Color, hi: Color, sh: Color, extra: Dictionary = {}) -> Dictionary:
	var pal := _pal(body, hi, sh, extra)
	pal["out"] = _c(6, 4, 8)
	if not extra.has("eye"):
		pal["eye"] = _c(28, 8, 12)
	if not extra.has("eye_in"):
		pal["eye_in"] = _c(210, 48, 72)
	return pal


func _base(id: String, name: String, kind: String) -> Dictionary:
	return {
		"id": id,
		"display_name": name,
		"kind": kind,
		"class_name": id.capitalize().replace(" ", ""),
		"locomotion": 0,
		"temperament": 1,
		"walk_speed": 38.0,
		"run_speed": 90.0,
		"jump_force": 150.0,
		"gravity": 1000.0,
		"max_fall_speed": 600.0,
		"ground_acceleration": 240.0,
		"air_control": 180.0,
		"max_health": 12,
		"attack_damage": 0.0,
		"attack_cooldown": 1.1,
		"attack_range": 22.0,
		"detection_range": 96.0,
		"flee_range": 112.0,
		"knockback_force": 70.0,
		"hurt_lock_time": 0.14,
		"can_attack": false,
		"show_health_bar": false,
		"charge_on_hit": false,
		"curl_on_threat": false,
		"wander_radius": 80.0,
		"idle_min": 0.7,
		"idle_max": 2.4,
		"wander_min": 1.1,
		"wander_max": 2.8,
		"hop": false,
		"hop_interval": 0.42,
		"perch": false,
		"light": false,
		"glow": false,
		"peck": false,
		"jump_obs": false,
		"flee_dark": true,
		"safe_block": false,
		"time_rule": 0,
		"population": 0,
		"habitats": PackedStringArray(["grassland", "forest"]),
		"spawn_weight": 1.0,
		"dark_weight": 0.0,
		"night_bonus": 0.0,
		"surface_only": true,
		"allow_cave": false,
		"needs_water": false,
		"near_water": false,
		"canvas": Vector2i(24, 20),
		"collider": Vector2(10, 10),
		"hurtbox": Vector2(12, 12),
		"sprite_off": Vector2(0, -10),
		"bar_off": Vector2(0, -18),
		"anim_speed": 6.0,
		"z": 16,
		"darkness_form": false,
		"anims": ["idle", "walk", "run", "hurt", "death"],
		"sfx": {"Idle": "idle_soft", "Hurt": "hurt", "Death": "death", "Alert": "alert"},
		"body_w": 12,
		"body_h": 7,
		"leg_h": 5,
		"head_w": 6,
		"head_h": 5,
		"ears": 0,
		"tail": 0,
	}


func _rabbit() -> Dictionary:
	var s := _base("rabbit", "Kaninchen", "hopper")
	s["class_name"] = "Rabbit"
	s["walk_speed"] = 46.0
	s["run_speed"] = 118.0
	s["jump_force"] = 170.0
	s["flee_range"] = 128.0
	s["max_health"] = 8
	s["hop"] = true
	s["spawn_weight"] = 1.6
	s["anims"] = ["idle", "walk", "run", "jump", "hurt", "death"]
	s["ears"] = 5
	s["tail"] = 2
	s["pal"] = _pal(_c(196, 186, 168), _c(224, 216, 198), _c(150, 138, 122), {"ear": _c(214, 168, 168)})
	return s


func _deer() -> Dictionary:
	var s := _base("deer", "Hirsch", "quad")
	s["class_name"] = "Deer"
	s["canvas"] = Vector2i(48, 40)
	s["collider"] = Vector2(18, 26)
	s["hurtbox"] = Vector2(20, 28)
	s["sprite_off"] = Vector2(0, -20)
	s["bar_off"] = Vector2(0, -34)
	s["walk_speed"] = 52.0
	s["run_speed"] = 148.0
	s["jump_force"] = 190.0
	s["flee_range"] = 176.0
	s["max_health"] = 36
	s["show_health_bar"] = true
	s["jump_obs"] = true
	s["spawn_weight"] = 0.7
	s["body_w"] = 20
	s["body_h"] = 10
	s["leg_h"] = 12
	s["head_w"] = 8
	s["antlers"] = true
	s["snout"] = true
	s["tail"] = 3
	s["anims"] = ["idle", "walk", "run", "jump", "hurt", "death"]
	s["pal"] = _pal(_c(150, 108, 70), _c(186, 142, 96), _c(102, 72, 46))
	s["sfx"]["Idle"] = "idle_soft"
	return s


func _boar() -> Dictionary:
	var s := _base("boar", "Wildschwein", "quad")
	s["class_name"] = "Boar"
	s["temperament"] = 2
	s["canvas"] = Vector2i(40, 28)
	s["collider"] = Vector2(22, 16)
	s["hurtbox"] = Vector2(24, 18)
	s["sprite_off"] = Vector2(0, -14)
	s["bar_off"] = Vector2(0, -24)
	s["walk_speed"] = 36.0
	s["run_speed"] = 110.0
	s["max_health"] = 50
	s["can_attack"] = true
	s["charge_on_hit"] = true
	s["attack_damage"] = 12.0
	s["show_health_bar"] = true
	s["flee_dark"] = true
	s["habitats"] = PackedStringArray(["forest"])
	s["spawn_weight"] = 0.55
	s["body_w"] = 18
	s["body_h"] = 10
	s["leg_h"] = 6
	s["tusks"] = true
	s["snout"] = true
	s["anims"] = ["idle", "walk", "run", "attack", "hurt", "death"]
	s["sfx"]["Attack"] = "grunt"
	s["sfx"]["Idle"] = "grunt"
	s["pal"] = _pal(_c(86, 64, 50), _c(118, 88, 68), _c(54, 40, 32), {"bone": _c(230, 220, 200)})
	return s


func _wolf() -> Dictionary:
	var s := _base("wolf", "Wolf", "quad")
	s["class_name"] = "Wolf"
	s["temperament"] = 3
	s["canvas"] = Vector2i(40, 28)
	s["collider"] = Vector2(20, 16)
	s["hurtbox"] = Vector2(22, 18)
	s["sprite_off"] = Vector2(0, -14)
	s["bar_off"] = Vector2(0, -24)
	s["walk_speed"] = 48.0
	s["run_speed"] = 128.0
	s["detection_range"] = 168.0
	s["attack_range"] = 26.0
	s["attack_damage"] = 14.0
	s["max_health"] = 42
	s["can_attack"] = true
	s["show_health_bar"] = true
	s["flee_dark"] = false
	s["habitats"] = PackedStringArray(["forest"])
	s["spawn_weight"] = 0.35
	s["dark_weight"] = 0.15
	s["snout"] = true
	s["tail"] = 5
	s["ears"] = 3
	s["body_w"] = 16
	s["body_h"] = 8
	s["anims"] = ["idle", "walk", "run", "attack", "hurt", "death"]
	s["sfx"]["Alert"] = "growl"
	s["sfx"]["Attack"] = "growl"
	s["sfx"]["Idle"] = "growl"
	s["pal"] = _pal(_c(112, 116, 124), _c(150, 154, 162), _c(70, 74, 82), {"eye_in": _c(220, 200, 120)})
	return s


func _fox() -> Dictionary:
	var s := _base("fox", "Fuchs", "quad")
	s["class_name"] = "Fox"
	s["canvas"] = Vector2i(32, 20)
	s["collider"] = Vector2(16, 12)
	s["hurtbox"] = Vector2(18, 14)
	s["sprite_off"] = Vector2(0, -10)
	s["walk_speed"] = 58.0
	s["run_speed"] = 142.0
	s["flee_range"] = 140.0
	s["idle_max"] = 1.4
	s["habitats"] = PackedStringArray(["forest", "sand"])
	s["spawn_weight"] = 0.8
	s["snout"] = true
	s["tail"] = 7
	s["ears"] = 3
	s["body_w"] = 12
	s["pal"] = _pal(_c(196, 112, 52), _c(224, 150, 78), _c(140, 72, 36), {"tail": _c(232, 228, 220)})
	return s


func _squirrel() -> Dictionary:
	var s := _base("squirrel", "Eichhörnchen", "hopper")
	s["class_name"] = "Squirrel"
	s["canvas"] = Vector2i(20, 18)
	s["collider"] = Vector2(8, 10)
	s["hurtbox"] = Vector2(10, 12)
	s["sprite_off"] = Vector2(0, -9)
	s["walk_speed"] = 62.0
	s["run_speed"] = 150.0
	s["max_health"] = 6
	s["habitats"] = PackedStringArray(["forest"])
	s["spawn_weight"] = 1.1
	s["ears"] = 3
	s["tail"] = 4
	s["tail_up"] = true
	s["anims"] = ["idle", "walk", "run", "hurt", "death"]
	s["pal"] = _pal(_c(168, 96, 52), _c(198, 130, 78), _c(110, 64, 36), {"tail": _c(150, 86, 48)})
	return s


func _rat() -> Dictionary:
	var s := _base("rat", "Ratte", "quad")
	s["class_name"] = "Rat"
	s["canvas"] = Vector2i(20, 12)
	s["collider"] = Vector2(10, 6)
	s["hurtbox"] = Vector2(12, 8)
	s["sprite_off"] = Vector2(0, -6)
	s["bar_off"] = Vector2(0, -12)
	s["walk_speed"] = 70.0
	s["run_speed"] = 156.0
	s["max_health"] = 5
	s["time_rule"] = 0
	s["night_bonus"] = 1.2
	s["habitats"] = PackedStringArray(["grassland", "sand", "forest"])
	s["surface_only"] = false
	s["allow_cave"] = true
	s["spawn_weight"] = 0.5
	s["snout"] = true
	s["tail"] = 6
	s["ears"] = 2
	s["body_w"] = 9
	s["body_h"] = 4
	s["leg_h"] = 3
	s["sfx"]["Alert"] = "squeak"
	s["sfx"]["Idle"] = "squeak"
	s["pal"] = _pal(_c(92, 84, 80), _c(128, 118, 112), _c(58, 52, 50), {"ear": _c(196, 140, 140)})
	return s


func _chicken() -> Dictionary:
	var s := _base("chicken", "Wildhuhn", "bird")
	s["class_name"] = "Chicken"
	s["locomotion"] = 0
	s["canvas"] = Vector2i(24, 20)
	s["walk_speed"] = 42.0
	s["run_speed"] = 108.0
	s["jump_force"] = 130.0
	s["peck"] = true
	s["jump_obs"] = true
	s["habitats"] = PackedStringArray(["grassland", "sand"])
	s["spawn_weight"] = 1.0
	s["comb"] = true
	s["anims"] = ["idle", "walk", "run", "eat", "jump", "hurt", "death"]
	s["sfx"]["Idle"] = "chirp"
	s["pal"] = _pal(_c(214, 206, 186), _c(236, 228, 210), _c(150, 140, 122), {"comb": _c(196, 48, 42), "beak": _c(214, 150, 40), "head": _c(236, 228, 210)})
	return s


func _bird() -> Dictionary:
	var s := _base("bird", "Vogel", "bird")
	s["class_name"] = "Bird"
	s["locomotion"] = 1
	s["population"] = 1
	s["perch"] = true
	s["canvas"] = Vector2i(20, 16)
	s["collider"] = Vector2(8, 8)
	s["hurtbox"] = Vector2(10, 10)
	s["sprite_off"] = Vector2(0, -8)
	s["walk_speed"] = 40.0
	s["run_speed"] = 130.0
	s["max_health"] = 4
	s["habitats"] = PackedStringArray(["grassland", "forest", "sand"])
	s["spawn_weight"] = 1.2
	s["z"] = 17
	s["anims"] = ["idle", "walk", "fly", "hurt", "death"]
	s["sfx"]["Idle"] = "chirp"
	s["sfx"]["Alert"] = "chirp"
	s["pal"] = _pal(_c(72, 122, 168), _c(110, 162, 206), _c(40, 78, 112), {"beak": _c(214, 150, 40)})
	return s


func _duck() -> Dictionary:
	var s := _base("duck", "Ente", "bird")
	s["class_name"] = "Duck"
	s["locomotion"] = 3
	s["population"] = 2
	s["near_water"] = true
	s["habitats"] = PackedStringArray(["grassland", "water"])
	s["canvas"] = Vector2i(24, 18)
	s["collider"] = Vector2(12, 10)
	s["walk_speed"] = 34.0
	s["run_speed"] = 88.0
	s["spawn_weight"] = 0.7
	s["anims"] = ["idle", "walk", "swim", "hurt", "death"]
	s["sfx"]["Idle"] = "croak"
	s["pal"] = _pal(_c(46, 90, 64), _c(78, 132, 92), _c(28, 58, 40), {"head": _c(36, 36, 36), "beak": _c(214, 140, 36)})
	return s


func _frog() -> Dictionary:
	var s := _base("frog", "Frosch", "frog")
	s["class_name"] = "Frog"
	s["locomotion"] = 3
	s["hop"] = true
	s["near_water"] = true
	s["habitats"] = PackedStringArray(["grassland", "water", "forest"])
	s["canvas"] = Vector2i(20, 14)
	s["collider"] = Vector2(10, 8)
	s["hurtbox"] = Vector2(12, 10)
	s["sprite_off"] = Vector2(0, -7)
	s["walk_speed"] = 28.0
	s["run_speed"] = 72.0
	s["jump_force"] = 150.0
	s["spawn_weight"] = 0.8
	s["anims"] = ["idle", "walk", "jump", "swim", "hurt", "death"]
	s["sfx"]["Idle"] = "croak"
	s["pal"] = _pal(_c(74, 142, 64), _c(118, 186, 86), _c(40, 92, 36), {"head": _c(86, 158, 70), "eye_in": _c(250, 240, 80)})
	return s


func _fish() -> Dictionary:
	var s := _base("fish", "Fisch", "fish")
	s["class_name"] = "Fish"
	s["locomotion"] = 2
	s["population"] = 2
	s["needs_water"] = true
	s["habitats"] = PackedStringArray(["water"])
	s["temperament"] = 0
	s["flee_range"] = 64.0
	s["canvas"] = Vector2i(20, 12)
	s["collider"] = Vector2(10, 6)
	s["hurtbox"] = Vector2(12, 8)
	s["sprite_off"] = Vector2(0, -6)
	s["walk_speed"] = 36.0
	s["run_speed"] = 70.0
	s["max_health"] = 4
	s["gravity"] = 0.0
	s["spawn_weight"] = 1.4
	s["surface_only"] = false
	s["anims"] = ["idle", "swim", "hurt", "death"]
	s["pal"] = _pal(_c(56, 122, 176), _c(110, 176, 220), _c(28, 72, 118), {"tail": _c(40, 90, 140)})
	return s


func _bee() -> Dictionary:
	var s := _base("bee", "Biene", "insect")
	s["class_name"] = "Bee"
	s["locomotion"] = 1
	s["population"] = 1
	s["temperament"] = 0
	s["flee_range"] = 48.0
	s["canvas"] = Vector2i(16, 16)
	s["collider"] = Vector2(6, 6)
	s["hurtbox"] = Vector2(8, 8)
	s["sprite_off"] = Vector2(0, -8)
	s["walk_speed"] = 28.0
	s["run_speed"] = 64.0
	s["max_health"] = 3
	s["gravity"] = 0.0
	s["habitats"] = PackedStringArray(["grassland", "forest"])
	s["spawn_weight"] = 0.9
	s["z"] = 17
	s["stripes"] = true
	s["anims"] = ["idle", "fly", "hurt", "death"]
	s["sfx"]["Idle"] = "buzz"
	s["pal"] = _pal(_c(232, 186, 48), _c(250, 220, 90), _c(28, 22, 16), {"wing": _c(220, 230, 236, 160)})
	return s


func _butterfly() -> Dictionary:
	var s := _base("butterfly", "Schmetterling", "insect")
	s["class_name"] = "Butterfly"
	s["locomotion"] = 1
	s["population"] = 1
	s["temperament"] = 1
	s["flee_range"] = 72.0
	s["canvas"] = Vector2i(20, 16)
	s["collider"] = Vector2(8, 6)
	s["hurtbox"] = Vector2(10, 8)
	s["sprite_off"] = Vector2(0, -8)
	s["walk_speed"] = 18.0
	s["run_speed"] = 46.0
	s["max_health"] = 2
	s["gravity"] = 0.0
	s["habitats"] = PackedStringArray(["grassland"])
	s["spawn_weight"] = 1.0
	s["time_rule"] = 1
	s["large_wings"] = true
	s["z"] = 17
	s["anims"] = ["idle", "fly", "hurt", "death"]
	s["pal"] = _pal(_c(48, 40, 36), _c(196, 86, 160), _c(86, 48, 140), {"wing": _c(214, 92, 64), "wing2": _c(78, 122, 196)})
	return s


func _snail() -> Dictionary:
	var s := _base("snail", "Schnecke", "snail")
	s["class_name"] = "Snail"
	s["temperament"] = 0
	s["flee_range"] = 0.0
	s["canvas"] = Vector2i(20, 12)
	s["collider"] = Vector2(10, 6)
	s["hurtbox"] = Vector2(12, 8)
	s["sprite_off"] = Vector2(0, -6)
	s["walk_speed"] = 8.0
	s["run_speed"] = 10.0
	s["max_health"] = 6
	s["habitats"] = PackedStringArray(["grassland", "forest", "sand"])
	s["spawn_weight"] = 0.4
	s["idle_max"] = 3.5
	s["anims"] = ["idle", "walk", "hurt", "death"]
	s["pal"] = _pal(_c(168, 132, 96), _c(206, 170, 124), _c(110, 82, 58), {"shell": _c(150, 86, 64), "ear": _c(196, 160, 130)})
	return s


func _hedgehog() -> Dictionary:
	var s := _base("hedgehog", "Igel", "quad")
	s["class_name"] = "Hedgehog"
	s["temperament"] = 2
	s["curl_on_threat"] = true
	s["canvas"] = Vector2i(24, 16)
	s["collider"] = Vector2(12, 8)
	s["hurtbox"] = Vector2(14, 10)
	s["sprite_off"] = Vector2(0, -8)
	s["walk_speed"] = 22.0
	s["run_speed"] = 36.0
	s["max_health"] = 16
	s["detection_range"] = 64.0
	s["spines"] = true
	s["body_w"] = 12
	s["body_h"] = 7
	s["leg_h"] = 3
	s["snout"] = true
	s["anims"] = ["idle", "walk", "curl", "hurt", "death"]
	s["pal"] = _pal(_c(92, 74, 58), _c(130, 108, 86), _c(54, 42, 32))
	return s


func _raven() -> Dictionary:
	var s := _base("raven", "Rabe", "bird")
	s["class_name"] = "Raven"
	s["locomotion"] = 1
	s["population"] = 1
	s["perch"] = true
	s["time_rule"] = 4
	s["canvas"] = Vector2i(22, 18)
	s["collider"] = Vector2(10, 10)
	s["walk_speed"] = 36.0
	s["run_speed"] = 120.0
	s["habitats"] = PackedStringArray(["forest", "grassland", "sand"])
	s["spawn_weight"] = 0.2
	s["dark_weight"] = 0.8
	s["night_bonus"] = 0.9
	s["flee_dark"] = false
	s["anims"] = ["idle", "walk", "fly", "hurt", "death"]
	s["sfx"]["Idle"] = "caw"
	s["sfx"]["Alert"] = "caw"
	s["pal"] = _pal(_c(22, 22, 26), _c(48, 48, 56), _c(10, 10, 12), {"beak": _c(40, 36, 36), "eye_in": _c(196, 48, 48)})
	return s


func _bat() -> Dictionary:
	var s := _base("bat", "Fledermaus", "bat")
	s["class_name"] = "Bat"
	s["locomotion"] = 1
	s["population"] = 1
	s["time_rule"] = 4
	s["allow_cave"] = true
	s["surface_only"] = false
	s["canvas"] = Vector2i(24, 16)
	s["collider"] = Vector2(12, 8)
	s["hurtbox"] = Vector2(14, 10)
	s["sprite_off"] = Vector2(0, -8)
	s["walk_speed"] = 50.0
	s["run_speed"] = 110.0
	s["gravity"] = 0.0
	s["habitats"] = PackedStringArray(["forest", "grassland", "sand"])
	s["spawn_weight"] = 0.15
	s["dark_weight"] = 0.9
	s["night_bonus"] = 1.0
	s["flee_dark"] = false
	s["z"] = 18
	s["anims"] = ["idle", "fly", "hurt", "death"]
	s["sfx"]["Idle"] = "squeak"
	s["sfx"]["Alert"] = "squeak"
	s["pal"] = _pal(_c(48, 36, 54), _c(78, 58, 86), _c(24, 16, 28), {"wing": _c(36, 28, 44), "ear": _c(78, 48, 64), "eye_in": _c(210, 64, 88)})
	return s


func _shadow_deer() -> Dictionary:
	var s := _deer()
	s["id"] = "shadow_deer"
	s["display_name"] = "Schattenhirsch"
	s["class_name"] = "ShadowDeer"
	s["time_rule"] = 3
	s["population"] = 3
	s["temperament"] = 1
	s["flee_range"] = 200.0
	s["spawn_weight"] = 0.0
	s["dark_weight"] = 0.35
	s["flee_dark"] = false
	s["darkness_form"] = true
	s["safe_block"] = false
	s["habitats"] = PackedStringArray(["forest", "grassland"])
	s["pal"] = _dark_pal(_c(36, 32, 48), _c(64, 52, 86), _c(16, 12, 24), {"eye": _c(20, 60, 70), "eye_in": _c(80, 220, 230), "bone": _c(90, 80, 110)})
	return s


func _dark_wolf() -> Dictionary:
	var s := _wolf()
	s["id"] = "dark_wolf"
	s["display_name"] = "Finsterwolf"
	s["class_name"] = "DarkWolf"
	s["canvas"] = Vector2i(44, 32)
	s["collider"] = Vector2(22, 18)
	s["hurtbox"] = Vector2(24, 20)
	s["sprite_off"] = Vector2(0, -16)
	s["bar_off"] = Vector2(0, -28)
	s["time_rule"] = 3
	s["population"] = 3
	s["walk_speed"] = 56.0
	s["run_speed"] = 146.0
	s["detection_range"] = 210.0
	s["attack_damage"] = 20.0
	s["max_health"] = 70
	s["spawn_weight"] = 0.0
	s["dark_weight"] = 0.55
	s["flee_dark"] = false
	s["darkness_form"] = true
	s["safe_block"] = true
	s["body_w"] = 18
	s["body_h"] = 9
	s["pal"] = _dark_pal(_c(18, 14, 22), _c(42, 28, 48), _c(8, 6, 12), {"eye_in": _c(220, 36, 58)})
	return s


func _moth() -> Dictionary:
	var s := _base("moth", "Nachtfalter", "insect")
	s["class_name"] = "Moth"
	s["locomotion"] = 1
	s["population"] = 3
	s["time_rule"] = 4
	s["light"] = true
	s["temperament"] = 0
	s["flee_range"] = 36.0
	s["canvas"] = Vector2i(20, 16)
	s["collider"] = Vector2(8, 6)
	s["gravity"] = 0.0
	s["walk_speed"] = 22.0
	s["run_speed"] = 40.0
	s["max_health"] = 2
	s["spawn_weight"] = 0.25
	s["dark_weight"] = 1.1
	s["night_bonus"] = 0.8
	s["flee_dark"] = false
	s["large_wings"] = true
	s["anims"] = ["idle", "fly", "hurt", "death"]
	s["pal"] = _pal(_c(90, 78, 64), _c(186, 162, 120), _c(48, 40, 32), {"wing": _c(150, 132, 96), "wing2": _c(110, 92, 70)})
	return s


func _firefly() -> Dictionary:
	var s := _base("firefly", "Glühkäfer", "insect")
	s["class_name"] = "Firefly"
	s["locomotion"] = 1
	s["population"] = 3
	s["time_rule"] = 4
	s["glow"] = true
	s["temperament"] = 0
	s["flee_range"] = 40.0
	s["canvas"] = Vector2i(16, 16)
	s["collider"] = Vector2(6, 6)
	s["gravity"] = 0.0
	s["walk_speed"] = 16.0
	s["run_speed"] = 28.0
	s["max_health"] = 2
	s["spawn_weight"] = 0.2
	s["dark_weight"] = 1.3
	s["night_bonus"] = 1.1
	s["flee_dark"] = false
	s["glow_body"] = true
	s["z"] = 17
	s["anims"] = ["idle", "fly", "hurt", "death"]
	s["pal"] = _pal(_c(36, 42, 28), _c(64, 74, 40), _c(18, 22, 14), {"glow": _c(210, 230, 70), "wing": _c(180, 200, 140, 140)})
	return s


func _dark_frog() -> Dictionary:
	var s := _frog()
	s["id"] = "dark_frog"
	s["display_name"] = "Dunkelfrosch"
	s["class_name"] = "DarkFrog"
	s["time_rule"] = 3
	s["population"] = 3
	s["spawn_weight"] = 0.0
	s["dark_weight"] = 0.7
	s["flee_dark"] = false
	s["darkness_form"] = true
	s["pal"] = _dark_pal(_c(28, 42, 36), _c(48, 78, 54), _c(12, 20, 16), {"eye_in": _c(170, 230, 80), "head": _c(32, 50, 40)})
	return s


func _corrupted_boar() -> Dictionary:
	var s := _boar()
	s["id"] = "corrupted_boar"
	s["display_name"] = "Verderbtes Wildschwein"
	s["class_name"] = "CorruptedBoar"
	s["canvas"] = Vector2i(42, 30)
	s["collider"] = Vector2(24, 18)
	s["temperament"] = 3
	s["time_rule"] = 3
	s["population"] = 3
	s["walk_speed"] = 44.0
	s["run_speed"] = 124.0
	s["detection_range"] = 150.0
	s["attack_damage"] = 18.0
	s["max_health"] = 80
	s["spawn_weight"] = 0.0
	s["dark_weight"] = 0.5
	s["flee_dark"] = false
	s["darkness_form"] = true
	s["safe_block"] = true
	s["pal"] = _dark_pal(_c(40, 22, 28), _c(72, 32, 42), _c(16, 8, 12), {"bone": _c(210, 180, 170), "eye_in": _c(220, 48, 64)})
	return s


func _write_frames(art: Object, spec: Dictionary) -> void:
	var id: String = spec["id"]
	var lines: PackedStringArray = PackedStringArray()
	var ext_id := 1
	var ids: Dictionary = {}
	var anims: Array = spec["anims"]
	for anim_variant in anims:
		var anim: String = String(anim_variant)
		var count := _frame_count(anim)
		for i in count:
			var img: Image = art.call("draw", spec, anim, i) as Image
			var path := "%s/%s/%s_%d.png" % [ASSET_ROOT, id, anim, i]
			img.save_png(path)
			var key := "%s_%d" % [anim, i]
			var rid := "%d_%s" % [ext_id, key.replace("_", "")]
			ids[key] = rid
			lines.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % [path, rid])
			ext_id += 1
	var out: PackedStringArray = PackedStringArray()
	out.append("[gd_resource type=\"SpriteFrames\" load_steps=%d format=3]" % (ext_id))
	out.append("")
	out.append_array(lines)
	out.append("")
	out.append("[resource]")
	out.append("animations = [")
	var blocks: PackedStringArray = PackedStringArray()
	for anim_variant2 in anims:
		var anim2: String = String(anim_variant2)
		var count2 := _frame_count(anim2)
		var frames: PackedStringArray = PackedStringArray()
		for i in count2:
			var key2 := "%s_%d" % [anim2, i]
			frames.append("{\n\"duration\": 1.0,\n\"texture\": ExtResource(\"%s\")\n}" % ids[key2])
		var loop := "true"
		if anim2 in ["hurt", "death", "attack"]:
			loop = "false"
		var speed := _anim_fps(anim2, spec)
		blocks.append("{\n\"frames\": [%s],\n\"loop\": %s,\n\"name\": &\"%s\",\n\"speed\": %s\n}" % [", ".join(frames), loop, anim2, str(speed)])
	out.append(",\n".join(blocks))
	out.append("]")
	_write_text("%s/%s_frames.tres" % [RES_ROOT, id], "\n".join(out) + "\n")


func _frame_count(anim: String) -> int:
	match anim:
		"hurt", "curl":
			return 2
		"death", "jump":
			return 4
		"attack", "eat":
			return 3
		_:
			return 4


func _anim_fps(anim: String, spec: Dictionary) -> float:
	var base: float = spec.get("anim_speed", 6.0)
	match anim:
		"idle":
			return maxf(base * 0.55, 3.0)
		"walk", "swim":
			return base
		"run", "fly":
			return base + 3.0
		"hurt":
			return 12.0
		"death":
			return 7.0
		"attack":
			return 10.0
		"jump":
			return 8.0
		_:
			return base


func _write_data(spec: Dictionary) -> void:
	var habitats := spec["habitats"] as PackedStringArray
	var hab_parts: PackedStringArray = PackedStringArray()
	for h in habitats:
		hab_parts.append("\"%s\"" % h)
	var canvas: Vector2i = spec["canvas"]
	var col: Vector2 = spec["collider"]
	var hurt: Vector2 = spec["hurtbox"]
	var spr: Vector2 = spec["sprite_off"]
	var bar: Vector2 = spec["bar_off"]
	var text := """[gd_resource type=\"Resource\" script_class=\"AnimalData\" load_steps=2 format=3]

[ext_resource type=\"Script\" path=\"res://scripts/animals/animal_data.gd\" id=\"1\"]

[resource]
script = ExtResource(\"1\")
id = &\"%s\"
display_name = \"%s\"
locomotion = %d
temperament = %d
walk_speed = %s
run_speed = %s
jump_force = %s
gravity = %s
max_fall_speed = %s
ground_acceleration = %s
air_control = %s
max_health = %d
attack_damage = %s
attack_cooldown = %s
attack_range = %s
detection_range = %s
flee_range = %s
knockback_force = %s
hurt_lock_time = %s
can_attack = %s
show_health_bar = %s
charge_on_hit = %s
curl_on_threat = %s
wander_radius = %s
idle_duration_min = %s
idle_duration_max = %s
wander_duration_min = %s
wander_duration_max = %s
hop_locomotion = %s
hop_interval = %s
perch_then_fly = %s
attracted_to_light = %s
glow = %s
peck_idle = %s
jump_small_obstacles = %s
flee_on_darkness = %s
blocked_by_safe_zone = %s
time_rule = %d
population = %d
habitats = PackedStringArray(%s)
spawn_weight = %s
darkness_spawn_weight = %s
night_spawn_bonus = %s
surface_only = %s
allow_cave = %s
needs_water = %s
near_water = %s
canvas_size = Vector2i(%d, %d)
collider_size = Vector2(%s, %s)
hurtbox_size = Vector2(%s, %s)
sprite_offset = Vector2(%s, %s)
health_bar_offset = Vector2(%s, %s)
animation_speed = %s
z_index_value = %d
darkness_form = %s
""" % [
		spec["id"], spec["display_name"], spec["locomotion"], spec["temperament"],
		str(spec["walk_speed"]), str(spec["run_speed"]), str(spec["jump_force"]),
		str(spec["gravity"]), str(spec["max_fall_speed"]), str(spec["ground_acceleration"]), str(spec["air_control"]),
		spec["max_health"], str(spec["attack_damage"]), str(spec["attack_cooldown"]), str(spec["attack_range"]),
		str(spec["detection_range"]), str(spec["flee_range"]), str(spec["knockback_force"]), str(spec["hurt_lock_time"]),
		_b(spec["can_attack"]), _b(spec["show_health_bar"]), _b(spec["charge_on_hit"]), _b(spec["curl_on_threat"]),
		str(spec["wander_radius"]), str(spec["idle_min"]), str(spec["idle_max"]), str(spec["wander_min"]), str(spec["wander_max"]),
		_b(spec["hop"]), str(spec["hop_interval"]), _b(spec["perch"]), _b(spec["light"]), _b(spec["glow"]),
		_b(spec["peck"]), _b(spec["jump_obs"]), _b(spec["flee_dark"]), _b(spec["safe_block"]),
		spec["time_rule"], spec["population"], ", ".join(hab_parts),
		str(spec["spawn_weight"]), str(spec["dark_weight"]), str(spec["night_bonus"]),
		_b(spec["surface_only"]), _b(spec["allow_cave"]), _b(spec["needs_water"]), _b(spec["near_water"]),
		canvas.x, canvas.y, str(col.x), str(col.y), str(hurt.x), str(hurt.y),
		str(spr.x), str(spr.y), str(bar.x), str(bar.y), str(spec["anim_speed"]), spec["z"], _b(spec["darkness_form"]),
	]
	_write_text("%s/%s_data.tres" % [RES_ROOT, spec["id"]], text)


func _write_definition(spec: Dictionary) -> void:
	var id: String = spec["id"]
	var text := """[gd_resource type=\"Resource\" script_class=\"AnimalDefinition\" load_steps=5 format=3]

[ext_resource type=\"Script\" path=\"res://scripts/animals/animal_definition.gd\" id=\"1\"]
[ext_resource type=\"PackedScene\" path=\"res://scenes/animals/%s/%s.tscn\" id=\"2\"]
[ext_resource type=\"Resource\" path=\"res://resources/animals/%s_data.tres\" id=\"3\"]
[ext_resource type=\"Texture2D\" path=\"res://assets/animals/%s/idle_0.png\" id=\"4\"]

[resource]
script = ExtResource(\"1\")
id = &\"%s\"
display_name = \"%s\"
scene = ExtResource(\"2\")
data = ExtResource(\"3\")
icon = ExtResource(\"4\")
""" % [id, id, id, id, id, spec["display_name"]]
	_write_text("%s/%s_def.tres" % [RES_ROOT, id], text)


func _write_scene(spec: Dictionary) -> void:
	var id: String = spec["id"]
	var script_path := "%s/%s.gd" % [SCRIPT_ROOT, id]
	var col: Vector2 = spec["collider"]
	var hurt: Vector2 = spec["hurtbox"]
	var spr: Vector2 = spec["sprite_off"]
	var bar: Vector2 = spec["bar_off"]
	var canvas: Vector2i = spec["canvas"]
	var sfx: Dictionary = spec["sfx"]
	var steps := 8
	if spec["can_attack"]:
		steps += 1
	steps += sfx.size()
	var ext: PackedStringArray = PackedStringArray()
	ext.append('[ext_resource type="Script" path="%s" id="1_script"]' % script_path)
	ext.append('[ext_resource type="SpriteFrames" path="res://resources/animals/%s_frames.tres" id="2_frames"]' % id)
	ext.append('[ext_resource type="Resource" path="res://resources/animals/%s_data.tres" id="3_data"]' % id)
	ext.append('[ext_resource type="Script" path="res://scripts/combat/hurtbox.gd" id="4_hurt"]')
	var next_id := 5
	if spec["can_attack"]:
		ext.append('[ext_resource type="Script" path="res://scripts/combat/enemy_hitbox.gd" id="5_hit"]')
		next_id = 6
	var sfx_ext: Dictionary = {}
	for key in sfx.keys():
		var rid := "%d_%s" % [next_id, String(key).to_lower()]
		sfx_ext[key] = rid
		ext.append('[ext_resource type="AudioStream" path="res://audio/sfx/animals/%s.wav" id="%s"]' % [String(sfx[key]), rid])
		next_id += 1
	var hit_sub := ""
	var hit_block := ""
	if spec["can_attack"]:
		hit_sub = """
[sub_resource type="RectangleShape2D" id="RectangleShape2D_hit"]
size = Vector2(16, 14)
"""
		hit_block = """
[node name="AttackHitbox" type="Area2D" parent="."]
position = Vector2(12, %s)
collision_layer = 0
collision_mask = 2
monitoring = false
monitorable = false
script = ExtResource("5_hit")

[node name="CollisionShape2D" type="CollisionShape2D" parent="AttackHitbox"]
shape = SubResource("RectangleShape2D_hit")
""" % str(-col.y * 0.45)
	var audio_nodes := "\n[node name=\"Audio\" type=\"Node\" parent=\".\"]\n"
	for key in sfx.keys():
		var vol := "-12.0"
		if String(sfx[key]) == "buzz":
			vol = "-18.0"
		audio_nodes += """
[node name="%s" type="AudioStreamPlayer2D" parent="Audio"]
stream = ExtResource("%s")
volume_db = %s
max_distance = 380.0
bus = &"SFX"
""" % [String(key), sfx_ext[key], vol]
	var text := """[gd_scene load_steps=%d format=3]

%s

[sub_resource type="RectangleShape2D" id="RectangleShape2D_body"]
size = Vector2(%s, %s)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_hurt"]
size = Vector2(%s, %s)
%s
[node name="%s" type="CharacterBody2D"]
z_index = %d
collision_layer = 4
collision_mask = 33
floor_snap_length = 8.0
floor_max_angle = 0.872665
floor_constant_speed = true
script = ExtResource("1_script")
data = ExtResource("3_data")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 0
position = Vector2(%s, %s)
sprite_frames = ExtResource("2_frames")
animation = &"idle"

[node name="HealthBarAnchor" type="Marker2D" parent="."]
position = Vector2(%s, %s)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, %s)
shape = SubResource("RectangleShape2D_body")

[node name="Hurtbox" type="Area2D" parent="."]
collision_layer = 4
collision_mask = 0
monitoring = false
monitorable = true
script = ExtResource("4_hurt")

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hurtbox"]
position = Vector2(0, %s)
shape = SubResource("RectangleShape2D_hurt")
%s
[node name="GroundCheck" type="RayCast2D" parent="."]
position = Vector2(0, -2)
target_position = Vector2(0, 10)
collision_mask = 1

[node name="WallCheck" type="RayCast2D" parent="."]
position = Vector2(6, %s)
target_position = Vector2(12, 0)
collision_mask = 1

[node name="EdgeCheck" type="RayCast2D" parent="."]
position = Vector2(10, -2)
target_position = Vector2(0, 14)
collision_mask = 1

[node name="VisibleOnScreenNotifier2D" type="VisibleOnScreenNotifier2D" parent="."]
position = Vector2(0, %s)
rect = Rect2(%s, %s, %s, %s)
%s
""" % [
		steps,
		"\n".join(ext),
		str(col.x), str(col.y),
		str(hurt.x), str(hurt.y),
		hit_sub,
		String(spec["class_name"]),
		spec["z"],
		str(spr.x), str(spr.y),
		str(bar.x), str(bar.y),
		str(-col.y * 0.5),
		str(-hurt.y * 0.5),
		hit_block,
		str(-col.y * 0.5),
		str(spr.y),
		str(-canvas.x * 0.5), str(-canvas.y * 0.5), str(canvas.x), str(canvas.y),
		audio_nodes,
	]
	_write_text("%s/%s/%s.tscn" % [SCENE_ROOT, id, id], text)


func _write_catalog(ids: PackedStringArray) -> void:
	var ext: PackedStringArray = PackedStringArray()
	ext.append('[ext_resource type="Script" path="res://scripts/animals/animal_catalog.gd" id="1"]')
	var i := 2
	var refs: PackedStringArray = PackedStringArray()
	for id in ids:
		ext.append('[ext_resource type="Resource" path="res://resources/animals/%s_def.tres" id="%d"]' % [id, i])
		refs.append("ExtResource(\"%d\")" % i)
		i += 1
	var text := """[gd_resource type=\"Resource\" script_class=\"AnimalCatalog\" load_steps=%d format=3]

%s

[resource]
script = ExtResource(\"1\")
animals = [%s]
""" % [i, "\n".join(ext), ", ".join(refs)]
	_write_text("%s/animal_catalog.tres" % RES_ROOT, text)


func _write_settings() -> void:
	var text := """[gd_resource type=\"Resource\" script_class=\"AnimalSettings\" load_steps=2 format=3]

[ext_resource type=\"Script\" path=\"res://scripts/animals/animal_settings.gd\" id=\"1\"]

[resource]
script = ExtResource(\"1\")
max_active_animals = 16
max_surface_animals = 10
max_flying_animals = 6
max_water_animals = 4
max_darkness_animals = 4
max_critter_animals = 12
animal_spawn_interval = 3.2
darkness_spawn_interval = 2.0
min_spawn_distance = 720.0
max_spawn_distance = 1280.0
max_spawns_per_tick = 1
initial_surface_count = 4
animal_activation_distance = 480.0
animal_sleep_distance = 900.0
animal_despawn_distance = 1680.0
ai_near_interval = 0.18
ai_medium_interval = 0.42
lod_update_interval = 0.28
max_idle_sounds = 3
idle_sound_min_delay = 4.5
idle_sound_max_delay = 11.0
audio_max_distance = 380.0
"""
	_write_text("%s/animal_settings.tres" % RES_ROOT, text)


func _write_sfx() -> void:
	_save_wav("%s/idle_soft.wav" % AUDIO_ROOT, _tone(0.22, 420.0, 0.08, 0.12, 20.0, 3))
	_save_wav("%s/hurt.wav" % AUDIO_ROOT, _tone(0.14, 240.0, 0.22, 0.28, -80.0, 9))
	_save_wav("%s/death.wav" % AUDIO_ROOT, _tone(0.4, 90.0, 0.2, 0.3, -40.0, 11))
	_save_wav("%s/alert.wav" % AUDIO_ROOT, _tone(0.18, 520.0, 0.16, 0.1, 60.0, 5))
	_save_wav("%s/attack.wav" % AUDIO_ROOT, _tone(0.2, 110.0, 0.24, 0.22, -30.0, 7))
	_save_wav("%s/chirp.wav" % AUDIO_ROOT, _tone(0.12, 1400.0, 0.12, 0.04, 200.0, 15))
	_save_wav("%s/caw.wav" % AUDIO_ROOT, _tone(0.32, 280.0, 0.2, 0.18, -70.0, 17))
	_save_wav("%s/croak.wav" % AUDIO_ROOT, _tone(0.28, 160.0, 0.18, 0.2, -20.0, 19))
	_save_wav("%s/buzz.wav" % AUDIO_ROOT, _tone(0.6, 260.0, 0.08, 0.35, 0.0, 21))
	_save_wav("%s/growl.wav" % AUDIO_ROOT, _tone(0.45, 95.0, 0.22, 0.25, -15.0, 23))
	_save_wav("%s/grunt.wav" % AUDIO_ROOT, _tone(0.26, 120.0, 0.2, 0.22, -25.0, 25))
	_save_wav("%s/squeak.wav" % AUDIO_ROOT, _tone(0.1, 1800.0, 0.1, 0.08, 120.0, 27))


func _tone(dur: float, freq: float, amp: float, n_amt: float, slide: float, seed: int) -> PackedFloat32Array:
	var rate := 22050.0
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	for i in n:
		var t := float(i) / rate
		var f := freq + slide * t
		var s := sin(TAU * f * t) * amp
		s += _noise(i, seed) * n_amt * amp
		s *= _env(t, 0.015, dur * 0.4, dur * 0.45)
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


func _b(v: bool) -> String:
	return "true" if v else "false"


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, text: String) -> void:
	var fh := FileAccess.open(path, FileAccess.WRITE)
	if fh != null:
		fh.store_string(text)
