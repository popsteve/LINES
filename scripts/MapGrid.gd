extends Node2D

# Adapted Orientation for 6 directions + Center (as per Red Blob Games convention for pointy-top)
enum Orientation {
	E = 0,  # +q, +0r
	NE = 1, # +q, -r
	NW = 2, # +0q, -r
	W = 3,  # -q, +0r
	SW = 4, # -q, +r
	SE = 5, # +0q, +r
	CENTER = 6
}

enum StationType {
	NORMAL,
	START,
	END
}

class GridStation:
	var type: int = StationType.NORMAL
	var orientation: int = Orientation.CENTER
	var q: int = 0 # Axial coordinate q
	var r: int = 0 # Axial coordinate r
	
	func _init(station_type := StationType.NORMAL, station_orientation := Orientation.CENTER, q_coord := 0, r_coord := 0):
		type = station_type
		orientation = station_orientation
		q = q_coord
		r = r_coord
	
	func get_display_char() -> String:
		match type:
			StationType.START:
				return "S"
			StationType.END:
				return "E"
			_:
				return "O"

class MapGrid:
	# Map dimensions can be thought of differently for hex grids (e.g., radius or rectangular axial range)
	var map_radius: int = 10 # Example: Define map size by radius from center (0,0)
	var grid: Dictionary = {} # Using a Dictionary: Vector2i(q,r) -> GridStation
	var stations: Array = []
	
	func _init(radius: int = 10):
		map_radius = radius
		grid = {} # Initialize an empty dictionary

	# --- Hex Grid Coordinate Conversion (Pointy Top) ---
	# Based on https://www.redblobgames.com/grids/hexagons/
	
	func axial_to_cartesian(q: int, r: int, size: float) -> Vector2:
		var x = size * (sqrt(3.0) * q  +  sqrt(3.0)/2.0 * r)
		var y = size * (                               3.0/2.0 * r)
		return Vector2(x, y)

	func cartesian_to_axial(x: float, y: float, size: float) -> Vector2i:
		var q = (sqrt(3.0)/3.0 * x  -  1.0/3.0 * y) / size
		var r = (                             2.0/3.0 * y) / size
		return _axial_round(q, r)

	# Helper for rounding fractional axial coordinates to nearest hex integer coordinates
	func _axial_round(frac_q: float, frac_r: float) -> Vector2i:
		var frac_s = -frac_q - frac_r # Calculate third cube coordinate
		
		var q = round(frac_q)
		var r = round(frac_r)
		var s = round(frac_s)

		var q_diff = abs(q - frac_q)
		var r_diff = abs(r - frac_r)
		var s_diff = abs(s - frac_s)

		if q_diff > r_diff and q_diff > s_diff:
			q = -r - s
		elif r_diff > s_diff:
			r = -q - s
		# else: s = -q - r # s is already correct or fixed by the other two

		return Vector2i(int(q), int(r))
		
	# --- Grid Operations using Axial Coordinates ---

	func is_within_bounds(q: int, r: int) -> bool:
		# Rectangle-shaped hex grid
		# Define rectangle bounds
		var width = map_radius * 2  # Rectangle width (in hex units)
		var height = map_radius     # Rectangle height (in hex units)
		
		# Check if within rectangular bounds
		return q >= -width/2 and q <= width/2 and r >= -height and r <= height

	func is_valid_station_position(q: int, r: int) -> bool:
		if not is_within_bounds(q, r):
			return false
		# Check if the cell is empty
		return not grid.has(Vector2i(q, r))
	
	func add_station(station_type: int, orientation: int, q_coord: int, r_coord: int) -> bool:
		if not is_valid_station_position(q_coord, r_coord):
			print("Attempted to add station at invalid/occupied position (%d, %d)" % [q_coord, r_coord])
			return false
		
		var station = GridStation.new(station_type, orientation, q_coord, r_coord)
		grid[Vector2i(q_coord, r_coord)] = station
		stations.append(station)
		return true
	
	func get_station(q_coord: int, r_coord: int):
		var key = Vector2i(q_coord, r_coord)
		return grid.get(key, null) # Use .get() for safer dictionary access
	
	func get_random_empty_position() -> Vector2i:
		var max_attempts = 1000 # Allow more attempts for potentially sparse valid spots
		var attempts = 0
		
		while attempts < max_attempts:
			# Generate random q, r within a square range containing the hex radius
			# then check if it's truly within bounds and empty.
			var q = randi_range(-map_radius, map_radius)
			var r = randi_range(-map_radius, map_radius)
			
			if is_valid_station_position(q, r):
				return Vector2i(q, r)
			
			attempts += 1
		
		print("Could not find random empty position after %d attempts." % max_attempts)
		return Vector2i(-1000, -1000) # Return an unlikely coordinate as error indicator

	func get_grid_string() -> String:
		var grid_str = "Stations (Axial Coords q, r):\n"
		for station in stations:
			grid_str += "%s at (q=%d, r=%d) - Orientation: %d\n" % [station.get_display_char(), station.q, station.r, station.orientation]
		return grid_str

# --- Axial Directions (Pointy Top) ---
# Corresponds to Orientation enum order: E, NE, NW, W, SW, SE
var axial_direction_vectors = [
	Vector2i(1, 0),  # E
	Vector2i(1, -1), # NE
	Vector2i(0, -1), # NW
	Vector2i(-1, 0), # W
	Vector2i(-1, 1), # SW
	Vector2i(0, 1)   # SE
]

func _orientation_to_axial_offset(orientation: int) -> Vector2i:
	if orientation >= 0 and orientation < len(axial_direction_vectors):
		return axial_direction_vectors[orientation]
	else: # CENTER or invalid
		return Vector2i.ZERO


# --- Main Node ---
var map_grid = MapGrid.new(10) # Create a grid with radius 10
var hex_size = 32.0 # Size of hex (center to vertex distance) in pixels
var station_timer: Timer
var next_station_time: float

# Offset to center the grid drawing or adjust origin
var draw_offset = Vector2.ZERO

# --- Layers and Drawing Nodes ---
var background_layer: CanvasLayer
var gameplay_layer: CanvasLayer
var animation_layer: CanvasLayer

var background_grid_drawer: Node2D
var temporary_line_drawer: Node2D # Will have its own script to draw temporary lines
var permanent_lines_container: Node2D # Parent for finalized line nodes

# Dictionary to map GridStation data (by coords) to their VisualStation nodes
var grid_station_nodes: Dictionary = {}
var previously_hovered_station_node: Node2D = null

# Station scene - preload if you have one, otherwise we create basic Node2D for now
# var StationScene = preload("res://scenes/StationScene.tscn")

func _ready():
	# 1. Create CanvasLayers
	background_layer = CanvasLayer.new()
	background_layer.name = "BackgroundLayer"
	add_child(background_layer)
	background_layer.hide() # Hidden by default

	gameplay_layer = CanvasLayer.new()
	gameplay_layer.name = "GameplayLayer"
	add_child(gameplay_layer)

	animation_layer = CanvasLayer.new()
	animation_layer.name = "AnimationLayer"
	add_child(animation_layer)

	# 2. Setup BackgroundGridDrawer
	background_grid_drawer = Node2D.new()
	background_grid_drawer.name = "BackgroundGridDrawer"
	background_grid_drawer.script = load("res://scripts/BackgroundGridDrawer.gd")
	background_grid_drawer.map_grid_node = self # Pass reference
	background_layer.add_child(background_grid_drawer)

	# 3. Setup TemporaryLineDrawer (script to be created later)
	temporary_line_drawer = Node2D.new()
	temporary_line_drawer.name = "TemporaryLineDrawer"
	temporary_line_drawer.script = load("res://scripts/TemporaryLineDrawer.gd") # Assign the script
	temporary_line_drawer.map_grid_node = self # Pass reference
	gameplay_layer.add_child(temporary_line_drawer)

	# 4. Setup PermanentLinesContainer
	permanent_lines_container = Node2D.new()
	permanent_lines_container.name = "PermanentLinesContainer"
	gameplay_layer.add_child(permanent_lines_container)

	# Calculate offset to roughly center grid in viewport
	draw_offset = get_viewport_rect().size / 2.0
	
	# --- MODIFIED STATION SETUP ---
	# Setup Start and End Stations (as Nodes)
	_add_station_node(StationType.START, Orientation.E, 0, 0)
	
	var end_q = map_grid.map_radius
	var end_r = 0 
	var end_pos_found = false
	if map_grid.is_valid_station_position(end_q, end_r):
		_add_station_node(StationType.END, Orientation.W, end_q, end_r)
		end_pos_found = true
	else: 
		var random_end_pos = map_grid.get_random_empty_position()
		if random_end_pos != Vector2i(-1000, -1000):
			if map_grid.is_valid_station_position(random_end_pos.x, random_end_pos.y):
				_add_station_node(StationType.END, Orientation.W, random_end_pos.x, random_end_pos.y)
				end_pos_found = true
				
	if not end_pos_found:
		print("CRITICAL: Failed to place END station!")

	print("Map Grid Initialized with Layers.")
	# print(map_grid.get_grid_string()) # map_grid.stations now holds data, not nodes
	
	station_timer = Timer.new()
	station_timer.one_shot = true
	add_child(station_timer) 
	station_timer.timeout.connect(_on_station_timer_timeout)
	schedule_next_station()

	# Initial draw requests
	background_grid_drawer.queue_redraw()
	temporary_line_drawer.queue_redraw()

# Helper to add a station GridStation data AND create its Node2D representation
func _add_station_node(station_type: int, orientation: int, q_coord: int, r_coord: int) -> Node2D:
	if map_grid.add_station(station_type, orientation, q_coord, r_coord): # Adds to data grid
		var station_data = map_grid.get_station(q_coord, r_coord)
		
		var station_node = Node2D.new() 
		station_node.script = load("res://scripts/VisualStation.gd")
		station_node.name = "VisualStation_" + str(q_coord) + "_" + str(r_coord)
		
		# Pass necessary data to VisualStation script
		station_node.station_data = station_data
		station_node.hex_size = hex_size
		station_node.map_grid_node = self # Pass reference to this MapGrid instance
		
		# Position the VisualStation node globally
		station_node.position = map_grid.axial_to_cartesian(q_coord, r_coord, hex_size) + draw_offset
		
		gameplay_layer.add_child(station_node)
		grid_station_nodes[Vector2i(q_coord, r_coord)] = station_node # Store reference
		station_node.queue_redraw()
		return station_node
	return null

func schedule_next_station():
	next_station_time = randf_range(10.0, 30.0)
	print("Next station in %.1f seconds" % next_station_time)
	station_timer.start(next_station_time)

func _on_station_timer_timeout():
	add_random_station()
	schedule_next_station()

func add_random_station():
	var pos = map_grid.get_random_empty_position()
	if pos != Vector2i(-1000, -1000):
		var orientation_index = randi() % 6
		var orientation = orientation_index 
		
		# This now creates the station node and adds it to gameplay_layer
		if _add_station_node(StationType.NORMAL, orientation, pos.x, pos.y):
			print("Added new station node at axial (q=%d, r=%d)" % [pos.x, pos.y])
			# No direct queue_redraw() on MapGrid needed for stations anymore
	else:
		print("Could not add random station: No valid empty position found.")

func _process(delta):
	if has_node("NextStationLabel"): # Check if the node exists first
		if station_timer.is_stopped():
			$NextStationLabel.text = "Next station: -"
		else: 
			$NextStationLabel.text = "Next station in: %.1f s" % station_timer.time_left

# Drawing line variables
var drawing_line: bool = false
var line_start_station: GridStation = null
var current_line_points: Array = []
var hover_station: GridStation = null
var line_color: Color = Color(1.0, 0.8, 0.2, 0.8) # Yellow with some transparency

func _input(event):
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event) # This will now update TemporaryLineDrawer
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_left_button_down(event)
			else:
				_handle_left_button_up(event)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_handle_right_button_down(event)
				background_layer.show()
				background_grid_drawer.queue_redraw()
			else: # Right button released
				_handle_right_button_up(event) # Optional: if specific logic needed on release
				background_layer.hide()
				# No need to redraw background if hidden, but good practice if it could be partially transparent
				# background_grid_drawer.queue_redraw()

func _handle_mouse_motion(event: InputEventMouseMotion):
	var current_mouse_pos_viewport = event.position
	var mouse_axial_input_x = current_mouse_pos_viewport.x - draw_offset.x
	var mouse_axial_input_y = current_mouse_pos_viewport.y - draw_offset.y
	var mouse_axial = map_grid.cartesian_to_axial(mouse_axial_input_x, mouse_axial_input_y, hex_size)
	
	var new_hover_data = map_grid.get_station(mouse_axial.x, mouse_axial.y)

	if hover_station != new_hover_data:
		var old_hover_data = hover_station
		hover_station = new_hover_data

		# Use null check instead of is_instance_valid since GridStation is not an Object
		if old_hover_data != null:
			var old_node = grid_station_nodes.get(Vector2i(old_hover_data.q, old_hover_data.r))
			if is_instance_valid(old_node): # old_node IS a Node2D, so we keep is_instance_valid here
				old_node.queue_redraw()
		
		if hover_station != null:
			var new_node = grid_station_nodes.get(Vector2i(hover_station.q, hover_station.r))
			if is_instance_valid(new_node): # new_node IS a Node2D, so we keep is_instance_valid here
				new_node.queue_redraw()

	if drawing_line and line_start_station != null:
		# This logic for adding/removing points from current_line_points based on hover_station is correct
		if hover_station != null and hover_station != line_start_station:
			var previous_station_in_path = null
			if current_line_points.size() > 1:
				previous_station_in_path = current_line_points[current_line_points.size() - 2]
		
			if previous_station_in_path == hover_station:
				current_line_points.pop_back()
			else:
				if not current_line_points.has(hover_station):
					current_line_points.append(hover_station)
		
		# Update TemporaryLineDrawer with the current path, new hover_station, and current_mouse_pos_viewport
		if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("update_drawing"):
			temporary_line_drawer.update_drawing(current_line_points, hover_station, current_mouse_pos_viewport)

func _handle_left_button_down(event: InputEventMouseButton):
	var current_mouse_pos_viewport = event.position
	var mouse_axial_input_x = current_mouse_pos_viewport.x - draw_offset.x
	var mouse_axial_input_y = current_mouse_pos_viewport.y - draw_offset.y
	var mouse_axial = map_grid.cartesian_to_axial(mouse_axial_input_x, mouse_axial_input_y, hex_size)
	
	var clicked_station_data = map_grid.get_station(mouse_axial.x, mouse_axial.y)
	if clicked_station_data != null:
		drawing_line = true
		line_start_station = clicked_station_data
		current_line_points = [line_start_station]
		
		# Update TemporaryLineDrawer
		if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("start_drawing"):
			# Pass current_mouse_pos_viewport as the TemporaryLineDrawer expects coordinates
			# in the same space as station positions for its internal current_mouse_position
			temporary_line_drawer.start_drawing(current_line_points, hover_station) 
			# update_drawing will be called by mouse_motion if needed, start just needs path and hover

func _handle_left_button_up(event):
	if drawing_line and current_line_points.size() >= 2:
		print("Finalizing Line with %d points" % current_line_points.size())
		
		var perm_line_node = Node2D.new()
		perm_line_node.script = load("res://scripts/PermanentLineNode.gd")
		perm_line_node.name = "PermanentLine_" + str(permanent_lines_container.get_child_count())

		var points_for_line_node = []
		for station_data_point in current_line_points:
			points_for_line_node.append(map_grid.axial_to_cartesian(station_data_point.q, station_data_point.r, hex_size) + draw_offset)
		
		perm_line_node.line_path_points = points_for_line_node
		perm_line_node.line_color_to_use = line_color # line_color is a member of MapGrid.gd
		# perm_line_node.line_width_to_use = 5.0 # Or get from a variable
		
		permanent_lines_container.add_child(perm_line_node)
		perm_line_node.queue_redraw()

	drawing_line = false
	line_start_station = null
	current_line_points = []
	
	# Clear hover effect from the last station involved in drawing if any
	if hover_station != null: # Use null check instead of is_instance_valid
		var node = grid_station_nodes.get(Vector2i(hover_station.q, hover_station.r))
		if is_instance_valid(node): # node IS a Node2D, so we keep is_instance_valid here
			node.queue_redraw()
	hover_station = null

	if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("clear_drawing"):
		temporary_line_drawer.clear_drawing()

func _handle_right_button_down(event):
	drawing_line = false
	line_start_station = null
	current_line_points = []
	hover_station = null
	if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("clear_drawing"):
		temporary_line_drawer.clear_drawing()
	else:
		temporary_line_drawer.queue_redraw()
	# Background visibility handled in _input
	# Redraw stations to remove any hover highlights
	for child in gameplay_layer.get_children():
		if child.has_meta("is_station_node"): child.queue_redraw()

func _handle_right_button_up(event):
	pass # Background visibility handled in _input

# This _draw() function for MapGrid itself is now mostly empty,
# as drawing is delegated to child nodes on layers.
func _draw():
	pass

# Modified _draw_hexagon to take a drawer_node
func _draw_hexagon(drawer_node: CanvasItem, center: Vector2, size: float, fill_color: Color, border_color: Color, border_width: float):
	var points = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60 * i + 30 
		var angle_rad = deg_to_rad(angle_deg)
		# Draw relative to the drawer_node's local coordinate system if center is local to it
		# If center is global, then convert to drawer_node's local space: drawer_node.to_local(center)
		# Assuming 'center' is already in the global/MapGrid space, and drawer_node is a direct child of layer (or MapGrid)
		points.append(center + Vector2(size * cos(angle_rad), size * sin(angle_rad)))
	
	drawer_node.draw_polygon(points, PackedColorArray([fill_color]))
	if border_width > 0:
		var border_points = points.duplicate()
		border_points.append(points[0]) 
		drawer_node.draw_polyline(border_points, border_color, border_width, true)

# Remove old square grid helper function
# func _orientation_to_vector(orientation: int) -> Vector2: ...

# --- Input Handling for Line Drawing (To be added) --- # This comment is now outdated
# ...
