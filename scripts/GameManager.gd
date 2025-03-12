extends Node
class_name GameManager

# 游戏状态
enum GameState {SETUP, PLAYING, PAUSED, GAME_OVER}
var current_state: int = GameState.SETUP

# 游戏资源
var available_lines: int = 3
var available_trains: int = 3
var available_tunnels: int = 0
var available_interchanges: int = 0

# 游戏对象
var stations: Array = []
var lines: Array = []
var trains: Array = []
var passenger_types: Array = []

# 游戏定时器
var game_time: float = 0.0
var station_spawn_timer: float = 0.0
var station_spawn_interval: float = 15.0  # 15秒出现一个新站点
var week_timer: float = 0.0
var week_duration: float = 60.0  # 60秒一周
var current_week: int = 1

# 游戏配置
var min_station_distance: float = 150.0
var map_size: Vector2 = Vector2(1024, 600)
var line_colors: Array = [
	Color(1, 0, 0),  # 红色
	Color(0, 0, 1),  # 蓝色
	Color(0, 1, 0),  # 绿色
	Color(1, 1, 0),  # 黄色
	Color(1, 0, 1),  # 紫色
	Color(0, 1, 1),  # 青色
	Color(1, 0.5, 0)  # 橙色
]

# 信号
signal station_added(station)
signal line_added(line)
signal train_added(train)
signal week_changed(week)
signal game_state_changed(new_state)
signal game_over

func _ready():
	randomize()
	setup_game()

func _process(delta):
	match current_state:
		GameState.PLAYING:
			update_game(delta)
		GameState.PAUSED:
			pass
		GameState.GAME_OVER:
			pass

# 初始化游戏
func setup_game():
	# 清理先前的游戏数据
	stations.clear()
	lines.clear()
	trains.clear()
	
	# 初始化车站类型
	passenger_types = [
		Station.ShapeType.CIRCLE,
		Station.ShapeType.SQUARE,
		Station.ShapeType.TRIANGLE
	]
	
	# 创建初始车站
	for i in range(3):
		spawn_station()
	
	# 重置游戏计时器
	game_time = 0.0
	station_spawn_timer = 0.0
	week_timer = 0.0
	current_week = 1
	
	# 设置游戏状态为进行中
	set_game_state(GameState.PLAYING)

# 更新游戏状态
func update_game(delta):
	game_time += delta
	station_spawn_timer += delta
	week_timer += delta
	
	# 检查是否需要生成新车站
	if station_spawn_timer >= station_spawn_interval:
		spawn_station()
		station_spawn_timer = 0.0
	
	# 检查是否进入新的一周
	if week_timer >= week_duration:
		advance_week()
		week_timer = 0.0
	
	# 更新乘客生成逻辑
	update_passenger_generation(delta)
	
	# 检查游戏结束条件
	check_game_over_condition()

# 生成新的车站
func spawn_station():
	var station_id = stations.size()
	var shape_type = passenger_types[randi() % passenger_types.size()]
	
	# 随机生成车站位置，确保与现有车站保持一定距离
	var position = generate_station_position()
	
	var station = Station.new(station_id, shape_type, position)
	stations.append(station)
	add_child(station)
	emit_signal("station_added", station)
	
	# 随机生成1-2名乘客
	var initial_passengers = randi() % 2 + 1
	for i in range(initial_passengers):
		var passenger_type = passenger_types[randi() % passenger_types.size()]
		while passenger_type == shape_type:  # 确保乘客要去别的车站
			passenger_type = passenger_types[randi() % passenger_types.size()]
		station.add_passenger(passenger_type)

# 生成车站位置，确保与现有车站保持距离
func generate_station_position() -> Vector2:
	var max_attempts = 30
	var attempts = 0
	
	while attempts < max_attempts:
		var pos = Vector2(
			randf_range(50, map_size.x - 50),
			randf_range(50, map_size.y - 50)
		)
		
		var valid_position = true
		for existing_station in stations:
			if pos.distance_to(existing_station.position) < min_station_distance:
				valid_position = false
				break
		
		if valid_position:
			return pos
		
		attempts += 1
	
	# 如果多次尝试失败，放宽距离限制
	return Vector2(
		randf_range(50, map_size.x - 50),
		randf_range(50, map_size.y - 50)
	)

# 更新乘客生成逻辑
func update_passenger_generation(delta):
	# 每个车站随机生成乘客的概率随时间增加
	var base_probability = 0.01 * delta
	var week_factor = 1.0 + current_week * 0.1
	
	for station in stations:
		if randf() < base_probability * week_factor:
			# 随机选择一个目的地类型（不同于当前车站类型）
			var destination_type = station.shape_type
			while destination_type == station.shape_type:
				destination_type = passenger_types[randi() % passenger_types.size()]
			
			station.add_passenger(destination_type)

# 进入新的一周
func advance_week():
	current_week += 1
	emit_signal("week_changed", current_week)
	
	# 每周增加游戏资源
	if current_week % 2 == 0:  # 每两周增加一条线
		available_lines += 1
	
	if current_week % 3 == 0:  # 每三周增加一列火车
		available_trains += 1
	
	if current_week % 4 == 0:  # 每四周增加一个隧道
		available_tunnels += 1
	
	if current_week % 5 == 0:  # 每五周增加一个换乘站
		available_interchanges += 1
		
	# 增加游戏难度
	station_spawn_interval = max(7.0, station_spawn_interval - 0.5)  # 最低7秒一个站

# 创建新线路
func create_line(color_index: int) -> Line:
	if available_lines <= 0:
		return null
	
	var line_id = lines.size()
	var color = line_colors[color_index % line_colors.size()]
	
	var line = Line.new(line_id, color)
	lines.append(line)
	add_child(line)
	
	available_lines -= 1
	emit_signal("line_added", line)
	
	return line

# 创建新列车
func create_train(line: Line) -> Train:
	if available_trains <= 0 or line == null:
		return null
	
	var train_id = trains.size()
	var train = Train.new(train_id)
	
	if line.add_train(train):
		trains.append(train)
		add_child(train)
		
		available_trains -= 1
		emit_signal("train_added", train)
		
		return train
	
	return null

# 设置游戏状态
func set_game_state(new_state: int):
	if current_state != new_state:
		current_state = new_state
		emit_signal("game_state_changed", new_state)
		
		match new_state:
			GameState.GAME_OVER:
				emit_signal("game_over")

# 检查游戏结束条件
func check_game_over_condition():
	for station in stations:
		if station.is_overcrowded and station.overcrowd_timer >= station.max_overcrowd_time:
			set_game_state(GameState.GAME_OVER)
			break

# 暂停/继续游戏
func toggle_pause():
	if current_state == GameState.PLAYING:
		set_game_state(GameState.PAUSED)
	elif current_state == GameState.PAUSED:
		set_game_state(GameState.PLAYING)

# 重新开始游戏
func restart_game():
	setup_game() 