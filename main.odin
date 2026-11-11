package main

state: Game_State

main :: proc() {
	init_window("Tower defender")

	init(&state)


	PHYSICS_TIMESTEP :: 0.02

	MAX_PHYSICS_TO_CATCH_UP_ON :: 5 * PHYSICS_TIMESTEP
	physics_to_catch_up_on := f32(0)
	for process_frame() {
		set_mouse_cursor(.None)

		physics_to_catch_up_on += get_delta_time()
		if physics_to_catch_up_on > MAX_PHYSICS_TO_CATCH_UP_ON {
			// If we don't do this, a little bit of lag will cause physics_to_catch_up_on to
			// infinitely increase, causing each subsequent frame to take longer and longer.
			// Instead, we can just slow down the simulation a bit by doing this.
			physics_to_catch_up_on = MAX_PHYSICS_TO_CATCH_UP_ON
		}

		// Ensure determinism of the physics somewhat.
		dt := f32(PHYSICS_TIMESTEP)
		for physics_to_catch_up_on > 0 {
			physics_to_catch_up_on -= dt
			update_game(&state, dt)
		}

		render_game(&state)
	}

	close_window()
}

