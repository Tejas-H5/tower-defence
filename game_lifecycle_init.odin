package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:container/handle_map"
import "core:mem"

CAMERA_MOVE_SPEED :: 2.5
CAMERA_MOVE_SPEED_SLOW :: 0.5
CAMERA_MOVE_SPEED_SENSITIVITY :: 30
CAMERA_ZOOM_SPEED :: 5
CAMERA_ZOOM_SPEED_SENSITIVITY :: 20

// Colours should be consistent and convey meaning. 
COLOR_PLAYER :: Color{0, 0, 0, 255}
COLOR_ENEMY :: Color{255, 0, 0, 255}
COLOR_HUD :: Color{0, 0, 255, 255}
COLOR_MISSING :: Color{255, 255, 0, 255}
COLOR_WORLD_BG :: Color{255, 255, 255, 255}

PLAYER_MAX :: 1
BASES_MAX :: 1
ENEMIES_MAX :: 50_000
TOWERS_MAX :: 1000
BULLETS_MAX :: 1_000_000

MAX_TOTAL ::
	PLAYER_MAX +
	BASES_MAX +
	ENEMIES_MAX +
	TOWERS_MAX +
	BULLETS_MAX

Game_State :: struct {
	view: View_Bounds,

	player_memory:  Item_Pool_Memory(Entity, PLAYER_MAX),
	bases_memory:   Item_Pool_Memory(Entity, 1),
	enemies_memory: Item_Pool_Memory(Entity, 50_000),
	towers_memory:  Item_Pool_Memory(Entity, 1000),
	bullets_memory: Item_Pool_Memory(Entity, 1_000_000),

	spatial_grid: Spatial_Grid(2 * MAX_TOTAL),
	
	player:  Item_Pool(Entity), // There will only ever be one player but I do this for #soa code reuseability
	bases:   Item_Pool(Entity),
	enemies: Item_Pool(Entity),
	towers:  Item_Pool(Entity),
	bullets: Item_Pool(Entity),
	item_pools: [5]^Item_Pool(Entity),

	mouse_delta, prev_mouse_pos : Vec2,

	perf: struct {
		input, physics, ai, apply_phase: f64,
	},
}

Base :: struct {
	pos:  Vec2,
	size: f32,
}

Entity :: struct {
	added_before_this_frame: bool,
	_position, position_prev: Vec2,
	velocity:   Vec2,
	color:      Color,
	size:       f32,
	health:     f32,

	spatial_grid_handle: Spatial_Grid_Handle,

	move_speed: f32,

	// If this is 0, nothing happens. 
	// If this was greater than zero, _then_ gets decremented to <= 0, then it becomes collected.
	lifetime_timer: f32,
	shoot_cooldown: f32,
	shoot_cooldown_timer: f32,
	
	// spacial_grid: map[Vec2i]^Collision,
	// collisions: [  c]Collision,
}


init :: proc(state: ^Game_State) {
	megabytes := size_of(Game_State) / mem.Megabyte
	log("\n================ Memory usage: ", megabytes, "mb ================ ")

	state.view = {
		size = 1000,
	}

	state.spatial_grid.grid_size = 50

	state.player  = memory_to_pool(&state.player_memory)
	state.bases   = memory_to_pool(&state.bases_memory)
	state.enemies = memory_to_pool(&state.enemies_memory)
	state.towers  = memory_to_pool(&state.towers_memory)
	state.bullets = memory_to_pool(&state.bullets_memory)

	// NOTE: defines a bunch of things like the render order and 
	// update order. We might want to seperate this later.
	state.item_pools = {
		&state.bases,
		&state.enemies,
		&state.towers,
		&state.bullets,
		&state.player,
	}

	pool_add(&state.bases, {
		size   = 100,
		color  = COLOR_PLAYER,
		health = 100,
	})

	state.player.items[0] = {
		size   = 0,
		color  = {0, 0, 255, 255},
		health = 100,
	}

	for i in 0..<1000 {
		angle := rand.float32_range(-math.PI, math.PI)
		pos := 1000 * Vec2{math.cos(angle), math.sin(angle)}
		e := pool_add(&state.enemies, {
			size          = 10,
			health        = 100,
			move_speed    = 30 * rand.float32_range(1, 2),
			color         = {255, 0, 0, 255},
		})
		set_entity_position(state, &state.enemies, e, pos)
	}
}
