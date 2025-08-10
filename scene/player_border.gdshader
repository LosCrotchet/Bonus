shader_type canvas_item;

uniform vec4 color: source_color = vec4(1.0);
uniform vec2 size;
uniform float width;
uniform float speed = 1.0;
uniform float frequency = 2.0;

vec2 calculate(vec2 start, float len){
	while (len > 0.0){
		if (start.y == 1.0){
			if (1.0 >= start.x + len){
				return vec2(start.x + len, 1.0);
			}
			len -= (1.0 - start.x);
			start.x = 1.0;
		}
		if (start.x == 1.0){
			if (start.y >= len){
				return vec2(1.0, start.y - len);
			}
			len -= start.y;
			start.y = 0.0;
		}
		if (start.y == 0.0){
			if (start.x >= len){
				return vec2(start.x - len, 0.0);
			}
			len -= start.x;
			start.x = 0.0;
		}
		if (start.x == 0.0){
			if (1.0 - start.y >= len){
				return vec2(0.0, start.y + len);
			}
			len -= (1.0 - start.y);
			start.y = 1.0;
		}
	}
	return start;
}

void fragment()
{
	vec4 color_outline;
	vec4 mask = vec4(1.0, 1.0, 1.0, 0.0);
	color_outline = vec4(color.rgb, color.a);
	
	vec2 head, tail;
	
	float widx = width / size.x, widy = width / size.y;
	float is_flipped = 1.0;
	
	//float factor = (sin(TIME / 100.0) * 0.2 + 2.0) * 100.0;
	//factor = 100.0;
	float len;
	//len = 4.0 * (0.005 * float(int(TIME*speed*factor) % 200));
	//len = 2.0 * (sin(TIME) + 0.5*sin(2.0*TIME) + 1.5);
	len = 1.28 * (atan(3.0*tan(TIME)) + 1.57);

	head = calculate(vec2(1.0, 1.0), len);
	//tail = calculate(vec2(0.0, 1.0), 2.0 * (is_flipped * sin(TIME) + 1.0));
	tail = calculate(vec2(0.0, 1.0), len);
	
	if (head.x == 1.0){
		if (tail.x == 1.0){
			if (UV.x > 1.0-widx && UV.y > head.y && UV.y < tail.y){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
			if (tail.y < head.y){
				if (UV.x > 1.0-widx && (UV.y > head.y || UV.y < tail.y) || UV.y > 1.0-widy || UV.x < widx || UV.y < widy)
					mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.y == 1.0){
			if (UV.x > 1.0-widx && UV.y > head.y || UV.y > 1.0-widy && UV.x > tail.x){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.x == 0.0){
			if (UV.x > 1.0-widx && UV.y > head.y || UV.y > 1.0-widy || UV.x < widx && UV.y > tail.y){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.y == 0.0){
			if (UV.x > 1.0-widx && UV.y > head.y || UV.y > 1.0-widy || UV.x < widx || UV.y < widy && UV.x < tail.x){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
	}
	else if (head.y == 0.0){
		if (tail.y == 0.0){
			if (UV.y < widy && UV.x > head.x && UV.x < tail.x){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
			if (tail.x < head.x){
				if (UV.y < widy && (UV.x > head.x || UV.x < tail.x) || UV.y > 1.0-widy || UV.x > 1.0-widx || UV.y < widy)
					mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.x == 1.0){
			if (UV.y < widy && UV.x > head.x || UV.x > 1.0-widx && UV.y < tail.y){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.y == 1.0){
			if (UV.y < widy && UV.x > head.x || UV.x > 1.0-widx || UV.y > 1.0-widy && UV.x > tail.x){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.x == 0.0){
			if (UV.y < widy && UV.x > head.x || UV.y > 1.0-widy || UV.x > 1.0-widx || UV.x < widx && UV.y > tail.y){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
	}
	else if (head.x == 0.0){
		if (tail.x == 0.0){
			if (UV.x < widx && UV.y < head.y && UV.y > tail.y){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
			if (tail.y > head.y){
				if (UV.x < widx && (UV.y > tail.y || UV.y < head.y) || UV.y > 1.0-widy || UV.y < widy || UV.x > 1.0-widx)
					mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.y == 0.0){
			if (UV.x < widx && UV.y < head.y || UV.y < widy && UV.x < tail.x){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.x == 1.0){
			if (UV.x < widx && UV.y < head.y || UV.y < widy || UV.x > 1.0-widx && UV.y < tail.y){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.y == 1.0){
			if (UV.x < widx && UV.y < head.y || UV.y < widy || UV.x > 1.0-widx || UV.y > 1.0-widy && UV.x > tail.x){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
	}
	else if (head.y == 1.0){
		if (tail.y == 1.0){
			if (UV.y > 1.0-widy && UV.x < head.x && UV.x > tail.x){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
			if (tail.x > head.x){
				if (UV.y > 1.0-widy && (UV.x > tail.x || UV.x < head.x) || UV.x > 1.0-widx || UV.y < widy || UV.x < widx)
					mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.x == 0.0){
			if (UV.y > 1.0-widy && UV.x < head.x || UV.x < widx && UV.y > tail.y){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.y == 0.0){
			if (UV.y > 1.0-widy && UV.x < head.x || UV.x < widx || UV.y < widy && UV.x < tail.x){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
		else if (tail.x == 1.0){
			if (UV.y > 1.0-widy && UV.x < head.x || UV.x < widx || UV.y < widy || UV.x > 1.0-widx && UV.y < tail.y){
				mask = vec4(1.0, 1.0, 1.0, 1.0);
			}
		}
	}
	
	COLOR = mask * color_outline;
}

//void vertex()
//{
//	VERTEX += vec2(cos(TIME)*100.0, 0);
//}