extends Node2D
class_name Line

# 线路颜色
var line_color: Color
var line_id: int
var stations: Array = []
var trains: Array = []
var line_width: float = 5.0
var max_trains: int = 3

# 线路路径点，用于绘制线路和引导列车移动
var path_points: Array = []

signal train_added(train)
signal train_removed(train)

func _init(id: int, color: Color):
	line_id = id
	line_color = color

func _ready():
	pass

func _process(_delta):
	queue_redraw()

func _draw():
	# 如果线路有至少两个车站，绘制线路
	if stations.size() >= 2:
		for i in range(stations.size() - 1):
			draw_line(
				stations[i].position - global_position,
				stations[i + 1].position - global_position,
				line_color,
				line_width
			)

# 添加车站到线路
func add_station(station):
	if not stations.has(station):
		stations.append(station)
		station.connect_line(self)
		recalculate_path()
		return true
	return false

# 从线路中移除车站
func remove_station(station):
	var index = stations.find(station)
	if index != -1:
		stations.remove_at(index)
		station.disconnect_line(self)
		recalculate_path()
		return true
	return false

# 重新计算线路路径点
func recalculate_path():
	path_points.clear()
	
	# 简单实现：直接连接各站点
	for station in stations:
		path_points.append(station.position)

# 添加列车到线路
func add_train(train):
	if trains.size() < max_trains:
		trains.append(train)
		train.set_line(self)
		emit_signal("train_added", train)
		return true
	return false

# 从线路中移除列车
func remove_train(train):
	var index = trains.find(train)
	if index != -1:
		trains.remove_at(index)
		emit_signal("train_removed", train)
		return true
	return false

# 获取两个车站之间的路径段
func get_path_segment(from_station, to_station):
	var from_index = stations.find(from_station)
	var to_index = stations.find(to_station)
	
	if from_index == -1 or to_index == -1:
		return []
	
	var segment = []
	var step = 1 if to_index > from_index else -1
	var current = from_index
	
	while current != to_index:
		segment.append(stations[current].position)
		current += step
	
	segment.append(stations[to_index].position)
	return segment

# 获取指定车站的相邻车站
func get_adjacent_stations(station):
	var adjacent = []
	var index = stations.find(station)
	
	if index == -1:
		return adjacent
	
	if index > 0:
		adjacent.append(stations[index - 1])
	
	if index < stations.size() - 1:
		adjacent.append(stations[index + 1])
	
	return adjacent 
