package main

import "core:testing"

// odin test . -define:ODIN_TEST_NAMES=game.sparse_grid_ray_query


@(test)
test_line_intersects_rect :: proc(t: ^testing.T) {
	TestCase :: struct {
		line:   Line,
		rect:   Rect,
		result: LineXRectResult,
	}

	cases := []TestCase {
		// Inside
		{
			line = {{0, 0}, {1, 0}},
			rect = {{-2, -2}, {4, 4}},
			result = {num_hits = 1, hits = {{pos = {0, 0}, normal = {-1, 0}}, {}}},
		},
		// Left -> Right, 1
		{
			line = {{-2.5, 0}, {0, 0}},
			rect = {{-2, -2}, {4, 4}},
			result = {num_hits = 1, hits = {{pos = {-2, 0}, normal = {-1, 0}}, {}}},
		},
		// Left -> Right, 2
		{
			line = {{-2.5, 0}, {2.5, 0}},
			rect = {{-2, -2}, {4, 4}},
			result = {num_hits = 2, hits = {
				{pos = {-2, 0}, normal = {-1, 0}}, 
				{pos = {2, 0}, normal  = {1, 0}}, 
			}},
		},
		// Left <- Right, 1
		{
			line = {{2.5, 0}, {0, 0}},
			rect = {{-2, -2}, {4, 4}},
			result = {num_hits = 1, hits = {{pos = {2, 0}, normal = {1, 0}}, {}}},
		},
		// Left <- Right, 2
		{
			line = {{2.5, 0}, {-2.5, 0}},
			rect = {{-2, -2}, {4, 4}},
			result = {num_hits = 2, hits = {
				{pos = {2, 0}, normal = {1, 0}}, 
				{pos = {-2, 0}, normal  = {-1, 0}}, 
			}},
		},
		// Top -> Bottom, 1
		{
			line = {{0, 2.5}, {0, 0}},
			rect = {{-2, -2}, {4, 4}},
			result = {num_hits = 1, hits = {{pos = {0, 2}, normal = {0, 1}}, {}}},
		},
		// Top -> Bottom, 2
		{
			line = {{0, 2.5}, {0, -2.5}},
			rect = {{-2, -2}, {4, 4}},
			result = {num_hits = 2, hits = {
				{pos = {0, 2}, normal = {0, 1}}, 
				{pos = {0, -2}, normal = {0, -1}}, 
			}},
		},
		// Bottom -> Top, 1
		{
			line = {{0, -2.5}, {0, 0}},
			rect = {{-2, -2}, {4, 4}},
			result = {num_hits = 1, hits = {{pos = {0, -2}, normal = {0, -1}}, {}}},
		},
		// Bottom -> Top, 2
		{
			line = {{0, -2.5}, {0, 2.5}},
			rect = {{-2, -2}, {4, 4}},
			result = {num_hits = 2, hits = {
				{pos = {0, -2}, normal = {0, -1}}, 
				{pos = {0, 2}, normal = {0, 1}}, 
			}},
		},
	}

	for tc in cases {
		res := line_intersects_rect(tc.line, tc.rect)
		testing.expect_value(t, res, tc.result)
	}
}
