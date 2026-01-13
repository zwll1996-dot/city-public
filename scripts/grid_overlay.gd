## ============================================================
## 模块名称: 网格覆盖层（GridOverlay）
## 创建日期: 2026-01-11
## 功能说明:
##   - 绘制 32×32 的网格线与外框
##   - 提供 world↔cell 坐标转换
##   - 可选：鼠标悬停格子高亮
## 依赖关系:
##   - 挂载到 `World2D/GridOverlay`（Node2D）
## ============================================================

class_name GridOverlay
extends Node2D

## 单个格子的边长（像素）。
const TILE_SIZE := 32
## 网格宽度（格子数）。
const GRID_W := 30
## 网格高度（格子数）。
const GRID_H := 18

## 当前鼠标悬停的格子坐标；(-1,-1) 表示无效/未命中。
var _hover_cell: Vector2i = Vector2i(-1, -1)

## 初始化：进入场景树后立刻绘制一次。
func _ready() -> void:
	queue_redraw()

## 处理鼠标移动：更新悬停格子并触发重绘（用于高亮效果）。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# 平移相机时不更新悬停高亮，避免额外重绘造成“卡顿感”
		if (Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_CTRL)) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		# 步骤1：将鼠标世界坐标转换为格子坐标
		var cell := world_to_cell(get_global_mouse_position())
		if cell != _hover_cell:
			# 步骤2：只有变化时才重绘，减少无意义的 redraw
			_hover_cell = cell
			queue_redraw()

## 绘制回调：画淡色网格线、外框，并可选画鼠标悬停高亮。
func _draw() -> void:
	# 步骤1：计算整个网格的像素尺寸
	var grid_pixel_w := GRID_W * TILE_SIZE
	var grid_pixel_h := GRID_H * TILE_SIZE

	var line_color := Color(1, 1, 1, 0.18)
	var border_color := Color(1, 1, 1, 0.35)

	# 步骤2（可选）：鼠标悬停高亮（半透明填充）
	if _hover_cell.x >= 0 and _hover_cell.x < GRID_W and _hover_cell.y >= 0 and _hover_cell.y < GRID_H:
		draw_rect(
			Rect2(Vector2(_hover_cell) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE)),
			Color(1, 1, 1, 0.12),
			true
		)

	# 步骤3：画网格线（竖线 + 横线）
	for x in range(GRID_W + 1):
		var px := x * TILE_SIZE
		draw_line(Vector2(px, 0), Vector2(px, grid_pixel_h), line_color, 1.0)
	for y in range(GRID_H + 1):
		var py := y * TILE_SIZE
		draw_line(Vector2(0, py), Vector2(grid_pixel_w, py), line_color, 1.0)

	# 步骤4：画外框（矩形描边）
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid_pixel_w, grid_pixel_h)), border_color, false, 2.0)

## 世界坐标 → 格子坐标（向下取整）。
## @param world_pos: 世界坐标（global）
## @return: 格子坐标（Vector2i）
func world_to_cell(world_pos: Vector2) -> Vector2i:
	# Node2D.to_local：把世界坐标转换为本节点的局部坐标
	var local_pos := to_local(world_pos)
	return Vector2i(floori(local_pos.x / TILE_SIZE), floori(local_pos.y / TILE_SIZE))

## 格子坐标 → 世界坐标（格子的左上角）。
## @param cell: 格子坐标（Vector2i）
## @return: 左上角对应的世界坐标（Vector2）
func cell_to_world(cell: Vector2i) -> Vector2:
	# Node2D.to_global：把本节点局部坐标转换为世界坐标
	return to_global(Vector2(cell) * TILE_SIZE)
