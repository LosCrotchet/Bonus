@tool

class_name DefaultButton extends Button

@export var font_size: int = 40
@onready var top_layer = $TopLayer

# 定义Y轴的偏移量 (根据你的按钮实际大小可微调数值)
const DEFAULT_Y : float = -8.0   # 对应 CSS 的 translateY(-0.2em)
const HOVER_Y : float = -14.0    # 对应 CSS 的 translateY(-0.33em)
const ACTIVE_Y : float = 0.0     # 对应 CSS 的 translateY(0)

var tween : Tween

func _ready():
	# 初始化 TopLayer 的位置
	top_layer.position.y = DEFAULT_Y
	$TopLayer/Label.label_settings.font_size = font_size
	
	# 动态连接信号 (如果你已经在编辑器界面连线了，这里可以省略)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

# 核心动画函数
func animate_to(target_y: float):
	if tween and tween.is_valid():
		tween.kill() # 终止正在进行的动画，防止状态冲突
		
	# 创建补间动画，设置缓动曲线对应 CSS 的 "ease"
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 0.1秒动画时间，对应 CSS 的 "0.1s"
	tween.tween_property(top_layer, "position:y", target_y, 0.1)

# --- 信号处理 ---

func _on_mouse_entered():
	# 如果鼠标移入时按钮不是按下的状态，才触发 Hover 动画
	if not button_pressed:
		animate_to(HOVER_Y)

func _on_mouse_exited():
	# 鼠标移出时恢复默认
	if not button_pressed:
		animate_to(DEFAULT_Y)

func _on_button_down():
	# 按下时压到底部
	animate_to(ACTIVE_Y)

func _on_button_up():
	# 松开时，如果鼠标还在按钮范围内，就回到 Hover 状态，否则回到默认状态
	if is_hovered():
		animate_to(HOVER_Y)
	else:
		animate_to(DEFAULT_Y)

func _physics_process(delta: float) -> void:
	$TopLayer/Label.text = text
