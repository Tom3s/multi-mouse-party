package main

import "core:fmt"
import "core:c"
import "core:c/libc"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:strings"

import mm "manymouse"
import rl "vendor:raylib"

import Signal "signal"

WINDOW_SIZE :: [2]c.int{1280, 720};
NR_PLAYERS :: 2;

App_State :: struct{
    gpa: mem.Allocator,
    frame_alloc: mem.Allocator,

    arena: mem.Arena,

	players: [dynamic]Player,

	shaders: struct {
		cursor_material: rl.Shader, 
	},

	textures: struct {
		cursor_texture: rl.Texture2D,
		cursor_texture_size: [2]f32,
	}
}

init_app_state :: proc(state: ^App_State){
    state.gpa = os.heap_allocator();
    buffer := make([]u8, 50 * mem.Megabyte, allocator = state.gpa); // I dont care to free
    mem.arena_init(&state.arena, buffer);
    state.frame_alloc = mem.arena_allocator(&state.arena);

	state.players = make([dynamic]Player, 0, state.gpa);

	state.shaders.cursor_material = rl.LoadShader(nil, "shaders/outline_shader.fs");

	state.textures.cursor_texture = rl.LoadTexture("images/main_cursor.png");
	state.textures.cursor_texture_size = {
		cast(f32) state.textures.cursor_texture.width,
		cast(f32) state.textures.cursor_texture.height,
	}

}

Cursor :: struct {
	position: v2,
	velocity: v2,
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
	id: u32,
	device_id: u32,
	cursor: Cursor,
	color: [4]f32,
}

main :: proc(){
    context.allocator      = mem.panic_allocator();
    context.temp_allocator = mem.panic_allocator();

    rl.InitWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, "Multi Mouse Party (DEBUG)");
    defer rl.CloseWindow();

	// Eloszor kell a RayLib Init

	nr_mouses := mm.Init();
	defer mm.Quit();
	
	event: mm.Event = {}

    state: App_State;
    init_app_state(&state);

	

	for i in 0..<NR_PLAYERS {

		builder: strings.Builder; 
		strings.builder_init(&builder, allocator = state.frame_alloc);

		strings.write_string(&builder, "Press Click to assign mouse to player ");
		strings.write_int(&builder, i + 1);

		rl.BeginDrawing();
		rl.DrawText(
			strings.to_cstring(&builder),
			50, 50,
			25,
			rl.GetColor(0xFF_FF_FF_FF),
		)
		rl.EndDrawing();
		p: Player = {};
		init_player(&p, cast(u32) i);
		append(&state.players, p);
	}

    for !rl.WindowShouldClose(){
        err := free_all(state.frame_alloc);

		update_input(&state, &event);

        update(&state);

        buffer := make_slice([]u8, 50 * mem.Megabyte, allocator = state.frame_alloc);

        rl.BeginDrawing();
			draw(&state);
        rl.EndDrawing();
    }

}

init_player :: proc(p: ^Player, id: u32) {
	p.id = id;
	p.cursor = {
		position = {
			cast(f32) WINDOW_SIZE.x / 2,
			cast(f32) WINDOW_SIZE.y / 2,
		},
		velocity = {},
	};
	p.color = {
		rand.float32(),
		rand.float32(),
		rand.float32(),
		1.0
	}
	p.device_id = get_device_for_assign();
	// Check if already used
	fmt.println("[main.odin] Assigned device ", p.device_id, " to player ", p.id);
}

get_device_for_assign :: proc() -> u32{
	event: mm.Event = {};
	for {
		if (mm.PollEvent(&event) == 0) {
			continue;
		}
		
		if (event.type == .Button && event.value == 1) {
			return event.device;
		}
	}
}

update_input :: proc(state: ^App_State, event: ^mm.Event) {
	/*
		Kell ide a for, mert van h tobb event-be
		kuldi az inputot a driver (pl ha >500hz az eger szenzor)
		s olyankor input lag lesz
	*/
	for &p in state.players {
		p.cursor.velocity = {0, 0};
	}

	for mm.PollEvent(event) == 1 { // DO NOT DELETE 
		for &p in state.players {
			if p.device_id == event.device {
				if event.type == .Relmotion {
					relmotion := calculate_motion_vector(event^);
					p.cursor.position += relmotion;
					p.cursor.velocity += relmotion;
				}
			}
		}	
	}
}

update :: proc(state: ^App_State){
}

BACKGROUND_CLEAR_COLOR :: 0x202020FF;
CURSOR_SCALE :: 0.25;
draw :: proc(state: ^App_State){
	rl.ClearBackground(rl.GetColor(BACKGROUND_CLEAR_COLOR));



	// These could be parameterized
	treshold: f32 = 0.5;
	outline_width: f32 = 0.3;
	outline_color: v4 = {0, 0, 0, 1.0};

	rl.SetShaderValue(state.shaders.cursor_material, 0, &treshold, .FLOAT);
	rl.SetShaderValue(state.shaders.cursor_material, 1, &outline_width, .FLOAT);
	rl.SetShaderValue(state.shaders.cursor_material, 3, &outline_color, .VEC4);
	for &p in state.players {
		rl.SetShaderValue(state.shaders.cursor_material, 2, &p.color, .VEC4);
		
		rl.BeginShaderMode(state.shaders.cursor_material);
			rl.DrawTextureEx(
				state.textures.cursor_texture,
				p.cursor.position /* center */ \ 
					- state.textures.cursor_texture_size /* offset for texture */ \
					* {CURSOR_SCALE, CURSOR_SCALE} / 2 /* scale of offset */,
				0.0, // rotation
				CURSOR_SCALE,
				rl.GetColor(0xFF_FF_FF_FF),
			)
		rl.EndShaderMode();
	}

}
