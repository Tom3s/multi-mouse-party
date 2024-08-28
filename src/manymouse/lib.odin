package manymouse

import "core:c"

Event_Type :: enum(c.int) {
    Absmotion = 0,
    Relmotion,
    Button,
    Scroll,
    Disconnect,
    Max
}

Event :: struct {
    type: Event_Type,
    device: c.uint,
    item: c.uint,
    value: c.int,
    minval: c.int,
    maxval: c.int,
}

foreign import lib "manymouse.a"

@(link_prefix="ManyMouse_")
foreign lib {
	Init :: proc() -> c.int --- 
	DriverName :: proc() -> cstring ---;
	Quit :: proc() ---;
	DeviceName :: proc(index: c.uint) -> cstring ---;
	PollEvent :: proc(event: ^Event) -> c.int  ---;
}