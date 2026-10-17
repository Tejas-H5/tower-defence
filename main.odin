package main

main :: proc() {
	init_window("Tower defender")

	state: GameState
	init(&state)

	physics_time_needed := f32(0)

	for process_frame() {
		physics_time_needed += get_delta_time()

		// Ensure determinism of the physics somewhat.
		dt := f32(0.02)
		for physics_time_needed > 0 {
			physics_time_needed -= dt
			update_game(&state, dt)
		}

		render_game(&state)
	}

	close_window()
}

