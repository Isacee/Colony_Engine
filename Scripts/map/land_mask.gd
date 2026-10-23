extends RefCounted
## Grid of land/water flags. Anything outside the grid counts as water.

var size: Vector2i
var _cells := PackedByteArray()


func _init(grid_size: Vector2i) -> void:
	size = grid_size
	_cells.resize(size.x * size.y)


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func is_land(cell: Vector2i) -> bool:
	return contains(cell) and _cells[cell.y * size.x + cell.x] == 1


func set_land(cell: Vector2i, value: bool) -> void:
	if contains(cell):
		_cells[cell.y * size.x + cell.x] = 1 if value else 0


func land_neighbor_count(cell: Vector2i) -> int:
	var count := 0
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if is_land(cell + dir):
			count += 1
	return count
