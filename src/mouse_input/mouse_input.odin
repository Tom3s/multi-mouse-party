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

    // ... I guess reserved for other

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

init :: proc(){
    ret := mm.Init();
    assert(ret >= 0);
}

close :: proc(){
    mm.Quit();
}

/*
   Detects the number of mouses available
*/
detect :: proc() -> uint{
    value := mm.Init();
    assert(value >= 0);
    return cast(uint) value;
}

@private
saved_event: Maybe(Event) = nil;

poll :: proc() -> (Event, bool){
    saved, has_saved := saved_event.?;
    if has_saved{
        saved_event = nil;
        return saved, true;
    }

    event, has := simple_poll();
    if !has do return {}, false;

    relmotion, ok := event.kind.(Relative_Motion);
    if !ok do return event, true;

    // squashing relmotions together
    for {
        new_event, has := simple_poll();
        if !has {
            event.kind = relmotion;
            return event, true;
        }

        if new_event.device != event.device {
            saved_event = new_event;
            event.kind = relmotion;
            return event, true;
        }

        new_relmotion, ok := new_event.kind.(Relative_Motion);
        if !ok {
            saved_event = new_event;
            event.kind = relmotion;
            return event, true;
        }

        relmotion.x += new_relmotion.x;
        relmotion.y += new_relmotion.y;
    }
}

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
            } else if mm_e.item == 1{ // For some reason the mouse wheel generates a relative motion event, we discard that
                motion.y = cast(int) mm_e.value;
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

