from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.replace("\n", "\n"), encoding="utf-8")


def block(name: str, block_id: int, display: str, atlas: str, hardness: float, drop: int, solid: bool) -> None:
    write(
        ROOT / "resources" / "blocks" / f"{name}.tres",
        f"""[gd_resource type="Resource" script_class="BlockData" format=3]

[ext_resource type="Script" path="res://scripts/world/block_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = {block_id}
display_name = "{display}"
atlas_coords = Vector2i({atlas})
hardness = {hardness}
drop_item_id = {drop}
solid = {str(solid).lower()}
""",
    )


def item(name: str, item_id: int, display: str, icon: str, item_type: int, placeable: int, tree_type: str = "") -> None:
    extra = ""
    if tree_type:
        extra = f'\ntree_type = &"{tree_type}"'
    write(
        ROOT / "resources" / "items" / f"{name}.tres",
        f"""[gd_resource type="Resource" script_class="ItemData" format=3]

[ext_resource type="Script" path="res://scripts/items/item_data.gd" id="1_script"]
[ext_resource type="Texture2D" path="{icon}" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = {item_id}
display_name = "{display}"
icon = ExtResource("2_icon")
max_stack = 999
item_type = {item_type}
equipment_slot = 0
placeable_block_id = {placeable}
held_scale = 1.0{extra}
""",
    )


def tree(name: str, tree_id: str, display: str, trunk: int, leaf: int, sapling: int, wood: int, seed: int, mn: int, mx: int, hardness: float, style: str) -> None:
    write(
        ROOT / "resources" / "trees" / f"{name}.tres",
        f"""[gd_resource type="Resource" script_class="TreeData" format=3]

[ext_resource type="Script" path="res://scripts/world/tree_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
tree_id = &"{tree_id}"
display_name = "{display}"
trunk_block_id = {trunk}
leaf_block_id = {leaf}
sapling_block_id = {sapling}
wood_item_id = {wood}
seed_item_id = {seed}
min_height = {mn}
max_height = {mx}
growth_stage_count = 5
regrow_time = 10.0
trunk_hardness = {hardness}
crown_style = &"{style}"
""",
    )


block("oak_wood", 14, "Eichenholz", "0, 2", 1.0, 15, True)
block("birch_wood", 15, "Birkenholz", "1, 2", 0.8, 16, True)
block("pine_wood", 16, "Kiefernholz", "2, 2", 0.9, 17, True)
block("oak_leaves", 17, "Eichenblatter", "3, 2", 0.3, -1, False)
block("birch_leaves", 18, "Birkenblatter", "4, 2", 0.3, -1, False)
block("pine_leaves", 19, "Kiefernnadeln", "5, 2", 0.3, -1, False)
block("oak_sapling", 20, "Eichensetzling", "6, 2", 0.2, 18, False)
block("birch_sapling", 21, "Birkensetzling", "7, 2", 0.2, 19, False)
block("pine_sapling", 22, "Kiefernsetzling", "0, 3", 0.2, 20, False)

item("oak_wood", 15, "Eichenholz", "res://assets/world/tiles/oak_wood.png", 0, 14)
item("birch_wood", 16, "Birkenholz", "res://assets/world/tiles/birch_wood.png", 0, 15)
item("pine_wood", 17, "Kiefernholz", "res://assets/world/tiles/pine_wood.png", 0, 16)
item("oak_seed", 18, "Eichensamen", "res://assets/items/seeds/oak_seed.png", 6, -1, "oak")
item("birch_seed", 19, "Birkensamen", "res://assets/items/seeds/birch_seed.png", 6, -1, "birch")
item("pine_seed", 20, "Kiefernsamen", "res://assets/items/seeds/pine_seed.png", 6, -1, "pine")

tree("oak", "oak", "Eiche", 14, 17, 20, 15, 18, 5, 8, 1.0, "round")
tree("birch", "birch", "Birke", 15, 18, 21, 16, 19, 6, 10, 0.8, "narrow")
tree("pine", "pine", "Kiefer", 16, 19, 22, 17, 20, 8, 13, 0.9, "triangle")

print("resources written")
