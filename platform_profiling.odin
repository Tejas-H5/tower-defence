package main

import rl "vendor:raylib"

NamedTimer :: struct {
	name: string,
	t:    f64,
}

get_delta_time :: proc() -> f32 {
	return rl.GetFrameTime()
}

get_time :: proc() -> f64 {
	return rl.GetTime()
}

update_timer :: proc(t: ^f64) -> f64 {
	t1 := get_time()
	result := t1 - t^
	t^ = t1
	return result
}

