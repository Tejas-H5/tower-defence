package main

import "base:intrinsics"
import "core:math"

/*
 Problem constraints:
 - Finite number of items known at compile-time
 - Items will probably remain in the same cell most frames, and may transfer to an adjacent cell every now and then.
 - TODO: how to handle Large item ? the cells need to be larger than the largest item.
*/

Spatial_Grid :: struct($N: uint) {
	items:     [N]Spatial_Grid_Item,
	grid_size: f32,
	count:     i32,
	gen:       i32,
}

// This is a pretty large structure. Maybe we want to downsize it later at some point.
Spatial_Grid_Item :: struct {
	handle:     int, // This indexes into the main data. Also it's 1-based for ZII
	grid_coord: Grid_Coord,
	next:       ^Spatial_Grid_Item,
	prev:       ^Spatial_Grid_Item,
}

Spatial_Grid_Handle :: struct {
	grid_coord: Grid_Coord,
	slot:       ^Spatial_Grid_Item,
}

Grid_Coord :: [2]i32

__spatial_grid_coord_to_firt_slot :: proc(
	g: ^Spatial_Grid($N),
	grid_coord: Grid_Coord,
) -> ^Spatial_Grid_Item {
	// Two large ahh prime numbers. The AI pulled them up so I guess this code is AI slop now. Maybe they arent even prime lowkey.
	idx := abs(7919 * grid_coord.x + 9973 * grid_coord.y)
	return &g.items[idx % len(g.items)]
}

__spatial_grid_pos_to_coord :: proc(g: ^Spatial_Grid($N), pos: Vec2) -> Vec2i {
	grid_coord := Grid_Coord {
		i32(math.floor(pos.x / g.grid_size)),
		i32(math.floor(pos.y / g.grid_size)),
	}
	return grid_coord
}

spatial_grid_add_or_update :: proc(
	g: ^Spatial_Grid($N),
	handle: ^Spatial_Grid_Handle,
	pos: Vec2,
	idx: int,
) {
	assert(g.grid_size != 0)
	assert(handle != nil)

	grid_coord := __spatial_grid_pos_to_coord(g, pos)

	needs_update := handle.grid_coord != grid_coord || handle.slot == nil
	if needs_update {
		if handle.slot != nil {
			spatial_grid_remove(g, handle)
			handle.slot = nil
		}

		assert(g.count < len(g.items))
		dev_assert(handle.slot == nil)

		// Probably our hashmap should be a bit larger than it needs to be.
		if f32(g.count) / len(g.items) < 0.8 {
			log("Consider using a larger hashmap")
		}

		// Need to create a new item at idx, or the next available slot
		slot := __spatial_grid_coord_to_firt_slot(g, grid_coord)
		for slot.handle != 0 {
			if slot.next == nil {
				end := intrinsics.ptr_offset(&g.items[0], len(g.items))
				next_slot := slot
				for next_slot.handle != 0 {
					next_slot = intrinsics.ptr_offset(next_slot, 1)
					if next_slot == end {
						// wrap back around.
						next_slot = &g.items[0]
					}
				}
				slot.next = next_slot
				next_slot.prev = slot
				slot = next_slot
			} else {
				dev_assert(slot.next.prev == slot)
				// Use the next we've already computed.
				slot = slot.next
			}
		}

		slot.grid_coord = grid_coord
		slot.handle = idx + 1
		handle.slot = slot
		handle.grid_coord = grid_coord

		g.count += 1
	}
}

spatial_grid_remove :: proc(g: ^Spatial_Grid($N), handle: ^Spatial_Grid_Handle) {
	if handle.slot.prev != nil {
		handle.slot.prev.next = handle.slot.next
	}
	if handle.slot.next != nil {
		handle.slot.next.prev = handle.slot.prev
	}
	handle.slot^ = {}
	handle^ = {}

	g.count -= 1
}

Spatial_Grid_Iterator :: struct {
	slot: ^Spatial_Grid_Item,
}

spatial_grid_iterator :: proc(g: ^Spatial_Grid($N), pos: Vec2) -> Spatial_Grid_Iterator {
	coord := __spatial_grid_pos_to_coord(g, pos)
	slot := __spatial_grid_coord_to_firt_slot(g, coord)
	if slot.handle == 0 {
		slot = nil
	}
	return Spatial_Grid_Iterator{slot = slot}
}

spatial_grid_iterate :: proc(it: ^Spatial_Grid_Iterator) -> (int, bool) {
	if it.slot == nil {
		return -1, false
	}

	idx := it.slot.handle - 1
	it.slot = it.slot.next
	return idx, true
}

spatial_grid_print :: proc(g: ^Spatial_Grid) {
	// TODO: implement
}
