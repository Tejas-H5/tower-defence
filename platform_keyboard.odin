package main

import rl "vendor:raylib"

KeyboardKey :: rl.KeyboardKey
is_key_down :: rl.IsKeyDown
is_key_pressed :: rl.IsKeyPressed
is_key_repeated :: rl.IsKeyPressedRepeat

is_key_pressed_or_repeated :: proc(key: KeyboardKey) -> bool {
	return is_key_pressed(key) || is_key_repeated(key)
}

get_mouse_pos :: proc() -> Vec2 {
	return rl.GetMousePosition()
}

MouseButton :: rl.MouseButton
is_mouse_pressed :: rl.IsMouseButtonPressed
is_mouse_down :: rl.IsMouseButtonDown
get_mouse_scroll :: rl.GetMouseWheelMove
