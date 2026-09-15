import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHYS = "PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)"


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: str, pixels: list) -> None:
    h = len(pixels)
    w = len(pixels[0])
    raw = b""
    for row in pixels:
        raw += b"\x00"
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(png)


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png(path: str) -> list:
    # Decode real PNG row filters. The previous skip-first-byte reader
    # destroyed alpha and made world tiles invisible.
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    i = 8
    w = h = bit_depth = color_type = 0
    idat = b""
    while i < len(data):
        ln = struct.unpack(">I", data[i : i + 4])[0]
        tag = data[i + 4 : i + 8]
        payload = data[i + 8 : i + 8 + ln]
        if tag == b"IHDR":
            w, h, bit_depth, color_type, _comp, _filt, interlace = struct.unpack(">IIBBBBB", payload)
            if bit_depth != 8 or color_type != 6 or interlace != 0:
                raise ValueError("Only 8-bit non-interlaced RGBA PNGs are supported: %s" % path)
        elif tag == b"IDAT":
            idat += payload
        elif tag == b"IEND":
            break
        i += 12 + ln
    raw = zlib.decompress(idat)
    bpp = 4
    stride = w * bpp
    prev = bytearray(stride)
    pixels = []
    offset = 0
    for _y in range(h):
        filt = raw[offset]
        offset += 1
        row = bytearray(raw[offset : offset + stride])
        offset += stride
        for x in range(stride):
            left = row[x - bpp] if x >= bpp else 0
            up = prev[x]
            up_left = prev[x - bpp] if x >= bpp else 0
            if filt == 1:
                row[x] = (row[x] + left) & 255
            elif filt == 2:
                row[x] = (row[x] + up) & 255
            elif filt == 3:
                row[x] = (row[x] + ((left + up) // 2)) & 255
            elif filt == 4:
                row[x] = (row[x] + paeth(left, up, up_left)) & 255
            elif filt != 0:
                raise ValueError("Unsupported PNG filter %d in %s" % (filt, path))
        prev = row
        pixels.append([tuple(row[x * 4 : x * 4 + 4]) for x in range(w)])
    return pixels


def blit(dst, src, dx, dy):
    for y, row in enumerate(src):
        for x, px in enumerate(row):
            if 0 <= dy + y < len(dst) and 0 <= dx + x < len(dst[0]):
                dst[dy + y][dx + x] = px


def crop(img, x, y, w=16, h=16):
    return [row[x : x + w] for row in img[y : y + h]]


def clone_tile(tile):
    return [list(row) for row in tile]


def put(img, x, y, color):
    if 0 <= y < len(img) and 0 <= x < len(img[0]):
        img[y][x] = color


def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3)) + (255,)


ORES = [
    dict(key="copper", name="Kupfer", tier=1, block=9, item=11, atlas=(0, 1), req=10, spec_min=0, spec_max=150, r0=0.0, r1=0.125, vein=(5, 12), drop=(2, 4), xp=2, weight=1.40, hard=1.8, cat=1, special=0, color=(196, 108, 42), map="#C66C2A"),
    dict(key="tin", name="Zinn", tier=2, block=10, item=12, atlas=(1, 1), req=15, spec_min=50, spec_max=250, r0=0.042, r1=0.208, vein=(4, 10), drop=(2, 4), xp=3, weight=0.90, hard=2.1, cat=1, special=0, color=(196, 204, 210), map="#C4CCD2"),
    dict(key="ferrite", name="Ferrit", tier=3, block=11, item=13, atlas=(2, 1), req=22, spec_min=150, spec_max=400, r0=0.125, r1=0.333, vein=(4, 9), drop=(2, 3), xp=5, weight=0.55, hard=2.5, cat=1, special=0, color=(176, 64, 48), map="#B04030"),
    dict(key="aurel", name="Aurel", tier=4, block=12, item=14, atlas=(3, 1), req=30, spec_min=250, spec_max=500, r0=0.208, r1=0.417, vein=(3, 7), drop=(1, 3), xp=8, weight=0.40, hard=3.0, cat=1, special=0, color=(232, 186, 48), map="#E8BA30"),
    dict(key="cobalt", name="Kobalt", tier=5, block=23, item=33, atlas=(5, 1), req=40, spec_min=400, spec_max=650, r0=0.333, r1=0.542, vein=(3, 6), drop=(1, 3), xp=12, weight=0.28, hard=3.5, cat=1, special=0, color=(48, 96, 210), map="#3060D2"),
    dict(key="veyrite", name="Veyrit", tier=6, block=24, item=34, atlas=(6, 1), req=52, spec_min=550, spec_max=800, r0=0.458, r1=0.667, vein=(2, 5), drop=(1, 3), xp=18, weight=0.18, hard=4.1, cat=1, special=0, color=(148, 64, 196), map="#9440C4"),
    dict(key="cryonite", name="Cryonit", tier=7, block=25, item=35, atlas=(7, 1), req=65, spec_min=650, spec_max=900, r0=0.542, r1=0.750, vein=(2, 5), drop=(1, 2), xp=25, weight=0.12, hard=4.8, cat=1, special=0, color=(72, 210, 220), map="#48D2DC"),
    dict(key="ignitium", name="Ignitium", tier=8, block=26, item=36, atlas=(1, 3), req=80, spec_min=800, spec_max=1100, r0=0.667, r1=0.917, vein=(2, 4), drop=(1, 2), xp=35, weight=0.08, hard=5.6, cat=1, special=0, color=(232, 86, 28), map="#E8561C"),
    dict(key="voidium", name="Voidium", tier=9, block=27, item=37, atlas=(2, 3), req=100, spec_min=1000, spec_max=1200, r0=0.833, r1=1.0, vein=(1, 4), drop=(1, 2), xp=50, weight=0.05, hard=6.5, cat=1, special=0, color=(58, 24, 78), map="#3A184E"),
    dict(key="astralith", name="Astralith", tier=10, block=28, item=38, atlas=(3, 3), req=125, spec_min=1100, spec_max=1200, r0=0.917, r1=1.0, vein=(1, 3), drop=(1, 1), xp=100, weight=0.015, hard=7.5, cat=4, special=1, color=(186, 140, 255), map="#BA8CFF"),
]

PICKS = [
    dict(key="stone", name="Steinspitzhacke", id=22, tier=1, power=10, dmg=8, speed=1.0, dur=100, special="Stein/Erz", can="Kupfer", color=(150, 154, 158)),
    dict(key="copper", name="Kupferspitzhacke", id=40, tier=2, power=15, dmg=9, speed=1.05, dur=120, special="Kupfer/Zinn", can="Zinn", color=(196, 108, 42)),
    dict(key="tin", name="Zinnspitzhacke", id=41, tier=3, power=22, dmg=10, speed=1.10, dur=140, special="Zinn/Ferrit", can="Ferrit", color=(196, 204, 210)),
    dict(key="ferrite", name="Ferritspitzhacke", id=42, tier=4, power=30, dmg=11, speed=1.12, dur=160, special="Ferrit/Aurel", can="Aurel", color=(176, 64, 48)),
    dict(key="aurel", name="Aurelspitzhacke", id=43, tier=5, power=40, dmg=12, speed=1.15, dur=180, special="Aurel/Kobalt", can="Kobalt", color=(232, 186, 48)),
    dict(key="cobalt", name="Kobaltspitzhacke", id=44, tier=6, power=52, dmg=13, speed=1.18, dur=200, special="Kobalt/Veyrit", can="Veyrit", color=(48, 96, 210)),
    dict(key="veyrite", name="Veyritspitzhacke", id=45, tier=7, power=65, dmg=14, speed=1.20, dur=220, special="Veyrit/Cryonit", can="Cryonit", color=(148, 64, 196)),
    dict(key="cryonite", name="Cryonitspitzhacke", id=46, tier=8, power=80, dmg=15, speed=1.22, dur=240, special="Cryonit/Ignitium", can="Ignitium", color=(72, 210, 220)),
    dict(key="ignitium", name="Ignitiumspitzhacke", id=47, tier=9, power=100, dmg=16, speed=1.25, dur=260, special="Ignitium/Voidium", can="Voidium", color=(232, 86, 28)),
    dict(key="voidium", name="Voidiumspitzhacke", id=48, tier=10, power=125, dmg=17, speed=1.28, dur=280, special="Voidium/Astralith", can="Astralith", color=(58, 24, 78)),
    dict(key="astralith", name="Astralithspitzhacke", id=49, tier=11, power=160, dmg=18, speed=1.30, dur=320, special="Alle Materialien", can="Alles", color=(186, 140, 255)),
]


def make_ore_tile(stone, color, sparkle=None):
    tile = clone_tile(stone)
    spots = [
        (3, 4), (4, 5), (5, 4), (6, 6), (7, 5), (8, 7), (9, 4), (10, 6),
        (4, 9), (6, 10), (8, 9), (11, 10), (5, 12), (9, 12), (7, 3), (12, 8),
        (3, 11), (10, 3), (2, 7), (13, 5),
    ]
    light = mix(color, (255, 255, 255, 255), 0.35)
    dark = mix(color, (20, 16, 14, 255), 0.35)
    for i, (x, y) in enumerate(spots):
        put(tile, x, y, color + (255,))
        put(tile, x + (i % 2), y, light if i % 3 else dark)
    if sparkle:
        put(tile, 8, 6, sparkle + (255,))
        put(tile, 9, 7, sparkle + (255,))
    return tile


def make_item_icon(color, sparkle=None):
    img = [[(0, 0, 0, 0) for _ in range(16)] for _ in range(16)]
    stone = (118, 122, 126, 255)
    for y in range(3, 14):
        for x in range(3, 14):
            if (x - 8) ** 2 + (y - 8) ** 2 < 36:
                img[y][x] = stone
    light = mix(color, (255, 255, 255, 255), 0.4)
    for x, y in [(5, 6), (6, 7), (7, 6), (8, 8), (9, 7), (10, 9), (6, 10), (9, 11), (11, 6)]:
        put(img, x, y, color + (255,))
        put(img, x, y - 1, light)
    if sparkle:
        put(img, 8, 5, sparkle + (255,))
    return img


def make_pickaxe(base, head_color):
    img = clone_tile(base)
    head = head_color + (255,)
    light = mix(head_color, (255, 255, 255, 255), 0.35)
    for y in range(16):
        for x in range(16):
            r, g, b, a = img[y][x]
            if a < 20:
                continue
            if r > 120 and abs(r - g) < 30 and abs(g - b) < 30 and y < 9:
                img[y][x] = head if (x + y) % 2 == 0 else light
    return img


ORE_TRES = """[gd_resource type="Resource" script_class="OreData" format=3]

[ext_resource type="Script" path="res://scripts/world/ore_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
ore_id = &"{key}"
display_name = "{name}"
tier = {tier}
block_id = {block}
drop_item_id = {item}
required_pickaxe_power = {req}
spec_min_depth = {spec_min}
spec_max_depth = {spec_max}
min_depth_ratio = {r0}
max_depth_ratio = {r1}
vein_min_size = {vmin}
vein_max_size = {vmax}
drop_min = {dmin}
drop_max = {dmax}
xp_reward = {xp}
rarity_weight = {weight}
metal_category = {cat}
hardness = {hard}
map_color = Color({mr}, {mg}, {mb}, 1)
special_spawn = {special}
"""

BLOCK_TRES = """[gd_resource type="Resource" script_class="BlockData" format=3]

[ext_resource type="Script" path="res://scripts/world/block_data.gd" id="1_script"]
[ext_resource type="Resource" path="res://resources/ores/{key}_ore.tres" id="2_ore"]

[resource]
script = ExtResource("1_script")
id = {block}
display_name = "{name}erz"
atlas_coords = Vector2i({ax}, {ay})
hardness = {hard}
drop_item_id = {item}
solid = true
ore_data = ExtResource("2_ore")
map_color = Color({mr}, {mg}, {mb}, 1)
"""

ITEM_TRES = """[gd_resource type="Resource" script_class="ItemData" format=3]

[ext_resource type="Script" path="res://scripts/items/item_data.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/items/ores/{key}_ore.png" id="2_icon"]
[ext_resource type="Resource" path="res://resources/ores/{key}_ore.tres" id="3_ore"]

[resource]
script = ExtResource("1_script")
id = {item}
display_name = "{name}erz"
description = "Roherz. Benoetigt Pickaxe Power {req}."
icon = ExtResource("2_icon")
max_stack = 999
item_type = 5
category = 8
ore_data = ExtResource("3_ore")
ore_metal_category = {cat}
placeable_block_id = {block}
held_scale = 1.0
"""

PICK_TRES = """[gd_resource type="Resource" script_class="ItemData" format=3]

[ext_resource type="Script" path="res://scripts/items/item_data.gd" id="1_script"]
[ext_resource type="Script" path="res://scripts/items/tool_data.gd" id="2_tool"]
[ext_resource type="Texture2D" path="res://assets/items/tools/mining/pickaxes/{key}_pickaxe.png" id="3_icon"]

[sub_resource type="Resource" id="ToolData_1"]
script = ExtResource("2_tool")
tool_category = 1
base_damage = {dmg}
base_tool_power = {power}
base_use_speed = {speed}
base_max_durability = {dur}
base_range = 2.5
special = "{special}"
pickaxe_tier = {tier}

[resource]
script = ExtResource("1_script")
id = {id}
display_name = "{name}"
description = "Bergbau-Spitzhacke. Pickaxe Power {power}. Baut bis {can}."
icon = ExtResource("3_icon")
max_stack = 1
item_type = 1
category = 10
tool_kind = 1
tool_data = SubResource("ToolData_1")
placeable_block_id = -1
held_scale = 1.0
held_rotation_degrees = -45.0
held_flip_h = false
held_flip_v = false
damage = {dmg}
mining_speed = {speed}
attack_cooldown = 0.35
knockback = 100.0
"""


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def main() -> None:
    os.makedirs(os.path.join(ROOT, "resources", "ores"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "resources", "blocks", "ores"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "resources", "items", "materials", "ores"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "assets", "items", "ores"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "assets", "world", "ores"), exist_ok=True)
    atlas_path = os.path.join(ROOT, "assets", "world", "tiles", "terrain_atlas.png")
    atlas = read_png(atlas_path)
    stone = crop(atlas, 32, 0)
    new_atlas = [list(row) for row in atlas]
    for ore in ORES:
        sparkle = (240, 230, 255) if ore["key"] in ("astralith", "cryonite") else None
        tile = make_ore_tile(stone, ore["color"], sparkle)
        ax, ay = ore["atlas"]
        blit(new_atlas, tile, ax * 16, ay * 16)
        icon = make_item_icon(ore["color"], sparkle)
        write_png(os.path.join(ROOT, "assets", "items", "ores", f"{ore['key']}_ore.png"), icon)
        write_png(os.path.join(ROOT, "assets", "world", "ores", f"{ore['key']}_ore.png"), tile)
        mr, mg, mb = hex_to_rgb(ore["map"])
        with open(os.path.join(ROOT, "resources", "ores", f"{ore['key']}_ore.tres"), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(ORE_TRES.format(
                key=ore["key"], name=ore["name"], tier=ore["tier"], block=ore["block"], item=ore["item"],
                req=ore["req"], spec_min=ore["spec_min"], spec_max=ore["spec_max"], r0=ore["r0"], r1=ore["r1"],
                vmin=ore["vein"][0], vmax=ore["vein"][1], dmin=ore["drop"][0], dmax=ore["drop"][1],
                xp=ore["xp"], weight=ore["weight"], cat=ore["cat"], hard=ore["hard"],
                mr=mr, mg=mg, mb=mb, special="true" if ore["special"] else "false",
            ))
        block_dir = os.path.join(ROOT, "resources", "blocks", "ores")
        os.makedirs(block_dir, exist_ok=True)
        with open(os.path.join(block_dir, f"{ore['key']}_ore_block.tres"), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(BLOCK_TRES.format(
                key=ore["key"], name=ore["name"], block=ore["block"], item=ore["item"],
                ax=ax, ay=ay, hard=ore["hard"], mr=mr, mg=mg, mb=mb,
            ))
        item_dir = os.path.join(ROOT, "resources", "items", "materials", "ores")
        os.makedirs(item_dir, exist_ok=True)
        with open(os.path.join(item_dir, f"{ore['key']}_ore_item.tres"), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(ITEM_TRES.format(
                key=ore["key"], name=ore["name"], item=ore["item"], req=ore["req"], cat=ore["cat"], block=ore["block"],
            ))
    write_png(atlas_path, new_atlas)

    base_pick = read_png(os.path.join(ROOT, "assets", "items", "tools", "mining", "stone_pickaxe.png"))
    pick_dir = os.path.join(ROOT, "assets", "items", "tools", "mining", "pickaxes")
    tres_dir = os.path.join(ROOT, "resources", "items", "tools", "mining", "pickaxes")
    os.makedirs(pick_dir, exist_ok=True)
    os.makedirs(tres_dir, exist_ok=True)
    for pick in PICKS:
        icon = clone_tile(base_pick) if pick["key"] == "stone" else make_pickaxe(base_pick, pick["color"])
        write_png(os.path.join(pick_dir, f"{pick['key']}_pickaxe.png"), icon)
        with open(os.path.join(tres_dir, f"{pick['key']}_pickaxe.tres"), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(PICK_TRES.format(**pick))
    catalog_lines = [
        '[gd_resource type="Resource" script_class="OreCatalog" format=3]',
        "",
        '[ext_resource type="Script" path="res://scripts/world/ore_catalog.gd" id="1_script"]',
    ]
    for i, ore in enumerate(ORES, start=2):
        catalog_lines.append(f'[ext_resource type="Resource" path="res://resources/ores/{ore["key"]}_ore.tres" id="{i}_{ore["key"]}"]')
    catalog_lines += ["", "[resource]", 'script = ExtResource("1_script")']
    refs = ", ".join(f'ExtResource("{i}_{ore["key"]}")' for i, ore in enumerate(ORES, start=2))
    catalog_lines.append(f"ores = [{refs}]")
    catalog_lines.append("")
    with open(os.path.join(ROOT, "resources", "ores", "ore_catalog.tres"), "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(catalog_lines))
    print("generated ores and pickaxes")


if __name__ == "__main__":
    main()
