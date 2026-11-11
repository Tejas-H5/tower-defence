package main

import "core:math/linalg"
import "core:math"

/*
Current status:
     Box | Ray
Box:  x  |  x
Ray:  x  |
*/


RacyastHitInfo :: struct {
	t, u: f32,
	t_pos, u_pos: Vec2,
}

rect_intersects_rect :: proc(a, b: Rect) -> bool {
	return ranges_intersect(a.pos.x, a.pos.x + a.size.x, b.pos.x, b.pos.x + b.size.x) &&
           ranges_intersect(a.pos.y, a.pos.y + a.size.y, b.pos.y, b.pos.y + b.size.y)
}

ranges_intersect :: proc(a0, a1, b0, b1: f32) -> bool {
	if a1 < b0 {return false}
	if b1 < a0 {return false}
	return true
}

// https://paulbourke.net/geometry/pointlineplane/
// A lot better of a resource imo.
line_intersects_line :: proc(l1, l2: Line) -> (hit: bool, pos: Vec2) {
	r1_start := l1.start
	r1_end   := l1.end
	r2_start := l2.start
	r2_end   := l2.end

	x1, y1 := r1_start.x, r1_start.y
	x2, y2 := r1_end.x, r1_end.y
	x3, y3 := r2_start.x, r2_start.y
	x4, y4 := r2_end.x, r2_end.y

	denominator := ((y4 - y3) * (x2 - x1)) - ((x4 - x3) * (y2 - y1))

	t := (((x4 - x3) * (y1 - y3)) - ((y4 - y3) * (x1 - x3))) / denominator
	u := (((x2 - x1) * (y1 - y3)) - ((y2 - y1) * (x1 - x3))) / denominator

	pos = Vec2{x1, y1} + t * Vec2{x2-x1, y2-y1}
	// Should be basically the same position right
	// pos.u_pos = Vec2{x3, y3} + u * Vec2{x4-x3, y4-y3}

	if 0 <= t && t <= 1 {
		if 0 <= u && u <= 1 {
			hit = true
		}
	}

	return
}

rect_contains_point :: proc(rect: Rect, point: Vec2) -> bool {
	if rect.pos.x < point.x && point.x < rect.pos.x + rect.size.x {
		if rect.pos.y < point.y && point.y < rect.pos.y + rect.size.y {
			return true
		}
	}
	return false
}

LineXRectHit :: struct {
	pos:    Vec2,
	normal: Vec2,
}

LineXRectResult :: struct {
	num_hits: int,
	hits: [2]LineXRectHit,
}

line_intersects_rect :: proc(line: Line, rect: Rect) -> (result: LineXRectResult) {
	if rect_contains_point(rect, line.start) {
		// If the ray starts inside the box, it's already colliding with the box. 
		// (rooms should be modeled with 4 massive boxes)
		result.num_hits = 1
		result.hits[0] = { pos = line.start, normal = linalg.normalize0(line.start - line.end) }
		return
	}

	add_hit :: proc(result: ^LineXRectResult, hit: LineXRectHit) {
		assert(result.num_hits < 2)
		result.hits[result.num_hits] = hit
		result.num_hits += 1
	}

	top_left     := rect.pos + {0, rect.size.y}
	bottom_left  := rect.pos
	top_right    := rect.pos + rect.size
	bottom_right := rect.pos + {rect.size.x, 0}

	hit: bool
	pos: Vec2

	hit, pos = line_intersects_line({top_left, top_right}, line)
	if hit {
		add_hit(&result, {pos, {0, 1}})
	}

	hit, pos = line_intersects_line({bottom_left, bottom_right}, line)
	if hit {
		add_hit(&result, {pos, {0, -1}})
	}

	if result.num_hits < 2 {
		hit, pos = line_intersects_line({top_left, bottom_left}, line)
		if hit {
			add_hit(&result, {pos, {-1, 0}})
		}

		if result.num_hits < 2 {
			hit, pos = line_intersects_line({top_right, bottom_right}, line)
			if hit {
				add_hit(&result, {pos, {1, 0}})
			}
		}
	}

	// Put the closer hit at pos[0] for convenience
	if result.num_hits == 2 {
		start_to_0 := linalg.length2(line.start - result.hits[0].pos)
		start_to_1 := linalg.length2(line.start - result.hits[1].pos)
		if start_to_0 > start_to_1 {
			result.hits[0], result.hits[1] = result.hits[1], result.hits[0]
		}
	}

	return
}


SURROUNDING_OFFSETS :: [9]Vec2i {
	// Putting 0,0 as the first cell is a clever performance optimization.
	{0,0},  
	{-1,-1},
	{0,-1}, 
	{1,-1},
	{-1,0},
	{1,0},
	{-1,1},
	{0,1}, 
	{1,1},
}

SURROUNDING_OFFSETS_F32 :: [9]Vec2 {
	// Putting 0,0 as the first cell is a clever performance optimization.
	{0,0}, 
	{-1,-1},
	{0,-1}, 
	{1,-1},
	{-1,0},
	{1,0},
	{-1,1},
	{0,1}, 
	{1,1},
}
