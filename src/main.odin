package main

import "core:fmt"
import "core:c"
import "core:c/libc"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:strings"
import "core:time"

import rl "vendor:raylib"

import mm     "src:manymouse"
import mi     "src:mouse_input"
import Signal "src:signal"

WINDOW_SIZE :: [2]c.int{1280, 720};
NR_PLAYERS :: 2;

App_State :: struct{
    gpa: mem.Allocator,
    frame_alloc: mem.Allocator,
	players: [dynamic]Player,

	targets: [dynamic]Target,

	shaders: struct {
		cursor_material: rl.Shader, 
	},
	textures: struct {
		cursor_texture: rl.Texture2D,
		cursor_texture_size: [2]f32,
	},

	// delta_time: time.Duration, // might wanna keep Duration representation
	delta_time: f64,
	delta_last_tick: time.Tick,
	

    // Never touch this
    arena: mem.Arena,
}

init_app_state :: proc(state: ^App_State){
    state.gpa = os.heap_allocator();
    buffer := make([]u8, 50 * mem.Megabyte, allocator = state.gpa); // I dont care to free
    mem.arena_init(&state.arena, buffer);
    state.frame_alloc = mem.arena_allocator(&state.arena);

	state.players = make([dynamic]Player, 0, state.gpa);
	state.targets = make([dynamic]Target, 0, state.gpa);
	for i in 0..<8 {
		append(&state.targets, make_target());
	}


	state.shaders.cursor_material = rl.LoadShader(nil, "shaders/outline_shader.fs");

	state.textures.cursor_texture = rl.LoadTexture("images/main_cursor.png");
	state.textures.cursor_texture_size = {
		cast(f32) state.textures.cursor_texture.width,
		cast(f32) state.textures.cursor_texture.height,
	}

	state.delta_last_tick = time.tick_now();
}

Cursor :: struct {
	position: v2,
	velocity: v2,
	pressed: bool,
	just_pressed: bool,
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
	score: f32,
}

DEFAULT_COLORS := [?]v4 {
	{ 1, 0.06, 0.08627451, 1.0}, 
	{ 0.0627451, 0.57254905, 0.7745098, 1.0},
	{ 0.65882355, 0.070588239, 0.53333336, 1.0},
	{ 0.188235298, 0.71764708, 0.14117648, 1.0},
	{ 0.72156864, 0.6, 0.0627451, 1.0},
	{ 0.84705883, 0.6509804, 0.64705884, 1.0},
};


main :: proc(){
    context.allocator      = mem.panic_allocator();
    context.temp_allocator = mem.panic_allocator();

    rl.InitWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, "Multi Mouse Party (DEBUG)");
    defer rl.CloseWindow();

	rl.SetMousePosition(rl.GetScreenWidth() / 2, rl.GetScreenHeight() / 2);
	rl.HideCursor();
	rl.DisableCursor();
	defer rl.ShowCursor();
	defer rl.EnableCursor();

	// Eloszor kell a RayLib Init

	nr_mouses := mm.Init();
	defer mm.Quit();
	

    state: App_State;
    init_app_state(&state);

	

	for i in 0..<NR_PLAYERS {

		builder: strings.Builder; 
		strings.builder_init(&builder, allocator = state.frame_alloc);

		strings.write_string(&builder, "Press Click to assign mouse to player ");
		strings.write_int(&builder, i + 1);

		rl.BeginDrawing();
		rl.ClearBackground(rl.GetColor(BACKGROUND_CLEAR_COLOR));
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

	for &target in state.targets {
		respawn_target(&target);
	}

	// Main loop
    for !rl.WindowShouldClose(){
        err := free_all(state.frame_alloc);

        // buffer := make_slice([]u8, 50 * mem.Megabyte, allocator = state.frame_alloc);

        update(&state);


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
	p.color = DEFAULT_COLORS[id];
	p.device_id = get_device_for_assign();
	// TODO: Check if already used
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

update_input :: proc(state: ^App_State) {
	/*
		Kell ide a for, mert van h tobb event-be
		kuldi az inputot a driver (pl ha >500hz az eger szenzor)
		s olyankor input lag lesz
	*/
	for &p in state.players {
		p.cursor.velocity = {0, 0};
		p.cursor.pressed = false;
		p.cursor.just_pressed = false;
	}

	event: mm.Event = {}

	for mm.PollEvent(&event) == 1 { // DO NOT DELETE 
		for &p in state.players {
			if p.device_id == event.device {
				if event.type == .Relmotion {
					relmotion := calculate_motion_vector(event);
					p.cursor.position += relmotion;
					p.cursor.velocity += relmotion;
				} else if event.type == .Button {
					p.cursor.pressed = event.value == 1;
					p.cursor.just_pressed = p.cursor.pressed
				}
				break;
			}
		}	
	}
}

update :: proc(state: ^App_State){
	update_input(state);
	update_delta_time(state);

	for &target in state.targets {
		update_target(&target, state^);
		for &p in state.players {
			if p.cursor.just_pressed && \
				check_target_collision(target, p.cursor.position) {
				p.score += target.lifetime / target.max_lifetime * DEFAULT_TARGET_SCORE;
				register_target_hit(&target);
				break;
			}
		}
	}
}

update_delta_time :: proc(state: ^App_State) {
	current_tick := time.tick_now();

	// state.delta_time = time.tick_diff(state.delta_last_tick, current_tick);
	delta_tick := time.tick_diff(state.delta_last_tick, current_tick);
	state.delta_time = time.duration_seconds(delta_tick);
	state.delta_last_tick = current_tick;
}

BACKGROUND_CLEAR_COLOR :: 0x202020FF;
CURSOR_SCALE :: 0.25;
draw :: proc(state: ^App_State){
	rl.ClearBackground(rl.GetColor(BACKGROUND_CLEAR_COLOR));


	for target in state.targets {
		draw_target(target);
	}

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

	for &p, index in state.players {
		builder: strings.Builder; 
		strings.builder_init(&builder, allocator = state.frame_alloc);

		strings.write_string(&builder, "Player ");
		
		strings.write_int(&builder, cast(int) p.id);
		strings.write_string(&builder, " score: ");
		
		strings.write_int(&builder, cast(int) p.score);
		
		rl.DrawText(
			strings.to_cstring(&builder),
			50, 50 + cast(i32) index * 50,
			25,
			rl.ColorFromNormalized(p.color)
		)
	}

}
