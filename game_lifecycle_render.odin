package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

render_game :: proc(game_state: ^Game_State) {
	set_mouse_cursor(.None)

	screen_center := Vec2{width(), height()} / 2

	// Perform physics update in a deterministic manner.
	// Plot twist: the render function owns physics update ??
	// Maybe consider multithreading later but how do u make it deterministic? not sure.
	{
		PHYSICS_TIMESTEP           :: 0.02
		MAX_PHYSICS_TO_CATCH_UP_ON :: PHYSICS_TIMESTEP

		// We would implement slow motion / pausing here.
		game_state.physics_to_catch_up_on += get_delta_time()
		if game_state.physics_to_catch_up_on > MAX_PHYSICS_TO_CATCH_UP_ON {
			// If we don't do this, a little bit of lag will cause state.physics_to_catch_up_on to
			// infinitely increase, causing each subsequent frame to take longer and longer.
			// Instead, we can just slow down the simulation a bit by doing this.
			game_state.physics_to_catch_up_on = MAX_PHYSICS_TO_CATCH_UP_ON
		}

		// Ensure determinism of the physics somewhat.
		dt := f32(PHYSICS_TIMESTEP)
		for game_state.physics_to_catch_up_on > 0 {
			game_state.physics_to_catch_up_on -= dt
			update_game(game_state, dt)
		}
	}


	// World
	{
		draw_bg(COLOR_WORLD_BG)


		// Debug world things
		{
			draw_spatial_grid :: proc(game_state: ^Game_State, grid: ^Spatial_Grid) {
				bottom_left := screen_to_world(game_state.view, {0, height()})
				top_right   := screen_to_world(game_state.view, {width(), 0})

				bottom_left_grid := pos_to_grid_coord(grid, bottom_left)
				top_right_grid   := pos_to_grid_coord(grid, top_right)

				for x in bottom_left_grid.x..<top_right_grid.x {
					for y in bottom_left_grid.y..<top_right_grid.y {
						rect := Rect{ 
							{f32(x), f32(y)} * grid.grid_size, 
							grid.grid_size, 
						}

						count := 0
						outline_color := Color{0, 0, 0, 100}
						slot := spatial_grid_coord_to_first_slot(grid, {x, y})
						if slot != nil {
							handle := slot.first
							for handle != nil {
								count += 1
								handle = handle.next
							}
						}

						heat := f32(count) / f32(grid.count)
						heat_bytes := byte(math.floor(255 * math.saturate(heat)))
						draw_rect_outline_world(game_state, rect, 3, outline_color)
						draw_rect_world(game_state, rect, Color{0, 0, 0, heat_bytes})
					}
				}
			}

			// Physics grid
			{
				draw_spatial_grid(game_state, &state.enemies.spatial_grid)
			}

			// World debug lines
			{
				for line in game_state.debug_lines {
					draw_line_world(
						game_state,
						line,
						10,
						{255, 0, 255, 255},
					) 
				}
			}
		}

		for pool in game_state.item_pools {
			for &item in pool_items(pool) {
				enemies_rect := get_rect(&item)

				color := item.color
				color.a = u8(255 * math.lerp(f32(0.1), 1, math.saturate(item.health / 100)))
				draw_rect_world(game_state, enemies_rect, color)

				thickness := item.size / 2
				draw_line_world(game_state, {item.position_prev, item.position}, thickness, color);
			}
		}
	}

	if game_state.bases.items[0].health <= 0 {
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

			debug_text_entry(&debug_text_pos, "%v player", game_state.player.count);
			debug_text_entry(&debug_text_pos, "%v bases", game_state.bases.count);
			debug_text_entry(&debug_text_pos, "%v enemies", game_state.enemies.count);
			debug_text_entry(&debug_text_pos, "%v towers", game_state.towers.count);
			debug_text_entry(&debug_text_pos, "%v bullets", game_state.bullets.count);

			log_timer :: proc(debug_text_pos: ^Vec2, timer: ^NamedTimer) {
				fps := min(1 / timer.t, 120)
				debug_text_entry(debug_text_pos, "%.3f %v", fps, timer.name)
				timer.t = 0
			}

			log_timer(&debug_text_pos, &game_state.perf.input)
			log_timer(&debug_text_pos, &game_state.perf.physics_integration)
			log_timer(&debug_text_pos, &game_state.perf.physics_bullet_line_queries)
			log_timer(&debug_text_pos, &game_state.perf.ai)
			log_timer(&debug_text_pos, &game_state.perf.ai_prioritisation)
			log_timer(&debug_text_pos, &game_state.perf.apply_phase)
		}

		// Cursor
		{
			cursor_pos := get_mouse_pos_world(game_state)
			cursor_size := Vec2{ 1, 1 } * 50
			screen_rect := world_rect_to_screen_rect(game_state.view, {cursor_pos - cursor_size / 2, cursor_size})
			screen_outline_thickness : f32 = 2
			draw_rect_outline(screen_rect, screen_outline_thickness, COLOR_HUD)

			if slot_is_held(0) {
				add_tower(game_state, cursor_pos)
			}
		}
	}
}
