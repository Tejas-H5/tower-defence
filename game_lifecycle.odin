package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

// timer == 0 -> timer is disabled
// timer > 0  -> timer is ticking
// timer < 0  -> timer has activated, and must be actioned!
advance_timer :: proc(val: ^f32, dt: f32) {
	if val^ != 0 {
		val^ -= dt
		if val^ <= 0 {
			val^ = -1
		}
	}
}

add_tower :: proc(state: ^Game_State, position: Vec2) -> int {
	t := pool_add(&state.towers, {
		color = COLOR_PLAYER,
		health = 100,
		size = 10,
		shoot_cooldown = 1, 
		// shoot_cooldown = 0.1, 
		shoot_cooldown_timer = 1,
	})
	set_entity_position(state, &state.towers, t, position)
	return t
}

add_bullet :: proc(state: ^Game_State, position: Vec2, velocity: Vec2) -> int {
	b := pool_add(&state.bullets, {
		health = 100,
		lifetime_timer = 5,
		velocity = velocity,
		size = 5,
		color = COLOR_PLAYER,
	})
	set_entity_position(state, &state.bullets, b, position)
	state.bullets.items[b].position_prev = position
	return b
}

is_dead :: proc(e: Entity) -> bool {
	return e.health <= 0
}

kill_entity :: proc(g: ^Game_State, pool: ^Item_Pool(Entity), i: int) {
	pool.items[i].health = -1
}

pool_to_type :: proc(g: ^Game_State, pool: ^Item_Pool(Entity)) -> ItemType {
	switch {
	case pool == &g.player:     return .Player;
	case pool == &g.bases:      return .Base;
	case pool == &g.enemies:    return .Enemy;
	case pool == &g.towers:     return .Tower;
	case pool == &g.bullets:    return .Bullet;
	}
	return .Player;
}

set_entity_position :: proc(g: ^Game_State, pool: ^Item_Pool(Entity), i: int,  pos: Vec2) {
	pool.items[i]._position = pos
	spatial_grid_add_or_update(
		&g.spatial_grid,
		&pool.items[i].spatial_grid_handle,
		pos,
		pool.items[i].size / 2,
		i,
		pool
	)
	__spatial_grid_validate_slot(&g.spatial_grid, pool.items[i].spatial_grid_handle.slot)
}

closest_entity_SLOWWW :: proc(pool: ^Item_Pool(Entity), pos: Vec2, max_range: f32) -> (int, bool) {
	target : int = -1
	min_dist : f32 = max_range
	for i in 0..<pool.count {
		dist := linalg.length(pool.items[i]._position - pos)
		if dist < min_dist {
			min_dist = dist
			target = i
		}
	}
	return target, target != -1
}

get_rect :: proc(e: ^Item_Pool(Entity), i: int) -> Rect {
	pos := e.items[i]._position
	size := e.items[i].size
	rect := Rect{ pos - size / 2, size }
	return rect
}
