package main

import "core:fmt"
import "core:c"
import "core:c/libc"
import "core:math/linalg"



import mm "manymouse"
import rl "vendor:raylib"
import stbi "vendor:stb/image"


import Signal "signal"

Player :: struct{
	id: int,
	device_id: c.uint,
}

State :: struct{
	p1: Player,
	p2: Player,
}




// Button :: struct{
// 	transform: int,
// 	size: int,
// 	collision: AABB,

// 	pressed: bool,
// 	hovered: bool,
// }


window_size: v2 = {1280, 720};

main :: proc(){
	nr := mm.Init();
	defer mm.Quit();

	rl.InitWindow(cast(i32) window_size.x, cast(i32) window_size.y, "Multi Mouse");
    defer rl.CloseWindow();

	rl.BeginDrawing();
		rl.DrawRectangle(200, 200, 500, 500, rl.GetColor(0x30_A0_A0_FF))
	rl.EndDrawing()

	for i in 0..<nr{
		fmt.println(mm.DeviceName(cast(c.uint) i));
	}

	// bs := signal.init(int);
	// button_down := Signal.init(int);
	// button_up := Signal.init(int);

	// print_button_down :: proc(data: rawptr, device_id: int) {
	// 	fmt.println("Player with device", device_id, "pressed click!!!");
	// }
	
	// print_button_up :: proc(data: rawptr, device_id: int) {
	// 	fmt.println("Player with device", device_id, "released click!!!");
	// }

	// Signal.connect(&button_down, nil, print_button_down);
	// Signal.connect(&button_up, nil, print_button_up);

	// detect players

	state: State;

	detect_player(&state.p1);
	fmt.println("P1 identified as", state.p1.device_id);
	detect_player(&state.p2);
	fmt.println("P2 identified as", state.p2.device_id);

	sh := rl.LoadShader(nil, "shaders/yuhuu.fs");

	// nr_channels: c.int = 0;
	// width: c.int = 0;
	// height: c.int = 0;
	// data := stbi.load("images/1millionbeers.jpg",&width, &height, &nr_channels, 3);
	// fmt.print(nr_channels, width, height, data);

	// image := rl.LoadTexture("images/icon.png");
	image := rl.LoadTexture("images/cursor.png");
	// image := rl.LoadTextureFromImage(file);

	treshold: f32 = 0.8;
	outlineWidth: f32 = 0.1;
	outlineColor: v4 = {0.5, 0.6, 0.8, 1.0};
	mainColor: v4 = {0.8, 0.2, 0.3, 1.0};

	imageSize: v2 = {256, 256}

	mousePos: v2 = {}
	imagePos: v2 = {}

	time: f32 = 1;

	for !rl.WindowShouldClose(){
		// input handler
		event: mm.Event;
		if (mm.PollEvent(&event) == 1){
			if (event.device == state.p1.device_id){
				//p1
				update_player(&state, &state.p1, event);
			} else if (event.device == state.p2.device_id){
				update_player(&state, &state.p2, event);
			}
		}

		
		if (rl.IsMouseButtonDown(.LEFT)){
			mousePos = rl.GetMousePosition();
			imagePos = mousePos - (imageSize / 2);
		}

		treshold = linalg.sin(time * 0.001);
		treshold = remap(treshold, -1, 1, 0.2, 0.9);
		// treshold = (treshold + 1) /;

		rl.SetShaderValue(sh, 0, &treshold, .FLOAT);
		rl.SetShaderValue(sh, 1, &outlineWidth, .FLOAT);
		rl.SetShaderValue(sh, 2, &mainColor, .VEC4);
		rl.SetShaderValue(sh, 3, &outlineColor, .VEC4);

		rl.BeginDrawing();
			rl.DrawRectangle(0, 0, cast(i32) window_size.x, cast(i32) window_size.y, rl.GetColor(0x30_A0_A0_FF))
			rl.BeginShaderMode(sh);
				// rl.DrawRectangle(150, 150, 500, 500, rl.GetColor(0xFF_FF_FF_FF))
				rl.DrawTexture(image, cast(i32) imagePos.x, cast(i32) imagePos.y, rl.GetColor(0xFF_FF_FF_FF));
			rl.EndShaderMode();
		rl.EndDrawing();

		time += 1;
	}
}

detect_player :: proc(p: ^Player){
	for {
		event: mm.Event;
		if (mm.PollEvent(&event) == 1){
			if (event.type == .Button && event.value == 1) {
				p.device_id = event.device;
				break;
			} 
		}
	}
}

update_player :: proc(state: ^State, p: ^Player, event: mm.Event){
	// fmt.println("Player got ", event);
}

remap :: proc(x, froma, toa, fromb, tob: f32) -> f32 {
	return linalg.lerp(
		fromb, tob,
		linalg.unlerp(froma, toa, x)
	)
}