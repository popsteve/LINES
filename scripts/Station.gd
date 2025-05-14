extends Node2D
class_name Station

# Signal declarations
signal game_over

# 车站形状类型（如方形、圆形、三角形等）
enum ShapeType {CIRCLE, SQUARE, TRIANGLE, DIAMOND, STAR, PENTAGON, HEXAGON}

# 车站属性
var station_id: int
var shape_type: int
var passengers: Array = []
var connected_lines: Array = []
var passenger_capacity: int = 6
var is_overcrowded: bool = false
var overcrowd_timer: float = 0.0
var max_overcrowd_time: float = 30.0  # 车站过载30秒后游戏结束

# 视觉表现
var base_color: Color = Color.WHITE
var highlight_color: Color = Color.YELLOW
var size: float = 25.0
var is_highlighted: bool = false

func _init(id: int, type: int, pos: Vector2):
	station_id = id
	shape_type = type
	position = pos

func _ready():
	# 初始化车站
	pass

func _process(delta):
	# 处理过载逻辑
	if is_overcrowded:
		overcrowd_timer += delta
		if overcrowd_timer >= max_overcrowd_time:
			emit_signal("game_over")
	
	# 其他更新逻辑
	queue_redraw()

func _draw():
	# 绘制车站形状
	match shape_type:
		ShapeType.CIRCLE:
			draw_circle(Vector2.ZERO, size, base_color if not is_highlighted else highlight_color)
		ShapeType.SQUARE:
			var rect = Rect2(-size, -size, size * 2, size * 2)
			draw_rect(rect, base_color if not is_highlighted else highlight_color)
		ShapeType.TRIANGLE:
			var points = [
				Vector2(0, -size),
				Vector2(-size, size),
				Vector2(size, size)
			]
			draw_colored_polygon(points, base_color if not is_highlighted else highlight_color)
		# 其他形状...

# 添加乘客到车站
func add_passenger(passenger_type: int):
	if passengers.size() < passenger_capacity:
		passengers.append(passenger_type)
		check_overcrowding()
		return true
	else:
		check_overcrowding()
		return false

# 从车站移除乘客
func remove_passenger(passenger_type: int):
	for i in range(passengers.size()):
		if passengers[i] == passenger_type:
			passengers.remove_at(i)
			check_overcrowding()
			return true
	return false

# 检查并更新车站的过载状态
func check_overcrowding():
	var was_overcrowded = is_overcrowded
	is_overcrowded = passengers.size() >= passenger_capacity
	
	if is_overcrowded and not was_overcrowded:
		# 车站刚开始过载
		overcrowd_timer = 0.0
	elif not is_overcrowded and was_overcrowded:
		# 车站不再过载
		overcrowd_timer = 0.0

# 连接一条线路到车站
func connect_line(line):
	if not connected_lines.has(line):
		connected_lines.append(line)

# 断开车站与线路的连接
func disconnect_line(line):
	var index = connected_lines.find(line)
	if index != -1:
		connected_lines.remove_at(index)

# 高亮显示车站
func highlight():
	is_highlighted = true

# 取消高亮
func unhighlight():
	is_highlighted = false 
