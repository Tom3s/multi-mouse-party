package manymouse

import "core:c"

Event_Type :: enum(c.int) {
    Absmotion = 0,
    Relmotion,
    Button,
    Scroll,
    Disconnect,
    Max,
}

Event :: struct {
    type: Event_Type,
    device: c.uint,
    item: c.uint, // item 0 - x; item 1 - y; right-down + coordinates
    value: c.int,
    minval: c.int,
    maxval: c.int,
}

when ODIN_OS == .Windows {
    foreign import lib "manymouse_windows.a"
}
when ODIN_OS == .Linux {
    foreign import lib "linux/manymouse.a"
}

@(link_prefix="ManyMouse_")
foreign lib {
	Init :: proc() -> c.int --- 
	DriverName :: proc() -> cstring ---;
	Quit :: proc() ---;
	DeviceName :: proc(index: c.uint) -> cstring ---;
	PollEvent :: proc(event: ^Event) -> c.int  ---;
}

