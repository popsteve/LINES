extends Node2D

# Reference to the main MapGrid node
var map_grid_node: Node2D 

func _draw():
	if not is_instance_valid(map_grid_node) or not is_instance_valid(map_grid_node.map_grid):
		return

	var mg = map_grid_node.map_grid # Shortcut to MapGrid class instance
	var hex_s = map_grid_node.hex_size
	var draw_off = map_grid_node.draw_offset
	
	# Calculate range based on screen dimensions to ensure full coverage
	var viewport_size = map_grid_node.get_viewport_rect().size
	var margin = map_grid_node.screen_margin
	
	# Calculate how many hexes we need to cover the screen
	# Hex spacing: horizontal = sqrt(3) * hex_size, vertical = 1.5 * hex_size
	var horizontal_range = int((viewport_size.x + 2 * margin) / (sqrt(3.0) * hex_s)) + 2
	var vertical_range = int((viewport_size.y + 2 * margin) / (1.5 * hex_s)) + 2
	var draw_radius = max(horizontal_range, vertical_range)
	
	for q in range(-draw_radius, draw_radius + 1):
		for r in range(-draw_radius, draw_radius + 1):
			if mg.is_within_bounds(q, r):
				var center_pixel = mg.axial_to_cartesian(q, r, hex_s) + draw_off
				# Call _draw_hexagon from the map_grid_node
				map_grid_node._draw_hexagon(self, center_pixel, hex_s, Color(0.2, 0.2, 0.2, 1), Color(0.4, 0.4, 0.4), 1.0) 