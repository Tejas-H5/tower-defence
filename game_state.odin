package main

import hm "core:container/handle_map"

import "core:math"
import "core:math/linalg"
import "core:math/rand"

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

MAX_ENTITIES :: 65534

EntitiesHandleMap :: hm.Static_Handle_Map(MAX_ENTITIES, Entity, EntityHandle)
GameState :: struct {
	view: ViewBounds,
	entities: EntitiesHandleMap,
	player, base: ^Entity,
	mouse_delta, prev_mouse_pos : Vec2,

	perf: struct {
		input, physics, ai, apply_phase: f64,
	},
}

Base :: struct {
	pos:  Vec2,
	size: f32,
}

EntityType :: enum {
	Base,
	Enemy,
	Player,
	Tower,
	Bullet,
}

EntityHandle :: hm.Handle32
Entity :: struct {
	added_before_this_frame:    bool,
	handle:     EntityHandle,
	type:       EntityType,
	position, position_prev:   Vec2,
	velocity:   Vec2,
	color:      Color,
	size:       f32,
	health:     f32,

	target_entity: EntityHandle,
	move_speed: f32,

	// If this is 0, nothing happens. 
	// If this was greater than zero, _then_ gets decremented to <= 0, then it becomes collected.
	lifetime_timer: f32,
	shoot_cooldown: f32,
	shoot_cooldown_timer: f32,
	
	// spacial_grid: map[Vec2i]^Collision,
	// collisions: [  c]Collision,
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

add_entity :: proc(state: ^GameState, e: Entity) -> EntityHandle {
	handle := hm.add(&state.entities, e)
	e := hm.get(&state.entities, handle)
	e.position_prev = e.position
	return handle
}

add_tower :: proc(state: ^GameState, position: Vec2) -> EntityHandle {
	return add_entity(state, {
		type = .Tower,
		position = position,
		color = COLOR_PLAYER,
		health = 100,
		size = 20,
		shoot_cooldown = 1, shoot_cooldown_timer = 1,
	})
}

add_bullet :: proc(state: ^GameState, position: Vec2, velocity: Vec2) -> EntityHandle {
	return add_entity(state, {
		type = .Bullet, 
		position = position,
		color    = COLOR_PLAYER,
		size     = 5,
		velocity = velocity,
	})
}

get_entity_rect :: proc(e: ^Entity) -> Rect {
	return Rect{e.position - e.size / 2, e.size}
}

is_dead :: proc(e: ^Entity) -> bool {
	return e.health <= 0
}

kill_entity :: proc(e: ^Entity) {
	e.health = -1
}

get_entity :: proc(state: ^GameState, h: EntityHandle) -> (^Entity, bool) #optional_ok {
	return hm.get(&state.entities, h)
}

EntityIterator :: hm.Static_Handle_Map_Iterator(EntitiesHandleMap)

entity_iterator :: proc(state: ^GameState) -> EntityIterator {
	return hm.iterator_make(&state.entities)
}

iterate_entities :: proc(iter: ^EntityIterator) -> (^Entity, bool) {
	e, _, ok :=  hm.static_iterate(iter)
	return e, ok
}

remove_entity :: proc(state: ^GameState, e: ^Entity) {
	hm.remove(&state.entities, e.handle)
}

entity_count :: proc(state: ^GameState) -> uint {
	return hm.len(state.entities)
}

closest_entity_SLOWWW :: proc(state: ^GameState, pos: Vec2, max_range: f32, type: EntityType) -> ^Entity {
	target : ^Entity
	min_dist : f32 = max_range
	for iter := entity_iterator(state); e_other in iterate_entities(&iter) {
		if e_other.type != type {continue}

		dist := linalg.length(e_other.position - pos)
		if dist < min_dist {
			min_dist = dist
			target = e_other
		}
	}
	return target
}

get_rect :: proc(e: ^Entity) -> Rect {
	rect := Rect{e.position - e.size / 2, e.size}
	return rect
}
