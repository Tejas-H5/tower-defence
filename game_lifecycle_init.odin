package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"

import pq "core:container/priority_queue"

// I don't actually use this anymore, but it's a good example of parapoly in odin
// import "core:container/handle_map"

IS_TEST_SCENARIO :: false

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
ENEMIES_MAX :: 1_000_000
TOWERS_MAX :: 30_000
BULLETS_MAX :: 1_000_000

MAX_TOTAL ::
	PLAYER_MAX +
	BASES_MAX +
	ENEMIES_MAX +
	TOWERS_MAX +
	BULLETS_MAX

Game_State :: struct {
	physics_to_catch_up_on: f32,

	view: View_Bounds,

	player_memory:  Item_Pool_Memory(Entity, PLAYER_MAX),
	bases_memory:   Item_Pool_Memory(Entity, BASES_MAX),
	enemies_memory: Item_Pool_Memory(Entity, ENEMIES_MAX),
	towers_memory:  Item_Pool_Memory(Entity, TOWERS_MAX),
	bullets_memory: Item_Pool_Memory(Entity, BULLETS_MAX),
	
	player:  Item_Pool(Entity), // There will only ever be one player but I do this for #soa code reuseability
	bases:   Item_Pool(Entity),
	enemies: Item_Pool(Entity),
	towers:  Item_Pool(Entity),

	bullets: Item_Pool(Entity),

	// Even with multiple bases, rather than
	closest_to_base: pq.Priority_Queue(EnemyTarget),
	
	item_pools: [ItemType]^Item_Pool(Entity),

	debug_lines: [dynamic; 100_000]Line,

	mouse_delta, prev_mouse_pos : Vec2,

	perf: Perf, 
}

EnemyTarget :: struct {
	idx: int,
	distance: f32,
}

Perf :: struct {
	input:                       NamedTimer,
	physics:                     NamedTimer,
	physics_integration:         NamedTimer,
	physics_bullet_line_queries: NamedTimer,
	ai:                          NamedTimer,
	ai_prioritisation:           NamedTimer,
	apply_phase:                 NamedTimer,
}

ItemType :: enum {
	Player,
	Base,
	Enemy,
	Tower,
	Bullet,
}

Base :: struct {
	pos:  Vec2,
	size: f32,
}

Entity :: struct {
	added_before_this_frame: bool,
	position, position_prev: Vec2,
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

	distance_to_base: f32,
	
	// spacial_grid: map[Vec2i]^Collision,
	// collisions: [  c]Collision,
}

EntitySoaPtr :: #soa^#soa[]Entity

init :: proc(state: ^Game_State) {
	megabytes := size_of(Game_State) / mem.Megabyte
	log("\n================ Memory usage: ", megabytes, "mb ================ ")

	state.view = {
		size = 1000,
	}

	state.perf.input.name                       = "input";
	state.perf.physics.name                     = "physics";
	state.perf.physics_integration.name         = "physics_integration";
	state.perf.physics_bullet_line_queries.name = "physics_bullet_line_queries";
	state.perf.ai.name                          = "ai";
	state.perf.ai_prioritisation.name           = "ai_prioritisation";
	state.perf.apply_phase.name                 = "apply_phase";

	// Init pools 
	{
		state.player  = memory_to_pool(&state.player_memory,  grid_size = 200)
		state.bases   = memory_to_pool(&state.bases_memory,   grid_size = 200)
		state.enemies = memory_to_pool(&state.enemies_memory, grid_size = 100)
		state.towers  = memory_to_pool(&state.towers_memory,  grid_size = 200)
		state.bullets = memory_to_pool(&state.bullets_memory, grid_size = 200)

		// NOTE: defines a bunch of things like the render order and 
		// update order. We might want to seperate this later.
		state.item_pools = {
			.Base   = &state.bases,
			.Enemy  = &state.enemies,
			.Tower  = &state.towers,
			.Bullet = &state.bullets,
			.Player = &state.player,
		}
	}

	pq.init(
		&state.closest_to_base,
		less = proc(a, b: EnemyTarget) -> bool {
			return a.distance < b.distance
		},
		swap = pq.default_swap_proc(EnemyTarget),
	)


	pool_add(&state.bases, {
		size   = 20,
		color  = COLOR_PLAYER,
		health = 100,
	})

	state.player.items[0] = {
		size   = 0,
		color  = {0, 0, 255, 255},
		health = 100,
	}


	n := IS_TEST_SCENARIO ? 100 : 10_000 // 100_000 
	for i in 0..<n {
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

	cg: Circle_Generator
	for pos in circle_generate(&cg, IS_TEST_SCENARIO ? 1 : 100) {
		t := add_tower(state, pos * rand.float32_range(50, 100))
		state.towers.items[t].shoot_cooldown_timer = rand.float32_range(0, state.towers.items[t].shoot_cooldown);
	}
}


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
	cooldown := f32(IS_TEST_SCENARIO ? 1 : 0.1)
	t := pool_add(&state.towers, {
		color                = COLOR_PLAYER,
		health               = 100,
		size                 = 10,
		shoot_cooldown       = cooldown,
		shoot_cooldown_timer = rand.float32_range(0, cooldown),
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

kill_entity :: proc(e: EntitySoaPtr) {
	e.health = -1
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
	e := &pool.items[i]
	e.position = pos

	grid := &pool.spatial_grid
	spatial_grid_add_or_update(
		grid,
		&e.spatial_grid_handle,
		pos,
		e.size / 2,
		i,
		pool
	)
	__spatial_grid_validate_slot(grid, e.spatial_grid_handle.slot)
}

closest_entity_SLOWWW :: proc(pool: ^Item_Pool(Entity), pos: Vec2, max_range: f32) -> (int, bool) {
	target : int = -1
	min_dist : f32 = max_range
	for i in 0..<pool.count {
		dist := linalg.length(pool.items[i].position - pos)
		if dist < min_dist {
			min_dist = dist
			target = i
		}
	}
	return target, target != -1
}

get_rect :: proc(e: EntitySoaPtr) -> Rect {
	pos := e.position
	size := e.size
	rect := Rect{ pos - size / 2, size }
	return rect
}
