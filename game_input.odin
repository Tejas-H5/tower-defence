package main

get_move_input_held :: proc() -> (direction: Vec2) {
	if is_key_held(.A) || is_key_held(.LEFT)  {direction += {-1, 0}}
	if is_key_held(.D) || is_key_held(.RIGHT) {direction += {1, 0}}
	if is_key_held(.W) || is_key_held(.UP)    {direction += {0, 1}}
	if is_key_held(.S) || is_key_held(.DOWN)  {direction += {0, -1}}
	return
}

get_z_axis_input_held :: proc() -> (amount: f32) {
	if is_key_held(.Q) {amount -= 1}
	if is_key_held(.E) {amount += 1}
	return
}

get_slow_movement_input_held :: proc() -> bool {
	return is_key_held(.LEFT_SHIFT)
}

get_mouse_pos_world :: proc(state: ^GameState) -> Vec2 {
	pos := get_mouse_pos()
	return screen_to_world(state.view, pos)
}

slot_to_key :: proc(slot: int) -> KeyboardKey {
	switch slot {
	case 0: return .ONE
	case 1: return .TWO
	case 2: return .THREE
	case 3: return .FOUR
	case 4: return .FIVE
	}
	return nil
}

slot_is_pressed :: proc(slot: int) -> bool {
	key := slot_to_key(slot)
	if key != nil {
		return is_key_pressed(key)
	}
	return false
}

slot_is_held :: proc(slot: int) -> bool {
	key := slot_to_key(slot)
	if key != nil {
		return is_key_held(key)
	}
	return false
}

// I was kinda thinking about also supporting 'mouse-only' gameplay, where everything can be clicked on. 
// This is as an alternative to keyboard only.

cursor_is_held :: proc() -> bool {
	if is_mouse_held(.LEFT) {return true}
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
