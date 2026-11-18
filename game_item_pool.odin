package main

Item_Pool_Memory :: struct($T: typeid, $N: uint) {
	items: #soa[N]T,
}

Item_Pool :: struct($T: typeid) {
	items: #soa[]T,
	count: int,
}

memory_to_pool :: proc(p: ^Item_Pool_Memory($T, $N)) -> Item_Pool(T) {
	return {
		items = p.items[:],
		count = 0,
	}
}

pool_add :: proc(p: ^Item_Pool($T), val: T) -> int {
	assert(p.count < len(p.items))

	idx := p.count
	p.count += 1
	p.items[idx] = val

	return idx
}

pool_unordered_remove :: proc(p: ^Item_Pool($T), idx: int) {
	assert(idx < p.count)
	p.items[idx] = p.items[p.count - 1]
	p.count -= 1
}

