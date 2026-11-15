package main

run_interactive_test :: proc() {
	init_window("Interactive test")

	start, end: Vec2
	placing_start: bool

	for process_frame() {
		draw_bg({255, 255, 255, 255})

		GRID_SPACING :: 300
		GRID_THICKNESS :: 2
		GRID_COLOR :: Color{0,0,0, 50}
		for i in 0..<20 {
			y := f32(i) * GRID_SPACING
			draw_line(Vec2{0, y}, Vec2{width(), y}, GRID_THICKNESS, GRID_COLOR)
		}
		for i in 0..<20 {
			x := f32(i) * GRID_SPACING
			draw_line(Vec2{x, 0}, Vec2{x, height()}, GRID_THICKNESS, GRID_COLOR)
		}

		if is_mouse_pressed(.LEFT) {
			if placing_start {
				start = get_mouse_pos()
			} else {
				end = get_mouse_pos()
			}
			placing_start = !placing_start
		}

		draw_marker :: proc(pos: Vec2, size: f32, color: Color) {
			rect := Rect{ pos - size, 2 * size }
			draw_rect_outline(rect, size, color)
		}
		draw_marker(start, 10, Color{255, 0, 0, 255})
		draw_marker(end,   10, Color{0, 255, 0, 255})

		draw_line(start, end, 3, Color{0, 0, 0, 255})
		
		it := grid_line_intersection_iterator(start, end, GRID_SPACING)
		safety := 0
		for pos in grid_line_intersection_iterate(&it) {
			safety += 1
			if safety > 2000 {
				log("NAHH")
				break
			}
			draw_marker(pos, 5, Color{0, 0,0, 50})
		}
	}

	close_window()
}
