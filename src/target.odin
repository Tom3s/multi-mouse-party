package main

import "core:fmt"
import "core:math/rand"
import "core:math/linalg"
import rl "vendor:raylib"

DEFAULT_TARGET_SIZE :: 64;
DEFAULT_TARGET_LIFETIME :: 3.0;
TARGET_RESPAWN_TRESHOLD :: 1.0;
TARGET_GRAVITY :: 1150.0;

DEFAULT_TARGET_SCORE :: 5;

Target_Type :: enum {
	STATIC,
	JUMPING,
	ON_PATH,
	ON_ROPE,
}

Target :: struct {
	type: Target_Type,

	position: v2,
	velocity: v2,
	size: f32,
	enabled: bool,
	lifetime: f32,
	max_lifetime: f32,
}

make_target :: proc() -> Target {
	return Target{
		type = .STATIC,
		position = {0,0},
		velocity = {0,0},
		size = DEFAULT_TARGET_SIZE,
		enabled = false,
		lifetime = 0.0,
		max_lifetime = DEFAULT_TARGET_LIFETIME,
	};
}

update_target :: proc(target: ^Target, state: App_State) {
	target.lifetime -= cast(f32) state.delta_time;

	#partial switch (target.type) {
		case .STATIC:
			if target.lifetime <= 0.0 {
				target.enabled = false;
			} 

		case .JUMPING:
			target.velocity.y += TARGET_GRAVITY * cast(f32) state.delta_time;
			target.position += target.velocity * cast(f32) state.delta_time;

			if target.velocity.y > 0 && target.position.y > cast(f32) WINDOW_SIZE.y + target.size {
				target.enabled = false;
			}
			// fmt.println("Jumping target: ", target.position);

		case:
			fmt.println("[target.odin] Unhandled target type");
	}
}

respawn_target :: proc(target: ^Target) {
	target.enabled = true;
	target.lifetime = target.max_lifetime;
	target.position = {
		rand.float32_range(
			cast(f32) target.size, 
			cast(f32) WINDOW_SIZE.x - target.size
		),
		rand.float32_range(
			cast(f32) target.size, 
			cast(f32) WINDOW_SIZE.y - target.size
		)
	}
}

register_target_hit :: proc(target: ^Target) {
	target.lifetime = 0.0;
	target.enabled = false;
}

get_target_score :: proc(target: Target) -> f32 {
	return linalg.ceil(target.lifetime / target.max_lifetime * DEFAULT_TARGET_SCORE);
}

check_target_collision :: proc(target: Target, position: v2) -> bool {
	if !target.enabled {
		return false;
	}
	return linalg.distance(
		target.position,
		position
	) <= cast(f32) target.size;
}

draw_target :: proc(target: Target) {
	if !target.enabled {
		return;
	}

	full_health_color: [4]u8 = {0xDD, 0xAA, 0x20, 0xFF};
	no_health_color: [4]u8 = {0x40, 0x40, 0x40, 0xFF};

	t := target.lifetime / target.max_lifetime;

	color := mix_color(no_health_color, full_health_color, t);

	rl.DrawCircle(
		cast(i32) target.position.x,
		cast(i32) target.position.y,
		target.size,
		cast(rl.Color) color,
	)
}

mix_color :: proc(a, b: [4]u8, t: f32) -> [4]u8 {
	return {
		lerp_u8(a.r, b.r, t),
		lerp_u8(a.g, b.g, t),
		lerp_u8(a.b, b.b, t),
		0xFF
	}
}

mix_color_with_alpha :: proc(a, b: [4]u8, t: f32) -> [4]u8 {
	return {
		lerp_u8(a.r, b.r, t),
		lerp_u8(a.g, b.g, t),
		lerp_u8(a.b, b.b, t),
		lerp_u8(a.a, b.a, t),
	}
}

lerp_u8 :: proc(a, b: u8, t: f32) -> u8 {
	out := cast(f32) a * (1.0 - t) + cast(f32) b * t;

	out = linalg.clamp(out, 0.0, 255.0);

	return cast(u8) out;
}