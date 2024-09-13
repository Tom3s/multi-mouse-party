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

import mi     "src:mouse_input"
import Signal "src:signal"

WINDOW_SIZE :: [2]c.int{1280, 720};
NR_PLAYERS :: 2;

App_State :: struct{
    gpa: mem.Allocator,
    frame_alloc: mem.Allocator,
	players: [dynamic]Player,

	targets: [dynamic]Target,

	labels: [16]Label,
 
	shaders: struct {
		cursor_material: rl.Shader, 
		outline: rl.Shader,
	},
	textures: struct {
		cursor_texture: rl.Texture2D,
		cursor_texture_size: [2]f32,
		crosshair_textures: [4]rl.Texture2D,
		crosshair_texture_size: [2]f32,
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
	for i in 0..<10 {
		append(&state.targets, make_target());
	}

	for i in 0..<16 {
		state.labels[i] = make_label();
	}


	state.shaders.cursor_material = rl.LoadShader(nil, "shaders/sdf_outline_shader.fs");
	state.shaders.outline = rl.LoadShader(nil, "shaders/general_outline_shader.fs");

	state.textures.cursor_texture = rl.LoadTexture("images/main_cursor.png");
	state.textures.cursor_texture_size = {
		cast(f32) state.textures.cursor_texture.width,
		cast(f32) state.textures.cursor_texture.height,
	}

	state.textures.crosshair_textures[0] = rl.LoadTexture("images/crosshair1.png");
	state.textures.crosshair_textures[1] = rl.LoadTexture("images/crosshair2.png");
	state.textures.crosshair_textures[2] = rl.LoadTexture("images/crosshair3.png");
	state.textures.crosshair_textures[3] = rl.LoadTexture("images/crosshair4.png");
	state.textures.crosshair_texture_size = {
		cast(f32) state.textures.crosshair_textures[0].width,
		cast(f32) state.textures.crosshair_textures[0].height,
	}

	state.delta_last_tick = time.tick_now();
}

Cursor :: struct {
	position: v2,
	velocity: v2,
	pressed: bool,
	just_pressed: bool,
}

Player :: struct {
	id: u32,
	device_id: mi.Device_Id,
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

	// nr_mouses := mm.Init();
	// defer mm.Quit();

	mi.init();
	defer mi.close();

	nr_mouses := mi.detect();
	

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
	fmt.println("[main.odin] Assigned device", p.device_id, "to player", p.id);
}

get_device_for_assign :: proc() -> mi.Device_Id{
	// TODO: add similar functionality to mouse_input
	for {
		mi.update()
		for i in 0..<mi.nr_mouses_no_detect() {
			state := mi.poll(cast(mi.Device_Id) i);
			if state.button[mi.Button_Kind.Left].just_pressed {
				return cast(mi.Device_Id) i;
			}
		}
	}

}

update_input :: proc(state: ^App_State) {
	for &p in state.players {
		p.cursor.velocity = {0, 0};
		// p.cursor.pressed = false;
		p.cursor.just_pressed = false;
	}
	
	mi.update();

	for &p in state.players {
		state: mi.State = mi.poll(p.device_id);
		p.cursor.position += state.relative_motion;
		p.cursor.velocity += state.relative_motion;
		// TODO: don't unnecessarily duplicate state info for player
		p.cursor.pressed = state.button[mi.Button_Kind.Left].pressed
		p.cursor.just_pressed = state.button[mi.Button_Kind.Left].just_pressed

	}	
}

update :: proc(state: ^App_State){
	update_input(state);
	update_delta_time(state);

	for &label in state.labels {
		update_label_animation(&label, cast(f32) state.delta_time);
	}

	
	player_hits: [dynamic]int = make([dynamic]int, NR_PLAYERS, state.frame_alloc);

	for &target in state.targets {
		update_target(&target, state^);
		for &p in state.players {
			if p.cursor.just_pressed && \
				check_target_collision(target, p.cursor.position) {
				score := linalg.ceil(target.lifetime / target.max_lifetime * DEFAULT_TARGET_SCORE);
				// TODO: move score calculation, to allow for multipliers (ex. double, triple hits)
				p.score += score;
				register_target_hit(&target);
				spawn_score_label(
					state,
					// p.cursor.position,
					target.position,
					cast(i32) score,
					rl.ColorFromNormalized(p.color),
				)
				player_hits[p.id] += 1;
				break;
			}
		}
	}

	for hit_count, index in player_hits {
		if hit_count > 1 {
			spawn_combo_label(
				state, 
				state.players[index].cursor.position - {0, 12}, // TODO: remove magic number
				hit_count,
			)
			bonus_score := 1.5 * linalg.pow(2.0, cast(f64) hit_count);
			state.players[index].score += cast(f32) bonus_score;
			spawn_score_label(
				state,
				state.players[index].cursor.position - {0, 24},
				cast(i32) bonus_score,
				rl.WHITE,
			)
		}
	}
}

get_label_from_pool :: proc(state: ^App_State) -> ^Label {
	oldest_label: ^Label = &state.labels[0]; // Potentially unsafe

	for &label in state.labels {
		if !label.visible {
			// select first that's unused
			oldest_label = &label;
			break;
		}
		// failsafe, if all of them are used
		if label.lifetime > oldest_label.lifetime {
			oldest_label = &label;
		}
	}

	return oldest_label;
}

spawn_score_label :: proc(state: ^App_State, position: v2, score: i32, color: rl.Color) {
	label: ^Label = get_label_from_pool(state);

	label.original_position = position
	
	builder: strings.Builder; 
	strings.builder_init(&builder, allocator = state.gpa);

	strings.write_string(&builder, "+");	
	strings.write_int(&builder, cast(int) score);

	label.text = strings.to_string(builder);
	label.text_size = 24;

	label.color = color;

	start_label_animation(label, .Float_Up);
}

spawn_combo_label :: proc(state: ^App_State, position: v2, hits: int) {
	label: ^Label = get_label_from_pool(state);

	label.original_position = position

	// label.text = "Double!";
	switch (hits) {
		case 2:
			label.text = "Double!";
		case 3:
			label.text = "Triple!";
		case 4:
			label.text = "QUADRA!";
		case 5:
			label.text = "PENTA!";
		case:
			label.text = "what?!"

	}
	label.text_size = 48;

	label.color = rl.WHITE;

	start_label_animation(label, .Float_Up);
}

update_delta_time :: proc(state: ^App_State) {
	current_tick := time.tick_now();

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

	// TODO: These could be parameterized
	treshold: f32 = 0.65;
	outline_width: f32 = 0.3;
	outline_color: v4 = {0, 0, 0, 1.0};

	rl.SetShaderValue(state.shaders.cursor_material, 0, &treshold, .FLOAT);
	rl.SetShaderValue(state.shaders.cursor_material, 1, &outline_width, .FLOAT);
	rl.SetShaderValue(state.shaders.cursor_material, 3, &outline_color, .VEC4);
	for &p in state.players {
		rl.SetShaderValue(state.shaders.cursor_material, 2, &p.color, .VEC4);
		
		rl.BeginShaderMode(state.shaders.cursor_material);
			rl.DrawTextureEx(
				state.textures.crosshair_textures[p.id % 4],
				p.cursor.position /* center */ \ 
					- state.textures.crosshair_texture_size /* offset for texture */ \
					* {CURSOR_SCALE, CURSOR_SCALE} / 2 /* scale of offset */,
				0.0, // rotation
				CURSOR_SCALE,
				rl.GetColor(0xFF_FF_FF_FF),
			)
		rl.EndShaderMode();
	}

	for &label in state.labels {
		draw_label(state, label);
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
