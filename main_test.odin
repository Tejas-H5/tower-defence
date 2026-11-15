package main

import "core:testing"

run_test :: proc() {
	t := new(testing.T)
	test_spatial_grid_iterate_line_through_the_middle(t)
	// test_spatial_grid_update_new_spot(t)
}

