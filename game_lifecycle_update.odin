package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

update_game :: proc(state: ^Game_State, dt: f32) {
	mouse_pos := get_mouse_pos()
	defer state.prev_mouse_pos = mouse_pos
	state.mouse_delta = mouse_pos - state.prev_mouse_pos

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
					move_speed: f32 =
						get_slow_movement_input_held() ? CAMERA_MOVE_SPEED_SLOW : CAMERA_MOVE_SPEED
					pos_vel_target := state.view.size * dir * move_speed
					size_vel_target :=
						state.view.size * get_z_axis_input_held() * CAMERA_ZOOM_SPEED
					state.view.pos_vel = linalg.lerp(
						state.view.pos_vel,
						pos_vel_target,
						dt * CAMERA_MOVE_SPEED_SENSITIVITY,
					)
					state.view.size_vel = linalg.lerp(
						state.view.size_vel,
						size_vel_target,
						dt * CAMERA_ZOOM_SPEED_SENSITIVITY,
					)
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

			set_entity_position(state, &state.player, 0, state.view.pos)
			// intentional - we want a teleport and not a move
			state.player.items[0].position_prev = state.player.items[0]._position
		}
	}
	state.perf.input += update_timer(&t)

	// Step world physics
	{
		for pool in state.item_pools {
			is_bullets_pool := pool == &state.bullets

			for i in 0 ..< pool.count {
				advance_timer(&pool.items.lifetime_timer[i], dt)
				advance_timer(&pool.items.shoot_cooldown_timer[i], dt)
				pool.items.position_prev[i] = pool.items._position[i]
				set_entity_position(state, pool, i, pool.items[i]._position + dt * pool.items.velocity[i])

				if is_bullets_pool {
					// Bullets get to damage enemies.
					// Oh shit maybe this is the slow bit ...
					// but this is far easier to speed up with a spatial hash than the 'closest enemy' thing the towers do.
					ray := Line{pool.items[i].position_prev, pool.items[i]._position}

					for i in 0 ..< state.enemies.count {
						other_rect := get_rect(&state.enemies, i)
						res := line_intersects_rect(ray, other_rect)
						if res.num_hits > 0 {
							set_entity_position(state, pool, i, res.hits[0].pos)
						}
					}
				}
			}
		}
	}
	state.perf.physics += update_timer(&t)

	// Figure out what just happened, action it
	{
		for pool in state.item_pools {
			is_bullets_pool := pool == &state.bullets
			is_tower_pool := pool == &state.towers
			is_enemy_pool := pool == &state.enemies

			for i in 0 ..< pool.count {
				if !pool.items[i].added_before_this_frame {continue}

				if is_tower_pool {
					if pool.items[i].shoot_cooldown_timer < 0 {
						pool.items[i].shoot_cooldown_timer = pool.items[i].shoot_cooldown


						MAX_RANGE :: 10_000
						// TODO: optimize this query somehow.
						pos := pool.items[i]._position
						target, ok := closest_entity_SLOWWW(&state.enemies, pos, MAX_RANGE)
						if ok {
							BULLET_SPEED :: 10_000
							velocity :=
								BULLET_SPEED *
								linalg.normalize0(state.enemies.items[target]._position - pos)
							h := pool_add(
								&state.bullets,
								{
									health = 100,
									lifetime_timer = 5,
									velocity = velocity,
									size = 5,
									color = COLOR_PLAYER,
								},
							)
							set_entity_position(state, &state.bullets, h, pos)
						}
					}
				} else if is_enemy_pool {
					pool.items[i].velocity =
						pool.items[i].move_speed *
						linalg.normalize0(state.bases.items[0]._position - pool.items[i]._position)

					if rect_intersects_rect(get_rect(&state.bases, 0), get_rect(pool, i)) {
						state.bases.items[0].health -= 1
						kill_entity(state, pool, i);
					}
				} else if is_bullets_pool {
					rect := get_rect(pool, i)
					bullet_health := pool.items[i].health

					bullet_hit := false
					for i in 0 ..< state.enemies.count {
						enemy_rect := get_rect(&state.enemies, i)

						// Raycasting already happened during the physics update. We only
						// need to check intersecting. TODO: if the raycast already detected the collision maybe we dont even need to do this!
						if rect_intersects_rect(rect, enemy_rect) {
							state.enemies.items[i].health -= bullet_health
							bullet_hit = true
							break
						}
					}

					if bullet_hit {
						kill_entity(state, pool, i)
					}
				}
			}
		}
	}
	state.perf.ai += update_timer(&t)

	// Clean up dead entities, add new entities
	{
		for pool in state.item_pools {
			for i := 0; i < pool.count; i += 1 {
				// Enable entities at the end, for correctness
				pool.items[i].added_before_this_frame = true

				if pool == &state.player {continue}
				if pool == &state.bases {continue}

				if pool.items[i].health <= 0 || pool.items[i].lifetime_timer < 0 {
					pool_remove(pool, i)
					i -= 1
				}
			}
		}
	}
	state.perf.apply_phase += update_timer(&t)
}
