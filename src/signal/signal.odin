package signal

// signal:
// - connect
// - emit
//
// - callback queue 


Signal_Block :: struct($Signal_Data: typeid){
	data: rawptr,
	callback: proc(rawptr, Signal_Data),
	id: int,
}
Signal :: struct ($Signal_Data: typeid){
	callbackQueue: [dynamic]Signal_Block(Signal_Data),
	ids: int,
}

init :: proc($Signal_Data: typeid) -> Signal(Signal_Data) {
	return {
		callbackQueue = make([dynamic]Signal_Block(Signal_Data)),
		ids = 0,
	};
} 

connect :: proc(s:^Signal($Signal_Data), data: rawptr, callback: proc(rawptr, Signal_Data)) -> int{
	id := s.ids;
	s.ids += 1;
	append(&s.callbackQueue, Signal_Block(Signal_Data){
		data = data,
		callback = callback,
		id = id,
	});

	return id;
}

disconnect :: proc(s: ^Signal($Signal_Data), id: int){
	for c, i in s.callbackQueue{
		if c.id == id{
			unordered_remove(&s.callbackQueue, i);
			break;
		}
	}
}

emit :: proc(s: Signal($Signal_Data), signal_data: Signal_Data) {
	for callback in s.callbackQueue {
		callback.callback(callback.data, signal_data);
	}
}