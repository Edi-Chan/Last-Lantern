# Aktueller Katalog: Items, Erze, Blöcke

Stand: 16.09.2026. Werte aus den Katalog-`.tres`-Dateien.

- Items: `resources/items/item_catalog.tres` (57 Einträge)
- Blöcke: `resources/blocks/block_catalog.tres` (28 Einträge)
- Erze: `resources/ores/ore_catalog.tres` (10 Einträge)
- Pflanzen: `resources/plants/plant_catalog.tres` (10 Einträge)

Blöcke haben **keine HP**. Abbau nutzt `hardness` plus passendes Werkzeug.

```
speed = 1.0 * use_speed * (1 + tool_power * 0.012)  # Bonus nur bei passendem ToolKind
Abbauzeit = max(hardness / speed, 0.05 s)
```

## Spieler

| Wert | Aktuell |
| --- | ---: |
| Leben | 100 |
| Ausdauer | 100 |
| Energie | 100 |
| Mining-Reichweite | 5.0 Tiles |

## Combat Dummy

| Wert | Aktuell |
| --- | ---: |
| Leben | 20 |

## Blöcke

| ID | Name | Härte | Solid | Drop-Item | Werkzeug | Power | Unbreakable | Atlas | Datei |
| ---: | --- | ---: | --- | ---: | --- | ---: | --- | --- | --- |
| 1 | Grass | 0.5 | true | 1 | NONE | 0 | false | Vector2i(0, 0) | `resources/blocks/grass.tres` |
| 2 | Dirt | 0.5 | true | 1 | NONE | 0 | false | Vector2i(1, 0) | `resources/blocks/dirt.tres` |
| 3 | Stone | 1.5 | true | 2 | PICKAXE | 1 | false | Vector2i(2, 0) | `resources/blocks/stone.tres` |
| 4 | Sand | 0.4 | true | 6 | NONE | 0 | false | Vector2i(3, 0) | `resources/blocks/sand.tres` |
| 5 | Granite | 2.0 | true | 7 | PICKAXE | 5 | false | Vector2i(4, 0) | `resources/blocks/granite.tres` |
| 6 | Slate | 1.8 | true | 8 | PICKAXE | 3 | false | Vector2i(5, 0) | `resources/blocks/slate.tres` |
| 7 | Wood | 1.0 | true | 9 | AXE | 1 | false | Vector2i(6, 0) | `resources/blocks/wood.tres` |
| 8 | Leaves | 0.2 | false | 10 | NONE | 0 | false | Vector2i(7, 0) | `resources/blocks/leaves.tres` |
| 9 | Kupfererz | 1.8 | true | 11 | PICKAXE | 10 | false | Vector2i(0, 1) | `resources/blocks/ores/copper_ore_block.tres` |
| 10 | Zinnerz | 2.1 | true | 12 | PICKAXE | 15 | false | Vector2i(1, 1) | `resources/blocks/ores/tin_ore_block.tres` |
| 11 | Ferriterz | 2.5 | true | 13 | PICKAXE | 22 | false | Vector2i(2, 1) | `resources/blocks/ores/ferrite_ore_block.tres` |
| 12 | Aurelerz | 3.0 | true | 14 | PICKAXE | 30 | false | Vector2i(3, 1) | `resources/blocks/ores/aurel_ore_block.tres` |
| 13 | Bedrock | 999.0 | true | -1 | NONE | 0 | true (hardness) | Vector2i(4, 1) | `resources/blocks/bedrock.tres` |
| 14 | Eichenholz | 1.0 | true | 15 | AXE | 1 | false | Vector2i(0, 2) | `resources/blocks/oak_wood.tres` |
| 15 | Birkenholz | 0.8 | true | 16 | AXE | 1 | false | Vector2i(1, 2) | `resources/blocks/birch_wood.tres` |
| 16 | Kiefernholz | 0.9 | true | 17 | AXE | 1 | false | Vector2i(2, 2) | `resources/blocks/pine_wood.tres` |
| 17 | Eichenblatter | 0.3 | false | -1 | NONE | 0 | false | Vector2i(3, 2) | `resources/blocks/oak_leaves.tres` |
| 18 | Birkenblatter | 0.3 | false | -1 | NONE | 0 | false | Vector2i(4, 2) | `resources/blocks/birch_leaves.tres` |
| 19 | Kiefernnadeln | 0.3 | false | -1 | NONE | 0 | false | Vector2i(5, 2) | `resources/blocks/pine_leaves.tres` |
| 20 | Eichensetzling | 0.2 | false | 18 | NONE | 0 | false | Vector2i(6, 2) | `resources/blocks/oak_sapling.tres` |
| 21 | Birkensetzling | 0.2 | false | 19 | NONE | 0 | false | Vector2i(7, 2) | `resources/blocks/birch_sapling.tres` |
| 22 | Kiefernsetzling | 0.2 | false | 20 | NONE | 0 | false | Vector2i(0, 3) | `resources/blocks/pine_sapling.tres` |
| 23 | Kobalterz | 3.5 | true | 33 | PICKAXE | 40 | false | Vector2i(5, 1) | `resources/blocks/ores/cobalt_ore_block.tres` |
| 24 | Veyriterz | 4.1 | true | 34 | PICKAXE | 52 | false | Vector2i(6, 1) | `resources/blocks/ores/veyrite_ore_block.tres` |
| 25 | Cryoniterz | 4.8 | true | 35 | PICKAXE | 65 | false | Vector2i(7, 1) | `resources/blocks/ores/cryonite_ore_block.tres` |
| 26 | Ignitiumerz | 5.6 | true | 36 | PICKAXE | 80 | false | Vector2i(1, 3) | `resources/blocks/ores/ignitium_ore_block.tres` |
| 27 | Voidiumerz | 6.5 | true | 37 | PICKAXE | 100 | false | Vector2i(2, 3) | `resources/blocks/ores/voidium_ore_block.tres` |
| 28 | Astralitherz | 7.5 | true | 38 | PICKAXE | 125 | false | Vector2i(3, 3) | `resources/blocks/ores/astralith_ore_block.tres` |

## Erze (OreData)

| Tier | ID | Name | Block | Drop-Item | Härte | Pick-Power | Tiefe Spec | Ratio min–max | Ader | Drop | XP | Gewicht | Special | Kategorie |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- | ---: | ---: | --- | --- |
| 1 | `copper` | Kupfer | 9 | 11 | 1.8 | 10 | 0–150 | 0.0–0.125 | 5–12 | 2–4 | 2 | 1.4 | false | RAW_ORE |
| 2 | `tin` | Zinn | 10 | 12 | 2.1 | 15 | 50–250 | 0.042–0.208 | 4–10 | 2–4 | 3 | 0.9 | false | RAW_ORE |
| 3 | `ferrite` | Ferrit | 11 | 13 | 2.5 | 22 | 150–400 | 0.125–0.333 | 4–9 | 2–3 | 5 | 0.55 | false | RAW_ORE |
| 4 | `aurel` | Aurel | 12 | 14 | 3.0 | 30 | 250–500 | 0.208–0.417 | 3–7 | 1–3 | 8 | 0.4 | false | RAW_ORE |
| 5 | `cobalt` | Kobalt | 23 | 33 | 3.5 | 40 | 400–650 | 0.333–0.542 | 3–6 | 1–3 | 12 | 0.28 | false | RAW_ORE |
| 6 | `veyrite` | Veyrit | 24 | 34 | 4.1 | 52 | 550–800 | 0.458–0.667 | 2–5 | 1–3 | 18 | 0.18 | false | RAW_ORE |
| 7 | `cryonite` | Cryonit | 25 | 35 | 4.8 | 65 | 650–900 | 0.542–0.75 | 2–5 | 1–2 | 25 | 0.12 | false | RAW_ORE |
| 8 | `ignitium` | Ignitium | 26 | 36 | 5.6 | 80 | 800–1100 | 0.667–0.917 | 2–4 | 1–2 | 35 | 0.08 | false | RAW_ORE |
| 9 | `voidium` | Voidium | 27 | 37 | 6.5 | 100 | 1000–1200 | 0.833–1.0 | 1–4 | 1–2 | 50 | 0.05 | false | RAW_ORE |
| 10 | `astralith` | Astralith | 28 | 38 | 7.5 | 125 | 1100–1200 | 0.917–1.0 | 1–3 | 1–1 | 100 | 0.015 | true | SPECIAL_ORE |

## Items (ItemCatalog)

| ID | Name | Typ | Kategorie | Stack | Platz-Block | ToolKind | Schaden | Defense | Haltbarkeit | Power | UseSpeed | Range | Pick-Tier | Sell | Rarity | Datei |
| ---: | --- | --- | --- | ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Dirt | BLOCK | BUILDING_MATERIAL | 999 | 2 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/dirt.tres` |
| 2 | Stone | BLOCK | BUILDING_MATERIAL | 999 | 3 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/stone.tres` |
| 4 | Test Helmet | ARMOR | ARMOR | 1 | -1 | NONE | 0 | 1 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/helmet.tres` |
| 5 | Test Chestplate | ARMOR | ARMOR | 1 | -1 | NONE | 0 | 2 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/chestplate.tres` |
| 6 | Sand | BLOCK | BUILDING_MATERIAL | 999 | 4 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/sand.tres` |
| 7 | Granite | BLOCK | BUILDING_MATERIAL | 999 | 5 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/granite.tres` |
| 8 | Slate | BLOCK | BUILDING_MATERIAL | 999 | 6 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/slate.tres` |
| 9 | Wood | BLOCK | BUILDING_MATERIAL | 999 | 7 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/wood.tres` |
| 10 | Leaves | BLOCK | BUILDING_MATERIAL | 999 | 8 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/leaves.tres` |
| 11 | Kupfererz | MATERIAL | ORE_METAL | 999 | 9 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/materials/ores/copper_ore_item.tres` |
| 12 | Zinnerz | MATERIAL | ORE_METAL | 999 | 10 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/materials/ores/tin_ore_item.tres` |
| 13 | Ferriterz | MATERIAL | ORE_METAL | 999 | 11 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/materials/ores/ferrite_ore_item.tres` |
| 14 | Aurelerz | MATERIAL | ORE_METAL | 999 | 12 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/materials/ores/aurel_ore_item.tres` |
| 15 | Eichenholz | BLOCK | BUILDING_MATERIAL | 999 | 14 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/oak_wood.tres` |
| 16 | Birkenholz | BLOCK | BUILDING_MATERIAL | 999 | 15 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/birch_wood.tres` |
| 17 | Kiefernholz | BLOCK | BUILDING_MATERIAL | 999 | 16 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/pine_wood.tres` |
| 18 | Eichensamen | SEED | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/oak_seed.tres` |
| 19 | Birkensamen | SEED | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/birch_seed.tres` |
| 20 | Kiefernsamen | SEED | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/pine_seed.tres` |
| 21 | Test Leggings | ARMOR | ARMOR | 1 | -1 | NONE | 0 | 1 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/leggings.tres` |
| 22 | Steinspitzhacke | TOOL | TOOL | 1 | -1 | PICKAXE | 8 | 0 | 100 | 10 | 1.0 | 2.5 | 1 | 0 | COMMON | `resources/items/tools/mining/pickaxes/stone_pickaxe.tres` |
| 23 | Steinaxt | TOOL | TOOL | 1 | -1 | AXE | 10 | 0 | 100 | 12 | 0.9 | 2.5 | 0 | 0 | COMMON | `resources/items/tools/woodcutting/stone_axe.tres` |
| 24 | Holzhammer | TOOL | TOOL | 1 | -1 | HAMMER | 5 | 0 | 120 | 8 | 1.0 | 2.5 | 0 | 0 | COMMON | `resources/items/tools/building_repair/wood_hammer.tres` |
| 25 | Einfacher Schraubenschlüssel | TOOL | TOOL | 1 | -1 | WRENCH | 6 | 0 | 100 | 8 | 0.8 | 2.0 | 0 | 0 | COMMON | `resources/items/tools/dismantling/simple_wrench.tres` |
| 26 | Holzhacke | TOOL | TOOL | 1 | -1 | HOE | 4 | 0 | 80 | 6 | 1.1 | 2.5 | 0 | 0 | COMMON | `resources/items/tools/farming/wood_hoe.tres` |
| 27 | Holzangel | TOOL | TOOL | 1 | -1 | FISHING_ROD | 2 | 0 | 80 | 5 | 1.0 | 8.0 | 0 | 0 | COMMON | `resources/items/tools/gathering/wood_fishing_rod.tres` |
| 28 | Sichel | TOOL | TOOL | 1 | -1 | SICKLE | 5 | 0 | 80 | 7 | 1.1 | 2.5 | 0 | 0 | COMMON | `resources/items/tools/farming/sickle.tres` |
| 29 | Kescher | TOOL | TOOL | 1 | -1 | NET | 1 | 0 | 70 | 4 | 1.0 | 3.0 | 0 | 0 | COMMON | `resources/items/tools/gathering/net.tres` |
| 30 | Fackel | TOOL | TOOL | 1 | -1 | NONE | 1 | 0 | 60 | 1 | 1.0 | 1.5 | 0 | 0 | COMMON | `resources/items/tools/exploration/torch.tres` |
| 31 | Laterne | TOOL | TOOL | 1 | -1 | NONE | 1 | 0 | 90 | 2 | 1.0 | 2.0 | 0 | 0 | COMMON | `resources/items/tools/exploration/lantern.tres` |
| 32 | Scanner | TOOL | TOOL | 1 | -1 | NONE | 0 | 0 | 100 | 3 | 1.0 | 6.0 | 0 | 0 | COMMON | `resources/items/tools/exploration/scanner.tres` |
| 33 | Kobalterz | MATERIAL | ORE_METAL | 999 | 23 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/materials/ores/cobalt_ore_item.tres` |
| 34 | Veyriterz | MATERIAL | ORE_METAL | 999 | 24 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/materials/ores/veyrite_ore_item.tres` |
| 35 | Cryoniterz | MATERIAL | ORE_METAL | 999 | 25 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/materials/ores/cryonite_ore_item.tres` |
| 36 | Ignitiumerz | MATERIAL | ORE_METAL | 999 | 26 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/materials/ores/ignitium_ore_item.tres` |
| 37 | Voidiumerz | MATERIAL | ORE_METAL | 999 | 27 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/materials/ores/voidium_ore_item.tres` |
| 38 | Astralitherz | MATERIAL | ORE_METAL | 999 | 28 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/materials/ores/astralith_ore_item.tres` |
| 40 | Kupferspitzhacke | TOOL | TOOL | 1 | -1 | PICKAXE | 9 | 0 | 120 | 15 | 1.05 | 2.5 | 2 | 0 | COMMON | `resources/items/tools/mining/pickaxes/copper_pickaxe.tres` |
| 41 | Zinnspitzhacke | TOOL | TOOL | 1 | -1 | PICKAXE | 10 | 0 | 140 | 22 | 1.1 | 2.5 | 3 | 0 | COMMON | `resources/items/tools/mining/pickaxes/tin_pickaxe.tres` |
| 42 | Ferritspitzhacke | TOOL | TOOL | 1 | -1 | PICKAXE | 11 | 0 | 160 | 30 | 1.12 | 2.5 | 4 | 0 | COMMON | `resources/items/tools/mining/pickaxes/ferrite_pickaxe.tres` |
| 43 | Aurelspitzhacke | TOOL | TOOL | 1 | -1 | PICKAXE | 12 | 0 | 180 | 40 | 1.15 | 2.5 | 5 | 0 | COMMON | `resources/items/tools/mining/pickaxes/aurel_pickaxe.tres` |
| 44 | Kobaltspitzhacke | TOOL | TOOL | 1 | -1 | PICKAXE | 13 | 0 | 200 | 52 | 1.18 | 2.5 | 6 | 0 | COMMON | `resources/items/tools/mining/pickaxes/cobalt_pickaxe.tres` |
| 45 | Veyritspitzhacke | TOOL | TOOL | 1 | -1 | PICKAXE | 14 | 0 | 220 | 65 | 1.2 | 2.5 | 7 | 0 | COMMON | `resources/items/tools/mining/pickaxes/veyrite_pickaxe.tres` |
| 46 | Cryonitspitzhacke | TOOL | TOOL | 1 | -1 | PICKAXE | 15 | 0 | 240 | 80 | 1.22 | 2.5 | 8 | 0 | COMMON | `resources/items/tools/mining/pickaxes/cryonite_pickaxe.tres` |
| 47 | Ignitiumspitzhacke | TOOL | TOOL | 1 | -1 | PICKAXE | 16 | 0 | 260 | 100 | 1.25 | 2.5 | 9 | 0 | COMMON | `resources/items/tools/mining/pickaxes/ignitium_pickaxe.tres` |
| 48 | Voidiumspitzhacke | TOOL | TOOL | 1 | -1 | PICKAXE | 17 | 0 | 280 | 125 | 1.28 | 2.5 | 10 | 0 | COMMON | `resources/items/tools/mining/pickaxes/voidium_pickaxe.tres` |
| 49 | Astralithspitzhacke | TOOL | TOOL | 1 | -1 | PICKAXE | 18 | 0 | 320 | 160 | 1.3 | 2.5 | 11 | 0 | COMMON | `resources/items/tools/mining/pickaxes/astralith_pickaxe.tres` |
| 50 | Weiße Wiesenblume | PLANT | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/plants/white_wildflower.tres` |
| 51 | Gelbe Wiesenblume | PLANT | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/plants/yellow_wildflower.tres` |
| 52 | Rotes Wildkraut | PLANT | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/plants/red_wildflower.tres` |
| 53 | Blaue Wiesenblume | PLANT | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/plants/blue_wildflower.tres` |
| 54 | Violette Waldblume | PLANT | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/plants/purple_wildflower.tres` |
| 55 | Wildgras | PLANT | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/plants/wild_grass.tres` |
| 56 | Hohes Gras | PLANT | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/plants/tall_grass.tres` |
| 57 | Farn | PLANT | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/plants/fern.tres` |
| 58 | Kleiner Busch | PLANT | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/plants/bush.tres` |
| 59 | Trockengras | PLANT | RESOURCE | 999 | -1 | NONE | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | COMMON | `resources/items/plants/dry_grass.tres` |

## Werkzeuge (Detail)

| ID | Name | Kategorie | Kind | Schaden | Power | UseSpeed | Haltbarkeit | Range | Pick-Tier | Special | Beschreibung |
| ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 22 | Steinspitzhacke | MINING | PICKAXE | 8 | 10 | 1.0 | 100 | 2.5 | 1 | Stein/Erz | Bergbau-Spitzhacke. Spitzhacken-Power 10. Baut bis Kupfer. |
| 23 | Steinaxt | WOODCUTTING | AXE | 10 | 12 | 0.9 | 100 | 2.5 |  | Holz | Fällt Bäume und Holz. |
| 24 | Holzhammer | BUILDING_REPAIR | HAMMER | 5 | 8 | 1.0 | 120 | 2.5 |  | Bauen/Reparieren | Vorbereitet fuer Bauen und Reparieren. |
| 25 | Einfacher Schraubenschlüssel | DISMANTLING | WRENCH | 6 | 8 | 0.8 | 100 | 2.0 |  | Demontieren | Vorbereitet zum Demontieren von Maschinen. |
| 26 | Holzhacke | FARMING | HOE | 4 | 6 | 1.1 | 80 | 2.5 |  | Erde/Farming | Vorbereitet fuer Erde und Farming. |
| 27 | Holzangel | GATHERING_SPECIAL | FISHING_ROD | 2 | 5 | 1.0 | 80 | 8.0 |  | Angeln | Vorbereitetes Angel-Item. Angeln ist noch nicht spielbar. |
| 28 | Sichel | FARMING | SICKLE | 5 | 7 | 1.1 | 80 | 2.5 |  | Pflanzen | Vorbereitetes Farming-Testitem. |
| 29 | Kescher | GATHERING_SPECIAL | NET | 1 | 4 | 1.0 | 70 | 3.0 |  | Sammeln | Vorbereitetes Sammel-Testitem. |
| 30 | Fackel | EXPLORATION | NONE | 1 | 1 | 1.0 | 60 | 1.5 |  | Licht | Vorbereitetes Erkundungs-Testitem. Kein Lichtsystem. |
| 31 | Laterne | EXPLORATION | NONE | 1 | 2 | 1.0 | 90 | 2.0 |  | Licht | Vorbereitetes Erkundungs-Testitem. Kein Lichtsystem. |
| 32 | Scanner | EXPLORATION | NONE | 0 | 3 | 1.0 | 100 | 6.0 |  | Erkundung | Vorbereitetes Erkundungs-Testitem. Keine Scanner-Funktion. |
| 40 | Kupferspitzhacke | MINING | PICKAXE | 9 | 15 | 1.05 | 120 | 2.5 | 2 | Kupfer/Zinn | Bergbau-Spitzhacke. Spitzhacken-Power 15. Baut bis Zinn. |
| 41 | Zinnspitzhacke | MINING | PICKAXE | 10 | 22 | 1.1 | 140 | 2.5 | 3 | Zinn/Ferrit | Bergbau-Spitzhacke. Spitzhacken-Power 22. Baut bis Ferrit. |
| 42 | Ferritspitzhacke | MINING | PICKAXE | 11 | 30 | 1.12 | 160 | 2.5 | 4 | Ferrit/Aurel | Bergbau-Spitzhacke. Spitzhacken-Power 30. Baut bis Aurel. |
| 43 | Aurelspitzhacke | MINING | PICKAXE | 12 | 40 | 1.15 | 180 | 2.5 | 5 | Aurel/Kobalt | Bergbau-Spitzhacke. Spitzhacken-Power 40. Baut bis Kobalt. |
| 44 | Kobaltspitzhacke | MINING | PICKAXE | 13 | 52 | 1.18 | 200 | 2.5 | 6 | Kobalt/Veyrit | Bergbau-Spitzhacke. Spitzhacken-Power 52. Baut bis Veyrit. |
| 45 | Veyritspitzhacke | MINING | PICKAXE | 14 | 65 | 1.2 | 220 | 2.5 | 7 | Veyrit/Cryonit | Bergbau-Spitzhacke. Spitzhacken-Power 65. Baut bis Cryonit. |
| 46 | Cryonitspitzhacke | MINING | PICKAXE | 15 | 80 | 1.22 | 240 | 2.5 | 8 | Cryonit/Ignitium | Bergbau-Spitzhacke. Spitzhacken-Power 80. Baut bis Ignitium. |
| 47 | Ignitiumspitzhacke | MINING | PICKAXE | 16 | 100 | 1.25 | 260 | 2.5 | 9 | Ignitium/Voidium | Bergbau-Spitzhacke. Spitzhacken-Power 100. Baut bis Voidium. |
| 48 | Voidiumspitzhacke | MINING | PICKAXE | 17 | 125 | 1.28 | 280 | 2.5 | 10 | Voidium/Astralith | Bergbau-Spitzhacke. Spitzhacken-Power 125. Baut bis Astralith. |
| 49 | Astralithspitzhacke | MINING | PICKAXE | 18 | 160 | 1.3 | 320 | 2.5 | 11 | Alle Materialien | Bergbau-Spitzhacke. Spitzhacken-Power 160. Baut bis Alles. |

## Rüstung

| ID | Name | Slot | Defense | Stack |
| ---: | --- | --- | ---: | ---: |
| 4 | Test Helmet | HEAD | 1 | 1 |
| 5 | Test Chestplate | CHEST | 2 | 1 |
| 21 | Test Leggings | LEGS | 1 | 1 |

## Bäume

| Art | Stamm-Block | Blatt | Setzling | Holz-Item | Samen | Höhe | Stufen | Regrow | Stamm-Härte | Top-Mult | Krone | Fäll-Tool |
| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| Birke | 15 | 18 | 21 | 16 | 19 | 6–10 | 5 | 10.0 s | 0.9 | 0.45 | narrow | AXE |
| Eiche | 14 | 17 | 20 | 15 | 18 | 5–8 | 5 | 10.0 s | 1.2 | 0.45 | round | AXE |
| Kiefer | 16 | 19 | 22 | 17 | 20 | 8–13 | 5 | 10.0 s | 1.0 | 0.45 | triangle | AXE |

## Pflanzen

| Item-ID | Name | Kategorie | Gewicht | Cluster-Chance | Cluster-Größe | Erntezeit s | Wind | Pflanzbar | Erntbar |
| ---: | --- | --- | ---: | ---: | --- | ---: | ---: | --- | --- |
| 50 | Weiße Wiesenblume | FLOWER | 1.0 | 0.28 | 3–5 | 0.05 | 0.55 | true | true |
| 51 | Gelbe Wiesenblume | FLOWER | 1.0 | 0.3 | 3–5 | 0.05 | 0.58 | true | true |
| 52 | Rotes Wildkraut | FLOWER | 0.7 | 0.18 | 2–4 | 0.05 | 0.5 | true | true |
| 53 | Blaue Wiesenblume | FLOWER | 0.45 | 0.12 | 2–3 | 0.05 | 0.52 | true | true |
| 54 | Violette Waldblume | FLOWER | 0.9 | 0.22 | 2–4 | 0.05 | 0.5 | true | true |
| 55 | Wildgras | GRASS | 1.4 | 0.35 | 3–5 | 0.05 | 0.9 | true | true |
| 56 | Hohes Gras | GRASS | 0.8 | 0.32 | 3–5 | 0.06 | 1.15 | true | true |
| 57 | Farn | FERN | 1.0 | 0.2 | 2–3 | 0.06 | 0.75 | true | true |
| 58 | Kleiner Busch | BUSH | 0.5 | 0.08 | 2–2 | 0.08 | 0.4 | true | true |
| 59 | Trockengras | GRASS | 1.2 | 0.25 | 2–4 | 0.05 | 0.85 | true | true |

## Laternen-Stufen (Welt-Laterne)

| Level | Name | Safe-Radius Tiles | Light Energy | Texture Scale | Sprite px |
| ---: | --- | ---: | ---: | ---: | ---: |
| 1 | Alte Laterne | 44 | 1.15 | 4.0 | 48.0 |
| 2 | Wächterlaterne | 68 | 1.4 | 5.6 | 56.0 |
| 3 | Große Laterne | 100 | 1.7 | 7.4 | 64.0 |
| 4 | The Last Lantern | 140 | 2.05 | 9.2 | 72.0 |

## Nicht im Katalog (inaktiv)

Alte Einzeldateien wie `pickaxe.tres`, `gold_ore.tres`, `iron_ore.tres`, `silver_ore.tres` können noch im Ordner liegen, stehen aber **nicht** in den Katalogen.
