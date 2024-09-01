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


Cursor :: struct{
}

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

main :: proc(){
    context.allocator      = mem.panic_allocator();
    context.temp_allocator = mem.panic_allocator();

    rl.InitWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, "Test");
    defer rl.CloseWindow();

    state: App_State;
    init_app_state(&state);


    for !rl.WindowShouldClose(){
        err := free_all(state.frame_alloc);
        update(&state);

        buffer := make_slice([]u8, 50 * mem.Megabyte, allocator = state.frame_alloc);

        rl.BeginDrawing();
            draw(&state);
        rl.EndDrawing();
    }

}

update :: proc(state: ^App_State){
}

draw :: proc(state: ^App_State){
}
