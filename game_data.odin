package main

GameState :: struct {
	view:     ViewBounds,
	entities: [dynamic; 5000]Entity,

	player, base: ^Entity,

	mouse_delta, prev_mouse_pos : Vec2,
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
}

Entity :: struct {
	type:       EntityType,
	position:   Vec2,
	velocity:   Vec2,
	color:      Color,
	size:       f32,
	health:     f32,
	move_speed: f32,
}

add_entity :: proc(state: ^GameState, type: EntityType) -> ^Entity {
	idx := len(state.entities)
	append(&state.entities, {})

	e := &state.entities[idx]

	e.type = type
	e.color = COLOR_BLACK
	e.health = 100

	return e
}

add_tower :: proc(state: ^GameState, position: Vec2) -> ^Entity {
	e := add_entity(state, .Tower)
	e.position = position
	e.color = COLOR_BLUE
	e.size = 20
	return e
}

get_entity_rect :: proc(e: ^Entity) -> Rect {
	return Rect{e.position - e.size / 2, e.size}
}


is_dead :: proc(e: ^Entity) -> bool {
	return e.health <= 0
}
