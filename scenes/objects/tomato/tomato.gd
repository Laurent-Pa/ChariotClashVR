extends XRToolsPickable
class_name TomatoPickable

@export var damage: int = 50
@export var arm_delay: float = 0.2

var _armed: bool = false


func _ready() -> void:
	super._ready()
	body_entered.connect(_on_body_entered)
	_arm_after_delay()


func _arm_after_delay() -> void:
	if arm_delay <= 0.0:
		_armed = true
		return
	await get_tree().create_timer(arm_delay).timeout
	_armed = true


func _on_body_entered(body: Node) -> void:
	if not _armed:
		return
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	queue_free()
