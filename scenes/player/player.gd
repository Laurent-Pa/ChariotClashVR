extends XROrigin3D

signal health_changed(current: int, max_value: int)

@export var max_health: int = 100

var health: int


func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)


func take_damage(damage: int) -> void:
	health = max(health - damage, 0)
	health_changed.emit(health, max_health)


func get_health() -> int:
	return health


func get_max_health() -> int:
	return max_health
