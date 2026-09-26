# Weapon Asset Guide

Konvention für Waffen- und Werkzeug-Texturen in Last Lantern.

## Lokale Richtung

Neue Assets möglichst so zeichnen:

```
GRIFF ─────────────────► SPITZE / KOPF
```

Lokal entspricht das `Vector2.RIGHT`.

16×16 Pixel, Nearest-Neighbor, transparenter Hintergrund.

## Griffpunkt

Die Hand hält den Griff. In ItemData:

- `held_pivot_offset` — Sprite2D.offset, Griff auf den Arm-Ursprung
- `held_offset` — Extra-Position
- `held_rotation_degrees` — nur Art-Offset (z. B. 45° für Diagonalschwerter)
- `held_scale` — 1.0 = automatische Größe
- `held_texture` — optional, sonst Inventory-`icon`
- `held_flip_h` / `held_flip_v` — nur Spezialfälle

## Icon vs Held Texture

`icon` = Inventar / Hotbar.

`held_texture` darf später größer sein. Leer = dasselbe wie `icon`.

## Flip-Regeln (Runtime)

Nicht links/rechts-Texturen duplizieren.

Der Weapon Controller rotiert `ToolArm` in die Aim-Richtung und setzt `flip_v`, wenn die Maus links vom Spieler ist. Dadurch bleibt die Waffe nie kopfüber.

## Beispiele

### Schwert

Diagonale Klinge, Griff unten links, Spitze oben rechts. `held_rotation_degrees = 45`. Action: `SWING`. Folgt im Idle nicht der Maus.

### Speer

Horizontal, Griff links, Spitze rechts. `held_rotation_degrees = 0`. Action: `THRUST`. Idle: 360° zur Maus. Attack: Richtung locken, gerader Stich.

### Spitzhacke / Axt

Wie Schwert diagonal, Kopf oben. Actions: `MINE` / `CHOP`. Idle zur Blickseite, Schlag um die gespeicherte Aim-Richtung.

### Bogen

Wurfarm links, Sehne rechts (Sehne = vorne). Action: `BOW`. Folgt der Maus, auch beim Draw.

## Neue Items

Schwert: Texture + ItemData (`weapon_kind = SWORD`) + WeaponData-Stats.

Speer: dasselbe mit `weapon_kind = SPEAR`.

Spitzhacke: `tool_kind = PICKAXE` + ToolData.

Kein neues Player-Script.
