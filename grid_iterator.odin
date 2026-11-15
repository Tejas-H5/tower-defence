package main

import "core:math"
import "core:math/linalg"

Grid_Line_Intersection_Iterator :: struct {
	grid_size: f32,
	start, pos, dir: Vec2,
	length: f32,
	t: f32,
}

grid_line_intersection_iterator :: proc(start, end: Vec2, grid_size: f32) -> Grid_Line_Intersection_Iterator {
	pos := start
	length := linalg.length(end - start)
	dir := linalg.normalize0(end - start)

	return {
		start     = start,
		length    = length,
		grid_size = grid_size,
		pos       = pos, 
		dir       = dir,
		t         = 0,
	};
}

grid_line_intersection_iterate :: proc(it: ^Grid_Line_Intersection_Iterator) -> (Vec2, bool)  {
	// TODO: Y 
	// TODO: direction
	// TODO: dir.x ~0, dir.y ~ 0

	next_grid_pos :: proc(val, grid_size: f32, positive: bool) -> f32 {
		EPSILON :: 0.0001

		grid_coord: f32
		if positive {
			grid_coord = math.ceil((val + EPSILON) / grid_size)
		} else {
			grid_coord = math.floor((val - EPSILON) / grid_size)
		}

		return grid_coord * grid_size
	}

	grid_x := next_grid_pos(it.pos.x, it.grid_size, it.dir.x > 0)
	t_x    := (grid_x - it.start.x) / it.dir.x

	grid_y := next_grid_pos(it.pos.y, it.grid_size, it.dir.y > 0)
	t_y    := (grid_y - it.start.y) / it.dir.y

	t_x_is_inf := math.is_inf(t_x)
	t_y_is_inf := math.is_inf(t_y)
	if t_x_is_inf && t_y_is_inf {
		return {}, false
	}

	t := min(t_x, t_y)
	if t_x_is_inf {
		t = t_y
	} else if t_y_is_inf {
		t = t_x
	}

	it.pos = it.start + it.dir * t

	amount_of_line_traversed := linalg.dot(it.dir, it.pos - it.start)
	if amount_of_line_traversed < 0 {
		return {}, false
	}
	if amount_of_line_traversed >= it.length {
		return {}, false
	}

	return it.pos, true
}

