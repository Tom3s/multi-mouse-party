package main

import "core:math/rand"
import "core:fmt"

Target_Minigame_State :: struct {
	time_since_last_spawn: f64,
	current_wave: int,

	targets: [dynamic]Target,
}


TARGET_GRID_SIZE :: [2]i32{7, 4};
TARGET_ROUNDS_TILL_MAX :: 10;


spawn_targets_in_grid :: proc(state: ^App_State, nr_targets: int) {
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

		target.lifetime = target.max_lifetime;
		target.enabled = true;

		append(&state.target_state.targets, target);
	}

}

@private
MAX_INDICES :: TARGET_GRID_SIZE.x * TARGET_GRID_SIZE.y;

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
}