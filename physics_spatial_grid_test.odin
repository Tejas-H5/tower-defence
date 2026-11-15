package main

import "core:testing"

Test_Entity :: struct {
	handle: Spatial_Grid_Handle,
	pos:    Vec2,
	idx:    int,
	radius: f32,
}

add_test_entity :: proc(g: ^Spatial_Grid($N), e:  ^Test_Entity) {
	spatial_grid_add_or_update(g, &e.handle, e.pos, e.radius, e.idx)
}

expect_indices_at_pos :: proc(t: ^testing.T, g: ^Spatial_Grid($N), pos: Vec2, expected_indices: []int, loc := #caller_location)  {
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
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity := Test_Entity{pos={0, 0}, idx=0, radius = 1}

	add_test_entity(&grid, &entity)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0 })
	testing.expect_value(t, grid.count, 1);
}


@(test)
test_spatial_grid_insert_two_same_spot :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity0 := Test_Entity{pos={0, 0}, idx = 0, radius = 1}
	entity1 := Test_Entity{pos={0, 0}, idx = 1, radius = 1}

	add_test_entity(&grid, &entity0)
	add_test_entity(&grid, &entity1)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0, 1 })
	testing.expect_value(t, grid.count, 2);
}


@(test)
test_spatial_grid_insert_two_different_spots :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity0 := Test_Entity{pos={0, 0},  idx = 0, radius = 1}
	entity1 := Test_Entity{pos={10, 0}, idx = 1, radius = 1}

	add_test_entity(&grid, &entity0)
	add_test_entity(&grid, &entity1)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0 })
	expect_indices_at_pos(t, &grid, {9.9999, 0}, []int{ 0 })

	expect_indices_at_pos(t, &grid, {10, 0}, []int{ 1 })
	expect_indices_at_pos(t, &grid, {19.9999, 0}, []int{ 1 })
	testing.expect_value(t, grid.count, 2);
}


@(test)
test_spatial_grid_update_same_spot :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity := Test_Entity{pos={0, 0}, idx = 0, radius = 1}
	add_test_entity(&grid, &entity)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0 })
	testing.expect_value(t, grid.count, 1);
}

@(test)
test_spatial_grid_update_new_spot :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity := Test_Entity{pos={0, 0}, idx = 0, radius = 1}
	add_test_entity(&grid, &entity)
	entity.pos = {10, 0}
	add_test_entity(&grid, &entity)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{})
	expect_indices_at_pos(t, &grid, {10, 0}, []int{0})
	testing.expect_value(t, grid.count, 1);
}


@(test)
test_spatial_grid_update_new_spot_with_other_items :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity0 := Test_Entity{pos={0, 0},  idx = 0, radius = 1}
	entity1 := Test_Entity{pos={10, 0}, idx = 1, radius = 1}

	add_test_entity(&grid, &entity0)
	add_test_entity(&grid, &entity1)

	entity0.pos = {10, 0}
	add_test_entity(&grid, &entity0)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{})
	expect_indices_at_pos(t, &grid, {10, 0}, []int{1, 0})
	testing.expect_value(t, grid.count, 2);
}


@(test)
test_spatial_grid_swap_positions:: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity0 := Test_Entity{pos={0, 0},  idx = 0, radius = 1}
	entity1 := Test_Entity{pos={10, 0}, idx = 1, radius = 1}

	add_test_entity(&grid, &entity0)
	add_test_entity(&grid, &entity1)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{0})
	expect_indices_at_pos(t, &grid, {10, 0}, []int{1})

	entity0.pos = {10, 0}
	entity1.pos = {0, 0}
	add_test_entity(&grid, &entity0)
	add_test_entity(&grid, &entity1)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{1})
	expect_indices_at_pos(t, &grid, {10, 0}, []int{0})
	testing.expect_value(t, grid.count, 2);
}

@(test)
test_spatial_grid_iterate_rect :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entities := []Test_Entity{
		{pos={0, 0},  idx = 0, radius = 1},
		{pos={10, 0}, idx = 1, radius = 1},
		{pos={0, 10}, idx = 2, radius = 1},
		{pos={10, 10}, idx = 3, radius = 1},
	}
	for &e in entities {
		add_test_entity(&grid, &e)
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
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entities := []Test_Entity{
		{pos={0, 0},  idx = 0, radius = 1},
		{pos={10, 0}, idx = 1, radius = 1},
		{pos={0, 10}, idx = 2, radius = 1},
		{pos={10, 10}, idx = 3, radius = 1},
	}
	for &e in entities {
		add_test_entity(&grid, &e)
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
