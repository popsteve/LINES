extends Node2D

var line_path_points: Array = [] # Array of Vector2 global coordinates
var line_color_to_use: Color = Color.GRAY
var line_width_to_use: float = 5.0

func _draw():
	if line_path_points.size() >= 2:
		for i in range(line_path_points.size() - 1):
			# The points are stored as global coordinates.
			# This Node2D should ideally be at (0,0) in the gameplay_layer, 
			# or these points need to be converted to its local space if it's not.
			# Assuming it's at (0,0) relative to the layer it's on.
			draw_line(line_path_points[i], line_path_points[i+1], line_color_to_use, line_width_to_use) 