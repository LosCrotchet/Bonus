shader_type canvas_item;

// 圆圈数量
uniform int count : hint_range(1, 32) = 10;
// 最小半径
uniform float min_radius : hint_range(0.01, 0.1) = 0.02;
// 最大半径
uniform float max_radius : hint_range(0.05, 0.3) = 0.1;
// 移动速度范围
uniform float speed_min : hint_range(0.1, 0.5) = 0.2;
uniform float speed_max : hint_range(0.5, 2.0) = 1.0;
// 生命周期（秒）
uniform float life_time : hint_range(1.0, 5.0) = 3.0;
// 圆圈颜色
uniform vec4 circle_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 边界留白（防止圆圈在边界处被切断）
uniform float margin : hint_range(0.0, 0.3) = 0.1;

// 伪随机数生成器
float rand(float seed) {
    return fract(sin(seed * 43758.5453) * 16777215.0 / 16777216.0);
}

void fragment() {
    vec2 uv = (UV - vec2(0.5)) * 2.0; // 居中并转换为[-1,1]范围
    vec4 final_color = vec4(0.0);
    float time_cycle = TIME / life_time; // 生命周期循环
    
    for (int i = 0; i < count; i++) {
        // 为每个圆生成唯一随机种子
        float seed = float(i) * 100.0;
        
        // 生成随机属性
        float radius = mix(min_radius, max_radius, rand(seed + 1.0));
        vec2 start_pos = vec2(
            mix(-1.0 + margin, 1.0 - margin, rand(seed + 2.0)),
            mix(-1.0 + margin, 1.0 - margin, rand(seed + 3.0))
        );
        vec2 direction = vec2(
            mix(-1.0, 1.0, rand(seed + 4.0)),
            mix(-1.0, 1.0, rand(seed + 5.0))
        );
        direction = normalize(direction); // 标准化方向向量
        float speed = mix(speed_min, speed_max, rand(seed + 6.0));
        float time_offset = rand(seed + 7.0); // 时间偏移使圆圈不同步
        
        // 计算当前生命周期进度 (0.0 - 1.0)
        float life_progress = fract(time_cycle + time_offset);
        
        // 计算消散透明度（最后0.2秒开始淡出）
        float alpha = 1.0 - smoothstep(0.8, 1.0, life_progress);
        
        // 计算当前位置（基于生命周期进度）
        vec2 current_pos = start_pos + direction * speed * life_progress * life_time;
        
        // 计算到圆心的距离
        float dist = distance(uv, current_pos);
        
        // 创建带抗锯齿的圆形
        float circle = smoothstep(radius, radius * 0.95, dist);
        
        // 累积颜色（使用加法混合）
        final_color += circle_color * circle * alpha;
    }
    
    // 输出最终颜色（限制最大值防止过曝）
    COLOR = vec4(final_color.rgb, min(final_color.a, 1.0));
}