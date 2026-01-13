## ============================================================
## 模块名称: 相机控制器（CameraController）
## 创建日期: 2026-01-11
## 功能说明:
##   - 鼠标滚轮：缩放
##   - 触控板两指拖动：平移画布（Cmd/Ctrl + 两指拖动=缩放）
##   - 触控板捏合：缩放
##   - Cmd/Ctrl + 鼠标左键拖拽：平移画布
##   - Space：重置缩放到初始值
## 依赖关系:
##   - 挂载到 `Camera2D` 节点
##   - `project.godot` 中存在输入动作 `cam_pan`（已绑定 Space）
## ============================================================

extends Camera2D

## 最小缩放（越小越远）。
@export var zoom_min: float = 2.0
## 最大缩放（越大越近）。
@export var zoom_max: float = 8.0

## 鼠标滚轮每格缩放倍率（越大越快）。
@export var wheel_zoom_step: float = 1.5

## Cmd/Ctrl + 鼠标拖拽平移速度系数（越大越快）。
@export var mouse_pan_speed: float = 3.0
## 鼠标拖拽平移的平滑程度（0=无平滑，0.1~0.3较顺滑）。
@export var mouse_pan_smoothness: float = 0.25

## 触控板两指拖动平移速度系数（越大越快）。
@export var trackpad_pan_speed: float = 7.0
## 触控板两指拖动方向反转（符合个人直觉则勾选）。
@export var invert_trackpad_pan: bool = false

@export var trackpad_zoom_step: float = 1.12
@export var trackpad_zoom_sensitivity: float = 0.02
@export var trackpad_delta_clamp: float = 80.0

var _panning := false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _trackpad_pan_accum: Vector2 = Vector2.ZERO
var _saw_wheel_this_frame := false
var _default_zoom: Vector2 = Vector2.ONE
var _reset_tween: Tween = null

func _ready() -> void:
	# 初始 zoom = Vector2(5,5)（场景里已设置；这里兜底一次）
	zoom = Vector2(5, 5)
	_set_zoom_scalar(zoom.x)
	set_process(true)
	_default_zoom = zoom

func _unhandled_input(event: InputEvent) -> void:
	# 1) 鼠标按键 + 滚轮缩放
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.is_echo():
			return

		# 左键：Cmd/Ctrl 按住时进入/退出鼠标拖拽平移
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed and (Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_CTRL)):
				_panning = true
				_last_mouse_pos = get_viewport().get_mouse_position()
				return
			if not mouse_button.pressed:
				_panning = false
				return

		# 鼠标滚轮缩放：每格 ×step 或 ÷step，clamp 在 [zoom_min, zoom_max]
		if mouse_button.pressed:
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_saw_wheel_this_frame = true
				_set_zoom_scalar(zoom.x * wheel_zoom_step)
				return
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_saw_wheel_this_frame = true
				_set_zoom_scalar(zoom.x / wheel_zoom_step)
				return

	# 2) 触控板两指拖动：PanGesture（平移）
	if event is InputEventPanGesture:
		# 若同一帧检测到鼠标滚轮事件，则忽略 PanGesture，避免滚轮触发平移。
		if _saw_wheel_this_frame:
			return
		var pan := event as InputEventPanGesture
		# Cmd/Ctrl + 两指拖动：缩放
		if Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_CTRL):
			var dy := clampf(pan.delta.y, -trackpad_delta_clamp, trackpad_delta_clamp)
			var factor := pow(trackpad_zoom_step, -dy * trackpad_zoom_sensitivity)
			_set_zoom_scalar(zoom.x * factor)
		else:
			_trackpad_pan_accum += pan.delta
		return

	# 3) 触控板捏合：MagnifyGesture（factor 接近 1.0，>1 通常放大，<1 缩小）
	if event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		_set_zoom_scalar(zoom.x * magnify.factor)
		return

	# 4) Space：重置缩放到初始值
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_SPACE:
			# 0.5 秒回到初始缩放，避免“瞬间跳变”的生硬感
			if _reset_tween != null and _reset_tween.is_running():
				_reset_tween.kill()
			_reset_tween = create_tween()
			_reset_tween.tween_property(self, "zoom", _default_zoom, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			return

	# 鼠标拖拽平移在 _process 里按帧计算（更稳定，减少“掉帧感”）

func _process(_delta: float) -> void:
	# 每帧重置滚轮标记（用于避免滚轮触发 PanGesture 平移）
	_saw_wheel_this_frame = false

	# 1) 触控板两指拖动平移
	if _trackpad_pan_accum != Vector2.ZERO:
		var z_trackpad := maxf(zoom.x, 0.0001)
		var delta_pan := (_trackpad_pan_accum / z_trackpad) * trackpad_pan_speed
		if invert_trackpad_pan:
			position += delta_pan
		else:
			position -= delta_pan
		_trackpad_pan_accum = Vector2.ZERO

	# 2) Space + 左键拖拽平移（鼠标）
	if not _panning:
		return
	if not (Input.is_key_pressed(KEY_META) or Input.is_key_pressed(KEY_CTRL)) or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_panning = false
		return

	var current_mouse_pos := get_viewport().get_mouse_position()
	var delta_screen := current_mouse_pos - _last_mouse_pos
	_last_mouse_pos = current_mouse_pos
	if delta_screen == Vector2.ZERO:
		return

	var z_mouse := maxf(zoom.x, 0.0001)
	var target_pos := position - (delta_screen / z_mouse) * mouse_pan_speed
	if mouse_pan_smoothness <= 0.0:
		position = target_pos
	else:
		position = position.lerp(target_pos, clampf(mouse_pan_smoothness, 0.0, 1.0))

func _set_zoom_scalar(z: float) -> void:
	z = clampf(z, zoom_min, zoom_max)
	zoom = Vector2(z, z)
