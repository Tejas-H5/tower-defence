package main

// Actually easier to use draw_rect_outline directly in many cases
draw_rect_outline_world :: proc(state: ^GameState, world_rect: Rect, world_thickness: f32, color: Color) {
	screen_rect      := world_rect_to_screen_rect(state.view, world_rect);
	screen_thickness := world_length_to_screen_length(state.view, world_thickness)
	draw_rect_outline(screen_rect, screen_thickness, color)
}

draw_rect_world :: proc(state: ^GameState, world_rect: Rect, color: Color) {
	screen_rect := world_rect_to_screen_rect(state.view, world_rect);
	draw_rect(screen_rect, color)
}

draw_line_world :: proc(state: ^GameState, world_line: Line, world_thickness: f32, color: Color) {
	screen_start     := world_to_screen(state.view, world_line.start)
	screen_end       := world_to_screen(state.view, world_line.end)
	screen_thickness := world_length_to_screen_length(state.view, world_thickness)
	draw_line(screen_start, screen_end, screen_thickness, color);
}
