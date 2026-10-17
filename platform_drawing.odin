package main

import "core:c"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

DrawableText :: struct {
	text:      cstring,
	font_size: f32,
	size:      Vec2,
}

drawable_text :: proc(font_size: f32, text: cstring) -> DrawableText {
	width := rl.MeasureText(text, c.int(font_size))
	return {
		text      = text,
		font_size = font_size,
		size      = Vec2 {
			f32(width),
			// When we implement text wrapping, height will be different from the size.
			font_size,
		},
	}
}

drawable_textf :: proc(size: f32, format: string, args: ..any) -> DrawableText {
	text := fmt.ctprintf(format, ..args)
	return drawable_text(size, text)
}

draw_text :: proc(text: DrawableText, pos: Vec2, color: Color) {
	rl.DrawText(text.text, c.int(pos.x), c.int(pos.y), c.int(text.font_size), color)
}

draw_rect :: proc(rect: Rect, color: Color) {
	x := c.int(math.ceil(rect.pos.x))
	y := c.int(math.ceil(rect.pos.y))
	w := c.int(math.ceil(rect.size.x))
	h := c.int(math.ceil(rect.size.y))
	rl.DrawRectangle(x, y, w, h, color)
}

draw_bg :: proc(color: Color) {
	draw_rect({{0, 0}, {width(), height()}}, COLOR_WHITE)
}

draw_rect_outline :: proc(rect: Rect, thickness: f32, color: Color) {
	x := rect.pos.x - thickness
	y := rect.pos.y - thickness
	w := rect.size.x + 2 * thickness
	h := rect.size.y + 2 * thickness
	draw_rect({{x, y}, {w, thickness}}, color)
	draw_rect({{x, y + h - thickness}, {w, thickness}}, color)
	draw_rect({{x, y + thickness}, {thickness, h - 2 * thickness}}, color)
	draw_rect({{x + w - thickness, y + thickness}, {thickness, h - 2 * thickness}}, color)
}
