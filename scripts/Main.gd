extends Node2D
class_name MainScene

# 游戏组件
var game_manager: GameManager
var game_ui: GameUI

# 交互状态
var selected_line: Line = null
var selected_station: Station = null
var is_drawing_line: bool = false
var current_line_color_index: int = 0

func _ready():
	# 设置默认分辨率为1080p
	get_window().size = Vector2i(1920, 1080)
	
	# 创建游戏管理器
	game_manager = GameManager.new()
	add_child(game_manager)
	
	# 创建游戏UI
	game_ui = GameUI.new()
	add_child(game_ui)
	
	# 设置UI的游戏管理器引用
	game_ui.set_game_manager(game_manager)
	
	# 连接UI信号
	game_ui.connect("line_color_selected", Callable(self, "_on_line_color_selected"))
	game_ui.connect("train_added_to_line", Callable(self, "_on_train_added_to_line"))
	
	# 连接游戏管理器信号
	game_manager.connect("station_added", Callable(self, "_on_station_added"))

func _process(delta):
	if is_drawing_line and selected_line != null:
		queue_redraw() # 触发重绘

func _draw():
	if is_drawing_line and selected_line != null and selected_station != null:
		# 绘制从选中车站到鼠标位置的临时线段
		draw_line(
			selected_station.position,
			get_global_mouse_position(),
			selected_line.line_color,
			selected_line.line_width
		)

func _input(event):
	if game_manager.current_state != GameManager.GameState.PLAYING:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 鼠标左键按下
				handle_left_mouse_pressed()
			else:
				# 鼠标左键释放
				handle_left_mouse_released()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 鼠标右键按下
			handle_right_mouse_pressed()
	
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed:
			# 空格键切换暂停状态
			game_manager.toggle_pause()

# 处理鼠标左键按下事件
func handle_left_mouse_pressed():
	var mouse_pos = get_global_mouse_position()
	
	# 检查是否点击了车站
	var clicked_station = find_station_at_position(mouse_pos)
	
	if clicked_station != null:
		if selected_line == null:
			# 如果没有选中线路，选择线路颜色并创建新线路
			selected_line = game_manager.create_line(current_line_color_index)
			if selected_line != null:
				selected_line.add_station(clicked_station)
				selected_station = clicked_station
				is_drawing_line = true
		else:
			# 如果已有选中的线路和车站，添加新车站到线路
			if selected_station != null and selected_station != clicked_station:
				if selected_line.add_station(clicked_station):
					selected_station = clicked_station
				else:
					# 添加失败，可能是线路已包含该车站
					pass
			else:
				selected_station = clicked_station
				is_drawing_line = true

# 处理鼠标左键释放事件
func handle_left_mouse_released():
	is_drawing_line = false

# 处理鼠标右键按下事件
func handle_right_mouse_pressed():
	selected_line = null
	selected_station = null
	is_drawing_line = false
	queue_redraw()

# 在指定位置查找车站
func find_station_at_position(position: Vector2) -> Station:
	for station in game_manager.stations:
		if position.distance_to(station.position) <= station.size:
			return station
	return null

# UI信号响应函数
func _on_line_color_selected(color_index: int):
	current_line_color_index = color_index
	selected_line = null
	selected_station = null
	is_drawing_line = false
	queue_redraw()

func _on_train_added_to_line(line_index: int):
	if line_index >= 0 and line_index < game_manager.lines.size():
		var line = game_manager.lines[line_index]
		game_manager.create_train(line)

# 游戏管理器信号响应函数
func _on_station_added(station: Station):
	# 当新车站添加时，将其高亮一段时间
	station.highlight()
	
	# 创建计时器，一段时间后取消高亮
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 2.0
	add_child(timer)
	timer.connect("timeout", Callable(self, "_on_highlight_timeout").bind(station, timer))
	timer.start()

func _on_highlight_timeout(station: Station, timer: Timer):
	station.unhighlight()
	timer.queue_free() 
