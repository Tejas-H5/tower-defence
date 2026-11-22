package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"
import pq "core:container/priority_queue"

update_game :: proc(game_state: ^Game_State, dt: f32) {
	mouse_pos := get_mouse_pos()
	defer game_state.prev_mouse_pos = mouse_pos
	game_state.mouse_delta = mouse_pos - game_state.prev_mouse_pos

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
					pos_vel_target := game_state.view.size * dir * move_speed
					size_vel_target :=
						game_state.view.size * get_z_axis_input_held() * CAMERA_ZOOM_SPEED
					game_state.view.pos_vel = linalg.lerp(
						game_state.view.pos_vel,
						pos_vel_target,
						dt * CAMERA_MOVE_SPEED_SENSITIVITY,
					)
					game_state.view.size_vel = linalg.lerp(
						game_state.view.size_vel,
						size_vel_target,
						dt * CAMERA_ZOOM_SPEED_SENSITIVITY,
					)
					game_state.view.pos += game_state.view.pos_vel * dt
					game_state.view.size += game_state.view.size_vel * dt
				}

				// Drag movement
				{
					if cursor_is_held() {
						delta := screen_size_to_world_size(game_state.view, game_state.mouse_delta)
						game_state.view.pos -= delta
					}
				}

				BOUNDS :: 10_000
				game_state.view.pos.x = clamp(game_state.view.pos.x, -BOUNDS, BOUNDS)
				game_state.view.pos.y = clamp(game_state.view.pos.y, -BOUNDS, BOUNDS)
				game_state.view.size = clamp(game_state.view.size, 100, 10000)
			}

			set_entity_position(game_state, &game_state.player, 0, game_state.view.pos)
			// intentional - we want a teleport and not a move
			game_state.player.items[0].position_prev = game_state.player.items[0].position
		}
	}
	game_state.perf.input.t += update_timer(&t)

	// Step world physics
	{
		t2 := t

		for pool in game_state.item_pools {
			is_bullets_pool := pool == &game_state.bullets

			for &item, item_idx in pool_items(pool) {
				advance_timer(&item.lifetime_timer, dt)
				advance_timer(&item.shoot_cooldown_timer, dt)
				item.position_prev = item.position
				set_entity_position(game_state, pool, item_idx, item.position + dt * item.velocity)
			}
		}
		game_state.perf.physics_integration.t += update_timer(&t2)

		// bullets
		// TODO: maybe we want this for everything?
		// TODO: generic collisions?
		{
			num_iterations := 0
			for &bullet, bullet_idx in pool_items(&game_state.bullets) {
				bullet_ray := Line{bullet.position_prev, bullet.position}

				// For every enemy that intersects with the bullet's movenent ray, 
				// we want to move the bullet back to the closest enemy.
				// TODO: piercing bullets that can move through multiple enemies?
				it := spatial_grid_line_iterator(&game_state.enemies.spatial_grid, bullet_ray)
				for slot in spatial_grid_line_iterate(&it) {
					num_iterations += 1
					enemy, ok := get_entity_for_slot(slot, &game_state.enemies)
					if ok {
						other_rect := get_rect(enemy)
						res := line_intersects_rect(bullet_ray, other_rect)
						if res.num_hits > 0 {
							set_entity_position(game_state, &game_state.bullets, bullet_idx, res.hits[0].pos)
						}
					}
				}
			}
			log("num iterations: ", num_iterations)
			game_state.perf.physics_bullet_line_queries.t += update_timer(&t2)
		}
	}
	game_state.perf.physics.t += update_timer(&t)

	// Figure out what just happened, action it
	{
		t2 := t

		pq.clear(&game_state.closest_to_base)
		for enemy, enemy_idx in pool_items(&game_state.enemies) {
			closest_distance: f32 = -1
			for base in pool_items(&game_state.bases) {
				distance := linalg.length(base.position - enemy.position)
				if closest_distance < 0 || distance < closest_distance {
					closest_distance = distance
				}
			}
			if closest_distance > 0 {
				pq.push(&game_state.closest_to_base, {enemy_idx, closest_distance})
			}
			if pq.len(game_state.closest_to_base) == game_state.towers.count {
				break;
			}
		}
		game_state.perf.ai_prioritisation.t += update_timer(&t2)

		for &tower, tower_idx in pool_items(&game_state.towers) {
			// NOTE: we will want more intelligent allocation of targets to towers later.

			if tower.shoot_cooldown_timer < 0 {
				tower.shoot_cooldown_timer = tower.shoot_cooldown

				targets_queue := &game_state.closest_to_base.queue
				if len(targets_queue) > 0 {
					target       := targets_queue[tower_idx % len(targets_queue)]
					target_enemy := &game_state.enemies.items[target.idx]

					BULLET_SPEED :: 10_000
					velocity := BULLET_SPEED * linalg.normalize0(target_enemy.position - tower.position)
					add_bullet(game_state, tower.position, velocity)
				}
			}
		}

		for &enemy in pool_items(&game_state.enemies) {
			enemy.velocity =
				enemy.move_speed *
				linalg.normalize0(game_state.bases.items[0].position - enemy.position)

			for &base in pool_items(&game_state.bases) {
				if rect_intersects_rect(get_rect(&base), get_rect(&enemy)) {
					game_state.bases.items[0].health -= 1
					kill_entity(&enemy)
				}
			}
		}

		for &bullet in pool_items(&game_state.bullets) {
			rect := get_rect(&bullet)
			bullet_health := bullet.health

			bullet_hit := false

			rect_it := spatial_grid_rect_iterator(&game_state.enemies.spatial_grid, rect)
			for slot in spatial_grid_rect_iterate(&rect_it) {
				enemy, ok := get_entity_for_slot(slot, &game_state.enemies)
				if ok {
					enemy_rect := get_rect(enemy)
					// Raycasting already happened during the physics update. We only
					// need to check intersecting. TODO: if the raycast already detected the collision maybe we dont even need to do this!
					if rect_intersects_rect(rect, enemy_rect) {
						enemy.health -= bullet_health
						bullet_hit = true
						break
					}
				}
			}

			if bullet_hit {
				kill_entity(&bullet)
			}
		}
	}
	game_state.perf.ai.t += update_timer(&t)

	// Clean up dead entities, add new entities
	{
		for pool in game_state.item_pools {
			for i := 0; i < pool.count; i += 1 {
				// Enable entities at the end, for correctness
				pool.items[i].added_before_this_frame = true

				if pool == &game_state.player {continue}
				if pool == &game_state.bases {continue}

				if pool.items[i].health <= 0 || pool.items[i].lifetime_timer < 0 {
					spatial_grid_remove(&pool.spatial_grid, &pool.items[i].spatial_grid_handle)
					pool_unordered_remove(pool, i)
					if i != pool.count {
						pool.items[i].spatial_grid_handle.slot.handle = i + 1
					}

					i -= 1
				}
			}
		}
	}
	game_state.perf.apply_phase.t += update_timer(&t)
}

get_entity_for_slot :: proc(slot: ^Spatial_Grid_Slot, expected_pool: ^Item_Pool(Entity)) -> (item: EntitySoaPtr, ok: bool) {
	pool := cast(^Item_Pool(Entity))slot.pool
	if pool != expected_pool {return nil, false}

	return pool_get(expected_pool, slot.handle - 1), true
}


