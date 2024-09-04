package main

import "core:fmt"
import "core:strings"
import "core:math/linalg"
import "core:mem"
import rl "vendor:raylib"

Label_Animation :: enum {
	None,
	Float_Up,
}

LABEL_FLOAT_UP_LIFETIME :: 1.2;

Label :: struct {
	text: string,
	original_position: v2,

	lifetime: f32,

	color: rl.Color,
	text_size: i32, 
	
	outline: i32,
	outline_color: rl.Color,

	animation_type: Label_Animation,

	visible: bool,
}

make_label :: proc(
	text: string = "", 
	text_size: i32 = 24,
	position: v2 = {0, 0}, 
	color: rl.Color = rl.WHITE,
	outline: i32 = 2,
	outline_color: rl.Color = rl.BLACK,
) -> Label {
	return Label{
		text = text,
		original_position = position,
		lifetime = 0.0,
		color = color,
		text_size = text_size,
		animation_type = .None,
		visible = false,
		outline = outline,
		outline_color = outline_color
	}
}

start_label_animation :: proc(label: ^Label, type: Label_Animation) {
	label.animation_type = type;
	label.lifetime = 0.0;
	label.visible = true;
}

update_label_animation :: proc(label: ^Label, delta: f32) {
	label.lifetime += delta;
	if label.lifetime >= LABEL_FLOAT_UP_LIFETIME {
		label.visible = false;
	}
} 

draw_label :: proc (state: ^App_State, label: Label) {
	if !label.visible {
		return;
	}


	out_text := strings.clone_to_cstring(label.text, allocator = state.frame_alloc);
	label_size := rl.MeasureText(out_text, label.text_size);
	t := label.lifetime / LABEL_FLOAT_UP_LIFETIME;
	label_y_offset := ease_out_cubic(t) * cast(f32) label.text_size * 2.5; // TODO: parameterize this constant
	
	position := label.original_position \
		- {cast(f32) label_size / 2, cast(f32) label.text_size / 2} \
		- {0.0, label_y_offset};
	
	color := label.color;

	if t >= 0.5 {
		color_t := remap(t, 0.5, 1.0, 0.0, 1.1);
		color_t = linalg.clamp(color_t, 0.0, 1.0);
		color.a = lerp_u8(color.a, 0, color_t); 
	}

	if label.outline > 0 {
		outline_color := label.outline_color
		if color.a < 255 {
			outline_color.a = color.a / 4;
		}

		rl.DrawText(
			out_text,
			cast(i32) position.x + label.outline, cast(i32) position.y + label.outline,
			label.text_size,
			outline_color
		);
		rl.DrawText(
			out_text,
			cast(i32) position.x - label.outline, cast(i32) position.y - label.outline,
			label.text_size,
			outline_color
		);
		rl.DrawText(
			out_text,
			cast(i32) position.x - label.outline, cast(i32) position.y + label.outline,
			label.text_size,
			outline_color
		);
		rl.DrawText(
			out_text,
			cast(i32) position.x + label.outline, cast(i32) position.y - label.outline,
			label.text_size,
			outline_color
		);
		
		rl.DrawText(
			out_text,
			cast(i32) position.x + label.outline, cast(i32) position.y,
			label.text_size,
			outline_color
		);
		rl.DrawText(
			out_text,
			cast(i32) position.x - label.outline, cast(i32) position.y,
			label.text_size,
			outline_color
		);
		rl.DrawText(
			out_text,
			cast(i32) position.x, cast(i32) position.y + label.outline,
			label.text_size,
			outline_color
		);
		rl.DrawText(
			out_text,
			cast(i32) position.x, cast(i32) position.y - label.outline,
			label.text_size,
			outline_color
		);

	}

	rl.DrawText(
		out_text, // TODO: look up unsafe_clone_to_cstring(..)
		cast(i32) position.x, cast(i32) position.y,
		label.text_size,
		color
	);
}

