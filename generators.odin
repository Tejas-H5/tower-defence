package main

import "core:math"

Circle_Generator :: struct {
	n: int,
}

circle_generate :: proc(g: ^Circle_Generator, num_verts: int) -> (Vec2, bool) {
	if g.n >= num_verts {return {}, false }

	t := math.TAU * f32(g.n) / f32(num_verts)
	g.n += 1
	return {math.cos(t), math.sin(t)}, true
}
