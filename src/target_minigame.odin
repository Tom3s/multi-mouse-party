package main

import "core:math/linalg"
import "core:math/rand"
import "core:fmt"

Target_Minigame_Phase :: enum {
	GRID,
	ALIEN,
	JUMPING,
	REACTION,
	LIGHTS,
}

Target_Minigame_State :: struct {
	time_since_last_spawn: f64,
	current_wave: int,

	targets_to_spawn: int,

	phase: Target_Minigame_Phase,

	targets: [dynamic]Target,
	targets_hit: int,
}


TARGET_GRID_SIZE :: [2]i32{7, 4};
TARGET_ROUNDS_TILL_MAX :: 10;

@private
JUMPING_SPAWN_COOLDOWN :: 5.0;

spawn_targets_in_grid :: proc(
	state: ^App_State, 
	nr_targets: int,
	target_lifetime: f32,
) {
	grid_dimensions_padded := TARGET_GRID_SIZE + {1, 1};
	grid_tile_size := min(
		cast(f32) WINDOW_SIZE.x / cast(f32) grid_dimensions_padded.x,
		cast(f32) WINDOW_SIZE.y / cast(f32) grid_dimensions_padded.y,
	)

	padding := (WINDOW_SIZE - grid_dimensions_padded * cast(i32) grid_tile_size) / 2;

	indices := get_random_indices(state, nr_targets);

	for i in 0..<nr_targets {
		position_on_grid: [2]int = {
			indices[i] % cast(int) TARGET_GRID_SIZE.x,
			indices[i] / cast(int) TARGET_GRID_SIZE.x,
		}

		target := make_target();
		target.size = grid_tile_size * 0.4;
		target.position = {
			cast(f32) padding.x + grid_tile_size * cast(f32)(position_on_grid.x + 1),
			cast(f32) padding.y + grid_tile_size * cast(f32)(position_on_grid.y + 1),
		}

		target.max_lifetime = target_lifetime;
		target.lifetime = target.max_lifetime;
		target.enabled = true;

		append(&state.target_state.targets, target);
	}

}

spawn_jumping_target :: proc(
	state: ^App_State, 
) {
	target := make_target()
	target.enabled = true;
	target.type = .JUMPING;
	// -1200 ~ middle
	// -1300 just top of screen
	// => +-100

	target.velocity = {0, -1200};
	
	y_velocity_offset := rand.float32_range(-100, 100);
	target.velocity.y += y_velocity_offset;
	target.position.y = cast(f32) WINDOW_SIZE.y + target.size;

	target.position.x = rand.float32_range(
		0, cast(f32) WINDOW_SIZE.x
	)
	x_velocity_offset := -(target.position.x - (cast(f32) WINDOW_SIZE.x / 2));
	target.velocity.x += x_velocity_offset;



	fmt.println("New target pos: ", target.position, " ; velocity: ", target.velocity);

	append(&state.target_state.targets, target);
}

@private
MAX_INDICES :: TARGET_GRID_SIZE.x * TARGET_GRID_SIZE.y;

@private
get_random_indices :: proc(state: ^App_State, nr_indices: int) -> [dynamic]int {
	// TODO: make it safe
	// if nr_indices > cast(int) MAX_INDICES {
	// 	nr_indices = cast(int) MAX_INDICES;
	// }
	
	indices: [dynamic]int = make([dynamic]int, 0, state.frame_alloc);
	
	used_indices: [MAX_INDICES]bool;

	if nr_indices <= (cast(int) MAX_INDICES / 2) {
		for i in 0..<nr_indices {
			for {
				random_index := rand.int31_max(MAX_INDICES);
				if used_indices[random_index] do continue;
				
				used_indices[random_index] = true;
				break;
			}
		}
	} else {
		for &index in used_indices {
			index = true;
		}
		for i in 0..<(cast(int) MAX_INDICES - nr_indices) {
			for {
				random_index := rand.int31_max(MAX_INDICES);
				if !used_indices[random_index] do continue;
				
				used_indices[random_index] = false;
				break;
			}
		}
	}

	for i in 0..<MAX_INDICES {
		if used_indices[i] {
			append(&indices, cast(int) i);
		}
	}

	return indices;
}

update_target_state :: proc(state: ^App_State) {
	state.target_state.time_since_last_spawn += state.delta_time;

	for &target in state.target_state.targets {
		update_target(&target, state^);
	}

	if all_targets_hit(state^) {
		state.target_state.time_since_last_spawn = max(
			DEFAULT_TARGET_LIFETIME,
			state.target_state.time_since_last_spawn,
		);
	}

	// Grid Logic
	/*
	if state.target_state.time_since_last_spawn > DEFAULT_TARGET_LIFETIME + TARGET_RESPAWN_TRESHOLD {
		clear(&state.target_state.targets);
		
		max_targets := TARGET_GRID_SIZE.x * TARGET_GRID_SIZE.y;
		targets_to_spawn := linalg.lerp(
			5.0, cast(f64) max_targets, 
			linalg.clamp((cast(f64) state.target_state.current_wave / TARGET_ROUNDS_TILL_MAX), 0, 1),
		)
		target_lifetime := linalg.lerp(
			3.0, 1.0, 
			linalg.clamp((cast(f64) state.target_state.current_wave / (TARGET_ROUNDS_TILL_MAX * 2)), 0, 1),
		)
		spawn_targets_in_grid(
			state, 
			cast(int) targets_to_spawn,
			cast(f32) target_lifetime,
		);
		state.target_state.current_wave += 1;
		state.target_state.time_since_last_spawn = 0.0;
		state.target_state.targets_hit = 0;
	}
	*/

	// Jumping Logic
	if state.target_state.time_since_last_spawn > JUMPING_SPAWN_COOLDOWN {
		clear(&state.target_state.targets);

		// spawn_jumping_target(state);

		state.target_state.time_since_last_spawn = 0.0;
		state.target_state.targets_to_spawn = 5;
	}
	
	if state.target_state.phase == .JUMPING {
		if state.target_state.time_since_last_spawn > 0.35 \
			&& state.target_state.targets_to_spawn > 0 {
			spawn_jumping_target(state);
			state.target_state.time_since_last_spawn = 0.0;
			state.target_state.targets_to_spawn -= 1;

		}
	}
}

all_targets_hit :: proc(state: App_State) -> bool {
	return state.target_state.targets_hit == len(state.target_state.targets);
}
