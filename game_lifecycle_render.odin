package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

render_game :: proc(state: ^Game_State) {
	screen_center := Vec2{width(), height()} / 2

	// World
	{
		draw_bg(COLOR_WORLD_BG)

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

			debug_text_entry(&debug_text_pos, "%.3f input", min(1 / state.perf.input, 120))
			state.perf.input = 0
			debug_text_entry(&debug_text_pos, "%.3f physics", min(1 / state.perf.physics, 120))
			state.perf.physics = 0
			debug_text_entry(&debug_text_pos, "%.3f ai", min(1 / state.perf.ai, 120))
			state.perf.ai = 0
			debug_text_entry(&debug_text_pos, "%.3f apply_phase", min(1 / state.perf.apply_phase, 120))
			state.perf.apply_phase = 0
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
