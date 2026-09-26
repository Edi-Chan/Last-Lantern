# Last Lantern — Charakter-System (KI-Briefing)

**Projekt:** Last Lantern (Godot 4, 2D, Terraria-ähnlich)  
**Spielroot:** `terraria/`  
**Einstieg:** `terraria/scenes/player/player.tscn`  
**Zweck dieses Dokuments:** vollständige, implementierungsnahe Beschreibung des Spielercharakters, damit eine andere KI das System verstehen, erweitern oder debuggen kann, ohne den Code neu zu raten.

---

## 1. Architektur in einem Satz

Der Spieler ist ein `CharacterBody2D` (`class_name Player`) **ohne gemeinsame Player-Basisklasse**. Fachlogik sitzt per **Komposition** in Child-Nodes: Bewegung/Animation/Rüstung visuell in `player.gd`, Werte in `PlayerStats` + `StatSheet`, Welt-Interaktion in `PlayerInteraction`, Inventar in `Inventory`, Nahkampf in `ToolHitbox`, Hand-Pose in `HeldItem`.

Es gibt **zwei Animationssysteme parallel**:

1. Körper + Rüstung: `AnimatedSprite2D` + `SpriteFrames` (Frame-States).
2. Werkzeug/Waffe: `AnimationPlayer` (Rotation/Position der Hand, Hitbox-Fenster).

Rüstung ist **kein eigenes Animations-Rig**. Sie sind Overlay-Sprites, die Animation, Frame und `flip_h` vom Körpersprite kopieren.

---

## 2. Dateikarte

### Scripts (`terraria/scripts/player/`)

| Datei | Klasse | Rolle |
|---|---|---|
| `player.gd` | `Player` | Root: Physik, Crouch, Sprint, Blick, Körperanimation, Rüstungs-Overlays, Bett, Schaden, Soft-Respawn |
| `player_stats.gd` | `PlayerStats` | HP / Stamina / Energy, StatSheet, Equipment-Rebuild, eingehender Schaden |
| `player_interaction.gd` | `PlayerInteraction` | Mining, Platzierung, Kampf, Bogen, Targeting |
| `player_camera.gd` | `PlayerCamera` | Zoom |
| `held_item.gd` | `HeldItem` | Hotbar-Item in der Hand, Idle-/Walk-Pose |
| `tool_hitbox.gd` | `ToolHitbox` | Nahkampf-Trefferfenster |

### Stats / Combat / Items

| Datei | Klasse |
|---|---|
| `scripts/stats/stat_id.gd` | `StatId` (26 IDs) |
| `scripts/stats/stat_sheet.gd` | `StatSheet` |
| `scripts/stats/stat_modifier.gd` | `StatModifier` |
| `scripts/inventory/inventory.gd` | `Inventory` |
| `scripts/items/item_data.gd` | `ItemData` |
| `scripts/items/item_instance_data.gd` | `ItemInstanceData` |
| `scripts/combat/combat_resolver.gd` | `CombatResolver` |
| `scripts/combat/damage_event.gd` | `DamageEvent` |
| `scripts/audio/player_audio.gd` | `PlayerAudio` |
| `scripts/liquid/water_interaction.gd` | `WaterInteraction` |
| `scripts/liquid/lava_interaction.gd` | `LavaInteraction` |

### Szenen

- `scenes/player/player.tscn` — Spieler
- `scenes/ui/player_stats_hud.tscn` — HP/Stamina/Energy-Balken
- `scenes/ui/character_creator.tscn` — nur Name (`LookRecord`), **keine** Haar/Haut/Kleidungs-Schichten

### SpriteFrames

- `resources/player/player_frames.tres` — Körper
- `resources/player/armor_helmet_frames.tres`
- `resources/player/armor_chest_frames.tres`
- `resources/player/armor_legs_frames.tres`

**Pflicht:** Alle Rüstungs-SpriteFrames müssen **dieselben Animationsnamen** wie der Körper haben.

### Assets

- Körper: `assets/player/player_idle.png`, `player_walk_a/b.png`, `player_run_a/b.png`, `player_jump.png`, `player_fall.png`, `player_use_tool.png`, `player_crouch_idle.png`, `player_crouch_walk_a/b.png`
- Rüstung: `assets/player/armor/{helmet,chest,legs}_*.png` (gleiche Animationsnamen)
- Generator: `tools/gen_player_sprites.py`

### Tests

- `tests/test_player_stats.gd`
- `tests/test_weapons.gd`
- `tests/test_liquid_system.gd`

---

## 3. Szenenbaum `player.tscn`

```
Player (CharacterBody2D, collision_layer=2, collision_mask=33)
├── Visuals (Node2D)                    # nicht skalieren; Spiegelung nur flip_h
│   ├── BaseSprite (AnimatedSprite2D)   # Körper, SpriteFrames = player_frames.tres
│   ├── LegArmorSprite  (z_index 1)
│   ├── ChestArmorSprite (z_index 2)
│   └── HelmetSprite     (z_index 3)
├── CollisionShape2D                    # stehen 20×42, ducken 20×28, Fußlinie y=0
├── Camera2D (PlayerCamera)
├── ToolPivot (HeldItem)                # nur scale.x für Spiegelung
│   └── ToolArm (Node2D)                # Rotation des Schwungs sitzt HIER
│       ├── HeldItemSprite
│       ├── ToolHitbox (Area2D, layer 16, mask 4)
│       └── CombatLight (PointLight2D)
├── InteractionPoint (Marker2D)
├── Inventory
├── Stats (PlayerStats)
├── WaterInteraction
├── LavaInteraction
├── Interaction (PlayerInteraction)
├── AnimationPlayer                     # Werkzeug-/Waffen-Clips
└── Audio (PlayerAudio)
```

**Wichtige Design-Regel:** `Visuals.scale` bleibt `Vector2.ONE`. Horizontales Spiegeln nur über `AnimatedSprite2D.flip_h`. Swing-Rotation darf **nicht** auf `ToolPivot` liegen, sonst dreht der Schwung beim Blick nach links nach oben statt nach unten.

Gruppen:

- `"player"` — Root
- `"player_stats"` — Stats-Node
- `"player_inventory"` — Inventory-Node

---

## 4. Bewegung (`Player._physics_process`)

Gameplay-Input ist tot, solange `UIManager.is_blocking_gameplay()` wahr ist (`world_input_enabled`).

### Export-Defaults

| Parameter | Default | Bedeutung |
|---|---|---|
| `move_speed` | 130 | Basis-Laufgeschwindigkeit |
| `ground_acceleration` | 900 | Beschleunigung am Boden |
| `air_acceleration` | 500 | in der Luft |
| `ground_friction` | 1100 | Reibung |
| `gravity` | 1000 | Gravitation |
| `jump_velocity` | -330 | Sprungimpuls |
| `jump_cut_multiplier` | 0.5 | Sprung kürzen beim Loslassen |
| `max_fall_speed` | 600 | Fallkappe |
| `sprint_multiplier` | 1.5 | zusätzlich zu Stat `SPRINT_SPEED` |
| `stamina_sprint_cost` | 20 / s | Sprint-Verbrauch |
| `stamina_regen_delay` | 0.6 s | Pause vor Regen |
| `sprint_min_stamina` | 15 | nach Erschöpfung wieder sprintbar |
| `crouch_speed_multiplier` | 0.45 | Ducktempo |

Effektive Geschwindigkeit: `_current_move_speed()` kombiniert Stats (`movement_multiplier()`, `sprint_multiplier()`), Crouch, Sprint, Wasser, Admin-NoClip.

### Fähigkeiten

- Laufen: `move_left` / `move_right` (A/D, Pfeile)
- Sprint: `sprint` (Shift), Stamina-Drain; bei 0 Ausdauer `_sprint_exhausted` bis 15 Stamina
- Ducken: `crouch` (C); Collider schrumpft **nur nach oben**, Unterkante bleibt auf der Fußlinie
- Aufstehen: `_has_standing_headroom()` gegen World-Layer 1
- Springen: Space/W, Jump-Cut, `jump_multiplier()` aus Stats
- Drop-through: Crouch+Jump auf Plattformen (Mask-Bit 6 kurz aus)
- Leitern: `_try_ladder()` über `BuildingPartSystem`
- Wasser/Lava: Child-Nodes ändern Gravity/Speed; tiefes Wasser blockiert Sprint
- Welt-Clamp: `world_generator.clamp_world_position`
- Bett: `use_bed()` / `leave_bed()`; Spawn wird gespeichert

Collider-Konstanten:

```
STAND_SIZE  = (20, 42), STAND_CENTER  = (0, -21)
CROUCH_SIZE = (20, 28), CROUCH_CENTER = (0, -14)
```

Hand-Pivot (vom Fuß-Ursprung des 40×56-Sprites):

```
TOOL_PIVOT_X = 10
TOOL_PIVOT_Y = -24
CROUCH_TOOL_PIVOT_Y = -16
JUMP_TOOL_PIVOT_Y = -28
FALL_TOOL_PIVOT_Y = -25
```

Blickrichtung: Input oder Maus beim Zielen (`_is_aiming()`). Deadzone `MOUSE_FACING_DEADZONE = 10`, damit der Sprite nicht bei Mini-Mausbewegungen flippt.

---

## 5. Stats-System

**Single Source of Truth:** `PlayerStats.sheet` vom Typ `StatSheet`. Keine verstreuten Player-Variablen für Kampfwerte.

### Formel

```
final = (base + Summe FLAT) × (1 + Summe PERCENT)
```

`StatModifier`: `stat`, `value`, `modifier_type` (FLAT / PERCENT), `source`, `source_kind` (EQUIPMENT, ACCESSORY, BUFF, …), optional `duration` / `remaining`.

### Alle StatIds (`stat_id.gd`)

| ID | Anzeigename | Default-Base (aus `StatSheet.apply_defaults()`) |
|---|---|---|
| MAX_HEALTH | Max. Leben | 100 |
| HEALTH_REGEN | Leben-Regeneration | 0 |
| MAX_STAMINA | Max. Ausdauer | 100 |
| STAMINA_REGEN | Ausdauer-Regeneration | 15 |
| MAX_ENERGY | Max. Energie | 100 |
| MOVEMENT_SPEED | Bewegungstempo | 1.0 |
| SPRINT_SPEED | Sprinttempo | 1.5 |
| JUMP_POWER | Sprungkraft | 1.0 |
| ARMOR | Rüstung | 0 |
| DAMAGE_MULTIPLIER | Schaden | 1.0 |
| ATTACK_SPEED | Angriffstempo | 1.0 |
| CRIT_CHANCE | Krit. Chance | 0.05 |
| CRIT_DAMAGE | Krit. Schaden | 1.5 |
| ARMOR_PENETRATION | Rüstungsdurchdringung | (siehe Sheet) |
| KNOCKBACK_MODIFIER | Rückstoß | |
| KNOCKBACK_RESISTANCE | Rückstoß-Resistenz | |
| MINING_SPEED | Abbaugeschwindigkeit | |
| WOODCUTTING_SPEED | Holzfäll-Geschwindigkeit | |
| HARVEST_AMOUNT | Erntemenge | |
| BUILDING_SPEED | Baugeschwindigkeit | |
| REPAIR_SPEED | Reparaturgeschwindigkeit | |
| FIRE_RESISTANCE | Feuer | |
| COLD_RESISTANCE | Kälte | |
| POISON_RESISTANCE | Gift | |
| BLEEDING_RESISTANCE | Bluten | |
| DARKNESS_RESISTANCE | Finsternis | |

### Vitalwerte

| Wert | Verbrauch | Regeneration | Gameplay |
|---|---|---|---|
| Health | Schaden | `HEALTH_REGEN` / s in `_process` | HUD, Soft-Respawn bei 0 |
| Stamina | Sprint | nach Delay über `stamina_regen_rate()` | verdrahtet |
| Energy | — | HUD + Save vorhanden | **nicht im Gameplay verbraucht** |

Equipment-Rebuild (`PlayerStats.rebuild_from_inventory`):

1. Alle Modifier mit `SourceKind.EQUIPMENT` und `ACCESSORY` entfernen.
2. Für jeden Equipment-Key (`head`, `chest`, `legs`, `accessory_1`, `accessory_2`) Item lesen.
3. `StatSheet.modifiers_from_item(item)` addieren.

`ItemData.defense` wird als **FLAT `StatId.ARMOR`** mitgelesen. Zusätzliche Boni über `ItemData.stat_modifiers[]`.

### Eingehender Schaden (`apply_incoming_damage`)

```
after_armor = incoming  falls ignore_armor
            = max(incoming - armor_defense, 0) sonst
final       = after_armor × (1 - resistance_for(damage_type))
```

Ausgehender Schaden: Item-Basis → `CombatResolver.apply_hit()` × `damage_multiplier()` → Crit (`crit_chance` / `crit_multiplier`) → Knockback × `knockback_modifier()`.

Player-Eingang: `take_damage()` / `apply_damage_event()` → Stats → `CombatTextSystem.present()`. Bei Darkness-DoT: Signal `fog_hurt` (aktuell **kein Subscriber** im Projekt).

### Tod

Kein Permadeath. Signal `depleted` → `_on_health_depleted()`: voll heilen, Stamina voll, teleport zu Bett oder World-Spawn (`resolve_respawn_position()`).

---

## 6. Inventar und Rüstung anlegen

### Slots

- 70 Item-Slots: **0–9 Hotbar**, **10–69 Beutel**
- 5 Equipment-Keys:

```
head        → ItemData.EquipmentSlot.HEAD
chest       → CHEST
legs        → LEGS
accessory_1 → ACCESSORY
accessory_2 → ACCESSORY
```

Anlegen läuft über `Inventory.transfer()` + `accepts()` (Typ-Check). Accessoires: erster freier Slot via `find_equipment_key()`.

Signale: `inventory_changed`, `selected_slot_changed`, `equipment_changed`.

Bei `equipment_changed`:

1. `Player._refresh_armor_visuals()`
2. `PlayerStats.rebuild_from_inventory()`

### Visuelles Anlegen (`player.gd`)

```
_refresh_armor_visuals():
  _apply_armor_item(LegArmorSprite,  inventory.get_equipment_item("legs"))
  _apply_armor_item(ChestArmorSprite, inventory.get_equipment_item("chest"))
  _apply_armor_item(HelmetSprite,     inventory.get_equipment_item("head"))
  _sync_armor_layers()

_apply_armor_item(sprite, item):
  wenn item == null oder item.armor_sprite_frames == null → sprite.visible = false
  sonst sprite.sprite_frames = item.armor_sprite_frames
       sprite.speed_scale = 0.0   # KEINE eigene Playback-Zeit
       sprite.visible = true

_sync_armor_layers():
  kopiert animation, frame, flip_h vom BaseSprite auf alle drei Overlay-Sprites
```

`speed_scale = 0.0` ist absichtlich: Rüstung darf nicht asynchron zum Körper laufen. Sync passiert jedes Physics-Frame nach `_update_animation()`.

Accessoires haben **kein** Overlay-Sprite, nur Stats.

### ItemData-Felder für Rüstung

- `equipment_slot`
- `defense` (int, wird ARMOR-FLAT)
- `armor_sprite_frames: SpriteFrames`
- optional `stat_modifiers[]`

Beispiel Holzhelm: `resources/items/equipment/wood_helmet.tres`  
`id = 120`, `equipment_slot = 1` (HEAD), `defense = 1`, Frames → `armor_helmet_frames.tres`.

Weitere Sets:

- Holz: `wood_{helmet,chestplate,leggings}.tres`
- 10 Metalle × 3 Slots unter `resources/items/equipment/metal/`  
  copper, tin, ferrite, aurel, cobalt, veyrite, cryonite, ignitium, voidium, astralith

Charakter-Vorschau im Inventar: `Player.compose_preview_texture()` compositet Base + Armor in eine Textur. `CharacterPage` zeigt Stats + Equipment-Slots.

Charaktererstellung: nur Name. Keine Haar-/Haut-/Kleidungsschichten (steht so in `character_creator_screen.gd`).

### Checkliste: neues Rüstungsitem

1. Sprites unter `assets/player/armor/` für **alle** Körper-Animationsnamen (siehe Abschnitt 7).
2. SpriteFrames-Resource (oder bestehende Slot-Frames wiederverwenden, wenn das Set die gleichen Overlays nutzt).
3. `ItemData`.tres: `equipment_slot`, `defense`, `armor_sprite_frames`, optional Modifier.
4. In `item_catalog.tres` registrieren.
5. Test: Item in Slot ziehen → Overlay sichtbar, Frame = Körper, Stats in CharacterPage aktualisiert.

---

## 7. Animationen

### 7.1 Körper (`AnimatedSprite2D`)

State-Machine in `_update_animation()`, Priorität von oben nach unten:

1. nicht am Boden → `jump` wenn `velocity.y < 0`, sonst `fall`
2. duckend → `crouch_walk` wenn `|vx| > 8`, sonst `crouch_idle`
3. Schwung aktiv (`_is_swinging()`) → `use_tool`
4. sprintend und bewegend → `run`
5. bewegend → `walk`
6. sonst → `idle`

Existierende Animationen in `player_frames.tres`:

| Name | Frames | Loop | Speed |
|---|---|---|---|
| `idle` | 1 (`player_idle.png`) | ja | 5 |
| `walk` | 2 (a/b) | ja | 8 |
| `run` | 2 (a/b) | ja | 11 |
| `crouch_idle` | 1 | ja | 5 |
| `crouch_walk` | 2 (a/b) | ja | 6 |
| `jump` | 1 | ja | 5 |
| `fall` | 1 | ja | 5 |
| `use_tool` | 1 (`player_use_tool.png`) | (siehe tres) | |

**Es gibt keine** eigenen Animationen für: Tod, Schwimmen, Leiter, Bett, Schaden-Hit-Flash, Bogen-Ziehen am Körper, Idle-Varianten, Haar, Gesicht.

Landen: `_update_landing()` spielt SFX ab `LANDING_MIN_SPEED = 140`. Schritte: `_on_sprite_frame_changed()` mit Volume-Unterschied Crouch vs Sprint.

### 7.2 Werkzeug / Waffe (`AnimationPlayer` in `player.tscn`)

Getriggert von `PlayerInteraction._play_attack_anim(name)`.

| Clip | Dauer | Zweck |
|---|---|---|
| `tool_swing` | 0.30 s | Werkzeug / Faust |
| `sword_swing` | 0.32 s | Schwert |
| `spear_thrust` | 0.42 s | Speer (Rotation + Position) |
| `bow_shot` | 0.45 s | Bogen |
| `lantern_burst` | 0.50 s | Laterne + CombatLight |
| `block_place` | 0.18 s | Block setzen |

`HeldItem`: solange der AnimationPlayer spielt, hat er Vorrang. Sonst setzt `_pose_for_current_state()` ToolArm-Position/Rotation anhand Körperanimation + Walk-Frame.

### 7.3 Hitbox-Timing

`ToolHitbox._process()` aktiviert Monitoring nur zwischen `hit_start` und `hit_end` des aktuellen Clips. Shapes grob:

| WeaponKind | Anim | Hitbox |
|---|---|---|
| NONE (Tool/Faust) | `tool_swing` | 24×26 |
| SWORD | `sword_swing` | 28×32 |
| SPEAR | `spear_thrust` | 42×10 |
| BOW | `bow_shot` + Projektil | keine Melee-Hitbox |
| LANTERN | `lantern_burst` | 26×26 |

Cooldown: `item.resolve_attack_cooldown() / attack_speed()`.

Bogen: RMB halten lädt, Loslassen schießt; Quick-Shot bei einmaligem LMB. Status: `PlayerInteraction.is_drawing_bow()`.

---

## 8. Kampf- und Interaktions-Pipeline

Input:

- LMB `use_item`: Mining, Nahkampf, Faust
- RMB `interact_secondary`: Platzieren, Bogen zielen, Treppen-Drag
- E `interact`: Welt-Objekte (z. B. Bett über `BuildingEntity`)
- Alt `auto_tool`: bestes Hotbar-Werkzeug für Zielblock
- Strg `block_autolock`: Targeting-Lock
- Tab `inventory`

Pipeline Nahkampf:

```
ToolHitbox._try_hit()
  → CombatResolver.find_damageable / resolve_damage / apply_hit
    → target.apply_damage_event() oder take_damage()
      → CombatTextSystem
```

Mining: `_handle_mining()`, `_break_block()`, Effizienz `_mining_efficiency()`, Progress-Bar am Highlight. Platzierung: Blöcke, Treppen, Samen, Pflanzen, Blueprints (`building_manager`).

---

## 9. Signale (Player-relevant)

| Signal | Quelle | Nutzung |
|---|---|---|
| `fog_hurt(amount)` | Player | emittiert, **kein Listener gefunden** |
| `health_changed` / `stamina_changed` / `energy_changed` | PlayerStats | HUD |
| `stats_changed` | PlayerStats | CharacterPage |
| `depleted` | PlayerStats | Soft-Respawn |
| `inventory_changed` / `equipment_changed` / `selected_slot_changed` | Inventory | UI, HeldItem, Armor-Visuals |
| `breath_changed` / `head_submerged` / `head_emerged` | WaterInteraction | BreathBar |

Save (`save_manager.gd`): Position, `character_name`, Stats `to_save_dict`, Bett-Spawn, Inventar, LookRecord.

---

## 10. Input-Map (Auszug `project.godot`)

| Action | Taste |
|---|---|
| move_left / move_right | A/D, Pfeile |
| jump | Space, W |
| crouch | C |
| sprint | Shift |
| use_item | LMB |
| interact_secondary | RMB |
| interact | E |
| inventory | Tab |
| zoom_in / zoom_out | + / - |
| block_autolock | Strg |
| auto_tool | Alt |
| world_map | M |
| toggle_minimap | N |
| hotbar_1 … hotbar_0 | 1–0 |

---

## 11. Bekannte Lücken / Erweiterungsregeln

- Energy ist vorbereitet (HUD, Save, Drain-API), **nicht** an Gameplay gebunden.
- Kein Death-State, keine Death-Animation, nur Soft-Respawn.
- Keine Körper-Animation für Schwimmen, Leiter, Bett, Hit-React, Bogen-Draw.
- `fog_hurt` ohne Subscriber.
- Charakterlook: nur Name, keine Layer für Haar/Haut/Kleidung.
- Weitere Waffenarten können an `ItemData.WeaponKind` (Kommentar: DAGGER, CROSSBOW) und `ToolKind` (SHOVEL) angehängt werden — dann neuen AnimationPlayer-Clip + Hitbox-Shape + Trigger in `PlayerInteraction` brauchen.

### Neuen Stat verdrahten

1. Enum in `StatId` + `display_name()` + `all_ids()`.
2. Default in `StatSheet.apply_defaults()`.
3. Accessor in `PlayerStats`.
4. Gameplay-Stelle nutzen.
5. `CharacterPage.refresh()` anzeigen.

### Neue Körper-Animation

1. PNG(s) unter `assets/player/`.
2. Clip in `player_frames.tres` **und** in allen drei Armor-SpriteFrames (gleiche Namen, gleiche Frame-Anzahl).
3. Priorität in `_update_animation()` einbauen.
4. Ggf. `HeldItem._pose_for_current_state()` für Handhaltung erweitern.

### Neue Waffenart

1. `WeaponKind` in `item_data.gd`.
2. Clip im AnimationPlayer von `player.tscn` (ToolArm, nicht Visuals).
3. Shape + hit_start/hit_end in `ToolHitbox`.
4. Start in `PlayerInteraction._start_*_attack`.
5. Cooldown/Tooltip in `ItemData`.

---

## 12. Wichtige Methoden-Kurzliste (`Player`)

`_ready`, `_physics_process`, `_clamp_to_world`, `play_sfx` / `play_weapon_swing` / `play_hit`, `get_combat_text_origin`, `take_damage`, `apply_damage_event`, `heal`, `_handle_inventory_toggle`, `_update_crouch`, `_apply_collider`, `_has_standing_headroom`, `_update_sprint`, `_current_move_speed`, `_handle_gravity`, `_handle_jump`, `_handle_movement`, `_update_facing`, `_mouse_facing`, `_is_aiming`, `is_auto_tool_held`, `_update_animation`, `_sync_armor_layers`, `_update_landing`, `_on_sprite_frame_changed`, `_try_ladder`, `_refresh_armor_visuals`, `_apply_armor_item`, `apply_appearance`, `use_bed`, `leave_bed`, `on_bed_removed`, `has_valid_bed_spawn`, `resolve_respawn_position`, `bed_to_save_dict` / `bed_from_save_dict`, `_on_health_depleted`, `apply_knockback`, `compose_preview_texture`.

`PlayerStats` (Auswahl): `rebuild_from_inventory`, `add_timed_modifier`, `get_final`, `combat_snapshot`, `set_health` / `set_stamina` / `set_energy`, `apply_incoming_damage`, `drain_stamina` / `restore_stamina`, `drain_energy` / `restore_energy`, `to_save_dict` / `from_save_dict`.

---

## 13. Prompt-Hinweis für eine Folge-KI

Arbeite nur im bestehenden Kompositionsmodell. Keine zweite Player-Basisklasse. Rüstung immer Overlay-Sync, nie eigene AnimationPlayer-Tracks auf den Armor-Sprites. Neue Körper-Clips müssen in Base **und** Helm/Brust/Beine existieren. Stats nur über `StatSheet` / `StatModifier`, nicht als lose Variablen auf `Player`. Energy nicht „heimlich“ als zweites Stamina missbrauchen, ohne HUD und Sheet mitzuziehen. Soft-Respawn nicht durch hartes `queue_free()` ersetzen, ohne Save/Bett zu berücksichtigen.
