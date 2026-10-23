extends Camera2D
## Pans with WASD or the arrow keys, stays inside the map, and reports the visible area.

signal view_changed(center: Vector2, view_size: Vector2)

@export var pan_speed: float = 700.0

var _bounds := Rect2()
var _last_center := Vector2.INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds


func focus_on(world_position: Vector2) -> void:
	position = world_position
	_clamp_to_bounds()
	_last_center = Vector2.INF
	_report_view()


func _process(delta: float) -> void:
	if _is_typing():
		return
	var direction := Vector2(
		_axis(KEY_D, KEY_RIGHT) - _axis(KEY_A, KEY_LEFT),
		_axis(KEY_S, KEY_DOWN) - _axis(KEY_W, KEY_UP))
	if direction != Vector2.ZERO:
		position += direction.normalized() * pan_speed * delta / zoom.x
		_clamp_to_bounds()
	_report_view()


func _axis(key: Key, alternate_key: Key) -> float:
	return 1.0 if Input.is_key_pressed(key) or Input.is_key_pressed(alternate_key) else 0.0


func _is_typing() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is TextEdit or focused is LineEdit


func _view_size() -> Vector2:
	return get_viewport_rect().size / zoom


func _clamp_to_bounds() -> void:
	if _bounds.size == Vector2.ZERO:
		return
	var half := _view_size() * 0.5
	var low := _bounds.position + half
	var high := _bounds.end - half
	position = Vector2(
		clampf(position.x, low.x, maxf(low.x, high.x)),
		clampf(position.y, low.y, maxf(low.y, high.y)))


func _report_view() -> void:
	if position != _last_center:
		_last_center = position
		view_changed.emit(position, _view_size())
