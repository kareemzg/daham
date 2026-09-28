shader_type canvas_item;
render_mode unshaded;

// A frosted pane: the sky behind it, blurred, with a tint over the top.
//
// This is what stops the bottom assembly reading as an opaque slab laid on the
// picture. The Milky Way's violet passes through it and a bright star shows as
// a soft smudge, so the panel belongs to the same night as everything else.
//
// It needs a `BackBufferCopy` directly before it in the tree, or SCREEN_TEXTURE
// is a frame stale and the blur lags the drift by one tick.
//
// The blur is two passes' worth of taps in one: a 13-tap spiral rather than a
// separable Gaussian, because this quad is drawn once per frame at the bottom
// of the screen and a second pass would cost more than the quality is worth.

// Godot 4 dropped the SCREEN_TEXTURE builtin: it is a uniform with a hint now,
// and the `BackBufferCopy` in front of this quad is what fills it.
uniform sampler2D screen_behind : hint_screen_texture, filter_linear_mipmap;

uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float corner_radius = 26.0;
// Which corners are rounded, clockwise from top-left. The assembly meets the
// bottom of the screen, so its lower corners are square.
uniform vec4 corners = vec4(1.0, 1.0, 0.0, 0.0);
uniform float blur_radius : hint_range(0.0, 40.0) = 18.0;
uniform vec4 tint : source_color = vec4(0.102, 0.125, 0.278, 0.34);
// A hairline along the top, which is what says "this is a surface".
uniform vec4 rim : source_color = vec4(0.66, 0.545, 0.839, 0.45);
uniform float rim_width = 2.0;

const vec2 TAPS[13] = {
	vec2(0.0, 0.0),
	vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.62, 0.62), vec2(-0.62, 0.62), vec2(0.62, -0.62), vec2(-0.62, -0.62),
	vec2(0.42, 0.0), vec2(-0.42, 0.0), vec2(0.0, 0.42), vec2(0.0, -0.42)
};

float rounded_box(vec2 at, vec2 half_size, float r) {
	vec2 d = abs(at) - half_size + vec2(r);
	return length(max(d, vec2(0.0))) - r + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 pixel = UV * rect_size;
	vec2 half_size = rect_size * 0.5;
	vec2 centred = pixel - half_size;

	// Pick this corner's radius: x sign chooses left/right, y chooses top/bottom.
	float top_r = centred.x < 0.0 ? corners.x : corners.y;
	float bottom_r = centred.x < 0.0 ? corners.w : corners.z;
	float r = corner_radius * (centred.y < 0.0 ? top_r : bottom_r);

	float dist = rounded_box(centred, half_size, r);
	float inside = 1.0 - smoothstep(-1.0, 1.0, dist);
	if (inside <= 0.001) {
		discard;
	}

	vec3 blurred = vec3(0.0);
	vec2 step_size = SCREEN_PIXEL_SIZE * blur_radius;
	for (int i = 0; i < 13; i++) {
		blurred += texture(screen_behind, SCREEN_UV + TAPS[i] * step_size).rgb;
	}
	blurred /= 13.0;

	vec3 face = mix(blurred, tint.rgb, tint.a);

	// The rim rides the top edge only, and follows the corners round.
	float top_edge = 1.0 - smoothstep(0.0, rim_width, -dist);
	float upper = 1.0 - smoothstep(0.0, rim_width * 2.0, centred.y + half_size.y);
	face = mix(face, rim.rgb, rim.a * top_edge * upper);

	COLOR = vec4(face, inside);
}
