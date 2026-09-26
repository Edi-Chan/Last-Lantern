# Weapon Aiming System

Einheitliches Maus-Aiming für Last Lantern. Combat bleibt `ToolHitbox` + `CombatResolver`.

## Datenfluss

```
MOUSE
  → AIM DIRECTION (PlayerAim / Player)
  → PLAYER FACING (Sprite flip_h, alle Visual-Layer)
  → WEAPON CONTROLLER (HeldItem auf ToolPivot)
       → ActionType bestimmt WIE
       → ItemData bestimmt WAS
       → Visual + ToolHitbox
```

## Aim Direction

Quelle: `terraria/scripts/player/player_aim.gd`

- Origin: `Player.get_aim_origin()` = `ToolPivot` (Hand-/Torsohöhe).
- `aim_direction = (mouse - origin).normalized()`
- `aim_angle = aim_direction.angle()`
- Deadzone 10 px auf der X-Achse, damit der Blick über dem Kopf nicht flackert.

Berechnung einmal pro Physics-Frame in `Player._refresh_aim()`.

## Player Facing

Die Maus bestimmt links/rechts, nicht die Laufrichtung.

- `aim_direction.x > deadzone` → rechts
- `aim_direction.x < -deadzone` → links
- Innerhalb der Deadzone bleibt die letzte Seite

Body, Haar, Kleidung, Rüstung nutzen dieselbe `flip_h` über `PlayerVisualController.set_facing`.

Laufen nach rechts und Zielen nach links ist erlaubt (Backpedal). Die Bewegung wird nicht umgedreht.

## Kein negative Scale

`ToolPivot.scale` bleibt `(1, 1)`.

Früher: `ToolPivot.scale.x = facing_sign`. Zusammen mit Rotation wurde die Waffe auf der linken Seite kopfüber.

Jetzt:

- Player-Layer: `flip_h`
- Waffe: Welt-Rotation von `ToolArm` + `HeldItemSprite.flip_v` wenn `aim_direction.x < 0`

`flip_v` spiegelt nur oben/unten des Sprites. Die Spitze bleibt entlang `+X` des Arms, also zur Maus.

## Attack Lock

`Player.lock_attack_aim(action)` speichert:

- `is_attacking`
- `attack_direction`
- `attack_angle`
- `attack_action`

Melee (Swing, Chop, Mine, Thrust, Stab) nutzt während der Animation die gespeicherte Richtung.

Bogen bleibt live an der Maus, auch beim Draw.

Nach Clip-Ende: `clear_attack_aim()`.

## Action Types

Bestehendes `ItemData.ActionType` / `PlayerAnimationContract.ActionType`:

| Action | Idle | Attack |
|---|---|---|
| SWING | Rest zur Blickseite | Bogen um `attack_angle` |
| OVERHEAD | Rest | größerer Bogen |
| CHOP | Rest | Chop-Bogen |
| MINE | Rest | Mining-Bogen |
| THRUST | Live 360° | Lock, zurück, Stich, zurück |
| STAB | Live 360° | kürzerer Stich |
| BOW | Live 360° | Draw live, Release entlang Aim |
| LANTERN | Rest | kurzer Burst-Swing |

Neue Waffe: Texture + ItemData + WeaponKind/ToolKind + Stats. `resolve_action_type()` mappt automatisch.

## Grip Point

Rotation um `HeldItemSprite.offset` (`held_pivot_offset` / Default je Typ).

Nicht um die Texturmitte, sofern ein Grip gesetzt ist.

## Hitbox

`ToolHitbox` bleibt Source of Truth.

- Rechteck entlang `ToolArm +X`
- Speer: lang und schmal, Offset zur Spitze
- `already_hit_targets` pro Attack
- Timing: `hit_start` / `hit_end` aus `ACTION_SPECS`, skaliert mit `AnimationPlayer.speed_scale` = Attack Speed

## Attack Speed

`PlayerInteraction._attack_speed_scale()` setzt:

- Animationsdauer
- Hitbox-Fenster (über Anim-Zeit)
- Cooldown

## Debug

Im Debug-Build: **F7** schaltet `AdminManager.show_weapon_debug`.

- Grün: live Aim
- Rot: gelockte Attack-Richtung
- Punkt: Grip
- Punkt: ungefähre Spitze

## Wichtige Dateien

- `terraria/scripts/player/player_aim.gd`
- `terraria/scripts/player/held_item.gd`
- `terraria/scripts/player/player.gd`
- `terraria/scripts/player/player_interaction.gd`
- `terraria/scripts/player/tool_hitbox.gd`
- `terraria/scripts/items/item_data.gd`
- `terraria/scripts/player/player_animation_contract.gd`
