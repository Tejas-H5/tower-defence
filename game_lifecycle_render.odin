package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

render_game :: proc(game: ^Game_State) {
	set_mouse_cursor(.None)

	screen_center := Vec2{width(), height()} / 2

	// Perform physics update in a deterministic manner.
	// Plot twist: the render function owns physics update ??
	// Maybe consider multithreading later but how do u make it deterministic? not sure.
	{
		PHYSICS_TIMESTEP           :: 0.02
		MAX_PHYSICS_TO_CATCH_UP_ON :: PHYSICS_TIMESTEP

		// We would implement slow motion / pausing here.
		game.physics_to_catch_up_on += get_delta_time()
		if game.physics_to_catch_up_on > MAX_PHYSICS_TO_CATCH_UP_ON {
			// If we don't do this, a little bit of lag will cause state.physics_to_catch_up_on to
			// infinitely increase, causing each subsequent frame to take longer and longer.
			// Instead, we can just slow down the simulation a bit by doing this.
			game.physics_to_catch_up_on = MAX_PHYSICS_TO_CATCH_UP_ON
		}

		// Ensure determinism of the physics somewhat.
		dt := f32(PHYSICS_TIMESTEP)
		for game.physics_to_catch_up_on > 0 {
			game.physics_to_catch_up_on -= dt
			update_game(game, dt)
		}
	}


	// World
	{
		draw_bg(COLOR_WORLD_BG)


		// Debug world things
		{
			// Physics grid
			{
				bottom_left := screen_to_world(game.view, {0, height()})
				top_right   := screen_to_world(game.view, {width(), 0})

				bottom_left_grid := pos_to_grid_coord(&game.spatial_grid, bottom_left)
				top_right_grid   := pos_to_grid_coord(&game.spatial_grid, top_right)

				for x in bottom_left_grid.x..<top_right_grid.x {
					for y in bottom_left_grid.y..<top_right_grid.y {
						rect := Rect{ 
							{f32(x), f32(y)} * game.spatial_grid.grid_size, 
							game.spatial_grid.grid_size, 
						}

						count := 0
						outline_color := Color{0, 0, 0, 100}
						slot := spatial_grid_coord_to_first_slot(&game.spatial_grid, {x, y})
						if slot != nil {
							handle := slot.first
							for handle != nil {
								count += 1
								handle = handle.next
							}

							if slot.visited {
								outline_color.g = 255
							}
						}

						heat := f32(count) / f32(game.spatial_grid.count)
						heat_bytes := byte(math.floor(255 * math.saturate(heat)))
						draw_rect_outline_world(game, rect, 3, outline_color)
						draw_rect_world(game, rect, Color{0, 0, 0, heat_bytes})
					}
				}
			}

			// World debug lines
			{
				for line in game.debug_lines {
					draw_line_world(
						game,
						line,
						10,
						{255, 0, 255, 255},
					) 
				}
			}
		}

		for pool in game.item_pools {
			for i in 0..<pool.count {
				enemies_rect := get_rect(pool, i)
				color := pool.items[i].color
				health := pool.items[i].health
				size := pool.items[i].size
				position := pool.items[i]._position
				position_prev := pool.items[i].position_prev

				color.a = u8(255 * math.lerp(f32(0.1), 1, math.saturate(health / 100)))
				draw_rect_world(game, enemies_rect, color)

				thickness := size / 2
				draw_line_world(game, {position_prev, position}, thickness, color);
			}
		}
	}

	if game.bases.items[0].health <= 0 {
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

			debug_text_entry(&debug_text_pos, "%v player", game.player.count);
			debug_text_entry(&debug_text_pos, "%v bases", game.bases.count);
			debug_text_entry(&debug_text_pos, "%v enemies", game.enemies.count);
			debug_text_entry(&debug_text_pos, "%v towers", game.towers.count);
			debug_text_entry(&debug_text_pos, "%v bullets", game.bullets.count);
			debug_text_entry(&debug_text_pos, "%v spatial grid", game.spatial_grid.count);

			warn_abt_perf :: proc(val: f64, subsystem: string) -> f64 {
				if val < 30 {
					log(subsystem, "was slow!!!")
				}
				return val
			}

			debug_text_entry(&debug_text_pos, "%.3f input", warn_abt_perf(min(1 / game.perf.input, 120), "input"))
			game.perf.input = 0
			debug_text_entry(&debug_text_pos, "%.3f physics", warn_abt_perf(min(1 / game.perf.physics, 120), "physics"))
			game.perf.physics = 0
			debug_text_entry(&debug_text_pos, "%.3f ai", warn_abt_perf(min(1 / game.perf.ai, 120), "ai"))
			game.perf.ai = 0
			debug_text_entry(&debug_text_pos, "%.3f apply_phase", warn_abt_perf(min(1 / game.perf.apply_phase, 120), "apply_phase"))
			game.perf.apply_phase = 0


			if false {
				grid := &game.spatial_grid

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
			cursor_pos := get_mouse_pos_world(game)
			cursor_size := Vec2{ 1, 1 } * 50
			screen_rect := world_rect_to_screen_rect(game.view, {cursor_pos - cursor_size / 2, cursor_size})
			screen_outline_thickness : f32 = 2
			draw_rect_outline(screen_rect, screen_outline_thickness, COLOR_HUD)

			if slot_is_held(0) {
				add_tower(game, cursor_pos)
			}
		}
	}
}
