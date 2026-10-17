package main

import "core:c"
import "core:fmt"
import rl "vendor:raylib"

LOGGING_ENABLED :: true

log :: proc(args: ..any, loc := #caller_location) {
	if (LOGGING_ENABLED) {
		fmt.print(loc, ": ")
		fmt.println(..args)
	}
}

COLOR_WHITE :: rl.WHITE
COLOR_BLACK :: rl.BLACK
COLOR_GREY :: Color{125, 125, 125, 255}
COLOR_RED :: rl.RED
COLOR_GREEN :: rl.GREEN
COLOR_BLUE :: rl.BLUE

Color :: rl.Color
Vec2 :: [2]f32
Rect :: struct {
	pos:  Vec2,
	size: Vec2,
}
CursorType :: rl.MouseCursor

last_monitor: c.int
last_cursor: CursorType

init_window :: proc(name: cstring) {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(800, 600, name)
	rl.SetWindowState({.WINDOW_MAXIMIZED, .WINDOW_RESIZABLE})

	rl.BeginDrawing()

	last_monitor = -1
}

close_window :: proc() {
	rl.CloseWindow()
}

process_frame :: proc() -> bool {
	result := !rl.WindowShouldClose()

	rl.EndDrawing()

	monitor := rl.GetCurrentMonitor()
	if last_monitor != monitor {
		last_monitor = monitor
		rl.SetTargetFPS(rl.GetMonitorRefreshRate(monitor))
	}

	free_all(context.temp_allocator)

	rl.SetMouseCursor(rl.MouseCursor(last_cursor))
	last_cursor = CursorType.DEFAULT

	rl.BeginDrawing()

	return result
}

pos_in_rect :: proc(pos: Vec2, rect: Rect) -> bool {
	return(
		(rect.pos.x <= pos.x && pos.x <= (rect.pos.x + rect.size.x)) &&
		(rect.pos.y <= pos.y && pos.y <= (rect.pos.y + rect.size.y)) \
	)
}

width :: proc() -> f32 {
	return f32(rl.GetScreenWidth())
}

height :: proc() -> f32 {
	return f32(rl.GetScreenHeight())
}

set_mouse_cursor :: proc(type: rl.MouseCursor) {
	rl.SetMouseCursor(type)
}

get_delta_time :: proc() -> f32 {
	return rl.GetFrameTime()
}

