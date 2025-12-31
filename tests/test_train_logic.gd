extends SceneTree

# Simple test runner for Train logic without Godot engine's visual components being active
# Run with: godot -s tests/test_train_logic.gd

# Mock Classes
class MockStation:
	extends Node
	var station_id
	var shape_type
	var passengers = []
	var connected_lines = []
	var passenger_capacity = 6
	var position = Vector2(0, 0)

	func _init(id, type, pos):
		station_id = id
		shape_type = type
		position = pos

	func remove_passenger(type):
		passengers.erase(type)

class MockLine:
	extends Node
	var stations = []
	var line_color = Color(1, 0, 0)

	func _init(id, color):
		pass

	func get_path_segment(from_s, to_s):
		return [from_s.position, to_s.position]

	func get_adjacent_stations(station):
		var idx = stations.find(station)
		var adj = []
		if idx > 0: adj.append(stations[idx-1])
		if idx < stations.size() - 1: adj.append(stations[idx+1])
		return adj

func _init():
	print("Starting Train Logic Tests...")
	test_wait_and_load_logic()
	test_routing_logic()
	print("All tests finished.")
	quit()

func test_wait_and_load_logic():
	print("Testing wait and load logic...")

	# Setup
	var s1 = MockStation.new(1, 0, Vector2(0,0)) # Circle
	s1.passengers.append(1) # Square passenger - should be loaded

	var train_script = load("res://scripts/Train.gd")
	if not train_script:
		print("Error: Could not load Train.gd")
		return

	var train = train_script.new(1)
	train.current_station = s1
	train.max_passengers = 6
	train.passengers = []
	train.wait_duration = 1.0
	train.previous_station = s1 # Just to prevent null errors in routing if called

	# Simulate Arrival
	train.arrive_at_station(s1)

	# Check 1: Should be waiting
	if train.is_waiting:
		print("PASS: Train enters waiting state upon arrival.")
	else:
		print("FAIL: Train did not enter waiting state.")

	# Check 2: Passengers should NOT be loaded yet (unloaded only)
	if train.passengers.size() == 0:
		print("PASS: Passengers not loaded immediately.")
	else:
		print("FAIL: Passengers loaded too early.")

	# Simulate Wait Time Passing
	train._process(1.1) # Pass more than wait_duration

	# Check 3: Should not be waiting anymore
	if not train.is_waiting:
		print("PASS: Train finished waiting.")
	else:
		print("FAIL: Train is still waiting.")

	# Check 4: Passengers should be loaded now
	if train.passengers.size() == 1 and train.passengers[0] == 1:
		print("PASS: Passengers loaded after wait.")
	else:
		print("FAIL: Passengers not loaded correctly. Count: ", train.passengers.size())

func test_routing_logic():
	print("Testing routing logic...")

	var train_script = load("res://scripts/Train.gd")
	var train = train_script.new(2)

	var line = MockLine.new(1, Color.RED)
	var s1 = MockStation.new(1, 0, Vector2(0,0))
	var s2 = MockStation.new(2, 0, Vector2(100,0))
	var s3 = MockStation.new(3, 0, Vector2(200,0))

	line.stations = [s1, s2, s3]
	train.line = line

	# Case 1: At middle station (s2), came from s1. Should go to s3.
	train.current_station = s2
	train.previous_station = s1

	var next = train.decide_next_station()
	if next == s3:
		print("PASS: Train maintains direction (s1 -> s2 -> s3).")
	else:
		print("FAIL: Train did not maintain direction. Went to: ", next)

	# Case 2: At end (s3), came from s2. Should go to s2.
	train.current_station = s3
	train.previous_station = s2

	next = train.decide_next_station()
	if next == s2:
		print("PASS: Train reverses at end of line (s2 -> s3 -> s2).")
	else:
		print("FAIL: Train did not reverse at end.")
