extends Node2D
class_name Train

# 列车属性
var train_id: int
var line: Line = null
var current_station: Station = null
var next_station: Station = null
var passengers: Array = []
var max_passengers: int = 6
var speed: float = 100.0  # 像素/秒
var is_moving: bool = false
var path: Array = []
var path_index: int = 0

# 视觉表现
var train_color: Color = Color.WHITE
var train_size: Vector2 = Vector2(15, 10)

func _init(id: int):
	train_id = id

func _ready():
	pass

func _process(delta):
	if is_moving and next_station != null:
		move_along_path(delta)
	queue_redraw()

func _draw():
	# 绘制列车
	var rect = Rect2(-train_size.x/2, -train_size.y/2, train_size.x, train_size.y)
	draw_rect(rect, train_color)
	
	# 绘制乘客指示器
	var passenger_indicator_size = 3.0
	var spacing = 4.0
	var start_x = -((passengers.size() - 1) * spacing) / 2
	
	for i in range(passengers.size()):
		var passenger_type = passengers[i]
		var pos = Vector2(start_x + i * spacing, -train_size.y/2 - passenger_indicator_size - 2)
		
		# 根据乘客类型绘制不同颜色的指示器
		var passenger_color
		match passenger_type:
			Station.ShapeType.CIRCLE: passenger_color = Color.RED
			Station.ShapeType.SQUARE: passenger_color = Color.BLUE
			Station.ShapeType.TRIANGLE: passenger_color = Color.GREEN
			# 其他形状...
			_: passenger_color = Color.WHITE
		
		draw_circle(pos, passenger_indicator_size, passenger_color)

# 设置列车所属的线路
func set_line(new_line):
	line = new_line
	train_color = line.line_color
	
	# 如果线路有车站，设置初始车站
	if line.stations.size() > 0:
		set_current_station(line.stations[0])

# 设置当前车站
func set_current_station(station):
	current_station = station
	position = current_station.position
	is_moving = false

# 设置下一个目标车站
func set_next_station(station):
	next_station = station
	
	if current_station != null and next_station != null:
		# 获取从当前车站到下一站的路径
		path = line.get_path_segment(current_station, next_station)
		path_index = 0
		is_moving = true

# 沿路径移动
func move_along_path(delta):
	if path.size() < 2 or path_index >= path.size() - 1:
		# 到达目标站点
		if next_station != null:
			arrive_at_station(next_station)
		return
	
	var target_pos = path[path_index + 1]
	var direction = (target_pos - position).normalized()
	var move_distance = speed * delta
	
	if position.distance_to(target_pos) <= move_distance:
		# 到达路径点
		position = target_pos
		path_index += 1
	else:
		position += direction * move_distance

# 到达车站
func arrive_at_station(station):
	set_current_station(station)
	
	# 处理乘客上下车
	handle_passengers_at_station()
	
	# 如果还有下一站，继续移动
	if should_continue_to_next_station():
		set_next_station(decide_next_station())

# 处理列车到站时的乘客上下车
func handle_passengers_at_station():
	# 乘客下车
	var passengers_to_remove = []
	
	for i in range(passengers.size()):
		var passenger_type = passengers[i]
		if passenger_type == current_station.shape_type:
			passengers_to_remove.append(i)
	
	# 从后向前移除，避免索引问题
	for i in range(passengers_to_remove.size() - 1, -1, -1):
		passengers.remove_at(passengers_to_remove[i])
	
	# 乘客上车
	for passenger_type in current_station.passengers.duplicate():
		if passengers.size() < max_passengers:
			current_station.remove_passenger(passenger_type)
			passengers.append(passenger_type)
		else:
			break

# 判断是否应该继续前往下一站
func should_continue_to_next_station():
	# 如果还有空位且当前站还有乘客，等待一段时间
	if passengers.size() < max_passengers and current_station.passengers.size() > 0:
		# 在实际实现中可以添加一个计时器
		return false
	else:
		return true

# 决定下一个目标车站
func decide_next_station():
	var adjacent_stations = line.get_adjacent_stations(current_station)
	
	if adjacent_stations.size() == 0:
		return null
	elif adjacent_stations.size() == 1:
		return adjacent_stations[0]
	else:
		# 简单策略：如果有乘客要去某个方向的站，选择那个方向
		# 否则，交替选择方向
		
		# 此处使用简单逻辑，随机选择
		return adjacent_stations[randi() % adjacent_stations.size()] 
