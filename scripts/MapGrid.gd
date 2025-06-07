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
	var parent_node: Node2D # Reference to the outer MapGrid Node2D
	
	func _init(radius: int = 10, parent: Node2D = null):
		map_radius = radius
		grid = {} # Initialize an empty dictionary
		parent_node = parent

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
		# Convert axial to cartesian to check against screen boundaries with margin
		# Ensure parent_node and its properties are valid before accessing
		if not is_instance_valid(parent_node) or not is_instance_valid(parent_node.get_viewport()):
			printerr("is_within_bounds: parent_node or viewport not valid.")
			return false # Or handle error appropriately

		var cartesian_pos = axial_to_cartesian(q, r, parent_node.hex_size) + parent_node.draw_offset
		var viewport_size = parent_node.get_viewport_rect().size
		var margin = parent_node.screen_margin

		# Only use screen boundary check - this ensures full coverage
		return cartesian_pos.x >= margin and cartesian_pos.x <= viewport_size.x - margin and \
			   cartesian_pos.y >= margin and cartesian_pos.y <= viewport_size.y - margin

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
		var min_distance = 3 # Minimum distance from existing stations
		
		while attempts < max_attempts:
			# Generate random q, r within a square range containing the hex radius
			# then check if it's truly within bounds and empty.
			var q = randi_range(-map_radius, map_radius)
			var r = randi_range(-map_radius, map_radius)
			
			if is_valid_station_position(q, r) and is_far_enough_from_stations(q, r, min_distance):
				return Vector2i(q, r)
			
			attempts += 1
		
		print("Could not find random empty position after %d attempts." % max_attempts)
		return Vector2i(-1000, -1000) # Return an unlikely coordinate as error indicator
		
	func is_far_enough_from_stations(q: int, r: int, min_distance: int) -> bool:
		# Check distance from all existing stations using hex distance formula
		for station in stations:
			var distance = hex_distance(q, r, station.q, station.r)
			if distance < min_distance:
				return false
		return true
	
	func hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
		# Hex distance formula: (|q1-q2| + |q1+r1-q2-r2| + |r1-r2|) / 2
		return (abs(q1 - q2) + abs(q1 + r1 - q2 - r2) + abs(r1 - r2)) / 2

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
var map_grid # Will be initialized in _ready
var hex_size = 32.0 # Size of hex (center to vertex distance) in pixels
var station_timer: Timer

# Offset to center the grid drawing or adjust origin
var draw_offset = Vector2.ZERO
var screen_margin = 50.0 # Margin from the screen edges

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

# --- Color Palette for Lines ---
var color_palette: Array[Color] = [
	Color.RED, 
	Color.GREEN, 
	Color.BLUE, 
	Color.YELLOW, 
	Color.PURPLE # Changed from MAGENTA for better distinction potentially
]
var current_palette_index: int = 0
var color_picker_ui: HBoxContainer

# Station scene - preload if you have one, otherwise we create basic Node2D for now
# var StationScene = preload("res://scenes/StationScene.tscn")

func _ready():
	# Initialize the inner MapGrid class, passing 'self' as the parent_node
	map_grid = MapGrid.new(10, self)

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
	
	# 5. Setup Color Picker UI
	color_picker_ui = HBoxContainer.new()
	color_picker_ui.name = "ColorPickerUI"
	
	# Configure HBoxContainer properties (e.g., spacing)
	color_picker_ui.add_theme_constant_override("separation", 5) # Spacing between dots

	for i in range(color_palette.size()):
		var color_dot = ColorRect.new()
		color_dot.name = "ColorDot_" + str(i)
		color_dot.color = color_palette[i]
		color_dot.custom_minimum_size = Vector2(30, 30) # Size of the dots
		color_dot.mouse_filter = Control.MOUSE_FILTER_STOP # Make it clickable
		color_dot.gui_input.connect(Callable(self, "_on_color_dot_gui_input").bind(i))
		color_picker_ui.add_child(color_dot)
	
	gameplay_layer.add_child(color_picker_ui) # Add to a layer that's visible

	# Position the color picker UI at the bottom center
	# Ensure this runs after nodes are in tree and sizes are calculated, so call it deferred or use notification.
	# For simplicity here, we'll try to position it directly. It might need adjustment if size isn't ready.
	call_deferred("_position_color_picker")
	_update_color_picker_selection_visuals()

	# Calculate offset to roughly center grid in viewport
	# draw_offset = get_viewport_rect().size / 2.0
	# Adjust draw_offset to account for margin
	var viewport_size = get_viewport_rect().size
	draw_offset = Vector2(screen_margin + (viewport_size.x - 2 * screen_margin) / 2.0, \
						  screen_margin + (viewport_size.y - 2 * screen_margin) / 2.0)

	# Set map_radius for station generation (bounds checking now uses screen boundaries)
	var effective_width = viewport_size.x - 2 * screen_margin
	var effective_height = viewport_size.y - 2 * screen_margin
	
	# Calculate a reasonable radius for station placement based on screen size
	var stations_per_width = int(effective_width / (sqrt(3.0) * hex_size * 2)) # Approximate stations across width
	var stations_per_height = int(effective_height / (1.5 * hex_size * 2)) # Approximate stations down height
	map_grid.map_radius = max(min(stations_per_width, stations_per_height), 15) # Minimum radius of 15 for good coverage
	
	print("Set map_radius: %d for station generation. Grid will cover full viewport %dx%d with margin %d" % [map_grid.map_radius, int(viewport_size.x), int(viewport_size.y), int(screen_margin)])


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
	
	# Setup station timer for automatic station generation (without countdown display)
	station_timer = Timer.new()
	station_timer.one_shot = true
	add_child(station_timer) 
	station_timer.timeout.connect(_on_station_timer_timeout)
	schedule_next_station()

	# 6. Setup Connection Counter UI
	var connection_label = Label.new()
	connection_label.name = "ConnectionLabel"
	connection_label.text = "Connections: 0"
	connection_label.add_theme_font_size_override("font_size", 18)
	connection_label.add_theme_color_override("font_color", Color.WHITE)
	connection_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	connection_label.add_theme_constant_override("shadow_offset_x", 1)
	connection_label.add_theme_constant_override("shadow_offset_y", 1)
	
	# Position in upper right corner
	connection_label.position = Vector2(viewport_size.x - 150, 20)
	connection_label.size = Vector2(130, 30)
	gameplay_layer.add_child(connection_label)

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
	var next_station_time = randf_range(10.0, 30.0)
	print("Next station in %.1f seconds" % next_station_time)
	station_timer.start(next_station_time)

const MAX_STATIONS = 10

func _on_station_timer_timeout():
	add_random_station()
	if map_grid.stations.size() < MAX_STATIONS:
		schedule_next_station()

func add_random_station():
	# Check if we've reached the maximum number of stations (including START and END)
	if map_grid.stations.size() >= MAX_STATIONS:
		print("Maximum number of stations (%d) reached. No more stations will be added." % MAX_STATIONS)
		return
	
	var pos = map_grid.get_random_empty_position()
	if pos != Vector2i(-1000, -1000):
		var orientation_index = randi() % 6
		var orientation = orientation_index 
		
		# This now creates the station node and adds it to gameplay_layer
		if _add_station_node(StationType.NORMAL, orientation, pos.x, pos.y):
			print("Added new station node at axial (q=%d, r=%d). Total stations: %d/%d" % [pos.x, pos.y, map_grid.stations.size(), MAX_STATIONS])
			# No direct queue_redraw() on MapGrid needed for stations anymore
	else:
		print("Could not add random station: No valid empty position found.")

# Drawing line variables
var is_drawing_path: bool = false
var path_origin_station_data: GridStation = null
var current_path_axial_hexes: Array = [] # Stores Vector2i axial coordinates of the current path
var last_added_axial_hex: Vector2i = Vector2i(-10000,-10000) # Tracks the last hex added to the path to avoid duplicates
var hover_station: GridStation = null # Stores the GridStation data if mouse is hovering over one
var line_color: Color = Color(1.0, 0.8, 0.2, 0.8) # Yellow with some transparency

var extending_line_info: Dictionary = {"line_node": null, "extending_from_end": true} # To track line extension

# State for sequential deletion tracking
var last_hovered_axial_for_drag_delete: Vector2i = Vector2i(-10000, -10000)

# Circuit tracking
var connection_count: int = 0

func _convert_axial_path_to_cartesian(axial_path: Array) -> Array:
	var cartesian_points = []
	if axial_path.is_empty():
		return cartesian_points
	for axial_coord in axial_path:
		cartesian_points.append(map_grid.axial_to_cartesian(axial_coord.x, axial_coord.y, hex_size) + draw_offset)
	return cartesian_points

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

	# Handle station hover highlighting (independent of line drawing)
	if hover_station != new_hover_data:
		var old_hover_data = hover_station
		hover_station = new_hover_data

		if old_hover_data != null:
			var old_node = grid_station_nodes.get(Vector2i(old_hover_data.q, old_hover_data.r))
			if is_instance_valid(old_node):
				old_node.queue_redraw()
		
		if hover_station != null:
			var new_node = grid_station_nodes.get(Vector2i(hover_station.q, hover_station.r))
			if is_instance_valid(new_node):
				new_node.queue_redraw()

	# Handle path drawing if left button is down
	if is_drawing_path and path_origin_station_data != null:
		# Check if the mouse has moved to a new hex relevant for path drawing
		if mouse_axial != last_added_axial_hex:
			var path_changed = false
			# Check for backtracking: if the new axial is the second to last point, remove the last one
			if current_path_axial_hexes.size() >= 2 and mouse_axial == current_path_axial_hexes[current_path_axial_hexes.size() - 2]:
				current_path_axial_hexes.pop_back()
				path_changed = true
				# Update last_added_axial_hex to the new last element, or origin if path becomes too short
				if current_path_axial_hexes.size() > 0:
					last_added_axial_hex = current_path_axial_hexes.back()
				else: # Should not happen if origin is always [0]
					last_added_axial_hex = Vector2i(path_origin_station_data.q, path_origin_station_data.r) 

			# Add new hex if it's not already the last one in the path (to prevent duplicates from other logic)
			elif current_path_axial_hexes.is_empty() or mouse_axial != current_path_axial_hexes.back():
				# Further check: do not allow adding a hex if it creates an immediate self-loop 
				# (e.g., A -> B -> A by moving to B then immediately back to A if A isn't the start)
				# This is partially handled by the pop_back above. This `elif` handles forward additions.
				# We also want to avoid adding a point if it's already anywhere in the path *except* if it's the starting point
				# and we are about to close a loop (which is not yet supported for line drawing here).
				# For now, only add if it's genuinely a new progression or a valid backtrack handled above.
				if not current_path_axial_hexes.has(mouse_axial):
					current_path_axial_hexes.append(mouse_axial)
					last_added_axial_hex = mouse_axial
					path_changed = true
				# If mouse_axial IS in current_path_axial_hexes but not as backtrack, it's a loop attempt or re-crossing.
				# Current logic will prevent adding it, stopping the line from complex self-intersections.

			# Only update drawer if the path actually changed or if it's the initial drag after click
			if path_changed or current_path_axial_hexes.size() <= 2: # Update for very short paths too
				if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("update_line_path"):
					var path_to_draw_axial = current_path_axial_hexes.duplicate()
					# Always ensure the visual line extends to the current mouse position for feedback
					if path_to_draw_axial.is_empty() or path_to_draw_axial.back() != mouse_axial:
						path_to_draw_axial.append(mouse_axial)
					
					var cartesian_path_points = _convert_axial_path_to_cartesian(path_to_draw_axial)
					temporary_line_drawer.update_line_path(cartesian_path_points)
		else: # mouse_axial == last_added_axial_hex, but path might need to extend to current mouse for visual
			if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("update_line_path"):
				var path_to_draw_axial = current_path_axial_hexes.duplicate()
				if path_to_draw_axial.is_empty() or path_to_draw_axial.back() != mouse_axial:
					path_to_draw_axial.append(mouse_axial)
				var cartesian_path_points = _convert_axial_path_to_cartesian(path_to_draw_axial)
				temporary_line_drawer.update_line_path(cartesian_path_points)

	# Handle sequential drag-deletion when right button is held down
	if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		var current_mouse_axial = map_grid.cartesian_to_axial(current_mouse_pos_viewport.x - draw_offset.x, current_mouse_pos_viewport.y - draw_offset.y, hex_size)
		
		# Only process if mouse has moved to a new hex grid position
		if current_mouse_axial != last_hovered_axial_for_drag_delete:
			last_hovered_axial_for_drag_delete = current_mouse_axial
			_process_sequential_deletion_at_position(current_mouse_axial)

func _handle_left_button_down(event: InputEventMouseButton):
	# Show hex grid when left button is pressed (same as right button behavior)
	background_layer.show()
	background_grid_drawer.queue_redraw()
	
	var current_mouse_pos_viewport = event.position
	var mouse_axial_input_x = current_mouse_pos_viewport.x - draw_offset.x
	var mouse_axial_input_y = current_mouse_pos_viewport.y - draw_offset.y
	var mouse_axial = map_grid.cartesian_to_axial(mouse_axial_input_x, mouse_axial_input_y, hex_size)
	
	var clicked_station_data = map_grid.get_station(mouse_axial.x, mouse_axial.y)
	var clicked_on_line_endpoint = false # Flag to indicate if we clicked on a line endpoint
	
	# Reset extending_line_info for each new click, unless we determine we are extending.
	extending_line_info = {"line_node": null, "extending_from_end": true}

	if clicked_station_data != null:
		# Clicked on a station, check if it's an endpoint of an existing permanent line
		var clicked_station_axial = Vector2i(clicked_station_data.q, clicked_station_data.r)
		for line_node_child in permanent_lines_container.get_children():
			if line_node_child is Node2D and line_node_child.has_method("set_path_points"): # Check if it's a PermanentLineNode
				var perm_line_node = line_node_child
				if perm_line_node.axial_points.is_empty():
					continue
				
				var first_axial = perm_line_node.axial_points.front()
				var last_axial = perm_line_node.axial_points.back()
				
				if clicked_station_axial == first_axial:
					extending_line_info["line_node"] = perm_line_node
					extending_line_info["extending_from_end"] = false # Extending from the start
					print("Extending existing line from its START (via station click): ", perm_line_node.name)
					clicked_on_line_endpoint = true # Station is also a line endpoint
					break
				elif clicked_station_axial == last_axial:
					extending_line_info["line_node"] = perm_line_node
					extending_line_info["extending_from_end"] = true # Extending from the end
					print("Extending existing line from its END (via station click): ", perm_line_node.name)
					clicked_on_line_endpoint = true # Station is also a line endpoint
					break
		
		# If we clicked a station (and potentially an endpoint), proceed to start drawing
		is_drawing_path = true
		path_origin_station_data = clicked_station_data # This is the GridStation data
		current_path_axial_hexes.clear()
		current_path_axial_hexes.append(Vector2i(path_origin_station_data.q, path_origin_station_data.r))
		last_added_axial_hex = Vector2i(path_origin_station_data.q, path_origin_station_data.r)
		
		if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("set_drawing_active"):
			temporary_line_drawer.set_drawing_active(true)

		var initial_axial_path = [Vector2i(path_origin_station_data.q, path_origin_station_data.r), mouse_axial]
		if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("update_line_path"):
			var cartesian_path_points = _convert_axial_path_to_cartesian(initial_axial_path)
			temporary_line_drawer.update_line_path(cartesian_path_points)

	else: # Clicked on empty space OR potentially a line endpoint that is NOT a station
		for line_node_child in permanent_lines_container.get_children():
			if line_node_child is Node2D and line_node_child.has_method("set_path_points"):
				var perm_line_node = line_node_child
				if perm_line_node.axial_points.is_empty():
					continue

				var first_axial = perm_line_node.axial_points.front()
				var last_axial = perm_line_node.axial_points.back()

				var start_point_matches = (mouse_axial == first_axial)
				var end_point_matches = (mouse_axial == last_axial)

				if start_point_matches or end_point_matches:
					print("Clicked on a line endpoint directly.")
					is_drawing_path = true
					# Create a temporary GridStation data for the line endpoint
					# This helps keep the rest of the drawing logic consistent
					# It won't be added to the main grid.stations or have a visual node unless we want it to.
					path_origin_station_data = GridStation.new(StationType.NORMAL, Orientation.CENTER, mouse_axial.x, mouse_axial.y)
					
					extending_line_info["line_node"] = perm_line_node
					extending_line_info["extending_from_end"] = end_point_matches # True if extending from end, false if from start
					
					if end_point_matches:
						print("Starting new line segment from END of: ", perm_line_node.name)
					else:
						print("Starting new line segment from START of: ", perm_line_node.name)

					current_path_axial_hexes.clear()
					current_path_axial_hexes.append(mouse_axial) # Start path with the clicked endpoint
					last_added_axial_hex = mouse_axial
					
					clicked_on_line_endpoint = true # Mark that we started from a line endpoint

					if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("set_drawing_active"):
						temporary_line_drawer.set_drawing_active(true)
					
					# For initial draw, just the point itself or point to mouse immediately?
					# Let's use point to mouse for immediate feedback.
					var initial_axial_path_endpoint = [mouse_axial, mouse_axial] # Start and end at mouse for now, motion will update
					if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("update_line_path"):
						var cartesian_path_points = _convert_axial_path_to_cartesian(initial_axial_path_endpoint)
						temporary_line_drawer.update_line_path(cartesian_path_points)
					break # Found a line endpoint to start drawing from

		if not clicked_on_line_endpoint and not clicked_station_data: # Clicked on truly empty space
			# Check if we clicked on a line body (not endpoint) to change its color
			var line_clicked_for_color_change = _check_line_click_for_color_change(current_mouse_pos_viewport)
			if line_clicked_for_color_change:
				return # Color change handled, don't start drawing
				
			if is_drawing_path: # Should not happen if logic is correct, but as a safeguard
				is_drawing_path = false
				path_origin_station_data = null
				current_path_axial_hexes.clear()
				last_added_axial_hex = Vector2i(-10000,-10000)
				if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("clear_drawing"):
					temporary_line_drawer.clear_drawing()

func _handle_left_button_up(_event: InputEventMouseButton):
	if is_drawing_path and path_origin_station_data != null and current_path_axial_hexes.size() >= 2:
		print("Finalizing Line Path with %d points" % current_path_axial_hexes.size())

		# The first point in current_path_axial_hexes is the origin station of this new segment.
		# If extending, this origin station is already the end/start of the existing line.
		# So, we should use points from current_path_axial_hexes starting from the *second* element if extending.
		var new_segment_axial_points = current_path_axial_hexes.duplicate()
		if extending_line_info["line_node"] != null and new_segment_axial_points.size() > 0:
			# Check if the first point of the new segment is indeed the same as the connection point
			# This is a safeguard. The actual connection logic will combine lists.
			# For now, let's assume new_segment_axial_points contains the new part including the connection point.
			pass # No special pop here, combine logic will handle it.

		if extending_line_info["line_node"] != null:
			var line_to_extend = extending_line_info["line_node"]
			var existing_axial_points = line_to_extend.axial_points.duplicate()
			var combined_axial_points = []

			if extending_line_info["extending_from_end"]:
				# Append new segment (minus its first point, which is the old end)
				combined_axial_points = existing_axial_points
				if new_segment_axial_points.size() > 1:
					for i in range(1, new_segment_axial_points.size()):
						combined_axial_points.append(new_segment_axial_points[i])
				print("Extended line (from end) with %d new axial points. Total: %d" % [new_segment_axial_points.size()-1, combined_axial_points.size()])
			else: # Extending from the start
				# Prepend new segment (reversed, and minus its first point, which is the old start)
				var reversed_new_segment = []
				if new_segment_axial_points.size() > 1:
					for i in range(new_segment_axial_points.size() - 1, 0, -1): # Iterate from second-to-last down to second
						reversed_new_segment.append(new_segment_axial_points[i])
				combined_axial_points = reversed_new_segment + existing_axial_points
				print("Extended line (from start) with %d new axial points. Total: %d" % [new_segment_axial_points.size()-1, combined_axial_points.size()])

			if combined_axial_points.size() >= 2:
				var new_cartesian_points = _convert_axial_path_to_cartesian(combined_axial_points)
				line_to_extend.set_path_points(new_cartesian_points, combined_axial_points)
				line_to_extend.queue_redraw() # Ensure the updated line redraws
				
				# Check for new connections created by extending this line
				_check_for_connections(combined_axial_points)
			else:
				print("WARN: Extended line resulted in less than 2 points. Not updating.")
		else:
			# Create a new PermanentLineNode
			var perm_line_node = Node2D.new()
			perm_line_node.script = load("res://scripts/PermanentLineNode.gd")
			perm_line_node.name = "PermanentLine_" + str(permanent_lines_container.get_child_count())

			var cartesian_points_for_line_node = _convert_axial_path_to_cartesian(new_segment_axial_points) # Use all points for new line
			
			perm_line_node.set_path_points(cartesian_points_for_line_node, new_segment_axial_points)
			perm_line_node.line_color_to_use = color_palette[current_palette_index] # Use selected color
			
			permanent_lines_container.add_child(perm_line_node)
			perm_line_node.queue_redraw()
			
			# Check for new connections created by this line
			_check_for_connections(new_segment_axial_points)
	else:
		if is_drawing_path: # Path was too short or something went wrong
			print("Line drawing cancelled or path too short.")

	# Reset drawing state
	is_drawing_path = false
	path_origin_station_data = null
	current_path_axial_hexes.clear()
	last_added_axial_hex = Vector2i(-10000,-10000)
	
	# Hide hex grid when left button is released
	background_layer.hide()
	
	if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("clear_drawing"):
		temporary_line_drawer.clear_drawing()

func _handle_right_button_down(event: InputEventMouseButton):
	# First, check if we are cancelling a line drawing operation
	if is_drawing_path:
		is_drawing_path = false
		path_origin_station_data = null
		current_path_axial_hexes.clear()
		last_added_axial_hex = Vector2i(-10000,-10000)
		if is_instance_valid(temporary_line_drawer) and temporary_line_drawer.has_method("clear_drawing"):
			temporary_line_drawer.clear_drawing()
		print("Line drawing cancelled by right-click.")
		return # Successfully cancelled drawing, don't proceed to delete or show background

	var mouse_viewport_pos: Vector2 = event.position
	# Convert mouse position to axial grid coordinates
	var mouse_axial_input_x = mouse_viewport_pos.x - draw_offset.x
	var mouse_axial_input_y = mouse_viewport_pos.y - draw_offset.y
	var clicked_axial_coord = map_grid.cartesian_to_axial(mouse_axial_input_x, mouse_axial_input_y, hex_size)
	
	var line_action_taken = false
	var line_to_redraw = null # Store the line that was modified to redraw it once

	print("Right-clicked on hex grid position: (%d, %d)" % [clicked_axial_coord.x, clicked_axial_coord.y])

	var children_to_iterate = permanent_lines_container.get_children() # Iterate over a copy
	for line_node_child in children_to_iterate:
		if not (line_node_child is Node2D and line_node_child.has_method("set_path_points") and line_node_child.has_method("_draw")) :
			continue
		
		var perm_line_node = line_node_child
		if not is_instance_valid(perm_line_node) or perm_line_node.get("axial_points") == null:
			continue

		var current_axial_points = perm_line_node.axial_points
		
		if current_axial_points.size() < 2:
			continue

		# Check if the clicked grid position matches any point in this line
		var clicked_point_index = -1
		for i in range(current_axial_points.size()):
			if current_axial_points[i] == clicked_axial_coord:
				clicked_point_index = i
				break
		
		if clicked_point_index >= 0:
			print("Found line %s passing through grid position (%d, %d) at index %d" % [perm_line_node.name, clicked_axial_coord.x, clicked_axial_coord.y, clicked_point_index])
			line_to_redraw = perm_line_node

			if current_axial_points.size() == 2: # Line only has 2 points
				permanent_lines_container.remove_child(perm_line_node)
				perm_line_node.queue_free()
				print("Deleted entire line (was 2 points): ", perm_line_node.name)
				line_to_redraw = null # It's gone
			elif clicked_point_index == 0: # Clicked first point
				var new_axial_points = current_axial_points.slice(1) # Remove first point
				if new_axial_points.size() < 2: # Resulting line too short
					permanent_lines_container.remove_child(perm_line_node)
					perm_line_node.queue_free()
					print("Deleted line (became too short after removing first point): ", perm_line_node.name)
					line_to_redraw = null
				else:
					perm_line_node.set_path_points(_convert_axial_path_to_cartesian(new_axial_points), new_axial_points)
					print("Deleted first point of line: ", perm_line_node.name)
			elif clicked_point_index == current_axial_points.size() - 1: # Clicked last point
				var new_axial_points = current_axial_points.slice(0, current_axial_points.size() - 1) # Remove last point
				if new_axial_points.size() < 2: # Resulting line too short
					permanent_lines_container.remove_child(perm_line_node)
					perm_line_node.queue_free()
					print("Deleted line (became too short after removing last point): ", perm_line_node.name)
					line_to_redraw = null
				else:
					perm_line_node.set_path_points(_convert_axial_path_to_cartesian(new_axial_points), new_axial_points)
					print("Deleted last point of line: ", perm_line_node.name)
			else: # Clicked a middle point, split the line
				var part1_axial = current_axial_points.slice(0, clicked_point_index + 1) # Up to and including the clicked point
				var part2_axial = current_axial_points.slice(clicked_point_index)   # From the clicked point to the end
				
				# Update original line to be part1
				if part1_axial.size() < 2:
					permanent_lines_container.remove_child(perm_line_node)
					perm_line_node.queue_free()
					print("Part 1 of split was too short, deleted original line: ", perm_line_node.name)
					line_to_redraw = null # Original line is gone
				else:
					perm_line_node.set_path_points(_convert_axial_path_to_cartesian(part1_axial), part1_axial)
					print("Split line (part 1 updated): ", perm_line_node.name)

				# Create new line for part2 if it's long enough
				if part2_axial.size() >= 2:
					var new_perm_line_node = Node2D.new()
					new_perm_line_node.script = load("res://scripts/PermanentLineNode.gd")
					new_perm_line_node.name = "PermanentLine_" + str(permanent_lines_container.get_child_count())
					
					new_perm_line_node.line_color_to_use = perm_line_node.line_color_to_use # Copy color
					new_perm_line_node.line_width_to_use = perm_line_node.line_width_to_use # Copy width
					
					new_perm_line_node.set_path_points(_convert_axial_path_to_cartesian(part2_axial), part2_axial)
					permanent_lines_container.add_child(new_perm_line_node)
					new_perm_line_node.queue_redraw() # Redraw the new part
					print("Split line (part 2 created): ", new_perm_line_node.name)
				else:
					print("Part 2 of split was too short, not created.")
				
			line_action_taken = true
			# Initialize sequential deletion tracking for any successful deletion
			last_hovered_axial_for_drag_delete = clicked_axial_coord
			break # Found and processed a line, stop checking other lines
	
	if is_instance_valid(line_to_redraw): # If an existing line was modified (not deleted or split into new one solely)
		line_to_redraw.queue_redraw()

	if line_action_taken:
		# Recalculate connections after any line deletion
		_recalculate_all_connections()
		print("Line deletion action completed.")
		return # Do not show background if a line action was performed

	# If no line was actioned and no drawing was cancelled, then show background
	print("Right-click on empty space or no line found at grid position. Showing background.")
	background_layer.show()
	background_grid_drawer.queue_redraw()

func _handle_right_button_up(_event):
	# Reset sequential deletion tracking when right button is released
	last_hovered_axial_for_drag_delete = Vector2i(-10000,-10000)
	print("Sequential deletion ended")

# --- Sequential Deletion Function ---
func _process_sequential_deletion_at_position(axial_coord: Vector2i):
	print("Sequential deletion at grid position: (%d, %d)" % [axial_coord.x, axial_coord.y])
	
	var lines_to_process = permanent_lines_container.get_children().duplicate() # Process a copy to avoid issues with deletion during iteration
	var any_line_modified = false
	
	for line_node_child in lines_to_process:
		if not (line_node_child is Node2D and line_node_child.has_method("set_path_points")):
			continue
		
		var perm_line_node = line_node_child
		if not is_instance_valid(perm_line_node) or perm_line_node.get("axial_points") == null:
			continue

		var current_axial_points = perm_line_node.axial_points
		
		if current_axial_points.size() < 2:
			continue

		# Check if this grid position matches any point in this line
		var point_index = -1
		for i in range(current_axial_points.size()):
			if current_axial_points[i] == axial_coord:
				point_index = i
				break
		
		if point_index >= 0:
			print("Sequential deletion: Found line %s at index %d" % [perm_line_node.name, point_index])
			any_line_modified = true

			if current_axial_points.size() == 2: # Line only has 2 points
				permanent_lines_container.remove_child(perm_line_node)
				perm_line_node.queue_free()
				print("Sequential deletion: Deleted entire line (2 points): ", perm_line_node.name)
			elif point_index == 0: # First point
				var new_axial_points = current_axial_points.slice(1)
				if new_axial_points.size() < 2:
					permanent_lines_container.remove_child(perm_line_node)
					perm_line_node.queue_free()
					print("Sequential deletion: Deleted line (too short after removing first): ", perm_line_node.name)
				else:
					perm_line_node.set_path_points(_convert_axial_path_to_cartesian(new_axial_points), new_axial_points)
					perm_line_node.queue_redraw()
					print("Sequential deletion: Removed first point from: ", perm_line_node.name)
			elif point_index == current_axial_points.size() - 1: # Last point
				var new_axial_points = current_axial_points.slice(0, current_axial_points.size() - 1)
				if new_axial_points.size() < 2:
					permanent_lines_container.remove_child(perm_line_node)
					perm_line_node.queue_free()
					print("Sequential deletion: Deleted line (too short after removing last): ", perm_line_node.name)
				else:
					perm_line_node.set_path_points(_convert_axial_path_to_cartesian(new_axial_points), new_axial_points)
					perm_line_node.queue_redraw()
					print("Sequential deletion: Removed last point from: ", perm_line_node.name)
			else: # Middle point - split the line
				var part1_axial = current_axial_points.slice(0, point_index + 1)
				var part2_axial = current_axial_points.slice(point_index)
				
				# Update original line to be part1
				if part1_axial.size() < 2:
					permanent_lines_container.remove_child(perm_line_node)
					perm_line_node.queue_free()
					print("Sequential deletion: Part 1 too short, deleted original: ", perm_line_node.name)
				else:
					perm_line_node.set_path_points(_convert_axial_path_to_cartesian(part1_axial), part1_axial)
					perm_line_node.queue_redraw()
					print("Sequential deletion: Split line part 1: ", perm_line_node.name)

				# Create new line for part2 if long enough
				if part2_axial.size() >= 2:
					var new_perm_line_node = Node2D.new()
					new_perm_line_node.script = load("res://scripts/PermanentLineNode.gd")
					new_perm_line_node.name = "PermanentLine_" + str(permanent_lines_container.get_child_count())
					
					new_perm_line_node.line_color_to_use = perm_line_node.line_color_to_use
					new_perm_line_node.line_width_to_use = perm_line_node.line_width_to_use
					
					new_perm_line_node.set_path_points(_convert_axial_path_to_cartesian(part2_axial), part2_axial)
					permanent_lines_container.add_child(new_perm_line_node)
					new_perm_line_node.queue_redraw()
					print("Sequential deletion: Split line part 2: ", new_perm_line_node.name)
			
			# Process only the first line found at this position for this iteration
			# Multiple lines at the same position will be processed in subsequent drags
			break
	
	if any_line_modified:
		# Recalculate connections after any line modification
		_recalculate_all_connections()
		print("Sequential deletion: Modified lines at position (%d, %d)" % [axial_coord.x, axial_coord.y])

# --- Connection Detection Function ---
func _check_for_connections(_line_points: Array):
	# Simplified: always do full recalculation instead of incremental updates
	# This ensures accuracy and handles complex cases like multiple circuits, 
	# overlapping connections, etc.
	_recalculate_all_connections()

# --- Connection Recalculation Function ---
func _recalculate_all_connections():
	connection_count = 0
	
	# Iterate through all permanent lines and count connections.
	# NOTE: This logic counts each line between two stations as one connection.
	# Two separate lines between the same two stations will count as two connections.
	for line_node_child in permanent_lines_container.get_children():
		if not (line_node_child is Node2D and line_node_child.has_method("set_path_points")):
			continue
		
		var perm_line_node = line_node_child
		if not is_instance_valid(perm_line_node) or perm_line_node.get("axial_points") == null:
			continue

		var current_axial_points = perm_line_node.axial_points
		if current_axial_points.size() < 2:
			continue
		
		var start_point = current_axial_points.front()
		var end_point = current_axial_points.back()
		
		# Check if both endpoints are stations
		var start_station = map_grid.get_station(start_point.x, start_point.y)
		var end_station = map_grid.get_station(end_point.x, end_point.y)
		
		if start_station != null and end_station != null:
			connection_count += 1
	
	_update_connection_display()
	print("Recalculated connections: %d" % connection_count)

func _update_connection_display():
	var connection_label = get_node_or_null("GameplayLayer/ConnectionLabel")
	if connection_label:
		connection_label.text = "Connections: %d" % connection_count

# --- Color Change Function ---
func _check_line_click_for_color_change(mouse_viewport_pos: Vector2) -> bool:
	# Check if we clicked on any existing line to change its color
	for line_node_child in permanent_lines_container.get_children():
		if not (line_node_child is Node2D and line_node_child.has_method("set_path_points")):
			continue
		
		var perm_line_node = line_node_child
		if not is_instance_valid(perm_line_node) or perm_line_node.get("axial_points") == null:
			continue

		var current_axial_points = perm_line_node.axial_points
		if current_axial_points.size() < 2:
			continue

		var click_threshold = perm_line_node.line_width_to_use / 2.0 + 3.0

		# Check if we clicked on any segment of this line
		for i in range(current_axial_points.size() - 1):
			var axial_p1: Vector2i = current_axial_points[i]
			var axial_p2: Vector2i = current_axial_points[i+1]
			
			# Convert axial segment points to Cartesian for hit detection
			var cartesian_p1 = map_grid.axial_to_cartesian(axial_p1.x, axial_p1.y, hex_size) + draw_offset
			var cartesian_p2 = map_grid.axial_to_cartesian(axial_p2.x, axial_p2.y, hex_size) + draw_offset
			
			var closest_point_on_segment: Vector2 = Geometry2D.get_closest_point_to_segment(mouse_viewport_pos, cartesian_p1, cartesian_p2)
			var distance_to_segment: float = mouse_viewport_pos.distance_to(closest_point_on_segment)

			if distance_to_segment < click_threshold:
				# Change the line color to the currently selected color
				var new_color = color_palette[current_palette_index]
				if perm_line_node.line_color_to_use != new_color:
					perm_line_node.line_color_to_use = new_color
					perm_line_node.queue_redraw()
					print("Changed line color to: ", new_color)
				else:
					print("Line already has the selected color")
				return true # Found and processed a line click
	
	return false # No line was clicked

# --- Color Picker UI Functions ---
func _position_color_picker():
	if not is_instance_valid(color_picker_ui):
		return
	# Wait for the container to figure out its size
	await get_tree().process_frame # Or await get_tree().idle_frame
	
	var viewport_size = get_viewport_rect().size
	var picker_size = color_picker_ui.size # Use actual size after children are added
	
	if picker_size.x == 0 and color_picker_ui.get_child_count() > 0: # Fallback if size is not updated yet
		var min_size = color_picker_ui.get_combined_minimum_size()
		picker_size = min_size

	color_picker_ui.position = Vector2(
		(viewport_size.x - picker_size.x) / 2.0,
		viewport_size.y - picker_size.y - 10 # 10px padding from bottom
	)

func _on_color_dot_gui_input(event: InputEvent, color_index: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		current_palette_index = color_index
		print("Selected color: ", color_palette[current_palette_index], " at index: ", current_palette_index)
		_update_color_picker_selection_visuals()
		# Optionally, consume the event if needed:
		# get_viewport().set_input_as_handled()

func _update_color_picker_selection_visuals():
	if not is_instance_valid(color_picker_ui):
		return
	for i in range(color_picker_ui.get_child_count()):
		var dot_node = color_picker_ui.get_child(i)
		if not is_instance_valid(dot_node) or not dot_node is ColorRect:
			continue

		# Remove existing stylebox to reset border/visuals
		dot_node.remove_theme_stylebox_override("panel")

		if i == current_palette_index:
			# Highlight selected dot (e.g., with a border)
			var selected_style = StyleBoxFlat.new()
			selected_style.bg_color = dot_node.color # Keep its background
			selected_style.set_border_width_all(3) # Border width
			selected_style.border_color = Color.WHITE # Border color for selected
			dot_node.add_theme_stylebox_override("panel", selected_style)
		else:
			# Optional: style for non-selected dots (e.g., slight dim or thinner border)
			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = dot_node.color
			# normal_style.set_border_width_all(1)
			# normal_style.border_color = Color(0.5, 0.5, 0.5, 0.5) # Dimmer border
			dot_node.add_theme_stylebox_override("panel", normal_style)


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
