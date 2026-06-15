extends CharacterBody3D

enum State { IDLE, CHASE, ATTACK, HIT, DEAD }

@export var move_speed: float = 1.4
@export var chase_range: float = 8.0
@export var attack_range: float = 1.5
@export var rotation_speed: float = 5.0
@export var attack_cooldown: float = 1.5
@export var max_health: int = 100
@export var respawn_delay: float = 3.0
@export var attack_damage: int = 20
@export var avoid_distance: float = 1.2
@export var avoid_side_distance: float = 0.9
@export var avoid_collision_mask: int = 1

var current_state: State = State.IDLE
var health: int
var attack_timer: float = 0.0
var _spawn_position: Vector3
var _spawn_rotation: float
var _fall_tween: Tween
var player: Node3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: Node3D = $Model

signal bot_died
signal bot_hit(damage: int)


func _ready() -> void:
	_spawn_position = global_position
	_spawn_rotation = rotation.y
	health = max_health
	_find_player()
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = attack_range * 0.8
	nav_agent.max_speed = move_speed
	nav_agent.velocity_computed.connect(_on_nav_velocity_computed)


func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HIT:
			_process_hit(delta)
		State.DEAD:
			_process_dead(delta)


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]


func _process_idle(delta: float) -> void:
	if not player:
		_find_player()
		return

	var distance = _flat_distance_to_player()
	if distance < chase_range:
		current_state = State.CHASE
		nav_agent.target_position = player.global_position


func _process_chase(delta: float) -> void:
	if not player:
		current_state = State.IDLE
		return

	nav_agent.target_position = player.global_position

	var distance = _flat_distance_to_player()
	if distance <= attack_range:
		current_state = State.ATTACK
		attack_timer = attack_cooldown
		return

	if distance > chase_range * 1.5:
		current_state = State.IDLE
		return

	var next_pos = nav_agent.get_next_path_position()
	var direction = next_pos - global_position
	direction.y = 0.0
	if direction.length() < 0.01:
		# Fallback when no navigation path is available.
		direction = player.global_position - global_position
		direction.y = 0.0

	direction = direction.normalized()

	direction = _get_avoid_direction(direction)
	var desired_velocity = direction * move_speed
	desired_velocity.y = 0.0

	_smooth_rotate(direction, delta)
	nav_agent.set_velocity(desired_velocity)


func _process_attack(delta: float) -> void:
	if not player:
		current_state = State.IDLE
		return

	attack_timer -= delta

	var direction_to_player = (player.global_position - global_position).normalized()
	direction_to_player.y = 0.0
	_smooth_rotate(direction_to_player, delta)

	velocity = Vector3.ZERO
	move_and_slide()

	if attack_timer <= 0.0:
		attack_timer = attack_cooldown
		if player and player.has_method("take_damage"):
			player.call("take_damage", attack_damage)

	var distance = _flat_distance_to_player()
	if distance > attack_range * 1.2:
		current_state = State.CHASE


func _process_hit(delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()


func _process_dead(delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()


func _on_nav_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	velocity.y = 0.0
	move_and_slide()


func _get_avoid_direction(desired_direction: Vector3) -> Vector3:
	if desired_direction == Vector3.ZERO:
		return desired_direction

	var origin = global_position + Vector3(0, 0.9, 0)
	if _ray_hit(origin, desired_direction, avoid_distance):
		var left = Vector3(-desired_direction.z, 0.0, desired_direction.x).normalized()
		var right = Vector3(desired_direction.z, 0.0, -desired_direction.x).normalized()
		var left_clear = not _ray_hit(origin, left, avoid_side_distance)
		var right_clear = not _ray_hit(origin, right, avoid_side_distance)
		if left_clear and not right_clear:
			return left
		if right_clear and not left_clear:
			return right
		if left_clear and right_clear:
			return left

	return desired_direction


func _ray_hit(origin: Vector3, direction: Vector3, distance: float) -> bool:
	var space_state = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * distance,
		avoid_collision_mask
	)
	params.exclude = [self]
	return not space_state.intersect_ray(params).is_empty()


func _flat_distance_to_player() -> float:
	if not player:
		return INF
	var from_pos = global_position
	var to_pos = player.global_position
	from_pos.y = 0.0
	to_pos.y = 0.0
	return from_pos.distance_to(to_pos)


func _smooth_rotate(direction: Vector3, delta: float) -> void:
	if direction == Vector3.ZERO:
		return
	var target_rotation = atan2(direction.x, direction.z)
	var current_rotation = rotation.y
	rotation.y = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)


func take_damage(damage: int) -> void:
	if current_state == State.DEAD:
		return
	health -= damage
	bot_hit.emit(damage)
	if health <= 0:
		health = 0
		current_state = State.DEAD
		bot_died.emit()
		_start_respawn()
		return
	current_state = State.HIT
	await get_tree().create_timer(0.5).timeout
	if current_state == State.HIT:
		current_state = State.CHASE


func die() -> void:
	current_state = State.DEAD
	bot_died.emit()
	_start_respawn()


func _start_respawn() -> void:
	$CollisionShape3D.disabled = true
	_fall_tween = create_tween()
	_fall_tween.tween_property(model, "rotation_degrees:x", 90.0, 0.4).set_ease(Tween.EASE_IN)
	_fall_tween.tween_callback(model.set_visible.bind(false)).set_delay(respawn_delay)
	_fall_tween.tween_callback(respawn)


func respawn() -> void:
	health = max_health
	current_state = State.IDLE
	global_position = _spawn_position
	rotation.y = _spawn_rotation
	model.visible = true
	model.rotation_degrees.x = 0.0
	$CollisionShape3D.disabled = false
