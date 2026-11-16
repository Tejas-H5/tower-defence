package main

state: Game_State

main :: proc() {
	// main_program()
	run_test()
	// run_interactive_test()
}

main_program :: proc() {
	init_window("Tower defender")

	init(&state)

	for process_frame() {
		render_game(&state)
	}

	close_window()
}
