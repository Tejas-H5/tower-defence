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

Color :: rl.Color
Vec2 :: [2]f32
Vec2i :: [2]i32
Rect :: struct {
	pos:  Vec2,
	size: Vec2,
}
Line :: struct {
	start: Vec2,
	end: Vec2,
}

last_monitor: c.int

wanted_cursor, last_cursor : CursorType

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

	if wanted_cursor != last_cursor {
		defer last_cursor = wanted_cursor

		log("Updated mouse cursor to", wanted_cursor)

		if last_cursor == .None {
			rl.ShowCursor()
		} else if wanted_cursor == .None {
			rl.HideCursor()
		}

		switch wanted_cursor {
			case .Default:      rl.SetMouseCursor(.DEFAULT)
			case .Text:         rl.SetMouseCursor(.IBEAM)
			case .PointingHand: rl.SetMouseCursor(.POINTING_HAND)
			case .Crosshairs:   rl.SetMouseCursor(.CROSSHAIR)
			case .None:
				// Already handled
		}
	}

	// The cursor is immediate mode.
	set_mouse_cursor(.Default)

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

CursorType :: enum {
	Default,
	Text,
	PointingHand,
	Crosshairs,
	None,
}

set_mouse_cursor :: proc(type: CursorType) {
	wanted_cursor = type
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
