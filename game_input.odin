package main

get_move_input_down :: proc() -> (direction: Vec2) {
	if is_key_down(.A) || is_key_down(.LEFT)  {direction += {-1, 0}}
	if is_key_down(.D) || is_key_down(.RIGHT) {direction += {1, 0}}
	if is_key_down(.W) || is_key_down(.UP)    {direction += {0, 1}}
	if is_key_down(.S) || is_key_down(.DOWN)  {direction += {0, -1}}
	return
}

get_z_axis_input_down :: proc() -> (amount: f32) {
	if is_key_down(.Q) {amount -= 1}
	if is_key_down(.E) {amount += 1}
	return
}

get_slow_movement_input_down :: proc() -> bool {
	return is_key_down(.LEFT_SHIFT)
}

get_mouse_pos_world :: proc(state: ^GameState) -> Vec2 {
	pos := get_mouse_pos()
	return screen_to_world(state.view, pos)
}

// I was kinda thinking about also supporting 'mouse-only' gameplay, where everything can be clicked on. 
// This is as an alternative to keyboard only.

cursor_is_down :: proc() -> bool {
	if is_mouse_down(.LEFT) {return true}
	// if is_key_down(.Z)      {return true}
	// if is_key_down(.X)      {return true}
	return false
}

cursor_is_pressed :: proc() -> bool {
	if is_mouse_pressed(.LEFT) {return true}
	// if is_key_pressed(.Z)      {return true}
	// if is_key_pressed(.X)      {return true}
	return false
}
