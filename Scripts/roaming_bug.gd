extends Node2D
## Roaming bug that attacks nearby ants and may drop food when defeated.

signal defeated(position: Vector2, food_dropped: int)

const BUG_TEXTURE: Texture2D = preload("res://Assets/Bugs.png")

@export var max_health: float = 24.0
@export var movement_speed: float = 38.0
@export var attack_damage: float = 5.0
@export var attack_interval: float = 1.2

var simulation: Variant
var health: float = 24.0
var _target := Vector2.INF
var _attack_timer := 0.0
var _wander_timer := 0.0
var _sprite: Sprite2D
var _path := PackedVector2Array()
var _path_index := 0
var _path_target := Vector2.INF


func _ready() -> void:
	health = max_health
	_sprite = Sprite2D.new()
	_sprite.texture = BUG_TEXTURE
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0.0, 0.0, 90.0, 96.0)
	_sprite.scale = Vector2(0.3, 0.3)
	add_child(_sprite)


func _process(delta: float) -> void:
	if simulation == null:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	var ant: Node2D = simulation.find_nearest_ant(global_position, 110.0)
	if ant != null:
		_target = ant.global_position
		if global_position.distance_to(ant.global_position) <= 20.0:
			if _attack_timer == 0.0:
				ant.take_damage(attack_damage)
				_attack_timer = attack_interval
			return
	else:
		_wander_timer -= delta
		if _target == Vector2.INF or _wander_timer <= 0.0 or global_position.distance_to(_target) < 8.0:
			_target = simulation.random_exploration_target()
			_wander_timer = 3.0
	if _target != Vector2.INF:
		_move_toward_target(delta)


func _move_toward_target(delta: float) -> void:
	if _path_target == Vector2.INF or _path_target.distance_to(_target) > 32.0:
		_path_target = _target
		_path = simulation.find_path(global_position, _target)
		_path_index = 0
	var step := movement_speed * delta
	while _path_index < _path.size():
		var waypoint := _path[_path_index]
		var offset := waypoint - global_position
		if offset.length() > step:
			global_position += offset.normalized() * step
			return
		global_position = waypoint
		step -= offset.length()
		_path_index += 1
	_path_target = Vector2.INF


func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	if health == 0.0:
		var food := 0
		var roll := randi_range(0, 99)
		if roll < 15:
			food = 3
		elif roll < 50:
			food = 1
		defeated.emit(global_position, food)
		queue_free()
