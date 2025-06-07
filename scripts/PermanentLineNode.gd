extends Node2D

var line_path_points: Array = [] # Array of Vector2 global coordinates for the curve
var axial_points: Array = [] # Array of Vector2i axial coordinates that define this line
var line_color_to_use: Color = Color.GRAY
var line_width_to_use: float = 5.0
var curve: Curve2D = null
const HANDLE_TENSION = 0.25 # Affects the "curviness"

func _ready():
	# Ensure points are local to this node if it's not at (0,0)
	# For now, assuming this node is added to a layer at (0,0) or points are already global.
	# If line_path_points are global, and this node might move, convert points to local space.
	# However, draw_polyline uses global coordinates relative to the current canvas transform.
	# If this node itself is positioned via its `position` property, then drawing at (0,0) relative to itself is fine.
	# The points in line_path_points are global as per previous comments.
	# For draw_polyline in _draw, we need points relative to this node's transform if it's not at origin.
	# Let's assume for now that the parent (PermanentLinesContainer) is at origin or handles global space correctly.
	pass

func set_path_points(new_cartesian_points: Array, new_axial_points: Array):
	line_path_points = new_cartesian_points # For fallback drawing if needed
	axial_points = new_axial_points       # Store the definitive axial path
	curve = null # Clear previous curve

	if new_cartesian_points.size() < 2:
		queue_redraw()
		return

	curve = Curve2D.new()
	curve.bake_interval = 5.0 # For tessellation density

	if new_cartesian_points.size() == 2:
		# Straight line for two points
		curve.add_point(new_cartesian_points[0], Vector2.ZERO, Vector2.ZERO)
		curve.add_point(new_cartesian_points[1], Vector2.ZERO, Vector2.ZERO)
	else:
		# Calculate handles for 3+ points for a smooth curve
		for i in range(new_cartesian_points.size()):
			var p_i = new_cartesian_points[i]
			var in_delta = Vector2.ZERO
			var out_delta = Vector2.ZERO

			if i == 0: # First point
				var p_next = new_cartesian_points[i+1]
				out_delta = (p_next - p_i) * HANDLE_TENSION
			elif i == new_cartesian_points.size() - 1: # Last point
				var p_prev = new_cartesian_points[i-1]
				in_delta = (p_prev - p_i) * HANDLE_TENSION # Points from p_i towards p_prev
			else: # Intermediate points
				var p_prev = new_cartesian_points[i-1]
				var p_next = new_cartesian_points[i+1]
				var tangent = (p_next - p_prev).normalized() # Normalized tangent
				
				var dist_to_prev = p_i.distance_to(p_prev)
				var dist_to_next = p_i.distance_to(p_next)

				in_delta = -tangent * dist_to_prev * HANDLE_TENSION 
				out_delta = tangent * dist_to_next * HANDLE_TENSION
			
			curve.add_point(p_i, in_delta, out_delta)
			
	queue_redraw()

func _draw():
	if curve and curve.get_point_count() >= 2:
		# draw_polyline draws straight lines between points. 
		# To draw the curve smoothly, we need to get tessellated points from the curve.
		var tessellated_points = curve.get_baked_points() # This gives a smoother line based on interpolation method
		if tessellated_points and tessellated_points.size() >= 2:
			draw_polyline(tessellated_points, line_color_to_use, line_width_to_use, true) # Antialiased = true
	elif line_path_points.size() >= 2: # Fallback to simple polyline if curve setup failed or not enough points
		for i in range(line_path_points.size() - 1):
			draw_line(line_path_points[i], line_path_points[i+1], line_color_to_use, line_width_to_use, true) 