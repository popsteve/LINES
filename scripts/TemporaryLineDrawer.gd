extends Node2D

# Reference to the main MapGrid node to access data like hex_size, draw_offset, map_grid methods
var map_grid_node: Node2D 

var current_path_stations: Array = [] # Array of GridStation data objects
var current_hover_station: Variant = null # GridStation data object or null
var current_mouse_position: Vector2 # Local to this node (gameplay_layer)
var is_drawing: bool = false

# Colors for drawing
var segment_color: Color = Color(1.0, 0.8, 0.2, 0.9) # Yellowish for drawn segments
var preview_to_station_color: Color = Color(1.0, 0.5, 0.0, 0.7) # Orange for line to valid hover station
var preview_to_mouse_color: Color = Color(1.0, 0.5, 0.0, 0.4) # Fainter orange for line to mouse
var line_width: float = 4.0

func _ready():
	# We need map_grid_node to be set by the parent (MapGrid.gd)
	pass

func start_drawing(path: Array, hover: Variant):
	is_drawing = true
	current_path_stations = path.duplicate() # Store copies of GridStation data
	current_hover_station = hover
	current_mouse_position = Vector2.ZERO # Initialize to prevent null reference in first _draw call
	queue_redraw()

func update_drawing(path: Array, hover: Variant, mouse_pos: Vector2):
	if not is_drawing: # Should only update if actively drawing
		start_drawing(path, hover) # Or just set is_drawing = true
	is_drawing = true # Ensure it is set
	current_path_stations = path.duplicate()
	current_hover_station = hover
	current_mouse_position = mouse_pos
	queue_redraw()

func clear_drawing():
	is_drawing = false
	current_path_stations.clear()
	current_hover_station = null
	queue_redraw()

func _draw():
	if not is_drawing or not is_instance_valid(map_grid_node):
		return

	var mg = map_grid_node.map_grid
	var hex_s = map_grid_node.hex_size
	var draw_off = map_grid_node.draw_offset

	# 1. Draw already defined segments in current_path_stations
	if current_path_stations.size() >= 2:
		for i in range(current_path_stations.size() - 1):
			var station1_data = current_path_stations[i]
			var station2_data = current_path_stations[i+1]
			
			var p1 = mg.axial_to_cartesian(station1_data.q, station1_data.r, hex_s) + draw_off
			var p2 = mg.axial_to_cartesian(station2_data.q, station2_data.r, hex_s) + draw_off
			
			# Convert to local coordinates for this Node2D if it's not at (0,0) in gameplay_layer
			# Assuming TemporaryLineDrawer is at (0,0) relative to gameplay_layer for simplicity for now.
			draw_line(p1, p2, segment_color, line_width)

	# 2. Draw line from last station in path to current hover/mouse position
	if current_path_stations.size() > 0:
		var last_station_data = current_path_stations.back()
		var start_pos_preview = mg.axial_to_cartesian(last_station_data.q, last_station_data.r, hex_s) + draw_off
		
		var end_pos_preview: Vector2
		var preview_color: Color
		
		if current_hover_station != null and current_hover_station != last_station_data:
			# Draw to a valid hovered station
			end_pos_preview = mg.axial_to_cartesian(current_hover_station.q, current_hover_station.r, hex_s) + draw_off
			preview_color = preview_to_station_color
		else:
			# Draw to current mouse position (already passed as local to gameplay_layer)
			# If this node (TemporaryLineDrawer) is not at (0,0) in gameplay_layer, 
			# current_mouse_position would need to be to_local(current_mouse_position_global)
			end_pos_preview = current_mouse_position
			preview_color = preview_to_mouse_color
			
		# Check if start_pos_preview and end_pos_preview are different to avoid drawing zero-length line
		if start_pos_preview.distance_squared_to(end_pos_preview) > 0.01: # Small epsilon
			draw_line(start_pos_preview, end_pos_preview, preview_color, line_width) 