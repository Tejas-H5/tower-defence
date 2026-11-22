package main

import "core:testing"

Test_Entity :: struct {
	handle: Spatial_Grid_Handle,
	pos:    Vec2,
	idx:    int,
	radius: f32,
}

add_test_entity :: proc(t: ^testing.T, g: ^Spatial_Grid, e:  ^Test_Entity) {
	spatial_grid_add_or_update(g, &e.handle, e.pos, e.radius, e.idx, nil)
	__spatial_grid_validate(g)
}

expect_indices_at_pos :: proc(t: ^testing.T, g: ^Spatial_Grid, pos: Vec2, expected_indices: []int, loc := #caller_location)  {
	count := 0

	it := spatial_grid_iterator(g, pos)
	for slot in spatial_grid_iterate(&it) {
		if (!testing.expect(t, count < len(expected_indices), "too many items present", loc=loc)) {return}

		testing.expect_value(t, slot.handle - 1, expected_indices[count], loc)
		count += 1
	}

	testing.expect_value(t, count, len(expected_indices), loc)
}

@(test)
test_spatial_grid_insert_one :: proc(t: ^testing.T) {
	mem  := Spatial_Grid_Memory(5){}
	grid := spatial_grid_from_memory(&mem, 10)

	entity := Test_Entity{pos={0, 0}, idx=0, radius = 1}

	add_test_entity(t, &grid, &entity)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0 })
	testing.expect_value(t, grid.count, 1);
}


@(test)
test_spatial_grid_insert_two_same_spot :: proc(t: ^testing.T) {
	mem  := Spatial_Grid_Memory(5){}
	grid := spatial_grid_from_memory(&mem, 10)

	entity0 := Test_Entity{pos={0, 0}, idx = 0, radius = 1}
	entity1 := Test_Entity{pos={0, 0}, idx = 1, radius = 1}

	add_test_entity(t, &grid, &entity0)
	add_test_entity(t, &grid, &entity1)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0, 1 })
	testing.expect_value(t, grid.count, 2);
}


@(test)
test_spatial_grid_insert_two_different_spots :: proc(t: ^testing.T) {
	mem  := Spatial_Grid_Memory(5){}
	grid := spatial_grid_from_memory(&mem, 10)

	entity0 := Test_Entity{pos={0, 0},  idx = 0, radius = 1}
	entity1 := Test_Entity{pos={10, 0}, idx = 1, radius = 1}

	add_test_entity(t, &grid, &entity0)
	add_test_entity(t, &grid, &entity1)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0 })
	expect_indices_at_pos(t, &grid, {9.9999, 0}, []int{ 0 })

	expect_indices_at_pos(t, &grid, {10, 0}, []int{ 1 })
	expect_indices_at_pos(t, &grid, {19.9999, 0}, []int{ 1 })
	testing.expect_value(t, grid.count, 2);
}


@(test)
test_spatial_grid_update_same_spot :: proc(t: ^testing.T) {
	mem  := Spatial_Grid_Memory(5){}
	grid := spatial_grid_from_memory(&mem, 10)

	entity := Test_Entity{pos={0, 0}, idx = 0, radius = 1}
	add_test_entity(t, &grid, &entity)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0 })
	testing.expect_value(t, grid.count, 1);
}

@(test)
test_spatial_grid_update_new_spot :: proc(t: ^testing.T) {
	mem  := Spatial_Grid_Memory(5){}
	grid := spatial_grid_from_memory(&mem, 10)

	entity := Test_Entity{pos={0, 0}, idx = 0, radius = 1}
	add_test_entity(t, &grid, &entity)
	entity.pos = {10, 0}
	add_test_entity(t, &grid, &entity)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{})
	expect_indices_at_pos(t, &grid, {10, 0}, []int{0})
	testing.expect_value(t, grid.count, 1);
}


@(test)
test_spatial_grid_update_new_spot_with_other_items :: proc(t: ^testing.T) {
	mem  := Spatial_Grid_Memory(5){}
	grid := spatial_grid_from_memory(&mem, 10)

	entity0 := Test_Entity{pos={0, 0},  idx = 0, radius = 1}
	entity1 := Test_Entity{pos={10, 0}, idx = 1, radius = 1}

	add_test_entity(t, &grid, &entity0)
	add_test_entity(t, &grid, &entity1)

	entity0.pos = {10, 0}
	add_test_entity(t, &grid, &entity0)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{})
	expect_indices_at_pos(t, &grid, {10, 0}, []int{1, 0})
	testing.expect_value(t, grid.count, 2);
}

test_spatial_grid_swap_positions_internal :: proc(t: ^testing.T, c1, c2: Vec2) {
	mem  := Spatial_Grid_Memory(5){}
	grid := spatial_grid_from_memory(&mem, 10)

	entity0 := Test_Entity{pos=c1,  idx = 0, radius = 1}
	entity1 := Test_Entity{pos=c2, idx = 1, radius = 1}

	add_test_entity(t, &grid, &entity0)
	add_test_entity(t, &grid, &entity1)

	expect_indices_at_pos(t, &grid, c1, []int{0})
	expect_indices_at_pos(t, &grid, c2, []int{1})

	entity0.pos = c2
	entity1.pos = c1
	add_test_entity(t, &grid, &entity0)
	add_test_entity(t, &grid, &entity1)

	expect_indices_at_pos(t, &grid, c1, []int{1})
	expect_indices_at_pos(t, &grid, c2, []int{0})
	testing.expect_value(t, grid.count, 2);
}


@(test)
test_spatial_grid_swap_positions:: proc(t: ^testing.T) {
	test_spatial_grid_swap_positions_internal(t, {0, 0}, {0, 10})
}


@(test)
test_spatial_grid_swap_positions_works_with_colliding_hash :: proc(t: ^testing.T) {
	mem  := Spatial_Grid_Memory(5){}
	grid := spatial_grid_from_memory(&mem, 10)

	// Make sure our coordinates will collide
	coord1 := Vec2{0, 0}
	coord2 := Vec2{0, 50}
	idx1 := __spatial_grid_coord_to_hash(pos_to_grid_coord(&grid,coord1)) % len(grid.items)
	idx2 := __spatial_grid_coord_to_hash(pos_to_grid_coord(&grid,coord2)) % len(grid.items)
	testing.expect_value(t, idx1, idx2)

	test_spatial_grid_swap_positions_internal(t, coord1, coord2)
}

@(test)
test_spatial_grid_iterate_rect :: proc(t: ^testing.T) {
	mem  := Spatial_Grid_Memory(5){}
	grid := spatial_grid_from_memory(&mem, 10)

	entities := []Test_Entity{
		{pos={0, 0},  idx = 0, radius = 1},
		{pos={10, 0}, idx = 1, radius = 1},
		{pos={0, 10}, idx = 2, radius = 1},
		{pos={10, 10}, idx = 3, radius = 1},
	}
	for &e in entities {
		add_test_entity(t, &grid, &e)
	}

	count := 0
	iter := spatial_grid_rect_iterator(&grid, Rect{{9, 9}, {2, 2}})
	for e in spatial_grid_rect_iterate(&iter) {
		count += 1
	}

	testing.expect_value(t, count, 4)
}

@(test)
test_spatial_grid_iterate_line_through_the_middle :: proc(t: ^testing.T) {
	mem  := Spatial_Grid_Memory(5){}
	grid := spatial_grid_from_memory(&mem, 10)

	entities := []Test_Entity{
		{pos={0, 0},  idx = 0, radius = 1},
		{pos={10, 0}, idx = 1, radius = 1},
		{pos={0, 10}, idx = 2, radius = 1},
		{pos={10, 10}, idx = 3, radius = 1},
	}
	for &e in entities {
		add_test_entity(t, &grid, &e)
	}

	expected_indices := []int{0, 1}

	it := spatial_grid_line_iterator(&grid, {{-1, 5}, {11, 5}})
	count := 0
	for slot in spatial_grid_line_iterate(&it) {
		if count >= len(expected_indices) {
			break;
		}
		testing.expect_value(t, slot.handle - 1, expected_indices[count])
		count += 1
	}

	testing.expect_value(t, count, len(expected_indices))
}
