# Objektkatalog

Stand: 15.09.2026. Quelle der Wahrheit sind die Kataloge, nicht einzelne Rest-Dateien.

- Bloecke: `resources/blocks/block_catalog.tres`
- Erze: `resources/ores/ore_catalog.tres`
- Items: `resources/items/item_catalog.tres`
- Baeume: `resources/trees/` (oak, birch, pine)

Welt: 800 × 240 Tiles, Tilegroesse 16×16 px, Seed `12345`. Erz-Tiefen nutzen `min_depth_ratio` / `max_depth_ratio` relativ zur Welt-Hoehe. Die Spec-Tiefe (`spec_min_depth` / `spec_max_depth`) bezieht sich auf die Referenzhoehe **1200**.

---

## 1. Was du aktuell abbauen kannst

Startwerkzeug: **Steinspitzhacke** (Item-ID 22).

| Wert | Aktuell |
| --- | --- |
| ToolKind | **PICKAXE** |
| Spitzhacken-Power | **10** |
| Pickaxe-Tier | 1 |
| Schaden | 8 |
| Use-Speed | 1.0 |
| Haltbarkeit | 100 |
| Tool-Reichweite | 2.5 Tiles |
| Spieler-Mining-Reichweite | 5.0 Tiles |

Zentrale Regel in `BlockData.evaluate_break`:

1. `is_unbreakable` oder `hardness >= 100` → `UNBREAKABLE` (Bedrock).
2. `required_tool == NONE` und Power 0 → ohne Werkzeug abbaubar (Gras, Dirt, Sand, Blaetter, Setzlinge).
3. Sonst muss das gehaltene Item `tool_kind == required_tool` **und** `tool_power >= required_tool_power` haben.
4. Falsches Werkzeug → `WRONG_TOOL`, kein Schaden, kein Drop.
5. Richtiges Werkzeug, zu wenig Power → `TOOL_TOO_WEAK`, kein Schaden, kein Drop.
6. Power allein reicht nie: eine starke Axt baut kein Erz.

Erze lesen `required_tool` / `required_tool_power` aus `OreData` (immer PICKAXE). Holzbloecke und Baumstaemme brauchen `AXE`.

Abbauzeit:

```text
speed = base_mining_speed (1.0)
      * use_speed des gehaltenen Items
      * (1 + tool_power * 0.012)   nur wenn ToolKind zum Block passt
time  = max(hardness / speed, 0.05 Sekunden)
```

Mit der Steinspitzhacke auf Stein/Erz: `speed = 1.12`. Auf Holz gilt der Bonus nicht, weil die Spitzhacke dort nicht abbauen darf.

### Jetzt ja

| Objekt | Block-ID | Härte | Drop | Werkzeug | Power | Dauer |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Gras | 1 | 0.5 | Dirt ×1 | keines | 0 | ~0.50 s (Hand) |
| Dirt | 2 | 0.5 | Dirt ×1 | keines | 0 | ~0.50 s (Hand) |
| Sand | 4 | 0.4 | Sand ×1 | keines | 0 | ~0.40 s (Hand) |
| Stone | 3 | 1.5 | Stone ×1 | PICKAXE | 1 | ~1.34 s (Stein-Pick) |
| Granite | 5 | 2.0 | Granite ×1 | PICKAXE | 5 | ~1.79 s (Stein-Pick) |
| Slate | 6 | 1.8 | Slate ×1 | PICKAXE | 3 | ~1.61 s (Stein-Pick) |
| Wood (generic) | 7 | 1.0 | Wood ×1 | AXE | 1 | ~0.97 s (Stein-Axt) |
| Leaves (generic) | 8 | 0.2 | Leaves ×1 | keines | 0 | ~0.20 s (Hand) |
| Eichenholz | 14 | 1.0 / Stamm 1.2 | Eichenholz ×1 | AXE | 1 | ~0.97 / 1.17 s (Stein-Axt) |
| Birkenholz | 15 | 0.8 / Stamm 0.9 | Birkenholz ×1 | AXE | 1 | ~0.78 / 0.87 s (Stein-Axt) |
| Kiefernholz | 16 | 0.9 / Stamm 1.0 | Kiefernholz ×1 | AXE | 1 | ~0.87 / 0.97 s (Stein-Axt) |
| Baumblaetter | 17–19 | 0.3 | nichts | keines | 0 | ~0.30 s (Hand) |
| Setzlinge | 20–22 | 0.2 | Samen ×1 | keines | 0 | ~0.20 s (Hand) |
| **Kupfererz** | 9 | 1.8 | Kupfererz 2–4 | PICKAXE | 10 | ~1.61 s (Stein-Pick) |

Baeume faellt nur die **Steinaxt** (Power 12, ToolKind AXE) als ganzer Baum. Spitzhacke, Hammer und andere Tools faellen keine Baeume und bauen keine Holzbloecke.

`SHOVEL` ist noch nicht im Enum; Dirt/Sand bleiben vorerst ohne Werkzeug. Das Feld `required_tool` kann spaeter auf SHOVEL umgestellt werden, ohne die Mining-Logik umzuschreiben.

### Jetzt nein

| Objekt | Grund | Braucht mindestens |
| --- | --- | --- |
| Holz / Baumstamm mit Spitzhacke | falsches Werkzeug | Steinaxt |
| Stein / Erz mit Axt | falsches Werkzeug | passende Spitzhacke |
| Zinnerz | Power 15 | Kupferspitzhacke |
| Ferriterz | Power 22 | Zinnspitzhacke |
| Aurelerz | Power 30 | Ferritspitzhacke |
| Kobalterz | Power 40 | Aurelspitzhacke |
| Veyriterz | Power 52 | Kobaltspitzhacke |
| Cryoniterz | Power 65 | Veyritspitzhacke |
| Ignitiumerz | Power 80 | Cryonitspitzhacke |
| Voidiumerz | Power 100 | Ignitiumspitzhacke |
| Astralitherz | Power 125 | Voidiumspitzhacke |
| Bedrock | `is_unbreakable` | nie |

Naechster sinnvoller Schritt: Kupfer farmen → Kupferspitzhacke (Power 15) → Zinn.

---

## 2. Pickaxe-Leiter

Eine Spitzhacke baut **Stein, Granit, Schiefer und Erze**, wenn `tool_kind == PICKAXE` und `tool_power >= required_tool_power`. Hoehere Erze und falsche Werkzeuge geben rotes Feedback und brechen nicht.

| Item | ID | Tier | Power | Schaden | Tempo | Haltbarkeit | Reichweite | Baut bis |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Steinspitzhacke | 22 | 1 | **10** | 8 | 1.00 | 100 | 2.5 | Kupfer |
| Kupferspitzhacke | 40 | 2 | 15 | 9 | 1.05 | 120 | 2.5 | Zinn |
| Zinnspitzhacke | 41 | 3 | 22 | 10 | 1.10 | 140 | 2.5 | Ferrit |
| Ferritspitzhacke | 42 | 4 | 30 | 11 | 1.12 | 160 | 2.5 | Aurel |
| Aurelspitzhacke | 43 | 5 | 40 | 12 | 1.15 | 180 | 2.5 | Kobalt |
| Kobaltspitzhacke | 44 | 6 | 52 | 13 | 1.18 | 200 | 2.5 | Veyrit |
| Veyritspitzhacke | 45 | 7 | 65 | 14 | 1.20 | 220 | 2.5 | Cryonit |
| Cryonitspitzhacke | 46 | 8 | 80 | 15 | 1.22 | 240 | 2.5 | Ignitium |
| Ignitiumspitzhacke | 47 | 9 | 100 | 16 | 1.25 | 260 | 2.5 | Voidium |
| Voidiumspitzhacke | 48 | 10 | 125 | 17 | 1.28 | 280 | 2.5 | Astralith |
| Astralithspitzhacke | 49 | 11 | 160 | 18 | 1.30 | 320 | 2.5 | alles |

Gemeinsame Item-Werte aller 11 Spitzhacken:

- `item_type = TOOL`
- `category = TOOL` (Farbe `#24C7C8`)
- `tool_kind = PICKAXE`
- `tool_category = MINING`
- `max_stack = 1`
- `attack_cooldown = 0.35`
- `knockback = 100`
- `held_rotation_degrees = -45`
- `placeable_block_id = -1`

Die alte Placeholder-Spitzhacke **Pickaxe** (ID 3) ist geloescht. ID 3 ist frei.

---

## 3. Alle Bloecke

Vision-Occlusion ist `-1` (automatisch), ausser sie steht explizit. Automatik:

| IDs | Occlusion |
| --- | ---: |
| Luft 0 | 0.0 |
| Blaetter 8, 17, 18, 19 | 0.2 |
| Holz 7, 14, 15, 16 | 0.5 |
| Setzlinge 20, 21, 22 | 0.1 |
| Sand 4 | 0.9 |
| solid sonst | 1.0 |
| nicht solid sonst | 0.0 |

Atlas: Source 0, `texture_region_size = 16×16`.

### 3.1 Terrain

| ID | Name | Atlas | Härte | Solid | Drop-Item | Platzier-Item | Tool | Power |
| ---: | --- | --- | ---: | --- | --- | --- | --- | ---: |
| 1 | Grass | (0, 0) | 0.5 | ja | 1 Dirt | keines | keines | 0 |
| 2 | Dirt | (1, 0) | 0.5 | ja | 1 Dirt | Dirt (1) | keines | 0 |
| 3 | Stone | (2, 0) | 1.5 | ja | 2 Stone | Stone (2) | PICKAXE | 1 |
| 4 | Sand | (3, 0) | 0.4 | ja | 6 Sand | Sand (6) | keines | 0 |
| 5 | Granite | (4, 0) | 2.0 | ja | 7 Granite | Granite (7) | PICKAXE | 5 |
| 6 | Slate | (5, 0) | 1.8 | ja | 8 Slate | Slate (8) | PICKAXE | 3 |
| 7 | Wood | (6, 0) | 1.0 | ja | 9 Wood | Wood (9) | AXE | 1 |
| 8 | Leaves | (7, 0) | 0.2 | nein | 10 Leaves | Leaves (10) | keines | 0 |
| 13 | Bedrock | (4, 1) | 999.0 | ja | keines (−1) | keines | unzerstörbar | — |

Gras hat kein eigenes Item. Abgebautes Gras wird zu Dirt. Dirt platziert Dirt, nicht Gras.

Bedrock: 5 Reihen am Weltboden plus Weltkante (`world_edge_width = 3`).

### 3.2 Erzbloecke

Jeder Erzblock hat `ore_data` gesetzt. Mining liest Werkzeug und Power **nur** von dort (`required_tool = PICKAXE`).

| ID | Name | Atlas | Härte | Drop | Power | Map-Farbe |
| ---: | --- | --- | ---: | ---: | ---: | --- |
| 9 | Kupfererz | (0, 1) | 1.8 | 11 | 10 | `#C66C2A` |
| 10 | Zinnerz | (1, 1) | 2.1 | 12 | 15 | `#C4CCD2` |
| 11 | Ferriterz | (2, 1) | 2.5 | 13 | 22 | `#B04030` |
| 12 | Aurelerz | (3, 1) | 3.0 | 14 | 30 | `#E8BA30` |
| 23 | Kobalterz | (5, 1) | 3.5 | 33 | 40 | `#3060D2` |
| 24 | Veyriterz | (6, 1) | 4.1 | 34 | 52 | `#9440C4` |
| 25 | Cryoniterz | (7, 1) | 4.8 | 35 | 65 | `#48D2DC` |
| 26 | Ignitiumerz | (1, 3) | 5.6 | 36 | 80 | `#E8561C` |
| 27 | Voidiumerz | (2, 3) | 6.5 | 37 | 100 | `#3A184E` |
| 28 | Astralitherz | (3, 3) | 7.5 | 38 | 125 | `#BA8CFF` |

Adern ersetzen nur Stein/Granit/Schiefer (`STONE_LIKE`).

### 3.3 Holz, Blaetter, Setzlinge

| ID | Name | Atlas | Härte | Solid | Drop | Tool | Power |
| ---: | --- | --- | ---: | --- | --- | --- | ---: |
| 14 | Eichenholz | (0, 2) | 1.0 | ja | 15 Eichenholz | AXE | 1 |
| 15 | Birkenholz | (1, 2) | 0.8 | ja | 16 Birkenholz | AXE | 1 |
| 16 | Kiefernholz | (2, 2) | 0.9 | ja | 17 Kiefernholz | AXE | 1 |
| 17 | Eichenblaetter | (3, 2) | 0.3 | nein | keines | keines | 0 |
| 18 | Birkenblaetter | (4, 2) | 0.3 | nein | keines | keines | 0 |
| 19 | Kiefernnadeln | (5, 2) | 0.3 | nein | keines | keines | 0 |
| 20 | Eichensetzling | (6, 2) | 0.2 | nein | 18 Eichensamen | keines | 0 |
| 21 | Birkensetzling | (7, 2) | 0.2 | nein | 19 Birkensamen | keines | 0 |
| 22 | Kiefernsetzling | (0, 3) | 0.2 | nein | 20 Kiefernsamen | keines | 0 |

Stehende Baumstaemme nutzen zusaetzlich `TreeData.trunk_hardness` statt der Block-Härte. Faellen geht nur mit `required_felling_tool = AXE`.

---

## 4. Alle Erze

Kategorie: `RAW_ORE` (Roherz), ausser Astralith = `SPECIAL_ORE`. Spawn: `special_spawn` nur bei Astralith.

Drop-Menge: zufaellig zwischen `drop_min` und `drop_max`.

Tiefe in einer 240-Tile-Welt: `ratio * 240`. Spec-Spalte bleibt die Originaltabelle auf 1200.

| Erz | ID | Tier | Block | Item | Power | Härte | Drop | Ader | Ratio | ≈ Tiles (h=240) | Spec 1200 | XP | Gewicht | Special |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- | ---: | ---: | --- |
| Kupfer | copper | 1 | 9 | 11 | **10** | 1.8 | 2–4 | 5–12 | 0.000–0.125 | 0–30 | 0–150 | 2 | 1.40 | nein |
| Zinn | tin | 2 | 10 | 12 | 15 | 2.1 | 2–4 | 4–10 | 0.042–0.208 | 10–50 | 50–250 | 3 | 0.90 | nein |
| Ferrit | ferrite | 3 | 11 | 13 | 22 | 2.5 | 2–3 | 4–9 | 0.125–0.333 | 30–80 | 150–400 | 5 | 0.55 | nein |
| Aurel | aurel | 4 | 12 | 14 | 30 | 3.0 | 1–3 | 3–7 | 0.208–0.417 | 50–100 | 250–500 | 8 | 0.40 | nein |
| Kobalt | cobalt | 5 | 23 | 33 | 40 | 3.5 | 1–3 | 3–6 | 0.333–0.542 | 80–130 | 400–650 | 12 | 0.28 | nein |
| Veyrit | veyrite | 6 | 24 | 34 | 52 | 4.1 | 1–3 | 2–5 | 0.458–0.667 | 110–160 | 550–800 | 18 | 0.18 | nein |
| Cryonit | cryonite | 7 | 25 | 35 | 65 | 4.8 | 1–2 | 2–5 | 0.542–0.750 | 130–180 | 650–900 | 25 | 0.12 | nein |
| Ignitium | ignitium | 8 | 26 | 36 | 80 | 5.6 | 1–2 | 2–4 | 0.667–0.917 | 160–220 | 800–1100 | 35 | 0.08 | nein |
| Voidium | voidium | 9 | 27 | 37 | 100 | 6.5 | 1–2 | 1–4 | 0.833–1.000 | 200–240 | 1000–1200 | 50 | 0.05 | nein |
| Astralith | astralith | 10 | 28 | 38 | 125 | 7.5 | 1 | 1–3 | 0.917–1.000 | 220–240 | 1100–1200 | 100 | 0.015 | ja |

### Erz-Items

Alle: `item_type = MATERIAL`, `max_stack = 999`, `category = ORE_METAL` (`#708090`), platzierbar auf den zugehoerigen Block.

| ID | Name | Beschreibung | Platzierter Block | Metall |
| ---: | --- | --- | ---: | --- |
| 11 | Kupfererz | Roherz. Benoetigt Spitzhacken-Power 10. | 9 | RAW_ORE |
| 12 | Zinnerz | Roherz. Benoetigt Spitzhacken-Power 15. | 10 | RAW_ORE |
| 13 | Ferriterz | Roherz. Benoetigt Spitzhacken-Power 22. | 11 | RAW_ORE |
| 14 | Aurelerz | Roherz. Benoetigt Spitzhacken-Power 30. | 12 | RAW_ORE |
| 33 | Kobalterz | Roherz. Benoetigt Spitzhacken-Power 40. | 23 | RAW_ORE |
| 34 | Veyriterz | Roherz. Benoetigt Spitzhacken-Power 52. | 24 | RAW_ORE |
| 35 | Cryoniterz | Roherz. Benoetigt Spitzhacken-Power 65. | 25 | RAW_ORE |
| 36 | Ignitiumerz | Roherz. Benoetigt Spitzhacken-Power 80. | 26 | RAW_ORE |
| 37 | Voidiumerz | Roherz. Benoetigt Spitzhacken-Power 100. | 27 | RAW_ORE |
| 38 | Astralitherz | Spezialerz. Benoetigt Spitzhacken-Power 125. | 28 | SPECIAL_ORE |

Verarbeitetes Metall und Legierungen existieren noch nicht als Items.

---

## 5. Holz und Baeume

Drei Arten. Generisches Wood/Leaves (Block 7/8, Item 9/10) bleibt fuer Huetten/Platzhalter.

| Art | tree_id | Stamm | Blatt | Setzling | Holz-Item | Samen | Hoehe | Stufen | Nachwuchs | Stamm-Härte | Krone × | Krone |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- | ---: | ---: | --- |
| Eiche | oak | 14 | 17 | 20 | 15 | 18 | 5–8 | 5 | 10 s | 1.2 | 0.45 | round |
| Birke | birch | 15 | 18 | 21 | 16 | 19 | 6–10 | 5 | 10 s | 0.9 | 0.45 | narrow |
| Kiefer | pine | 16 | 19 | 22 | 17 | 20 | 8–13 | 5 | 10 s | 1.0 | 0.45 | triangle |

Gefaellter Baum droppt Holz (Anzahl ~ Stammhoehe) plus Samen. Einzelne Blaetter droppen nichts. Abgebauter Setzling droppt den Samen.

Samen pflanzen den zugehoerigen Setzling. Sie sind keine normalen Platzier-Bloecke (`placeable_block_id = -1`).

---

## 6. Alle Items im Katalog

47 Eintraege. Freie IDs: **3** (alte Placeholder-Datei, nicht katalogisiert), **39** und alles ausserhalb 1–49, das nicht unten steht.

Enums:

| Feld | Werte |
| --- | --- |
| ItemType | 0 BLOCK, 1 TOOL, 2 WEAPON, 3 ARMOR, 4 ACCESSORY, 5 MATERIAL, 6 SEED |
| ItemCategory | 6 BUILDING_MATERIAL `#9B6A43`, 7 RESOURCE `#BFC5CC`, 8 ORE_METAL `#708090`, 2 ARMOR `#3F7CFF`, 10 TOOL `#24C7C8` |
| EquipmentSlot | 0 NONE, 1 HEAD, 2 CHEST, 3 LEGS, 4 ACCESSORY |
| ToolKind | 0 NONE, 1 PICKAXE, 2 AXE, 3 HAMMER, 4 WRENCH, 5 HOE, 6 SICKLE, 7 FISHING_ROD, 8 NET |
| ToolCategory | 1 MINING, 2 WOODCUTTING, 3 BUILDING_REPAIR, 4 DISMANTLING, 5 FARMING, 6 GATHERING_SPECIAL, 7 EXPLORATION |

### 6.1 Baumaterialien

`item_type = BLOCK`, `category = BUILDING_MATERIAL`, Stack 999.

| ID | Name | platziert Block | Icon |
| ---: | --- | ---: | --- |
| 1 | Dirt | 2 Dirt | `assets/world/tiles/dirt_placeholder.png` |
| 2 | Stone | 3 Stone | `assets/world/tiles/stone_placeholder.png` |
| 6 | Sand | 4 Sand | `assets/world/tiles/sand_placeholder.png` |
| 7 | Granite | 5 Granite | `assets/world/tiles/granite_placeholder.png` |
| 8 | Slate | 6 Slate | `assets/world/tiles/slate_placeholder.png` |
| 9 | Wood | 7 Wood | `assets/world/tiles/wood_placeholder.png` |
| 10 | Leaves | 8 Leaves | `assets/world/tiles/leaves_placeholder.png` |
| 15 | Eichenholz | 14 Eichenholz | `assets/world/tiles/oak_wood.png` |
| 16 | Birkenholz | 15 Birkenholz | `assets/world/tiles/birch_wood.png` |
| 17 | Kiefernholz | 16 Kiefernholz | `assets/world/tiles/pine_wood.png` |

### 6.2 Samen

`item_type = SEED`, `category = RESOURCE`, Stack 999, nicht direkt als Block platzierbar.

| ID | Name | tree_type | Setzling-Block |
| ---: | --- | --- | ---: |
| 18 | Eichensamen | oak | 20 |
| 19 | Birkensamen | birch | 21 |
| 20 | Kiefernsamen | pine | 22 |

### 6.3 Ruestung (Holz)

`item_type = ARMOR`, `category = ARMOR`, Stack 1. Overlay-Frames vorhanden.

| ID | Name | Slot | Defense | Frames |
| ---: | --- | --- | ---: | --- |
| 120 | Holzhelm | HEAD | 1 | `armor_wood_helmet_frames.tres` |
| 121 | Holzbrustrüstung | CHEST | 2 | `armor_wood_chest_frames.tres` |
| 122 | Holzbeinschutz | LEGS | 2 | `armor_wood_legs_frames.tres` |

### 6.4 Demo-Tools

Alle: `item_type = TOOL`, `category = TOOL`, Stack 1, `attack_cooldown = 0.35`, `knockback = 100`. Funktionen ausser Axt/Spitzhacke sind vorbereitet, nicht voll spielbar.

| ID | Name | ToolKind | Kategorie | Power | Schaden | Tempo | Haltbarkeit | Range | Special | Rotation | Flip H |
| ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- |
| 23 | Steinaxt | AXE | Holzfällen | 12 | 10 | 0.9 | 100 | 2.5 | Holz | −45 | ja |
| 24 | Holzhammer | HAMMER | Bauen / Reparieren | 8 | 5 | 1.0 | 120 | 2.5 | Bauen/Reparieren | −30 | nein |
| 25 | Einfacher Schraubenschlüssel | WRENCH | Demontieren | 8 | 6 | 0.8 | 100 | 2.0 | Demontieren | −20 | nein |
| 26 | Holzhacke | HOE | Landwirtschaft | 6 | 4 | 1.1 | 80 | 2.5 | Erde/Farming | −40 | nein |
| 27 | Holzangel | FISHING_ROD | Sammeln / Spezial | 5 | 2 | 1.0 | 80 | 8.0 | Angeln | −15 | nein |
| 28 | Sichel | SICKLE | Landwirtschaft | 7 | 5 | 1.1 | 80 | 2.5 | Pflanzen | −35 | nein |
| 29 | Kescher | NET | Sammeln / Spezial | 4 | 1 | 1.0 | 70 | 3.0 | Sammeln | −25 | nein |
| 30 | Fackel | NONE | Erkundung | 1 | 1 | 1.0 | 60 | 1.5 | Licht | 0 | nein |
| 31 | Laterne | NONE | Erkundung | 2 | 1 | 1.0 | 90 | 2.0 | Licht | 0 | nein |
| 32 | Scanner | NONE | Erkundung | 3 | 0 | 1.0 | 100 | 6.0 | Erkundung | 0 | nein |

| ID | Beschreibung |
| ---: | --- |
| 23 | Fällt Bäume und Holz. |
| 24 | Vorbereitet fuer Bauen und Reparieren. |
| 25 | Vorbereitet zum Demontieren von Maschinen. |
| 26 | Vorbereitet fuer Erde und Farming. |
| 27 | Vorbereitetes Angel-Item. Angeln ist noch nicht spielbar. |
| 28 | Vorbereitetes Farming-Testitem. |
| 29 | Vorbereitetes Sammel-Testitem. |
| 30 | Vorbereitetes Erkundungs-Testitem. Kein Lichtsystem. |
| 31 | Vorbereitetes Erkundungs-Testitem. Kein Lichtsystem. |
| 32 | Vorbereitetes Erkundungs-Testitem. Keine Scanner-Funktion. |

Erz-Items und Spitzhacken stehen in Abschnitt 4 und 2.

---

## 7. Start-Inventar

`scripts/inventory/inventory.gd`

| Was | Wo | Menge |
| --- | --- | ---: |
| Steinspitzhacke (22) | Hotbar (erster freier Slot) | 1 |
| Tools 22–32 | Beutel, falls noch nicht vorhanden | je 1 |
| Stone (2) | Beutel | 20 |

Slots: 0–9 Hotbar, 10–39 Beutel (40 gesamt). Equipment: head, chest, legs, accessory_1, accessory_2.

Hoehere Spitzhacken (40–49) startest du **nicht**. Die liegen nur im Katalog.

---

## 8. ID-Uebersicht

### Bloecke 1–28

```text
 1 Grass          2 Dirt           3 Stone          4 Sand
 5 Granite        6 Slate          7 Wood           8 Leaves
 9 Kupfererz     10 Zinnerz       11 Ferriterz     12 Aurelerz
13 Bedrock       14 Eichenholz    15 Birkenholz    16 Kiefernholz
17 Eichenblaetter 18 Birkenblaetter 19 Kiefernnadeln 20 Eichensetzling
21 Birkensetzling 22 Kiefernsetzling 23 Kobalterz  24 Veyriterz
25 Cryoniterz    26 Ignitiumerz   27 Voidiumerz    28 Astralitherz
```

### Items im Katalog

```text
 1 Dirt           2 Stone          3 (frei)         4 (frei)
 5 (frei)         6 Sand           7 Granite        8 Slate
 9 Wood          10 Leaves        11 Kupfererz     12 Zinnerz
13 Ferriterz     14 Aurelerz      15 Eichenholz    16 Birkenholz
17 Kiefernholz   18 Eichensamen   19 Birkensamen   20 Kiefernsamen
21 (frei)        22 Steinspitzhacke 23 Steinaxt    24 Holzhammer
25 Schraubenschlüssel 26 Holzhacke 27 Holzangel    28 Sichel
29 Kescher       30 Fackel        31 Laterne       32 Scanner
33 Kobalterz     34 Veyriterz     35 Cryoniterz    36 Ignitiumerz
37 Voidiumerz    38 Astralitherz  39 (frei)        40 Kupferspitzhacke
41 Zinnspitzhacke 42 Ferritspitzhacke 43 Aurelspitzhacke 44 Kobaltspitzhacke
45 Veyritspitzhacke 46 Cryonitspitzhacke 47 Ignitiumspitzhacke
48 Voidiumspitzhacke 49 Astralithspitzhacke
```

---

## 9. Entfernte Altlast

Englische Root-Erze (`items/{copper,iron,silver,gold}_ore.tres`), Root-Bloecke (`blocks/{copper,iron,silver,gold}_ore.tres`), Placeholder `pickaxe.tres` und Test-Ruestung (`helmet.tres`, `chestplate.tres`, `leggings.tres`) sind geloescht.

Eisen, Silber und Gold als Erz-Progression gibt es nicht. Stattdessen: Kupfer → Zinn → Ferrit → Aurel → Kobalt → Veyrit → Cryonit → Ignitium → Voidium → Astralith.

---

## 10. Weltwerte, die Drops beeinflussen

| Parameter | Wert |
| --- | --- |
| Weltbreite / -hoehe | 800 × 240 |
| Oberflaeche Basis / Amplitude | y=72 ± 14 |
| Dirt-Tiefe | 4–8 |
| Sandregion Breite / Tiefe | 6–30 / 3–6 |
| Hoehlenanteil | 0.17 |
| Bedrock-Reihen | 5 |
| Baum-Abstand (Generator-Huettenholz separat) | 4–9 |
| Huettenziel | 9, Mindestabstand 70 |

Erz-Adern spawnen nur in Stein, Granit und Schiefer unter der Oberflaeche, nie in Bedrock.
