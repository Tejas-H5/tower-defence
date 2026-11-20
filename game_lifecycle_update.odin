package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

update_game :: proc(game: ^Game_State, dt: f32) {
	mouse_pos := get_mouse_pos()
	defer game.prev_mouse_pos = mouse_pos
	game.mouse_delta = mouse_pos - game.prev_mouse_pos

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
					pos_vel_target := game.view.size * dir * move_speed
					size_vel_target :=
						game.view.size * get_z_axis_input_held() * CAMERA_ZOOM_SPEED
					game.view.pos_vel = linalg.lerp(
						game.view.pos_vel,
						pos_vel_target,
						dt * CAMERA_MOVE_SPEED_SENSITIVITY,
					)
					game.view.size_vel = linalg.lerp(
						game.view.size_vel,
						size_vel_target,
						dt * CAMERA_ZOOM_SPEED_SENSITIVITY,
					)
					game.view.pos += game.view.pos_vel * dt
					game.view.size += game.view.size_vel * dt
				}

				// Drag movement
				{
					if cursor_is_held() {
						delta := screen_size_to_world_size(game.view, game.mouse_delta)
						game.view.pos -= delta
					}
				}

				BOUNDS :: 10_000
				game.view.pos.x = clamp(game.view.pos.x, -BOUNDS, BOUNDS)
				game.view.pos.y = clamp(game.view.pos.y, -BOUNDS, BOUNDS)
				game.view.size = clamp(game.view.size, 100, 10000)
			}

			set_entity_position(game, &game.player, 0, game.view.pos)
			// intentional - we want a teleport and not a move
			game.player.items[0].position_prev = game.player.items[0]._position
		}
	}
	game.perf.input += update_timer(&t)

	// Step world physics
	{
		num_iterations := 0
		for pool in game.item_pools {
			is_bullets_pool := pool == &game.bullets

			for i in 0 ..< pool.count {
				advance_timer(&pool.items.lifetime_timer[i], dt)
				advance_timer(&pool.items.shoot_cooldown_timer[i], dt)
				pool.items.position_prev[i] = pool.items._position[i]
				set_entity_position(game, pool, i, pool.items[i]._position + dt * pool.items.velocity[i])

				if is_bullets_pool {
					bullet := pool.items[i]
					// Bullets get to damage enemies.
					// Oh shit maybe this is the slow bit ...
					// but this is far easier to speed up with a spatial hash than the 'closest enemy' thing the towers do.

					bullet_ray := Line{bullet.position_prev, bullet._position}


					it := spatial_grid_line_iterator(&game.spatial_grid, bullet_ray)
					for slot in spatial_grid_line_iterate(&it) {
						num_iterations += 1
						enemy_pool := cast(^Item_Pool(Entity))slot.pool
						if enemy_pool == &game.enemies {

							j := slot.handle - 1

							other_rect := get_rect(&state.enemies, j)
							res := line_intersects_rect(bullet_ray, other_rect)
							if res.num_hits > 0 {
								set_entity_position(game, pool, i, res.hits[0].pos)
							}
						}
					}
				}
			}
		}
		log("num iterations: ", num_iterations)
	}
	game.perf.physics += update_timer(&t)

	// Figure out what just happened, action it
	{
		for pool in game.item_pools {
			is_bullets_pool := pool == &game.bullets
			is_tower_pool := pool == &game.towers
			is_enemy_pool := pool == &game.enemies

			for i in 0 ..< pool.count {
				if !pool.items[i].added_before_this_frame {continue}

				if is_tower_pool {
					if pool.items[i].shoot_cooldown_timer < 0 {
						pool.items[i].shoot_cooldown_timer = pool.items[i].shoot_cooldown


						MAX_RANGE :: 10_000
						// TODO: optimize this query somehow.
						pos := pool.items[i]._position
						target, ok := closest_entity_SLOWWW(&game.enemies, pos, MAX_RANGE)
						if ok {
							BULLET_SPEED :: 10_000
							velocity := 
								BULLET_SPEED * 
								linalg.normalize0(game.enemies.items[target]._position - pos)
							h := add_bullet(game, pos, velocity)
						}
					}
				} else if is_enemy_pool {
					pool.items[i].velocity =
						pool.items[i].move_speed *
						linalg.normalize0(game.bases.items[0]._position - pool.items[i]._position)

					if rect_intersects_rect(get_rect(&game.bases, 0), get_rect(pool, i)) {
						game.bases.items[0].health -= 1
						kill_entity(game, pool, i);
					}
				} else if is_bullets_pool {
					rect := get_rect(pool, i)
					bullet_health := pool.items[i].health

					bullet_hit := false
					for i in 0 ..< game.enemies.count {
						enemy_rect := get_rect(&game.enemies, i)

						// Raycasting already happened during the physics update. We only
						// need to check intersecting. TODO: if the raycast already detected the collision maybe we dont even need to do this!
						if rect_intersects_rect(rect, enemy_rect) {
							game.enemies.items[i].health -= bullet_health
							bullet_hit = true
							break
						}
					}

					if bullet_hit {
						kill_entity(game, pool, i)
					}
				}
			}
		}
	}
	game.perf.ai += update_timer(&t)

	// Clean up dead entities, add new entities
	{
		for pool in game.item_pools {
			for i := 0; i < pool.count; i += 1 {
				// Enable entities at the end, for correctness
				pool.items[i].added_before_this_frame = true

				if pool == &game.player {continue}
				if pool == &game.bases {continue}

				if pool.items[i].health <= 0 || pool.items[i].lifetime_timer < 0 {
					spatial_grid_remove(&game.spatial_grid, &pool.items[i].spatial_grid_handle)
					pool_unordered_remove(pool, i)
					if i != pool.count {
						pool.items[i].spatial_grid_handle.slot.handle = i + 1
					}

					i -= 1
				}
			}
		}
	}
	game.perf.apply_phase += update_timer(&t)
}

