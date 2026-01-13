## ============================================================
## 模块名称: 建筑管理器（BuildingManager）
## 创建日期: 2026-01-11
## 功能说明:
##   - 左键：在网格格子放置占位建筑
##   - 右键：删除格子中的占位建筑
##   - 使用 Dictionary 记录格子占用
## 依赖关系:
##   - 同级节点 `GridOverlay`（挂载 `GridOverlay` 脚本）
##   - 同级节点 `Buildings`（作为建筑占位节点容器）
## ============================================================

extends Node2D

const TILE_SIZE := 32

## 格子占用表：key=Vector2i（格子坐标），value=Node（该格子的占位节点）。
var occupied: Dictionary = {}

## @onready：节点进入场景树后再获取引用，避免还没 ready 时找不到节点。
@onready var _grid_overlay: GridOverlay = get_parent().get_node_or_null("GridOverlay") as GridOverlay
@onready var _buildings: Node2D = get_parent().get_node_or_null("Buildings") as Node2D

func _ready() -> void:
	if _grid_overlay == null:
		push_error("BuildingManager: 未找到同级节点 GridOverlay（期望路径：World2D/GridOverlay）")
		set_process_unhandled_input(false)
		return
	if _buildings == null:
		push_error("BuildingManager: 未找到同级节点 Buildings（期望路径：World2D/Buildings）")
		set_process_unhandled_input(false)
		return

## 鼠标点击交互：
## - 左键：空格子则放置
## - 右键：占用则删除
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.is_echo():
		return

	# 若正在相机平移（Cmd/Ctrl + 左键），则不处理左键放置，避免拖拽时误放置。
	if (Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_CTRL)) and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		return

	# 步骤1：通过 GridOverlay 统一完成“世界坐标 → 格子坐标”的转换
	var cell: Vector2i = _grid_overlay.world_to_cell(get_global_mouse_position())
	# 步骤2：越界直接忽略（防止在网格外误放置）
	if cell.x < 0 or cell.x >= _grid_overlay.GRID_W or cell.y < 0 or cell.y >= _grid_overlay.GRID_H:
		return

	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		# 步骤3：检查是否已占用
		if occupied.has(cell):
			return

		# 步骤4：创建占位块（ColorRect：简单可见的方块）
		var placeholder := ColorRect.new()
		placeholder.color = Color(0.55, 0.55, 0.55, 1.0)
		placeholder.size = Vector2(TILE_SIZE, TILE_SIZE)
		# 让占位块不拦截鼠标事件，避免影响后续点击检测
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 步骤5：对齐到格子左上角（以 GridOverlay 的坐标系为准）
		var world_pos: Vector2 = _grid_overlay.cell_to_world(cell)
		placeholder.position = _buildings.to_local(world_pos)
		_buildings.add_child(placeholder)

		# 步骤6：记录占用并输出日志
		occupied[cell] = placeholder
		print("Placed at (%d,%d)" % [cell.x, cell.y])
		return

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		# 步骤3：检查是否有占用可删
		if not occupied.has(cell):
			return

		# Dictionary 取值可能没有静态类型：这里显式声明为 Node，避免解析期类型推断报错。
		var node: Node = occupied.get(cell) as Node
		if node != null and is_instance_valid(node):
			node.queue_free()
		# 步骤4：移除占用记录并输出日志
		occupied.erase(cell)
		print("Removed at (%d,%d)" % [cell.x, cell.y])
