/*
   It is not thread safe
*/
package mouse_input

import mm "src:manymouse"

Device_Id :: distinct u32;

Event :: struct{
    device: Device_Id,
    kind: union{
        Relative_Motion,   
        Absolute_Motion,
        Button,
        Scroll,
        Disconnected,
    }
}

Relative_Motion :: struct{
    x: int,
    y: int,
}

Absolute_Motion :: struct{
    x: int,
    y: int,
}

Button_Kind :: enum {
    Left = 0,
    Rigth,
    Middle,

    // reserved spaces currently did not find mouse which uses them
    Reserved_1, 
    Reserved_2, 
    Reserved_3, 
    Reserved_4, 

    // side buttons on a usual mouse
    Extra_1 = 7,
    Extra_2,
}


Button :: struct{
    pos: enum{
        Up,
        Down,
    },
    kind: Button_Kind,
}

Scroll :: struct{
    wheel: enum{
        Vertical,
        Horizontal,
    },
    direction: enum{
        Up,
        Down,

        Right = Up,
        Left = Down,
    },
}

Disconnected :: struct{}


State :: struct{
    relative_motion:  [2]int,
    absolute_motion: [2]int,
    disconnected: bool,
    button: [Button_Kind]struct{
        pressed: bool, 
        just_pressed: bool,
        just_released: bool,
    },
    scroll: [2]int,
}

@private
global: struct{
    state_len: int,
    states: [100]State, // We only support about 6 mouses or so, so it does not need to be dynamic
}

@private
clear :: proc(){
    for i in 0..<global.state_len{
        global.states[i] = {};
    }
}

init :: proc(){
    ret := mm.Init();
    assert(ret >= 0);
    global.state_len = cast(int) ret;
    clear();
}

close :: proc(){
    mm.Quit();
}

/*
   Detects the number of mouses available
*/
detect :: proc() -> uint{
    mm.Quit();
    value := mm.Init();
    assert(value >= 0);
    global.state_len = cast(int) value;
    clear();
    return cast(uint) value;
}

// Call every frame
update :: proc(){
    for i in 0..<global.state_len{
        global.states[i].relative_motion  = {};
        global.states[i].absolute_motion = {};
        global.states[i].scroll = {};

        for kind in Button_Kind{
            global.states[i].button[kind].just_pressed  = false;
            global.states[i].button[kind].just_released = false;
        }
    }

    for {
        event, has := simple_poll();
        if !has do return;

        state := &global.states[event.device];

        switch e in event.kind{
        case Relative_Motion:
            state.relative_motion.x += e.x;
            state.relative_motion.y += e.y;
        case Absolute_Motion:
            state.absolute_motion.x += e.x;
            state.absolute_motion.y += e.y;
        case Button:
            state.button[e.kind].just_pressed  = e.pos == .Down;
            state.button[e.kind].just_released = e.pos == .Up;
            state.button[e.kind].pressed       = e.pos == .Down;
        case Scroll:
            if e.wheel == .Vertical{
                if e.direction == .Up{
                    state.scroll.y -= 1;
                } else if e.direction == .Down{
                    state.scroll.y += 1;
                }
            } else if e.wheel == .Horizontal{
                if e.direction == .Left{
                    state.scroll.x -= 1;
                } else if e.direction == .Right{
                    state.scroll.x += 1;
                }
            }
        case Disconnected:
            state.disconnected = true;
        }
    }
}

// Need to call update on the frame before poll
poll :: proc(device: Device_Id) -> State{
    return global.states[device];
}

@private
simple_poll :: proc() -> (Event, bool){
    mm_e: mm.Event;
    if mm.PollEvent(&mm_e) == 1{
        e: Event;
        e.device = cast(Device_Id) mm_e.device;
        switch mm_e.type{
        case .Relmotion:
            motion := Relative_Motion{ };
            if mm_e.item == 0{
                motion.x = cast(int) mm_e.value;
            } else if mm_e.item == 1{ 
                motion.y = cast(int) mm_e.value;
            } else { // For some reason the mouse scroll generates a relative motion event, we discard that
                return simple_poll(); // get the scroll 
            }
            e.kind = motion;
        case .Absmotion:
            motion := Absolute_Motion{ };
            if mm_e.item == 0{
                motion.x = cast(int) mm_e.value;
            } else {
                motion.y = cast(int) mm_e.value;
            }
            e.kind = motion;
        case .Button:
            button := Button{ };
            button.kind = cast(Button_Kind) mm_e.item;
            if mm_e.value == 1 { button.pos = .Down; }
            else { button.pos = .Up; }
            e.kind = button;
        case .Scroll:
            scroll := Scroll{};
            if mm_e.item == 0{
                scroll.wheel = .Vertical;
            } else {
                scroll.wheel = .Horizontal;
            }

            if mm_e.value > 0{
                scroll.direction = .Up;
            } else {
                scroll.direction = .Down;
            }
            e.kind = scroll;
        case .Disconnect:
            e.kind = Disconnected{};
        case .Max: // Unhandled
        }
        return e, true;
    }


    return {}, false;
}

nr_mouses_no_detect :: proc() -> int {
	return global.state_len;
}

