package main

import "core:testing"

Test_Entity :: struct {
	handle: Spatial_Grid_Handle,
	pos:    Vec2,
}

expect_indices_at_pos :: proc(t: ^testing.T, g: ^Spatial_Grid($N), pos: Vec2, expected_indices: []int, loc := #caller_location)  {
	count := 0

	it := spatial_grid_iterator(g, pos)
	for idx in spatial_grid_iterate(&it) {
		if (!testing.expect(t, count < len(expected_indices), "too many items present", loc=loc)) {return}

		testing.expect_value(t, idx, expected_indices[count], loc)
		count += 1
	}

	testing.expect_value(t, count, len(expected_indices), loc)
}

@(test)
test_spatial_grid_insert_one :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity := Test_Entity{pos={0, 0}}

	spatial_grid_add_or_update(&grid, &entity.handle, entity.pos, 0)
	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0 })
	testing.expect_value(t, grid.count, 1);
}


@(test)
test_spatial_grid_insert_two_same_spot :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity := Test_Entity{pos={0, 0}}
	entity2 := Test_Entity{pos={0, 0}}

	spatial_grid_add_or_update(&grid, &entity.handle, entity.pos, 0)
	spatial_grid_add_or_update(&grid, &entity2.handle, entity2.pos, 1)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0, 1 })
	testing.expect_value(t, grid.count, 2);
}


@(test)
test_spatial_grid_insert_two_different_spots :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity := Test_Entity{pos={0, 0}}
	entity2 := Test_Entity{pos={10, 0}}

	spatial_grid_add_or_update(&grid, &entity.handle, entity.pos, 0)
	spatial_grid_add_or_update(&grid, &entity2.handle, entity2.pos, 1)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0 })
	expect_indices_at_pos(t, &grid, {9.9999, 0}, []int{ 0 })

	expect_indices_at_pos(t, &grid, {10, 0}, []int{ 1 })
	expect_indices_at_pos(t, &grid, {19.9999, 0}, []int{ 1 })
	testing.expect_value(t, grid.count, 2);
}


@(test)
test_spatial_grid_update_same_spot :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity := Test_Entity{pos={0, 0}}
	spatial_grid_add_or_update(&grid, &entity.handle, entity.pos, 0)
	spatial_grid_add_or_update(&grid, &entity.handle, entity.pos, 0)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{ 0 })
	testing.expect_value(t, grid.count, 1);
}

@(test)
test_spatial_grid_update_new_spot :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity := Test_Entity{pos={0, 0}}
	spatial_grid_add_or_update(&grid, &entity.handle, entity.pos, 0)
	entity.pos = {10, 0}
	spatial_grid_add_or_update(&grid, &entity.handle, entity.pos, 0)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{})
	expect_indices_at_pos(t, &grid, {10, 0}, []int{0})
	testing.expect_value(t, grid.count, 1);
}


@(test)
test_spatial_grid_update_new_spot_with_other_items :: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity := Test_Entity{pos={0, 0}}
	entity2 := Test_Entity{pos={10, 0}}

	spatial_grid_add_or_update(&grid, &entity.handle, entity.pos, 0)
	spatial_grid_add_or_update(&grid, &entity2.handle, entity2.pos, 1)

	entity.pos = {10, 0}
	spatial_grid_add_or_update(&grid, &entity.handle, entity.pos, 0)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{})
	expect_indices_at_pos(t, &grid, {10, 0}, []int{1, 0})
	testing.expect_value(t, grid.count, 2);
}


@(test)
test_spatial_grid_swap_positions:: proc(t: ^testing.T) {
	grid := Spatial_Grid(5){ grid_size = f32(10) }

	entity := Test_Entity{pos={0, 0}}
	entity2 := Test_Entity{pos={10, 0}}

	spatial_grid_add_or_update(&grid, &entity.handle, entity.pos, 0)
	spatial_grid_add_or_update(&grid, &entity2.handle, entity2.pos, 1)

	entity.pos = {10, 0}
	entity2.pos = {0, 0}
	spatial_grid_add_or_update(&grid, &entity.handle, entity.pos, 0)
	spatial_grid_add_or_update(&grid, &entity2.handle, entity2.pos, 1)

	expect_indices_at_pos(t, &grid, {0, 0}, []int{0})
	expect_indices_at_pos(t, &grid, {10, 0}, []int{1})
	testing.expect_value(t, grid.count, 2);
}
