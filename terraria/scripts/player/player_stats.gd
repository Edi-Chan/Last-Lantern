class_name PlayerStats
extends Node

## Gehoert an: Player/Stats in res://scenes/player/player.tscn
##
## Einzige Quelle der Charakterwerte. Alle Aenderungen laufen ueber die
## set_*-Methoden, damit die Werte garantiert geklemmt sind und genau ein
## Signal pro echter Aenderung entsteht. Die HUD haengt an diesen Signalen und
## wird nicht pro Frame neu aufgebaut.

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal energy_changed(current: float, maximum: float)
## Fuer diese Phase nur ein Hinweis nach aussen, kein Death-/Respawn-System.
signal depleted

@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
## Dritter Charakterwert. Das Projekt hatte bisher keinen, daher Energy.
@export var max_energy: float = 100.0

var health: float = 100.0
var stamina: float = 100.0
var energy: float = 100.0
var armor_defense: int = 0

func _ready() -> void:
	add_to_group("player_stats")
	health = max_health
	stamina = max_stamina
	energy = max_energy


## Die HUD ruft das nach dem Verbinden auf, damit sie sofort 100/100 zeigt und
## nicht erst auf die erste Aenderung warten muss.
func emit_all() -> void:
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	energy_changed.emit(energy, max_energy)


func set_health(value: float) -> void:
	var clamped := clampf(value, 0.0, max_health)
	if is_equal_approx(clamped, health):
		return
	health = clamped
	health_changed.emit(health, max_health)
	if health <= 0.0:
		depleted.emit()


func set_stamina(value: float) -> void:
	var clamped := clampf(value, 0.0, max_stamina)
	if is_equal_approx(clamped, stamina):
		return
	stamina = clamped
	stamina_changed.emit(stamina, max_stamina)


func set_energy(value: float) -> void:
	var clamped := clampf(value, 0.0, max_energy)
	if is_equal_approx(clamped, energy):
		return
	energy = clamped
	energy_changed.emit(energy, max_energy)


func take_damage(amount: float, ignore_armor: bool = false) -> void:
	if amount <= 0.0:
		return
	var reduced := amount if ignore_armor else maxf(amount - float(armor_defense), 0.0)
	set_health(health - reduced)


func set_armor_defense(value: int) -> void:
	armor_defense = maxi(value, 0)


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	set_health(health + amount)


func drain_stamina(amount: float) -> void:
	set_stamina(stamina - amount)


func restore_stamina(amount: float) -> void:
	set_stamina(stamina + amount)


func drain_energy(amount: float) -> void:
	set_energy(energy - amount)


func restore_energy(amount: float) -> void:
	set_energy(energy + amount)
