extends Node2D

# Preload the MapGrid script to access its inner class definitions for type checking
const MapGridScript = preload("res://scripts/MapGrid.gd")

# Reference to the main MapGrid node to access data like hex_size, draw_offset, map_grid methods
var map_grid_node: Node2D 

var current_line_path_cartesian: Array = [] # Stores cartesian points for the temporary line
var temp_curve: Curve2D = null # Curve for temporary drawing
var is_drawing: bool = false
const HANDLE_TENSION = 0.25 # Match PermanentLineNode

# Color for drawing the temporary line
var line_color: Color = Color(1.0, 0.5, 0.0, 0.7) # Orange-ish preview
var line_width: float = 4.0

func _ready():
	if not is_instance_valid(map_grid_node):
		printerr("TemporaryLineDrawer: map_grid_node was not set in _ready().")

# This function will be called by MapGrid.gd to update the path
func update_line_path(cartesian_points: Array):
	if not is_instance_valid(map_grid_node):
		printerr("TemporaryLineDrawer: map_grid_node is not valid in update_line_path.")
		return
	current_line_path_cartesian = cartesian_points
	temp_curve = null # Clear previous curve

	if cartesian_points.size() < 2:
		if is_drawing:
			queue_redraw()
		return

	temp_curve = Curve2D.new()
	temp_curve.bake_interval = 5.0 # Match permanent line for consistency

	if cartesian_points.size() == 2:
		temp_curve.add_point(cartesian_points[0], Vector2.ZERO, Vector2.ZERO)
		temp_curve.add_point(cartesian_points[1], Vector2.ZERO, Vector2.ZERO)
	else:
		for i in range(cartesian_points.size()):
			var p_i = cartesian_points[i]
			var in_delta = Vector2.ZERO
			var out_delta = Vector2.ZERO

			if i == 0:
				var p_next = cartesian_points[i+1]
				out_delta = (p_next - p_i) * HANDLE_TENSION
			elif i == cartesian_points.size() - 1:
				# For the temporary line, the last point is the mouse cursor.
				# We want it to smoothly connect from the previous point.
				var p_prev = cartesian_points[i-1]
				in_delta = (p_prev - p_i) * HANDLE_TENSION 
			else:
				var p_prev = cartesian_points[i-1]
				var p_next = cartesian_points[i+1]
				var tangent = (p_next - p_prev).normalized()
				var dist_to_prev = p_i.distance_to(p_prev)
				var dist_to_next = p_i.distance_to(p_next)
				in_delta = -tangent * dist_to_prev * HANDLE_TENSION
				out_delta = tangent * dist_to_next * HANDLE_TENSION
			
			temp_curve.add_point(p_i, in_delta, out_delta)

	if is_drawing:
		queue_redraw()

func set_drawing_active(active: bool):
	is_drawing = active
	if not active:
		current_line_path_cartesian.clear()
		temp_curve = null
	queue_redraw()

func clear_drawing():
	set_drawing_active(false)

func _draw():
	if not is_drawing or not is_instance_valid(map_grid_node):
		return

	if temp_curve and temp_curve.get_point_count() >= 2:
		var tessellated_points = temp_curve.get_baked_points()
		if tessellated_points and tessellated_points.size() >= 2:
			draw_polyline(tessellated_points, line_color, line_width, true)
	elif current_line_path_cartesian.size() >= 2: # Fallback
		for i in range(current_line_path_cartesian.size() - 1):
			var point_a = current_line_path_cartesian[i]
			var point_b = current_line_path_cartesian[i+1]
			if point_a is Vector2 and point_b is Vector2 and point_a.distance_squared_to(point_b) > 0.01:
				draw_line(point_a, point_b, line_color, line_width, true)
