extends Node2D

var station_data # The GridStation data object (will be map_grid_node.GridStation type)
var hex_size: float = 32.0
# Direct reference to MapGrid node to check hover_station and access its enums/classes
var map_grid_node: Node2D 

func _draw():
	if not is_instance_valid(station_data) or not is_instance_valid(map_grid_node) or not map_grid_node.has_method("_draw_hexagon"):
		return

	var color = Color.DARK_GRAY # Default for NORMAL
	# Access enums via map_grid_node instance (assuming MapGrid.gd script is on map_grid_node)
	match station_data.type:
		map_grid_node.StationType.START:
			color = Color.GREEN
		map_grid_node.StationType.END:
			color = Color.RED
		map_grid_node.StationType.NORMAL:
			color = Color(0.7, 0.7, 0.7, 0.8)

	if is_instance_valid(map_grid_node.hover_station) and map_grid_node.hover_station == station_data:
		color = Color.YELLOW
	
	var local_center = Vector2.ZERO
	map_grid_node._draw_hexagon(self, local_center, hex_size * 0.9, color, Color(0.9,0.9,0.9), 1.5)

	if station_data.orientation != map_grid_node.Orientation.CENTER:
		var offset_axial = map_grid_node._orientation_to_axial_offset(station_data.orientation)
		var dir_cartesian_offset = map_grid_node.map_grid.axial_to_cartesian(offset_axial.x, offset_axial.y, hex_size) - \
		                         map_grid_node.map_grid.axial_to_cartesian(0,0,hex_size)
		dir_cartesian_offset = dir_cartesian_offset.normalized()
		draw_line(local_center, dir_cartesian_offset * hex_size * 0.6, Color.BLUE, 3.0) 