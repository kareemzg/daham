shader_type canvas_item;
render_mode unshaded;

// What sits UNDER a panel: either a soft drop shadow or a hard halo ring.
//
// It lives on its own quad behind the panel, grown by `spread + blur` on every
// side, so the panel's own rect stays exactly the size the layout gave it.
// Without it the interface reads flat: the hard bottom edge says "this sits on
// something", but not "this sits above the background".
//
// `spread` with no `blur` gives the crisp ring the design puts around a picked
// wheel tile; `blur` with no `spread` gives an ordinary drop shadow.

uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float corner_radius = 20.0;
uniform float blur = 20.0;
uniform float spread = 0.0;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.4);

float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	if (blur <= 0.0 && spread <= 0.0) {
		discard;
	}
	vec2 p = UV * rect_size;
	// The quad is padded by spread + blur, so insetting by blur leaves the
	// panel's shape grown by spread, which is what the falloff runs from.
	vec2 half_size = max(rect_size * 0.5 - vec2(blur), vec2(1.0));
	float r = min(corner_radius + spread, min(half_size.x, half_size.y));
	float d = sd_round_box(p - rect_size * 0.5, half_size, r);
	float softness = max(blur, 0.75);
	float coverage = 1.0 - smoothstep(-softness, softness, d);
	// Squared falloff for a real shadow: closer to a blur than a straight ramp,
	// and it keeps the shadow from spreading into a grey halo. A hard ring has
	// no falloff to shape, so it stays linear.
	float alpha = coverage;
	if (blur > 0.0) {
		alpha = coverage * coverage;
	}
	COLOR = vec4(shadow_color.rgb, shadow_color.a * alpha);
}
