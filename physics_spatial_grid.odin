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
	// TODO: cells
	items:   [N]Spatial_Grid_Item,
	slots:   [N]Spatial_Grid_Slot,
	grid_size: f32,
	max_entity_radius: f32,
	count:     int,

	num_hops: int,
	num_accesses: int,

	num_removals: int,
	num_inserts: int,
	num_updates: int,
}


// This is a pretty large structure. Maybe we want to downsize it later at some point.
// TODO: rename to Spatial_Grid_Cell
Spatial_Grid_Item :: struct {
	first: ^Spatial_Grid_Slot,
	last:  ^Spatial_Grid_Slot,

	grid_coord: Grid_Coord,

	// Used to dedupe slots when we're iterating all grid x line intersections.
	visited:    bool,
}

// This may not be a stable reference
Spatial_Grid_Handle :: struct {
	// Should never be nil. This will be a stable reference.
	slot: ^Spatial_Grid_Slot,
}

Spatial_Grid_Slot :: struct {
	// `handle` indexes into the main data. Also it's 1-based for ZII. 
	// It's the only way we can tell if a value is present or not - the grid coord isn't
	// enough because 0, 0 is also a valid grid coord.
	handle: int, 
	// The pool this thing is a part of. if Spatial_Grid_Item had a $T parameter, this would be a part of it.
	pool: rawptr,

	item: ^Spatial_Grid_Item,
	next: ^Spatial_Grid_Slot,
	prev: ^Spatial_Grid_Slot,
}

Grid_Coord :: [2]i32


__spatial_grid_coord_to_hash :: proc(grid_coord: Grid_Coord) -> i32 {
	// Two large prime numbers
	return abs(7919 * grid_coord.x + 9973 * grid_coord.y)
}

__spatial_grid_coord_to_firt_slot_maybe :: proc(
	g: ^Spatial_Grid($N),
	grid_coord: Grid_Coord,
) -> ^Spatial_Grid_Item {
	idx := __spatial_grid_coord_to_hash(grid_coord)
	return &g.items[idx % len(g.items)]
}

spatial_grid_coord_to_firt_slot :: proc(
	g: ^Spatial_Grid($N),
	grid_coord: Grid_Coord,
) -> ^Spatial_Grid_Item {
	slot := __spatial_grid_coord_to_firt_slot_maybe(g, grid_coord)

	g.num_accesses += 1

	// We landed on some other grid coord, so need to linear probe to the next one.
	// If we find a slot with handle == 0 before we find our grid coord, we can actually conclude that
	// this coordinate just isn't in the grid.
	end := intrinsics.ptr_offset(&g.items[0], len(g.items))
	count := len(g.items)
	for !(slot.first == nil || slot.grid_coord == grid_coord) {
		slot = intrinsics.ptr_offset(slot, 1)
		if slot == end {
			// wrap back around.
			slot = &g.items[0]
		}

		if slot.grid_coord == grid_coord {
			break;
		}

		count -= 1
		if count == 0 {
			log("Worst case scenario just occured IRL.")
			break;
		}
		g.num_hops += 1
	}


	return slot
}

spatial_grid_pos_to_coord :: proc(g: ^Spatial_Grid($N), pos: Vec2) -> Vec2i {
	grid_coord := Grid_Coord {
		i32(math.floor(pos.x / g.grid_size)),
		i32(math.floor(pos.y / g.grid_size)),
	}
	return grid_coord
}

__spatial_grid_new_slot :: proc(g: ^Spatial_Grid($N)) -> ^Spatial_Grid_Slot {
	for &s in g.slots {
		if s.handle == 0 {
			return &s
		}
	}

	// NOTE: this is NOT the ZII way of doing things
	panic("Ran out of slots!!! shouldn't ever happen in practice if we've tuned our collection sizes properly")
}

spatial_grid_add_or_update :: proc(
	g: ^Spatial_Grid($N),
	handle: ^Spatial_Grid_Handle,
	pos: Vec2,
	radius: f32,
	idx: int,
	pool: rawptr,
) {
	if handle.slot == nil {
		handle.slot = __spatial_grid_new_slot(g)
	}

	assert(g.grid_size != 0)
	assert(handle != nil)

	slot := handle.slot
	
	__spatial_grid_validate_slot(g, slot)

	g.max_entity_radius = max(g.max_entity_radius, radius)
	dev_assert(g.max_entity_radius < g.grid_size / 2, "We need a larger grid")

	grid_coord := spatial_grid_pos_to_coord(g, pos)

	needs_update := slot.item == nil || slot.item.grid_coord != grid_coord
	if needs_update {
		__spatial_grid_validate(g)
		__spatial_grid_validate_slot(g, slot)
		if slot.item != nil {
			spatial_grid_remove_slot(g, slot)
			slot.item = nil
			g.num_updates += 1
			__spatial_grid_validate(g)
			__spatial_grid_validate_slot(g, slot)
		} else {
			g.num_inserts += 1
		}

		assert(g.count < len(g.items))
		dev_assert(slot.item == nil)

		// Probably our hashmap should be a bit larger than it needs to be.
		if f32(g.count) / f32(len(g.items)) > 0.8 {
			log("Consider using a larger hashmap")
		}

		g.num_accesses += 1

		// Need to create a new item at idx, or the next available slot
		item := spatial_grid_coord_to_firt_slot(g, grid_coord)
		assert(item.first == nil || item.grid_coord == grid_coord)

		slot.item = item

		__spatial_grid_validate(g)
	__spatial_grid_validate_slot(g, slot)
		if item.first == nil {
			// LGTM
			item.grid_coord = grid_coord
			item.first      = slot
			item.last       = slot
			__spatial_grid_validate(g)
	__spatial_grid_validate_slot(g, slot)
		} else {
			// LGTM
			assert(item.last != nil)
			assert(item.last.next == nil)
			item.last.next = slot
			slot.prev    = item.last
			item.last      = slot
			__spatial_grid_validate(g)
	__spatial_grid_validate_slot(g, slot)
		}

		g.count += 1
	}

	// Entities can move to a different index
	slot.handle = idx + 1
	slot.pool   = pool
	assert(slot.item != nil);

	__spatial_grid_validate_slot(g, slot)
}

spatial_grid_remove :: proc(g: ^Spatial_Grid($N), handle: ^Spatial_Grid_Handle) {
	spatial_grid_remove_slot(g, handle.slot)
	handle.slot = nil
}

spatial_grid_remove_slot :: proc(g: ^Spatial_Grid($N), slot: ^Spatial_Grid_Slot) {
	// TODO: free-list, free it from the free list

	if slot.item == nil {
		return
	}

	__spatial_grid_validate(g)
	__spatial_grid_validate_slot(g, slot)
	g.num_removals += 1

	handle_item := slot.item
	handle_prev := slot.prev
	handle_next := slot.next

	if slot.prev == nil && slot.next == nil {
		// Delete `item` from the hashmap

		item := slot.item
		slot^ = {}

		item^ = {}
		// We'll also need to move accross subsequent items so that their probing doesnt
		// stay broken. I.e you could add coordinate c1 at hash h1, add another c2 that also hashes to h1, remove
		// it needs to move accross. You've already inserted a whole bunch of crap after h1 so c2 gets moved over a lot.
		// We then remove c1. We try to find c2, and we hit a nil slot - the linear probe concludes c2 is not found.
		// Can be avoided basically by iterating all subsequent non-empty slots and saying 'would this have collided with h1? if so
		// move it to h1' then you repeat with this new hole - 'would this have collided with this new hole? eventually you'll
		// reach a second hole and you can stop (ideally).

		hole := item
		next := intrinsics.ptr_offset(hole, 1)
		end := intrinsics.ptr_offset(&g.items[0], len(g.items))
		for {
			if next == end {
				next = &g.items[0]
			}
			if next.first == nil {
				break
			}

			ptr := __spatial_grid_coord_to_firt_slot_maybe(g, next.grid_coord)
			if ptr == hole {
				hole^ = next^
				slot := hole.first
				for slot != nil {
					slot.item = hole
					slot = slot.next
				}
				__spatial_grid_validate_slot(g, hole.first)
				__spatial_grid_validate_slot(g, hole.last)
				next^ = {}
				hole = next
			}

			next = intrinsics.ptr_offset(next, 1)
		}

		__spatial_grid_validate(g)
		__spatial_grid_validate_slot(g, handle_prev)
		__spatial_grid_validate_slot(g, handle_next)
	} else {
		__spatial_grid_validate(g)
	__spatial_grid_validate_slot(g, slot)

		if handle_prev != nil {
			assert(handle_prev.next == slot)
		}
		if handle_next != nil {
			assert(handle_next.prev == slot)
		}

		assert(handle_prev != slot)
		assert(handle_next != slot)
		first := handle_item.first
		last := handle_item.last
		if handle_item.first == slot {
			handle_item.first = handle_next
		}
		if handle_item.last == slot {
			handle_item.last = handle_prev
		}
		if handle_prev != nil {
			handle_prev.next = handle_next
		}
		if handle_next != nil {
			handle_next.prev = handle_prev
		}

		if handle_prev != nil {
			assert(handle_prev.next == handle_next)
		}
		if handle_next != nil {
			assert(handle_next.prev == handle_prev)
		}
		__spatial_grid_validate(g)
		__spatial_grid_validate_slot(g, handle_prev)
		__spatial_grid_validate_slot(g, handle_next)

		slot^ = {}
	}

	g.count -= 1
}

Spatial_Grid_Iterator :: struct {
	slot: ^Spatial_Grid_Slot,
}

spatial_grid_iterator :: proc(g: ^Spatial_Grid($N), pos: Vec2) -> Spatial_Grid_Iterator {
	coord := spatial_grid_pos_to_coord(g, pos)
	return spatial_grid_iterator_from_coords(g, coord)
}

spatial_grid_iterator_from_coords :: proc(g: ^Spatial_Grid($N), coord: Grid_Coord) -> Spatial_Grid_Iterator {
	item := spatial_grid_coord_to_firt_slot(g, coord)
	slot: ^Spatial_Grid_Slot
	if item != nil {
		// Seems like a hack but I think it's fine.
		// It supports deduplicating iteration.
		if !item.visited {
			slot = item.first
		}
	}
	return Spatial_Grid_Iterator{slot = slot}
}

spatial_grid_iterate :: proc(it: ^Spatial_Grid_Iterator) -> (^Spatial_Grid_Slot, bool) {
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

	from := spatial_grid_pos_to_coord(g, rect.pos)
	to   := spatial_grid_pos_to_coord(g, rect.pos + rect.size)

	return {
		g    = g,
		from = from,
		pos  = from,
		to   = to,
		point_it = spatial_grid_iterator_from_coords(g, from),
	}
}

// Iterates all rectangles that intersect with this one.
spatial_grid_rect_iterate :: proc(it: ^Spatial_Grid_Rect_Iterator($N)) -> (^Spatial_Grid_Slot, bool) {
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
spatial_grid_line_iterate :: proc(it: ^Spatial_Grid_Line_Iterator($N)) -> (^Spatial_Grid_Slot, bool)  {
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
				coord := spatial_grid_pos_to_coord(it.g, pos)
				slot := spatial_grid_coord_to_firt_slot(it.g, coord)
				if slot != nil {
					slot.visited = false
				}
			}
			assert(has_slot == false)
			break
		}
	}

	if has_slot {
		is_head := slot.prev == nil
		if is_head {
			slot.item.visited = true
		}
	}

	return slot, has_slot
}


IS_VALIDATING_SPATIAL_GRID :: false

// Useful when testing.
__spatial_grid_validate :: proc(g: ^Spatial_Grid($N)) {
	if !IS_VALIDATING_SPATIAL_GRID {return}

	for &i in g.items {
		if i.first != nil {
			assert(i.last != nil)
		}
		if i.last != nil {
			assert(i.first != nil)
		}

		if i.first != nil {
			assert(i.first.item == &i)
			__spatial_grid_validate_slot(g, i.first);
			assert(i.last.item == &i)
			__spatial_grid_validate_slot(g, i.last);
		}
	}
}

__spatial_grid_validate_slot :: proc(g: ^Spatial_Grid($N), slot: ^Spatial_Grid_Slot) {
	if !IS_VALIDATING_SPATIAL_GRID {return}

	if slot == nil { return }

	slot := slot
	initial := slot

	{
		slot_prev := slot.prev
		slot_next := slot.next

		if slot_prev != nil {
			assert(slot_prev.next == slot)
		}
		if slot_next != nil {
			assert(slot_next.prev == slot)
		}
	}

	// TODO: re-enable and fix
	// assert(i.visited == false)
	for slot != nil {
		if slot.next != nil {
			assert(slot.next.prev == slot)
		}
		if slot.prev != nil {
			assert(slot.prev.next == slot)
		}
		slot = slot.next
	}

	slot = initial
	for slot != nil {
		if slot.next != nil {
			assert(slot.next.prev == slot)
		}
		if slot.prev != nil {
			assert(slot.prev.next == slot)
		}
		slot = slot.prev
	}
}

