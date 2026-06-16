extends XRToolsPickable
class_name TomatoPickable

@export var damage: int = 100
@export var arm_delay: float = 0.2
@export var despawn_time: float = 5.0

var _armed: bool = false
var _ground_timer: float = 0.0
var _was_on_floor: bool = false


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


func _physics_process(delta: float) -> void:
	if is_picked_up():
		_ground_timer = 0.0
		_was_on_floor = false
		return

	if _armed and not is_picked_up():
		var on_floor = get_contact_count() > 0
		if on_floor:
			if _was_on_floor:
				_ground_timer += delta
				if _ground_timer >= despawn_time:
					queue_free()
			else:
				_was_on_floor = true
				_ground_timer = 0.0
		else:
			_was_on_floor = false
			_ground_timer = 0.0


func _on_body_entered(body: Node) -> void:
	if not _armed:
		return
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
		queue_free()
