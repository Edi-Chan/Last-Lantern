# Player Visual System

Letztes Lantern verwendet **ein** Master-Animationssystem. Rüstung, Kleidung und Haar sind Overlay-Layer. Sie besitzen keine eigene State Machine.

## Prinzip

Der Player definiert die Pose. Ausrüstung definiert nur, wie diese Pose aussieht.

Beispiel: `run`, Frame 2, Blick nach links.

Dann zeigen Body, Haar, Shirt, Hose, Brustpanzer, Beinrüstung und Helm dieselbe Animation, denselben Frame und dieselbe Blickrichtung.

## Frame-Vertrag

Quelle: `terraria/scripts/player/player_animation_contract.gd`

| Feld | Wert |
|---|---|
| Frame-Größe | 40 × 56 |
| Pivot / Sprite-Offset | (20, 56) / `(0, -28)` |
| Fußlinie | y = 55 im Canvas, Root-Ursprung = Fuß |
| Sheet-Spalten | 6 |
| Sheet-Layout | eine Zeile pro Animation, Spalte = Frame |

Collider bleiben getrennt:

- Stehen: 20 × 42, Zentrum `(0, -21)`
- Ducken: 20 × 28, Zentrum `(0, -14)`

Animation bewegt den CharacterBody2D nicht (kein Root Motion).

## Layer-Reihenfolge

`Player/Visuals` (`PlayerVisualController`)

1. HairBack
2. BaseSprite (Haut/Körper)
3. ClothingLegs
4. ClothingShoes
5. ClothingChest
6. LegArmorSprite
7. ChestArmorSprite
8. HairFront
9. HelmetSprite
10. VisualEffects

Gehaltenes Item bleibt `Player/ToolPivot/ToolArm/HeldItemSprite`. Es liegt nicht in den Körper-Frames.

Während der Ausholphase einer Action kann `ToolPivot.z_index` kurz hinter den Körper, danach wieder davor.

Spiegeln nur über `flip_h`. `Visuals.scale` bleibt `Vector2.ONE`. Swing-Rotation sitzt auf `ToolArm`, nicht auf `ToolPivot`.

## Animationen

| Name | Frames | Loop | FPS |
|---|---|---|---|
| idle | 4 | ja | 6 |
| idle_alt | 3 | ja | 5 |
| walk | 6 | ja | 10 |
| run | 6 | ja | 14 |
| crouch_idle | 2 | ja | 5 |
| crouch_walk | 4 | ja | 8 |
| jump_start | 2 | nein | 14 |
| jump | 2 | ja | 8 |
| fall | 2 | ja | 8 |
| land | 2 | nein | 12 |
| swim_idle | 4 | ja | 6 |
| swim | 6 | ja | 10 |
| ladder_idle | 1 | ja | 5 |
| ladder_climb | 4 | ja | 8 |
| hurt | 2 | nein | 12 |
| death | 4 | nein | 8 |
| sleep | 2 | ja | 3 |
| use_swing | 6 | nein | 16 |
| use_overhead | 5 | nein | 14 |
| use_thrust | 5 | nein | 14 |
| use_chop | 5 | nein | 14 |
| use_mine | 5 | nein | 14 |
| use_stab | 4 | nein | 18 |
| bow_draw | 3 | nein | 10 |
| bow_release | 3 | nein | 14 |
| block_place | 3 | nein | 12 |
| interact | 3 | nein | 10 |
| use_tool | 1 | ja | 5 |

Priorität: Death → Hurt → Action/Bogen → Mining → Swim → Ladder → Air → Land → Crouch → Run → Walk → Idle.

## ActionType

`ItemData.action_type` oder automatisch aus `weapon_kind` / `tool_kind`:

| Item | ActionType | Körper | AnimationPlayer | Hitbox |
|---|---|---|---|---|
| Schwert | SWING | use_swing | use_swing | 0.10–0.24 |
| Speer | THRUST | use_thrust | use_thrust | 0.16–0.28 |
| Spitzhacke | MINE | use_mine | use_mine | 0.12–0.26 |
| Axt | CHOP | use_chop | use_chop | 0.12–0.26 |
| Dolch | STAB | use_stab | use_stab | 0.06–0.14 |
| Bogen | BOW | bow_draw / bow_release | bow_release | keine Melee |
| Laterne | LANTERN | use_swing | lantern_burst | 0.18–0.32 |

`StatId.ATTACK_SPEED` skaliert Animationsgeschwindigkeit, Hitbox-Fenster (über `AnimationPlayer.speed_scale`) und Cooldown gemeinsam.

## Neue Rüstung

Player-Code nicht ändern.

1. Overlay-Sheet 40×56, gleiche Zeilen wie der Contract, zeichnen.
2. `SpriteFrames` anlegen (Generator: `python terraria/tools/gen_player_sprites.py`).
3. Optional `EquipmentVisualData` mit Frames, Modulate, Haar-Policy.
4. `ItemData.armor_sprite_frames` oder `equipment_visual` setzen.
5. Equipment-Slot `HEAD` / `CHEST` / `LEGS`.
6. Im ItemCatalog registrieren.
7. Validator: Godot → `tools/validate_player_equipment.gd` ausführen.

Helme ohne `EquipmentVisualData` verstecken Haar automatisch (`HIDE_HAIR`).

## Neue Waffe

1. Item-Sprite.
2. `ItemData` mit `WeaponKind` (z. B. SWORD).
3. `ActionType` leer lassen oder explizit setzen (SWING).
4. Damage, Speed, Reach, Hold-Offset.
5. Catalog.

Keine neue Player-Animation.

## Appearance / Save

`LookRecord` speichert Name, Haarstil, Haarfarbe, Hautfarbe, Shirt-, Hosen- und Schuhfarbe. Keine Texturen. Rüstung bleibt Inventar/Equipment.

Vorschau (`compose_preview_texture`) nutzt dieselben Layer wie der echte Player und wird nur bei Equipment-/Appearance-Änderung neu gebaut.

## Assets erzeugen

Generator: `python terraria/tools/gen_player_sprites.py` (Körper/Kleidung).
Rüstung: `python terraria/tools/gen_armor_visuals.py` (eigene Sheets pro Material, keine Recolors).

## Validator

`PlayerEquipmentValidator.run()` prüft Animationsnamen, Framezahlen, Framegröße und fehlende Rüstungsanimationen.
