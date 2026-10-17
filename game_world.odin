package main

ViewBounds :: struct {
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

world_to_screen :: proc(view: ViewBounds, pos: Vec2) -> Vec2 {
	// We want to map -size/2 <-> size/2 to 0 <-> 1
	normalized := 0.5 + ((pos - view.pos) / view.size)
	normalized.y = 1 - normalized.y
	return normalized * screen_scale_factor() + screen_centre_offset()
}

screen_to_world :: proc(view: ViewBounds, pos: Vec2) -> Vec2 {
	normalized := (pos - screen_centre_offset()) / screen_scale_factor()
	normalized.y = 1 - normalized.y
	pos := ((normalized - 0.5) * view.size) + view.pos
	return pos
}

world_size_to_screen_size :: proc(view: ViewBounds, size: Vec2) -> Vec2 {
	vec := (size / view.size) * screen_scale_factor()
	vec.y = -vec.y
	return vec
}

world_rect_to_screen_rect :: proc(view: ViewBounds, rect: Rect) -> Rect {
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

screen_size_to_world_size :: proc(view: ViewBounds, size: Vec2) -> Vec2 {
	size := size
	size.y = -size.y
	return (size / screen_scale_factor()) * view.size
}

screen_length_to_world_length :: proc(view: ViewBounds, length: f32) -> f32 {
	length := length
	return (length / screen_scale_factor()) * view.size
}

rects_intersect :: proc(a, b: Rect) -> bool {
	return ranges_intersect(a.pos.x, a.pos.x + a.size.x, b.pos.x, b.pos.x + b.size.x) &&
           ranges_intersect(a.pos.y, a.pos.y + a.size.y, b.pos.y, b.pos.y + b.size.y)
}

ranges_intersect :: proc(a0, a1, b0, b1: f32) -> bool {
	if a1 < b0 {return false}
	if b1 < a0 {return false}
	return true
}
