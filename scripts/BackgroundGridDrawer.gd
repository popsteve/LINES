extends Node2D

# Reference to the main MapGrid node
var map_grid_node: Node2D 

func _draw():
	if not is_instance_valid(map_grid_node) or not is_instance_valid(map_grid_node.map_grid):
		return

	var mg = map_grid_node.map_grid # Shortcut to MapGrid class instance
	var hex_s = map_grid_node.hex_size
	var draw_off = map_grid_node.draw_offset
	
	var draw_radius = mg.map_radius + 1
	for q in range(-draw_radius, draw_radius + 1):
		for r in range(-draw_radius, draw_radius + 1):
			if mg.is_within_bounds(q, r):
				var center_pixel = mg.axial_to_cartesian(q, r, hex_s) + draw_off
				# Call _draw_hexagon from the map_grid_node
				map_grid_node._draw_hexagon(self, center_pixel, hex_s, Color(0.2, 0.2, 0.2, 1), Color(0.4, 0.4, 0.4), 1.0) 