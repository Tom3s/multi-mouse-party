package main

import "core:fmt"
import "core:c"
import "core:c/libc"
import "core:math/linalg"
import "core:mem"
import "core:os"

import mm "manymouse"
import rl "vendor:raylib"

import Signal "signal"

WINDOW_SIZE :: [2]c.int{1280, 720};

App_State :: struct{
    gpa: mem.Allocator,
    frame_alloc: mem.Allocator,

    arena: mem.Arena,
}

init_app_state :: proc(state: ^App_State){
    state.gpa = os.heap_allocator();
    buffer := make([]u8, 50 * mem.Megabyte, allocator = state.gpa); // I dont care to free
    mem.arena_init(&state.arena, buffer);
    state.frame_alloc = mem.arena_allocator(&state.arena);
}

Cursor :: struct {
	position: v2,
}

calculate_motion_vector :: proc(event: mm.Event) -> v2 {
	v: v2 = {}
	
	if (event.item == 0) {
		v.x += cast(f32) event.value;
	} else if (event.item == 1) {
		v.y += cast(f32) event.value;	
	}

	return v;
}

Player :: struct {
	device_id: u32,
	cursor: Cursor,
}

main :: proc(){
    context.allocator      = mem.panic_allocator();
    context.temp_allocator = mem.panic_allocator();

    rl.InitWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, "Multi Mouse Party (DEBUG)");
    defer rl.CloseWindow();

	nr_mouses := mm.Init();
	defer mm.Quit();

	event: mm.Event = {}

    state: App_State;
    init_app_state(&state);

	p1: Player = {
		cursor = {
			position = {
				cast(f32) WINDOW_SIZE.x / 2,
				cast(f32) WINDOW_SIZE.y / 2,
			}
		},
	}
	p2: Player = {
		cursor = {
			position = {
				cast(f32) WINDOW_SIZE.x / 2,
				cast(f32) WINDOW_SIZE.y / 2,
			}
		},
	}

	init_player_device(&p1);
	init_player_device(&p2);
	// players: []Player = ;

	outline_shader1 := rl.LoadShader(nil, "shaders/outline_shader.fs");
	outline_shader2 := rl.LoadShader(nil, "shaders/outline_shader.fs");
	treshold: f32 = 0.5;
	outline_width: f32 = 0.3;
	outline_color: v4 = {0, 0, 0, 1.0};
	main_color1: v4 = {0.8, 0.2, 0.3, 1.0};
	main_color2: v4 = {0.0, 0.6, 0.7, 1.0};

	rl.SetShaderValue(outline_shader1, 0, &treshold, .FLOAT);
	rl.SetShaderValue(outline_shader1, 1, &outline_width, .FLOAT);
	rl.SetShaderValue(outline_shader1, 3, &outline_color, .VEC4);
	rl.SetShaderValue(outline_shader2, 0, &treshold, .FLOAT);
	rl.SetShaderValue(outline_shader2, 1, &outline_width, .FLOAT);
	rl.SetShaderValue(outline_shader2, 3, &outline_color, .VEC4);
	rl.SetShaderValue(outline_shader1, 2, &main_color1, .VEC4);
	rl.SetShaderValue(outline_shader2, 2, &main_color2, .VEC4);

	cursor_texture := rl.LoadTexture("images/main_cursor.png");

    for !rl.WindowShouldClose(){
        err := free_all(state.frame_alloc);

		/*
			Kell ide a for, mert van h tobb event-be
			kuldi az inputot a driver (pl ha >500hz az eger szenzor)
			s olyankor input lag lesz
		*/
		for (mm.PollEvent(&event) == 1) { // DO NOT DELETE 
			if (p1.device_id == event.device) {
				if (event.type == .Relmotion) {
					relmotion := calculate_motion_vector(event);
					p1.cursor.position += relmotion;
				}
			}
			if (p2.device_id == event.device) {
				if (event.type == .Relmotion) {
					relmotion := calculate_motion_vector(event);
					p2.cursor.position += relmotion;
				}
			}
		}

        update(&state);

        buffer := make_slice([]u8, 50 * mem.Megabyte, allocator = state.frame_alloc);

        rl.BeginDrawing();
			rl.ClearBackground(rl.GetColor(0x202020FF));
			rl.BeginShaderMode(outline_shader1);
			rl.DrawTexture(
				cursor_texture, 
				cast(i32) p1.cursor.position.x,
				cast(i32) p1.cursor.position.y,
				rl.GetColor(0xFF_FF_FF_FF)
			);
			rl.EndShaderMode();
			rl.BeginShaderMode(outline_shader2);
				rl.DrawTexture(
					cursor_texture, 
						cast(i32) p2.cursor.position.x,
						cast(i32) p2.cursor.position.y,
						rl.GetColor(0xFF_FF_FF_FF)
					);
			rl.EndShaderMode();
            draw(&state);
        rl.EndDrawing();

    }

}

init_player_device :: proc(p: ^Player) {
	event: mm.Event = {};
	for {
		if (mm.PollEvent(&event) == 0) {
			continue;
		}
		
		if (event.type == .Button && event.value == 1) {
			p.device_id = event.device;
			break;
		}
	}
}

update :: proc(state: ^App_State){
}

draw :: proc(state: ^App_State){
}
