package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

init :: proc(state: ^GameState) {
	state.view = {
		size = 1000,
	}

	base_handle := add_entity(state, {
		type   = .Base,
		size   = 100,
		color  = COLOR_PLAYER,
		health = 100,
	})
	state.base = get_entity(state, base_handle)

	player_handle := add_entity(state, {
		type   = .Player,
		size   = 0,
		color  = {0, 0, 255, 255},
		health = 100,
	})
	state.player = get_entity(state, player_handle)

	for i in 0..<1000 {
		angle := rand.float32_range(-math.PI, math.PI)
		pos := 1000 * Vec2{math.cos(angle), math.sin(angle)}
		e := add_entity(state, {
			type          = .Enemy,
			size          = 10,
			position      = pos,
			health        = 100,
			target_entity = base_handle,
			move_speed    = 30 * rand.float32_range(1, 2),
			color         = {255, 0, 0, 255},
		})
	}
}

update_game :: proc(state: ^GameState, dt: f32) {
	mouse_pos := get_mouse_pos()
	defer state.prev_mouse_pos = mouse_pos
	state.mouse_delta          = mouse_pos - state.prev_mouse_pos

	base := state.base
	player := state.player

	assert(player != nil)
	assert(base != nil)

	// Get user input
	t := get_time()
	{
		// Player
		{
			// Camera movement
			{
				// Keyboard movement
				{
					dir := get_move_input_held()
					move_speed : f32 = get_slow_movement_input_held() ? CAMERA_MOVE_SPEED_SLOW : CAMERA_MOVE_SPEED
					pos_vel_target := state.view.size * dir * move_speed
					size_vel_target := state.view.size * get_z_axis_input_held() * CAMERA_ZOOM_SPEED
					state.view.pos_vel = linalg.lerp(state.view.pos_vel, pos_vel_target, dt * CAMERA_MOVE_SPEED_SENSITIVITY)
					state.view.size_vel = linalg.lerp(state.view.size_vel, size_vel_target, dt * CAMERA_ZOOM_SPEED_SENSITIVITY)
					state.view.pos += state.view.pos_vel * dt
					state.view.size += state.view.size_vel * dt
				}

				// Drag movement
				{
					if cursor_is_held() {
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
			player.position_prev = player.position
		}
	}
	state.perf.input += update_timer(&t)

	// Step world physics
	{
		for iter := entity_iterator(state); e in iterate_entities(&iter) {
			advance_timer(&e.lifetime_timer, dt)
			advance_timer(&e.shoot_cooldown_timer, dt)

			e.position_prev = e.position
			e.position += dt * e.velocity

			if e.type == .Bullet {
				ray := Line{e.position_prev, e.position}

				for iter := entity_iterator(state); e_other in iterate_entities(&iter) {
					if e_other.type != .Enemy     {continue}
					if e_other.handle == e.handle {continue}

					other_rect := get_rect(e_other)
					res := line_intersects_rect(ray, other_rect)
					if res.num_hits > 0 {
						e.position = res.hits[0].pos
					}
				}
			}
		}
	}
	state.perf.physics += update_timer(&t)

	// Figure out what just happened, action it
	{
		for iter := entity_iterator(state); bullet in iterate_entities(&iter) {
			if bullet.type != .Bullet {continue}
			
			rect := get_rect(bullet)

			for iter := entity_iterator(state); enemy in iterate_entities(&iter) {
				if enemy.type != .Enemy {continue}

				enemy_rect := get_rect(enemy)
				if rect_intersects_rect(rect, enemy_rect) {
					enemy.health -= bullet.health
					kill_entity(bullet)
				}
			}
		}

		for iter := entity_iterator(state); e in iterate_entities(&iter) {
			if !e.added_before_this_frame {continue}

			if e.shoot_cooldown_timer < 0 {
				e.shoot_cooldown_timer = e.shoot_cooldown

				MAX_RANGE :: 10_000
				// TODO: optimize this query somehow.
				target := closest_entity_SLOWWW(state, e.position, MAX_RANGE, .Enemy)
				if target != nil {
					BULLET_SPEED :: 10_000
					velocity := BULLET_SPEED * linalg.normalize0(target.position - e.position)
					h := add_entity(state, {
						type = .Bullet,
						health = 100,
						lifetime_timer = 5,
						position = e.position,
						velocity = velocity,
						size = 5,
						color = COLOR_PLAYER,
					})
				}
			}

			// This is kinda an AI thing
			target, has_target := get_entity(state, e.target_entity)
			if has_target {
				e.velocity = e.move_speed * linalg.normalize0(base.position - e.position)
			}

			// Enemies do damage to the bae
			if e.type == .Enemy {
				if base != nil {
					if rect_intersects_rect(get_entity_rect(base), get_entity_rect(e)) {
						base.health -= 1
						e.health = -1
					}
				}
			}
		}
	}
	state.perf.ai += update_timer(&t)

	// Clean up dead entities, add new entities
	{
		for iter := entity_iterator(state); e in iterate_entities(&iter) {
			// Enable entities at the end, for correctness
			e.added_before_this_frame = true;

			if e.type == .Player {continue}
			if e.type == .Base {continue}

			defer if is_dead(e) {
				remove_entity(state, e)
			}

			if e.lifetime_timer < 0 {
				kill_entity(e)
			}
		}
	}
	state.perf.apply_phase += update_timer(&t)
}

render_game :: proc(state: ^GameState) {
	screen_center := Vec2{width(), height()} / 2

	// World
	{
		draw_bg(COLOR_WORLD_BG)

		for iter := entity_iterator(state); e in iterate_entities(&iter) {
			enemies_rect := get_rect(e)
			color := e.color
			color.a = u8(255 * math.lerp(f32(0.1), 1, math.saturate(e.health / 100)))
			draw_rect_world(state, enemies_rect, color)

			thickness := e.size / 2
			draw_line_world(state, {e.position_prev, e.position}, thickness, color);
		}
	}


	if is_dead(state.base) {
		text := drawable_text(height() / 10, "You're dead, shii")
		draw_text(text, screen_center - text.size / 2, COLOR_HUD)
	}

	// HUD
	{
		// Debug text
		{
			debug_text_pos := Vec2{20, 20}
			debug_text_color := Color{0, 0, 0, 255}

			{
				text := drawable_textf(50, "%v entities", entity_count(state))
				draw_text(text, debug_text_pos, debug_text_color)
				debug_text_pos += {0, text.size.y}
			}

			{
				text := drawable_textf(50, "%.3f input", 1 / state.perf.input)
				draw_text(text, debug_text_pos, debug_text_color)
				debug_text_pos += {0, text.size.y}
				state.perf.input = 0
			}

			{
				text := drawable_textf(50, "%.3f physics", 1 / state.perf.physics)
				draw_text(text, debug_text_pos, debug_text_color)
				debug_text_pos += {0, text.size.y}
				state.perf.physics = 0
			}

			{
				text := drawable_textf(50, "%.3f ai", 1 / state.perf.ai)
				draw_text(text, debug_text_pos, debug_text_color)
				debug_text_pos += {0, text.size.y}
				state.perf.ai = 0
			}

			{
				text := drawable_textf(50, "%.3f apply_phase", 1 / state.perf.apply_phase)
				draw_text(text, debug_text_pos, debug_text_color)
				debug_text_pos += {0, text.size.y}
				state.perf.apply_phase = 0
			}
		}

		// Cursor
		{
			cursor_pos := get_mouse_pos_world(state)
			cursor_size := Vec2{ 1, 1 } * 50
			screen_rect := world_rect_to_screen_rect(state.view, {cursor_pos - cursor_size / 2, cursor_size})
			screen_outline_thickness : f32 = 2
			draw_rect_outline(screen_rect, screen_outline_thickness, COLOR_HUD)

			if slot_is_held(0) {
				add_tower(state, cursor_pos)
			}
		}
	}
}
