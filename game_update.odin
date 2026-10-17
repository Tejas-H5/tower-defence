package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

CAMERA_MOVE_SPEED :: 5
CAMERA_MOVE_SPEED_SLOW :: 1
CAMERA_MOVE_SPEED_SENSITIVITY :: 30
CAMERA_ZOOM_SPEED :: 5
CAMERA_ZOOM_SPEED_SENSITIVITY :: 20

init :: proc(state: ^GameState) {
	state.view = {
		size = 1000,
	}

	state.base = add_entity(state, .Base)
	state.base.size = 100
	state.base.color = COLOR_GREY
	state.base.health = 100

	state.player = add_entity(state, .Player)
	state.player.size = 0
	state.player.color = {0, 0, 255, 255}

	for i in 0 ..< 100 {
		e := add_entity(state, .Enemy)
		angle := rand.float32_range(-math.PI, math.PI)
		pos := 1000 * Vec2{math.cos(angle), math.sin(angle)}

		e.size = 10
		e.position = pos
		e.move_speed = 30 * rand.float32_range(1, 2)
	}

}

update_game :: proc(state: ^GameState, dt: f32) {
	mouse_pos := get_mouse_pos()
	defer state.prev_mouse_pos = mouse_pos
	state.mouse_delta = mouse_pos - state.prev_mouse_pos

	base: ^Entity
	player: ^Entity

	for &e in state.entities {
		if e.type == .Player {player = &e}
		if e.type == .Base {base = &e}
	}

	assert(player != nil)
	assert(base != nil)

	for &e in state.entities {
		e := &e

		if e.type == .Player {continue}
		if e.type == .Base {continue}
		if is_dead(e) {continue}

		if base != nil && base.health > 0 {
			e.velocity = e.move_speed * linalg.normalize0(base.position - e.position)
		} else {
			e.velocity = 0
		}

		e.position += dt * e.velocity

		if base != nil {
			if rects_intersect(get_entity_rect(base), get_entity_rect(e)) {
				base.health -= 1
				e.health = -1
			}
		}
	}

	// Player
	{
		// Camera movement
		{
			// Keyboard movement
			{
				dir := get_move_input_down()
				move_speed : f32 = get_slow_movement_input_down() ? CAMERA_MOVE_SPEED_SLOW : CAMERA_MOVE_SPEED
				pos_vel_target := state.view.size * dir * move_speed
				size_vel_target := state.view.size * get_z_axis_input_down() * CAMERA_ZOOM_SPEED
				state.view.pos_vel = linalg.lerp(state.view.pos_vel, pos_vel_target, dt * CAMERA_MOVE_SPEED_SENSITIVITY)
				state.view.size_vel = linalg.lerp(state.view.size_vel, size_vel_target, dt * CAMERA_ZOOM_SPEED_SENSITIVITY)
				state.view.pos += state.view.pos_vel * dt
				state.view.size += state.view.size_vel * dt
			}

			// Drag movement
			{
				if cursor_is_down() {
					delta := screen_size_to_world_size(state.view, state.mouse_delta)
					state.view.pos -= delta
				}
			}

			BOUNDS :: 10_000
			state.view.pos.x = clamp(state.view.pos.x, -BOUNDS, BOUNDS)
			state.view.pos.y = clamp(state.view.pos.y, -BOUNDS, BOUNDS)
			state.view.size = clamp(state.view.size, 100, 10000)
		}

		player.position = state.view.pos
	}
}

render_game :: proc(state: ^GameState) {
	screen_center := Vec2{width(), height()} / 2

	// Render
	{
		// World
		{
			draw_bg(COLOR_WHITE)

			for &e in state.entities {
				if is_dead(&e) {continue}

				enemies_rect := Rect{e.position - e.size / 2, e.size}
				color := e.color
				color.a = u8(255 * math.lerp(f32(0.1), 1, math.saturate(e.health / 100)))
				draw_rect_world(state, enemies_rect, color)
			}
		}

		if is_dead(state.base) {
			text := drawable_text(height() / 10, "You're dead, shii")
			draw_text(text, screen_center - text.size / 2, COLOR_RED)
		}

		// Cursor
		{
			cursor_pos := get_mouse_pos_world(state)
			cursor_size := Vec2{ 10, 10 }
			screen_rect := world_rect_to_screen_rect(state.view, {cursor_pos - cursor_size / 2, cursor_size})
			draw_rect_outline(screen_rect, 10, {255, 0, 0, 255})
		}
	}
}
