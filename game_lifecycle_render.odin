package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

render_game :: proc(state: ^Game_State) {
	set_mouse_cursor(.None)

	screen_center := Vec2{width(), height()} / 2

	// Perform physics update in a deterministic manner.
	// Plot twist: the render function owns physics update ??
	// Maybe consider multithreading later but how do u make it deterministic? not sure.
	{
		PHYSICS_TIMESTEP :: 0.02

		MAX_PHYSICS_TO_CATCH_UP_ON :: 5 * PHYSICS_TIMESTEP

		// We would implement slow motion / pausing here.
		state.physics_to_catch_up_on += get_delta_time()
		if state.physics_to_catch_up_on > MAX_PHYSICS_TO_CATCH_UP_ON {
			// If we don't do this, a little bit of lag will cause state.physics_to_catch_up_on to
			// infinitely increase, causing each subsequent frame to take longer and longer.
			// Instead, we can just slow down the simulation a bit by doing this.
			state.physics_to_catch_up_on = MAX_PHYSICS_TO_CATCH_UP_ON
		}

		// Ensure determinism of the physics somewhat.
		dt := f32(PHYSICS_TIMESTEP)
		for state.physics_to_catch_up_on > 0 {
			state.physics_to_catch_up_on -= dt
			update_game(state, dt)
		}
	}



	// World
	{
		draw_bg(COLOR_WORLD_BG)


		// Debug world things
		{
			// Physics grid
			{
				bottom_left := screen_to_world(state.view, {0, height()})
				top_right   := screen_to_world(state.view, {width(), 0})

				bottom_left_grid := spatial_grid_pos_to_coord(&state.spatial_grid, bottom_left)
				top_right_grid   := spatial_grid_pos_to_coord(&state.spatial_grid, top_right)

				for x in bottom_left_grid.x..<top_right_grid.x {
					for y in bottom_left_grid.y..<top_right_grid.y {
						rect := Rect{ 
							{f32(x), f32(y)} * state.spatial_grid.grid_size, 
							state.spatial_grid.grid_size, 
						}

						draw_rect_outline_world(state, rect, 3, Color{0, 0, 0, 100})
						count := 0
						slot := spatial_grid_coord_to_firt_slot(&state.spatial_grid, {x, y})
						if slot != nil {
							handle := slot.first
							for handle != nil {
								count += 1
								handle = handle.next
							}
						}

						heat := f32(count) / f32(state.spatial_grid.count)
						heat_bytes := byte(math.floor(255 * math.saturate(heat)))
						draw_rect_world(state, rect, Color{0, 0, 0, heat_bytes})
					}
				}
			}
		}


		for pool in state.item_pools {
			for i in 0..<pool.count {
				enemies_rect := get_rect(pool, i)
				color := pool.items[i].color
				health := pool.items[i].health
				size := pool.items[i].size
				position := pool.items[i]._position
				position_prev := pool.items[i].position_prev

				color.a = u8(255 * math.lerp(f32(0.1), 1, math.saturate(health / 100)))
				draw_rect_world(state, enemies_rect, color)

				thickness := size / 2
				draw_line_world(state, {position_prev, position}, thickness, color);
			}
		}
	}

	if state.bases.items[0].health <= 0 {
		text := drawable_text(height() / 10, "You're dead, shii")
		draw_text(text, screen_center - text.size / 2, COLOR_HUD)
	}

	// HUD
	{
		// Debug text
		{
			debug_text_pos := Vec2{20, 20}

			debug_text_entry :: proc(debug_text_pos: ^Vec2, format: string, args: ..any) {
				debug_text_color := Color{0, 0, 0, 255}
				text := drawable_textf(50, format, ..args)
				draw_text(text, debug_text_pos^, debug_text_color)
				debug_text_pos^ += {0, text.size.y}
			}

			debug_text_entry(&debug_text_pos, "%v player", state.player.count);
			debug_text_entry(&debug_text_pos, "%v bases", state.bases.count);
			debug_text_entry(&debug_text_pos, "%v enemies", state.enemies.count);
			debug_text_entry(&debug_text_pos, "%v towers", state.towers.count);
			debug_text_entry(&debug_text_pos, "%v bullets", state.bullets.count);
			debug_text_entry(&debug_text_pos, "%v spatial grid", state.spatial_grid.count);

			warn_abt_perf :: proc(val: f64, subsystem: string) -> f64 {
				if val < 30 {
					log(subsystem, "was slow!!!")
				}
				return val
			}

			debug_text_entry(&debug_text_pos, "%.3f input", warn_abt_perf(min(1 / state.perf.input, 120), "input"))
			state.perf.input = 0
			debug_text_entry(&debug_text_pos, "%.3f physics", warn_abt_perf(min(1 / state.perf.physics, 120), "physics"))
			state.perf.physics = 0
			debug_text_entry(&debug_text_pos, "%.3f ai", warn_abt_perf(min(1 / state.perf.ai, 120), "ai"))
			state.perf.ai = 0
			debug_text_entry(&debug_text_pos, "%.3f apply_phase", warn_abt_perf(min(1 / state.perf.apply_phase, 120), "apply_phase"))
			state.perf.apply_phase = 0


			if false {
				grid := &state.spatial_grid

				debug_text_entry(
					&debug_text_pos,
					"%v h, %v a, %v r, + %v, - %v, ~ %v",
					grid.num_hops,
					grid.num_accesses,
					f64(grid.num_hops) / f64(grid.num_accesses),
					grid.num_inserts,
					grid.num_removals,
					grid.num_updates,
				)
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
