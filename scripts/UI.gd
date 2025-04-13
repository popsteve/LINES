extends CanvasLayer
class_name GameUI

# UI元素引用
var week_label: Label
var lines_label: Label
var trains_label: Label
var tunnels_label: Label
var interchanges_label: Label
var pause_button: Button
var game_over_panel: Panel

# 游戏管理器引用
var game_manager: GameManager

signal line_color_selected(color_index)
signal train_added_to_line(line_index)
signal pause_toggled

func _ready():
	# Initialize UI elements AFTER game_manager is set
	# initialize_ui_elements() - Removed from here
	
	# Connect signals AFTER game_manager is set
	# connect_signals() - Removed from here
	pass # Add pass to avoid empty function error

# 初始化UI元素
func initialize_ui_elements():
	# 创建顶部信息面板
	var top_panel = Panel.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.set_size(Vector2(0, 50))
	add_child(top_panel)
	
	# Create MarginContainer for top panel content
	var top_margin_container = MarginContainer.new()
	top_margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_margin_container.add_theme_constant_override("margin_top", 5)
	top_margin_container.add_theme_constant_override("margin_left", 10)
	top_margin_container.add_theme_constant_override("margin_right", 10)
	top_panel.add_child(top_margin_container)
	
	var hbox = HBoxContainer.new()
	top_margin_container.add_child(hbox)
	
	# 创建周数标签
	week_label = Label.new()
	week_label.text = "Week 1"
	hbox.add_child(week_label)
	
	# 添加空间
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# 创建资源标签
	lines_label = Label.new()
	lines_label.text = "Lines: 3"
	hbox.add_child(lines_label)
	
	trains_label = Label.new()
	trains_label.text = "Trains: 3"
	hbox.add_child(trains_label)
	
	tunnels_label = Label.new()
	tunnels_label.text = "Tunnels: 0"
	hbox.add_child(tunnels_label)
	
	interchanges_label = Label.new()
	interchanges_label.text = "Interchanges: 0"
	hbox.add_child(interchanges_label)
	
	# 添加空间
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer2)
	
	# 创建暂停按钮
	pause_button = Button.new()
	pause_button.text = "Pause"
	hbox.add_child(pause_button)
	
	# 创建底部工具面板
	var bottom_panel = Panel.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.set_size(Vector2(0, 80))
	add_child(bottom_panel)
	
	# Create MarginContainer for bottom panel content
	var bottom_margin_container = MarginContainer.new()
	bottom_margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_margin_container.add_theme_constant_override("margin_bottom", 10)
	bottom_margin_container.add_theme_constant_override("margin_left", 10)
	bottom_margin_container.add_theme_constant_override("margin_right", 10)
	bottom_panel.add_child(bottom_margin_container)
	
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_margin_container.add_child(bottom_hbox)
	
	# 创建线路颜色选择按钮
	for i in range(7):  # 7种颜色
		var color_button = create_color_button(i)
		bottom_hbox.add_child(color_button)
	
	# 创建游戏结束面板
	game_over_panel = Panel.new()
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	game_over_panel.set_size(Vector2(400, 200))
	game_over_panel.visible = false
	add_child(game_over_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(vbox)
	
	var game_over_label = Label.new()
	game_over_label.text = "Game Over!"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(game_over_label)
	
	var restart_button = Button.new()
	restart_button.text = "Restart Game"
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(restart_button)
	
	# 连接重新开始按钮信号
	restart_button.connect("pressed", Callable(self, "_on_restart_button_pressed"))

# 创建颜色选择按钮
func create_color_button(color_index: int) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(50, 50)
	
	# 设置按钮颜色
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = game_manager.line_colors[color_index]
	button.add_theme_stylebox_override("normal", style_box)
	
	# 连接按钮点击信号
	button.connect("pressed", Callable(self, "_on_color_button_pressed").bind(color_index))
	
	return button

# 连接信号
func connect_signals():
	pause_button.connect("pressed", Callable(self, "_on_pause_button_pressed"))
	
	if game_manager:
		game_manager.connect("week_changed", Callable(self, "_on_week_changed"))
		game_manager.connect("game_state_changed", Callable(self, "_on_game_state_changed"))
		game_manager.connect("game_over", Callable(self, "_on_game_over"))

# 设置游戏管理器引用
func set_game_manager(manager: GameManager):
	game_manager = manager
	if game_manager == null:
		printerr("GameManager is null in set_game_manager!")
		return
		
	# Now that game_manager is set, initialize UI elements and connect signals
	initialize_ui_elements()
	connect_signals()
	update_ui()

# 更新UI显示
func update_ui():
	if game_manager:
		week_label.text = "Week " + str(game_manager.current_week)
		lines_label.text = "Lines: " + str(game_manager.available_lines)
		trains_label.text = "Trains: " + str(game_manager.available_trains)
		tunnels_label.text = "Tunnels: " + str(game_manager.available_tunnels)
		interchanges_label.text = "Interchanges: " + str(game_manager.available_interchanges)
		
		# 更新暂停按钮文本
		if game_manager.current_state == GameManager.GameState.PAUSED:
			pause_button.text = "Resume"
		else:
			pause_button.text = "Pause"

# 按钮事件处理函数
func _on_color_button_pressed(color_index: int):
	emit_signal("line_color_selected", color_index)

func _on_pause_button_pressed():
	emit_signal("pause_toggled")
	
	if game_manager:
		game_manager.toggle_pause()
		update_ui()

func _on_restart_button_pressed():
	if game_manager:
		game_manager.restart_game()
		game_over_panel.visible = false
		update_ui()

# 游戏事件响应函数
func _on_week_changed(week: int):
	update_ui()

func _on_game_state_changed(new_state: int):
	update_ui()

func _on_game_over():
	game_over_panel.visible = true 
