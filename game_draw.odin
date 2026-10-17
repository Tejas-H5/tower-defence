package main

draw_rect_outline_world :: proc(state: ^GameState, rect: Rect, thickness: f32, color: Color) {
	world_rect := world_rect_to_screen_rect(state.view, rect);
	world_thickness := screen_length_to_world_length(state.view, thickness)
	draw_rect_outline(world_rect, world_thickness, color)
}

draw_rect_world :: proc(state: ^GameState, rect: Rect, color: Color) {
	world_rect := world_rect_to_screen_rect(state.view, rect);
	draw_rect(world_rect, color)
}
