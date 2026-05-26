extends CharacterBody3D

enum State { IDLE, CHASE, ATTACK, HIT, DEAD }

@export var move_speed: float = 3.0
@export var chase_range: float = 8.0
@export var attack_range: float = 1.5
@export var rotation_speed: float = 5.0
@export var attack_cooldown: float = 1.5
@export var max_health: int = 100
@export var attack_damage: int = 10

var current_state: State = State.IDLE
var health: int
var attack_timer: float = 0.0
var player: Node3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: Node3D = $Model

signal bot_died
signal bot_hit(damage: int)


func _ready() -> void:
	health = max_health
	_find_player()
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = attack_range * 0.8


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

	var distance = global_position.distance_to(player.global_position)
	if distance < chase_range:
		current_state = State.CHASE
		nav_agent.target_position = player.global_position


func _process_chase(delta: float) -> void:
	if not player:
		current_state = State.IDLE
		return

	nav_agent.target_position = player.global_position

	var distance = global_position.distance_to(player.global_position)
	if distance <= attack_range:
		current_state = State.ATTACK
		attack_timer = attack_cooldown
		return

	if distance > chase_range * 1.5:
		current_state = State.IDLE
		return

	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	direction.y = 0.0

	velocity = direction * move_speed
	velocity.y = 0.0

	_smooth_rotate(direction, delta)
	move_and_slide()


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

	var distance = global_position.distance_to(player.global_position)
	if distance > attack_range * 1.2:
		current_state = State.CHASE


func _process_hit(delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()


func _process_dead(delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()


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
		return
	current_state = State.HIT
	await get_tree().create_timer(0.5).timeout
	if current_state == State.HIT:
		current_state = State.CHASE


func die() -> void:
	current_state = State.DEAD
	bot_died.emit()
	queue_free()


func respawn() -> void:
	health = max_health
	current_state = State.IDLE
