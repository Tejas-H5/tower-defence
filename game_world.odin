package main

View_Bounds :: struct {
	pos: Vec2,
	size: f32,

	pos_vel: Vec2,
	size_vel: f32,
}

screen_scale_factor :: proc() -> f32 {
	return height()
}
screen_centre_offset :: proc() -> Vec2 { 
	return {(width() - height()) / 2, 0}
}

world_to_screen :: proc(view: View_Bounds, pos: Vec2) -> Vec2 {
	// We want to map -size/2 <-> size/2 to 0 <-> 1
	normalized := 0.5 + ((pos - view.pos) / view.size)
	normalized.y = 1 - normalized.y
	return normalized * screen_scale_factor() + screen_centre_offset()
}

screen_to_world :: proc(view: View_Bounds, pos: Vec2) -> Vec2 {
	normalized := (pos - screen_centre_offset()) / screen_scale_factor()
	normalized.y = 1 - normalized.y
	pos := ((normalized - 0.5) * view.size) + view.pos
	return pos
}

world_size_to_screen_size :: proc(view: View_Bounds, size: Vec2) -> Vec2 {
	vec := (size / view.size) * screen_scale_factor()
	vec.y = -vec.y
	return vec
}

world_length_to_screen_length :: proc(view: View_Bounds, length: f32) -> f32 {
	return (length / view.size) * screen_scale_factor()
}

world_rect_to_screen_rect :: proc(view: View_Bounds, rect: Rect) -> Rect {
	pos  := world_to_screen(view, rect.pos)
	size := world_size_to_screen_size(view, rect.size)
	if size.x < 0 {
		pos.x += size.x
		size.x = -size.x
	}
	if size.y < 0 {
		pos.y += size.y
		size.y = -size.y
	}
	return Rect{pos, size}
}

screen_size_to_world_size :: proc(view: View_Bounds, size: Vec2) -> Vec2 {
	size := size
	size.y = -size.y
	return (size / screen_scale_factor()) * view.size
}

screen_length_to_world_length :: proc(view: View_Bounds, length: f32) -> f32 {
	return (length / screen_scale_factor()) * view.size
}
