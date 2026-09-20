shader_type canvas_item;
render_mode unshaded;

// One rounded panel, the shape every tile, chip, button and well is made of.
//
// The node's rect covers the face AND the hard bottom edge under it, so a tile
// can sit on its edge without a second node. Sizes are in pixels rather than UV
// so the corner radius and the border keep their thickness at any size, which is
// what lets one material serve a 48px grid cell and a 200px wheel disc.
//
// The soft shadow beneath is a separate quad; see `panel_shadow.gdshader`.

uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float corner_radius = 20.0;

// The face: a three-stop ramp, run down the face or out from a point.
uniform vec4 face_top : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 face_mid : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform vec4 face_bottom : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float mid_stop : hint_range(0.02, 0.98) = 0.5;
/// 0 runs the ramp top to bottom; 1 runs it outward from `gradient_center`,
/// which is what makes the wheel read as a lit dome instead of a flat disc.
uniform float radial : hint_range(0.0, 1.0) = 0.0;
uniform vec2 gradient_center = vec2(0.5, 0.3);

uniform float highlight : hint_range(0.0, 1.0) = 0.45;
uniform float highlight_height : hint_range(0.01, 1.0) = 0.18;

// A stroke in a darker shade of the face colour, never black.
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float border_width = 3.0;

// The hard bottom edge. Height in pixels, taken off the bottom of the rect.
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float bottom_edge = 0.0;

// Recessed look for empty grid cells: shadow inside the top of the shape.
uniform float inner_shadow : hint_range(0.0, 1.0) = 0.0;

// Rims hugging the inside of the shape, the way the wheel disc has a light one
// at the top and a dark one at the bottom. Heights in pixels; they follow the
// corners rather than cutting flat bands, so on a circle they read as a second,
// inner frame. This is what `highlight` cannot do: that one is a soft fade.
uniform vec4 inner_top_color : source_color = vec4(1.0, 1.0, 1.0, 0.18);
uniform float inner_top = 0.0;
uniform vec4 inner_bottom_color : source_color = vec4(0.0, 0.0, 0.0, 0.18);
uniform float inner_bottom = 0.0;

float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec3 ramp(float t) {
	if (t < mid_stop) {
		return mix(face_top.rgb, face_mid.rgb, t / max(mid_stop, 0.001));
	}
	return mix(face_mid.rgb, face_bottom.rgb, (t - mid_stop) / max(1.0 - mid_stop, 0.001));
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 face_size = vec2(rect_size.x, max(rect_size.y - bottom_edge, 1.0));

	float r_outer = min(corner_radius, min(rect_size.x, rect_size.y) * 0.5);
	float r_face = min(corner_radius, min(face_size.x, face_size.y) * 0.5);

	float d_outer = sd_round_box(p - rect_size * 0.5, rect_size * 0.5, r_outer);
	float d_face = sd_round_box(p - face_size * 0.5, face_size * 0.5, r_face);

	float aa = max(fwidth(d_outer), 0.0001);
	float a_outer = 1.0 - smoothstep(-aa, aa, d_outer);
	if (a_outer <= 0.002) {
		discard;
	}
	float a_face = 1.0 - smoothstep(-aa, aa, d_face);

	float v = clamp(p.y / face_size.y, 0.0, 1.0);
	// Radial distance normalised against the farthest corner, matching how CSS
	// sizes a radial gradient by default.
	vec2 in_face = p / face_size;
	float aspect = face_size.x / max(face_size.y, 1.0);
	vec2 offset = (in_face - gradient_center) * vec2(aspect, 1.0);
	vec2 farthest = max(abs(gradient_center), abs(vec2(1.0) - gradient_center)) * vec2(aspect, 1.0);
	float radial_t = clamp(length(offset) / max(length(farthest), 0.001), 0.0, 1.0);

	vec3 col = ramp(mix(v, radial_t, radial));

	float shine = (1.0 - smoothstep(0.0, highlight_height, v)) * highlight;
	col = mix(col, vec3(1.0), shine);

	if (inner_shadow > 0.0) {
		// Darkest just inside the rim, and darker at the top than the bottom,
		// so the light still reads as coming from above.
		float depth = 1.0 - smoothstep(0.0, face_size.y * 0.42, -d_face);
		float from_top = 1.0 - smoothstep(0.0, 0.55, v);
		col *= 1.0 - inner_shadow * depth * (0.3 + 0.7 * from_top);
	}

	if (inner_top > 0.0) {
		// The face shifted down: what the shift leaves uncovered along the top
		// is the rim, curving with the shape.
		float dropped = sd_round_box(
			p - vec2(0.0, inner_top) - face_size * 0.5, face_size * 0.5, r_face
		);
		float rim = smoothstep(-aa, aa, dropped) * a_face;
		col = mix(col, inner_top_color.rgb, rim * inner_top_color.a);
	}

	if (inner_bottom > 0.0) {
		// Same trick the other way up.
		float lifted = sd_round_box(
			p - vec2(0.0, -inner_bottom) - face_size * 0.5, face_size * 0.5, r_face
		);
		float rim = smoothstep(-aa, aa, lifted) * a_face;
		col = mix(col, inner_bottom_color.rgb, rim * inner_bottom_color.a);
	}

	// The border band lies inside the face edge, width pixels thick.
	float band = smoothstep(-border_width - aa, -border_width + aa, d_face) * a_face;
	col = mix(col, border_color.rgb, band * border_color.a);

	// Anything inside the outer shape but below the face is the hard edge.
	col = mix(edge_color.rgb, col, a_face);

	COLOR = vec4(col, a_outer);
}
