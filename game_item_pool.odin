package main

Item_Pool_Memory :: struct($T: typeid, $N: uint) {
	items: #soa[N]T,
	spatial_grid: Spatial_Grid_Memory(2 * N),
}

Item_Pool :: struct($T: typeid) {
	items: #soa[]T,
	spatial_grid: Spatial_Grid,
	count: int,
}

memory_to_pool :: proc(p: ^Item_Pool_Memory($T, $N), grid_size: f32) -> Item_Pool(T) {
	return {
		items = p.items[:],
		count = 0,
		spatial_grid = spatial_grid_from_memory(&p.spatial_grid, grid_size),
	}
}

pool_add :: proc(p: ^Item_Pool($T), val: T) -> int {
	assert(p.count < len(p.items))

	idx := p.count
	p.count += 1
	p.items[idx] = val

	return idx
}

// Returns the item that you've swapped in, so that you can fix up it's internal
// indices and whatnot as needed
pool_unordered_remove :: proc(p: ^Item_Pool($T), idx: int) {
	assert(idx < p.count)
	p.items[idx] = p.items[p.count - 1]
	p.count -= 1
}

pool_items :: proc(p: ^Item_Pool($T)) -> #soa[]T {
	return p.items[0:p.count]
}

pool_get :: proc(p: ^Item_Pool($T), i: int) -> #soa^#soa[]T {
	assert(i < p.count)
	return &p.items[i]
}
