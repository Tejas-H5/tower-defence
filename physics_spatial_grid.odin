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
	// TODO: Could be SOA ?
	items:     [N]Spatial_Grid_Item,
	grid_size: f32,
	max_entity_radius: f32,
	count:     int,
}

// This is a pretty large structure. Maybe we want to downsize it later at some point.
Spatial_Grid_Item :: struct {
	handle:     int, // This indexes into the main data. Also it's 1-based for ZII
	grid_coord: Grid_Coord,

	// Used to dedupe slots when we're iterating all grid x line intersections.
	visited:    bool,

	next:       ^Spatial_Grid_Item,
	prev:       ^Spatial_Grid_Item,
}

Spatial_Grid_Handle :: struct {
	grid_coord: Grid_Coord,
	slot:       ^Spatial_Grid_Item,
}

Grid_Coord :: [2]i32


__spatial_grid_coord_to_firt_slot_maybe :: proc(
	g: ^Spatial_Grid($N),
	grid_coord: Grid_Coord,
) -> ^Spatial_Grid_Item {
	// Two large prime numbers
	idx := abs(7919 * grid_coord.x + 9973 * grid_coord.y)
	return &g.items[idx % len(g.items)]
}

__spatial_grid_coord_to_firt_slot :: proc(
	g: ^Spatial_Grid($N),
	grid_coord: Grid_Coord,
) -> ^Spatial_Grid_Item {
	slot := __spatial_grid_coord_to_firt_slot_maybe(g, grid_coord)

	if slot.handle == 0 || slot.grid_coord == grid_coord {
		return slot
	}

	// We landed on some other grid coord, so need to linear probe to the next one.
	// If we find a slot with handle == 0 before we find our grid coord, we can actually conclude that
	// this coordinate just isn't in the grid.
	end := intrinsics.ptr_offset(&g.items[0], len(g.items))
	count := len(g.items)
	for slot.handle != 0 && slot.grid_coord != grid_coord {
		slot = intrinsics.ptr_offset(slot, 1)
		if slot == end {
			// wrap back around.
			slot = &g.items[0]
		}
		count -= 1
		if count == 0 {
			break;
		}
	}

	assert(slot.handle == 0 || slot.grid_coord == grid_coord)
	return slot
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
	radius: f32,
	idx: int,
) {
	assert(g.grid_size != 0)
	assert(handle != nil)

	g.max_entity_radius = max(g.max_entity_radius, radius)
	dev_assert(g.max_entity_radius < g.grid_size / 2, "We need a larger grid")

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
		if f32(g.count) / f32(len(g.items)) > 0.8 {
			log("Consider using a larger hashmap")
		}

		// Need to create a new item at idx, or the next available slot
		slot := __spatial_grid_coord_to_firt_slot_maybe(g, grid_coord)
		validate_slot(slot)
		for slot.handle != 0 {
			validate_slot(slot)

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
				validate_slot(slot)
			} else {
				dev_assert(slot.next.prev == slot)
				// Use the next we've already computed.
				slot = slot.next
				validate_slot(slot)
			}
		}

		slot.grid_coord = grid_coord
		handle.slot = slot
		handle.grid_coord = grid_coord
		validate_slot(slot)

		g.count += 1
	}

	// Entities can move to a different index
	handle.slot.handle = idx + 1
	assert(handle.slot != nil)
}

spatial_grid_remove :: proc(g: ^Spatial_Grid($N), handle: ^Spatial_Grid_Handle) {
	// We need to remove things by moving the next node to here:
	// before: a -> x -> b -> ...  | after:  a -> b -----> ...
	//
	// This is as opposed to a flow-through approach where we make prev.next = next and next.prev = prev, 
	// which we *don't* want in this case:
	// before: a -> x -> b -> ...  | after:  a ------> b -> ...
	//
	// That way, the 'head' of the embedded linked list stays put.
	// If it doesn't, then it breaks linear probing/finding.

	validate_slot(handle.slot)
	if handle.slot.next != nil {
		next := handle.slot.next
		prev := handle.slot.prev
		visited := handle.slot.visited
		handle.slot^ = handle.slot.next^
		handle.slot.prev = prev
		// Preserving 'visited' allows iteration to not break by re-visiting cells
		// if we were deleting things while iterating.
		handle.slot.visited = visited

		if handle.slot.next != nil {
			handle.slot.next.prev = handle.slot
		}
		next^ = {}
		validate_slot(handle.slot)
	} else {
		if handle.slot.prev != nil {
			handle.slot.prev.next = nil
		}
		handle.slot^ = {}
		validate_slot(handle.slot)
	}

	handle^ = {}

	g.count -= 1
}

Spatial_Grid_Iterator :: struct {
	slot: ^Spatial_Grid_Item,
}

spatial_grid_iterator :: proc(g: ^Spatial_Grid($N), pos: Vec2) -> Spatial_Grid_Iterator {
	coord := __spatial_grid_pos_to_coord(g, pos)
	return spatial_grid_iterator_from_coords(g, coord)
}

spatial_grid_iterator_from_coords :: proc(g: ^Spatial_Grid($N), coord: Grid_Coord) -> Spatial_Grid_Iterator {
	slot := __spatial_grid_coord_to_firt_slot(g, coord)
	if slot.handle == 0 {
		slot = nil
	} else if slot.visited {
		slot = nil
	}
	return Spatial_Grid_Iterator{slot = slot}
}

spatial_grid_iterate :: proc(it: ^Spatial_Grid_Iterator) -> (^Spatial_Grid_Item, bool) {
	if it.slot == nil {
		return nil, false
	}

	this_slot := it.slot
	it.slot = it.slot.next
	return this_slot, true
}

Spatial_Grid_Rect_Iterator :: struct($N: uint) {
	g:    ^Spatial_Grid(N),
	point_it:   Spatial_Grid_Iterator,
	from, to, pos: Grid_Coord,
}

spatial_grid_rect_iterator :: proc(g: ^Spatial_Grid($N), rect: Rect) -> Spatial_Grid_Rect_Iterator(N) {
	rect := rect

	// If the vertices of our rectangle is close enough to the borders of the grid it's in, 
	// it can start colliding with entities in the neighbouring grid. 
	// But it needs to be close enough, hence max_entity_radius.
	// Rather than having 4 if-statements, we can simply offset the query rect by this
	// amount and then this automatically includes
	rect.pos -= Vec2{g.max_entity_radius, g.max_entity_radius}
	rect.size += 2 * Vec2{g.max_entity_radius, g.max_entity_radius}

	from := __spatial_grid_pos_to_coord(g, rect.pos)
	to   := __spatial_grid_pos_to_coord(g, rect.pos + rect.size)

	return {
		g    = g,
		from = from,
		pos  = from,
		to   = to,
		point_it = spatial_grid_iterator_from_coords(g, from),
	}
}

// Iterates all rectangles that intersect with this one.
spatial_grid_rect_iterate :: proc(it: ^Spatial_Grid_Rect_Iterator($N)) -> (^Spatial_Grid_Item, bool) {
	res, ok := spatial_grid_iterate(&it.point_it)
	for !ok { 
		it.pos += { 1, 0 }
		if it.pos.x > it.to.x {
			it.pos = { it.from.x, it.pos.y + 1 }
		}
		if it.pos.y > it.to.y {
			break
		}
		it.point_it = spatial_grid_iterator_from_coords(it.g, it.pos)
		res, ok = spatial_grid_iterate(&it.point_it)
	}

	return res, ok
}

Spatial_Grid_Line_Iterator :: struct($N: uint) {
	g: ^Spatial_Grid(N),
	start, end: Vec2,
	// The line will have a thickness. A line passing very close but not intersecting
	// a grid square may also be colliding with something in that other grid square.
	// A regular point iterator would miss it but the rect iterator wouldn't.
	rect_it: Spatial_Grid_Rect_Iterator(N), 
	grid_it: Grid_Line_Intersection_Iterator,
}

__spatial_grid_line_iterator_rect_iterator :: proc(g: ^Spatial_Grid($N), pos: Vec2) -> Spatial_Grid_Rect_Iterator(N) {
	return spatial_grid_rect_iterator(g, Rect{
		pos - g.max_entity_radius,
		2 * g.max_entity_radius
	})
}

spatial_grid_line_iterator :: proc(g: ^Spatial_Grid($N), line: Line) -> Spatial_Grid_Line_Iterator(N) {
	return {
		g = g,
		start = line.start,
		end = line.end,
		rect_it = __spatial_grid_line_iterator_rect_iterator(g, line.start),
		grid_it = grid_line_intersection_iterator(line.start, line.end, g.grid_size),
	};
}

// NOTE: doesn't work when you're inserting new items. At least, I intentionally don't handle that case.
spatial_grid_line_iterate :: proc(it: ^Spatial_Grid_Line_Iterator($N)) -> (^Spatial_Grid_Item, bool)  {
	slot, has_slot := spatial_grid_rect_iterate(&it.rect_it)

	for !has_slot {
		next_intersection_pos, ok := grid_line_intersection_iterate(&it.grid_it)
		if ok {
			it.rect_it = __spatial_grid_line_iterator_rect_iterator(it.g, next_intersection_pos)
			slot, has_slot = spatial_grid_rect_iterate(&it.rect_it)
		} else {
			// No more grid slots. Let's go back over the points and clear the visited flag.
			// This is more efficient than looping over every single grid item
			grid_it := grid_line_intersection_iterator(it.start, it.end, it.grid_it.grid_size)
			for pos in grid_line_intersection_iterate(&grid_it) {
				coord := __spatial_grid_pos_to_coord(it.g, pos)
				slot := __spatial_grid_coord_to_firt_slot(it.g, coord)
				slot.visited = false
			}
			break
		}
	}

	if has_slot {
		is_head := slot.prev == nil
		if is_head {
			slot.visited = true
		}
	}

	return slot, has_slot
}

validate_slot :: proc(slot: ^Spatial_Grid_Item) {
	if slot.next != nil {
		dev_assert(slot.next.prev == slot)
	}
	if slot.prev != nil {
		dev_assert(slot.prev.next == slot)
	}
}
