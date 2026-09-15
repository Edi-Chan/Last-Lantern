# Projektstruktur

Kleine, erweiterbare Grundlage für einen 2D-Sandbox-Prototypen.
Ordner bleiben leer, bis echte Dateien dazugehören. `.gitkeep` hält leere Ordner in Git sichtbar.

## Groessenreferenz

Diese Werte sind verbindlich fuer alle neuen Assets und Szenen.

| Was | Groesse |
| --- | --- |
| Welt-Tile (TileSet Region + Grafik) | 16 x 16 px |
| Player-Animationsframe | 40 x 56 px |
| Player-Gameplay-Collider stehend | 20 x 42 px |
| Player-Gameplay-Collider geduckt | 20 x 28 px |

Sichtbare Groesse ist nicht die Kollisionsgroesse. Haare, Arme und Werkzeug duerfen
ausserhalb des Colliders liegen; der Spriterahmen ist nie die Hitbox.

Der Player-Ursprung liegt auf Fusshoehe (y = 0 = Boden). Daraus folgt:
AnimatedSprite2D auf `y = -28` (Mitte des 56px-Frames), CollisionShape2D auf `y = -21`.
Bezogen auf die Sprite-Mitte sitzt der Collider damit auf `y = +7`.

Die Platzhaltergrafiken erzeugt `debug/gen_placeholder_art.py` reproduzierbar neu,
die Ausruestungs-Icons `debug/gen_equipment_icons.py`, die Soundeffekte `debug/gen_sfx.py`.

## Weltgenerierung

`scripts/world/world_generator.gd` haengt an der World-Wurzel und erzeugt die statische
Welt einmalig in `_ready`. Standard: 800 x 240 Tiles, Seed `12345` (0 = zufaellig).
Gearbeitet wird auf einem Byte-Array; erst am Ende wandert alles in den `TileMapLayer`.

Reihenfolge: Oberflaeche → Schichten → Sand → Hoehlen → Gestein → Erze → Rand/Bedrock
→ Cleanup → Spawn → Hoehleneingaenge → Baeume → Huetten.

Block-IDs 1-13 liegen in `resources/blocks/` und teilen sich `terrain_atlas.png`
(8 x 2 Kacheln). Leaves sind nicht solid. Bedrock (`hardness >= 100`) ist nicht abbaubar.

`Main` setzt den Player auf `WorldGenerator.player_spawn_position`.

## Kamera-Zoom

`Camera2D.zoom` ist in Godot ein Vergroesserungsfaktor: groesser heisst naeher dran.
`scripts/player/player_camera.gd` rechnet deshalb in `zoom_out` - "wie viel mehr Welt
ist sichtbar als bei 1:1" - und setzt `zoom = 1 / zoom_out`.

| zoom_out | Camera2D.zoom | sichtbare Welt |
| --- | --- | --- |
| 1 (Zoom In) | 1.0 | 640 x 360 px = 40 x 22.5 Tiles |
| 3 (Standard) | 0.333 | 1920 x 1080 px = 120 x 67.5 Tiles |
| 5 (Zoom Out) | 0.2 | 3200 x 1800 px = 200 x 112.5 Tiles |

Das Fenster skaliert den 640x360-Viewport um Faktor 2 (`stretch/scale_mode = integer`).
Pixelgenau ist die Darstellung nur, wenn `zoom * 2` ganzzahlig ist - also bei
`zoom_out = 1` und `zoom_out = 2`. Dazwischen werden Tiles herunterskaliert.

## Blickrichtung

`Player.facing_sign` ist die einzige Quelle der Blickrichtung (`+1` rechts, `-1` links).
Gespiegelt wird ausschliesslich ueber `AnimatedSprite2D.flip_h` und `ToolPivot.scale.x`.
Der `CharacterBody2D` und sein Collider werden nie negativ skaliert.

## Charakterwerte

`scripts/player/player_stats.gd` haengt als `Player/Stats` und ist die einzige Quelle
von Health, Stamina und Energy (je 100/100). Werte werden nur ueber `set_health`,
`set_stamina` und `set_energy` geschrieben - dort wird geklemmt und genau ein Signal
pro echter Aenderung gesendet. `Player.take_damage(amount)` ist der Einstieg fuer
Tool-Hitboxen und spaetere Gegner.

`scripts/ui/player_stats_hud.gd` (Szene `scenes/ui/player_stats_hud.tscn`, instanziert
als `HUD/PlayerStatsPanel`) haengt ausschliesslich an diesen Signalen und ruft nach dem
Verbinden `emit_all()`, damit die Startwerte sofort stehen. Kein Polling pro Frame.

Energy hat in dieser Phase bewusst keinen Verbraucher - nur Wert, Clamp und Balken.

## Bewegungszustaende

| Zustand | Geschwindigkeit | Animation | Schrittabstand |
| --- | --- | --- | --- |
| Gehen | 130 px/s | `walk` (8 FPS) | 0.30 s |
| Sprint (`sprint` = Shift) | 195 px/s (x1.5) | `run` (11 FPS) | 0.20 s |
| Ducken (`crouch` = Ctrl) | 58.5 px/s (x0.45) | `crouch_idle` / `crouch_walk` | 0.667 s, -6 dB |

Sprint verbraucht 20 Stamina/s, regeneriert 15/s nach 0.6 s Verzoegerung. Bei 0 Stamina
bricht der Sprint ab und ist erst ab `sprint_min_stamina` (15) wieder erlaubt.
Sprint und Ducken schliessen sich aus.

Der Schrittabstand wird gegen die Zielgeschwindigkeit gerechnet, nicht gegen
`velocity.x` - sonst setzt der erste Schritt beim Anlaufen einen mehrsekundigen Abstand.

Animationsprioritaet: `airborne` > `crouch` > Tool-Swing > `sprint` > `walk` > `idle`.

Beim Ducken schrumpft der Collider nur nach oben (Center `y = -21` -> `y = -14`), die
Unterkante bleibt auf der Fusslinie. Aufgestanden wird nur, wenn
`Player._has_standing_headroom()` den Stand-Collider per `intersect_shape` gegen
Physics-Layer 1 frei meldet. Die Testbox ist an allen Seiten 1 px kleiner, sonst melden
beruehrter Boden und anliegende Waende dauerhaft einen Treffer.

## ItemDrop-Physik

`ItemDrop` ist ein `CharacterBody2D` auf Layer 4 (Items) mit Maske 1 (World): er
kollidiert mit dem Terrain, blockiert den Player aber nicht. Aufgesammelt wird nur ueber
die `PickupArea` (Radius 26 px, Maske 2 = Player), getrennt vom 8x8-Weltcollider.

Startimpuls `(randf_range(-40, 40), -90)`, Gravity 1000, Luftreibung 40, Bodenreibung
400 und `stop_threshold` 3 px/s. Am Boden wird `velocity.y` auf 0 gesetzt;
`floor_snap_length = 4` haelt den Kontakt, ohne dass der Drop weiterrutscht.
`pickup_delay = 0.35 s` verhindert, dass ein abgebauter Block sofort verschwindet.

## HUD-Aufbau

`scenes/ui/hud.tscn` haelt die Zeichenreihenfolge (spaetere Kinder liegen oben):

```text
HUD (CanvasLayer)
├── PlayerStatsPanel   # links oben, 12 px Rand
├── Hotbar             # unten mittig
├── DebugLabel         # links unten, Schrift 8, mouse_filter = IGNORE
└── InventoryScreen    # mittig, liegt ueber allem
```

## Inventar-Referenzen

`Inventory.transfer(from, to)` nimmt Slot-Referenzen: ein `int` fuer Inventarslots 0-39
(davon 0-9 Hotbar) oder einen `String` fuer Equipment-Keys. Die Hotbar ist deshalb kein
Sonderfall - sie zeigt dieselben Slots. Equipment-Keys akzeptieren nur den passenden
`ItemData.EquipmentSlot`, siehe `Inventory.EQUIPMENT_TYPES`.

## Namensregeln

- Ordner und Dateien: `snake_case`
- Klassen mit `class_name`: `PascalCase`
- Szenen und Scripts zum selben Objekt teilen denselben Namen (`player.tscn` + `player.gd`)

## Hauptordner

| Ordner | Zweck |
| --- | --- |
| `assets/` | Grafiken und Animationen. Pixel-Art, nach Spielobjekt gruppiert. |
| `scenes/` | Godot-Szenen. Ein Objekt pro Szene, wenn es wiederverwendet wird. |
| `scripts/` | GDScript. Logik liegt hier, nicht neben jeder Szene. |
| `resources/` | Godot-`Resource`-Dateien (`.tres`) für Items, Waffen, Blöcke, Gegner. |
| `data/` | Rohe Tabellen später (JSON/CSV). Kein zweites Item-System. |
| `audio/` | Musik und Soundeffekte. `audio/sfx/` haelt die Spiel-Sounds. |
| `shaders/` | Optionale 2D-Shader. |
| `autoload/` | Nur wirklich globale Singletons. Standard: keiner. |
| `multiplayer/` | Späterer Netzwerkcode. Aktuell ungenutzt. |
| `debug/` | Entwicklerwerkzeuge. Aktuell die Generatoren fuer Platzhalter-Assets. |
| `addons/` | Editor-Plugins. Nicht für Spielcode verwenden. |

## Assets

```text
assets/
├── player/              # Spieler-Sprites
├── world/
│   ├── tiles/           # Block- und Terrain-Kacheln
│   └── backgrounds/     # Hintergründe
├── items/
│   ├── weapons/
│   ├── tools/
│   └── materials/
├── enemies/
└── ui/
```

Keine tieferen Kategorien, solange nur wenige Dateien existieren.

## Szenen

```text
scenes/
├── player/              # player.tscn
├── world/               # main.tscn und spätere Welt-Szenen
├── entities/            # Gegner und andere Wesen
├── items/               # Aufgehobene Gegenstände
├── ui/                  # hud.tscn, player_stats_hud.tscn, inventory_screen.tscn
└── test/                # Isolierte Testszenen
```

Die Startszene ist `scenes/world/main.tscn`.

## Scripts

```text
scripts/
├── player/              # Bewegung und spätere Spieler-Aktionen
├── world/               # Welt, Tiles, Generierung
├── entities/            # Gegner und andere Wesen
├── items/               # Item-Verhalten
├── inventory/           # Inventar und Hotbar
├── combat/              # Schaden und Leben, wenn nötig
├── ui/                  # UI-Logik
└── systems/             # Nur wirklich übergreifende Systeme
```

Kein Manager pro Feature. Ein Script entsteht erst, wenn es eine konkrete Aufgabe hat.

## Ressourcen

```text
resources/
├── items/               # z. B. wood.tres, stone.tres
├── weapons/             # z. B. wooden_sword.tres
├── blocks/              # z. B. dirt.tres
└── enemies/
```

Werte liegen in Resources. Verhalten bleibt im Code.

## Was bewusst fehlt

- Keine Autoloads
- Kein Multiplayer-Code
- Keine Chunk-Streaming-Architektur
- Keine Item-/Weapon-/Inventory-Manager
- Keine Crafting-, Quest- oder Biome-Systeme
