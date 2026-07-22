shader_type canvas_item;
render_mode blend_mix;

// Base color
uniform vec4 base_color : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform float transparency = 0.75;

// Light direction (screen space)
uniform vec2 light_dir = vec2(1.0, -0.3);

// Pane rotation (radians)
uniform float pane_rotation = 0.0;

// Polygon edges (screen space)
uniform vec2 poly[64];
uniform int poly_count;

// Viewport size
uniform vec2 viewport_size;

// -------------------------
// Rotation helper
// -------------------------

mat2 pane_rot_matrix() {
    float ca = cos(pane_rotation);
    float sa = sin(pane_rotation);
    return mat2(vec2(ca, sa), vec2(-sa, ca));
}

// -------------------------
// Distance helpers
// -------------------------

float dist_to_segment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
    vec2 proj = a + ab * t;
    return length(p - proj);
}

float dist_to_edges(vec2 p, mat2 R) {
    float d = 999999.0;

    for (int i = 0; i < poly_count; i++) {
        vec2 a = R * poly[i];
        vec2 b = R * poly[(i + 1) % poly_count];
        d = min(d, dist_to_segment(p, a, b));
    }

    return d;
}

// -------------------------
// Height (bevel)
// -------------------------

float height_at(vec2 pane_pos, mat2 R) {
    float d = dist_to_edges(pane_pos, R);

    float bevel_thickness = 8.0;

    float bevel = 1.0 - smoothstep(0.0, bevel_thickness, d);
    bevel = pow(bevel, 0.3);

    return bevel;
}

// -------------------------
// Fragment
// -------------------------

void fragment() {
    vec2 screen_pos = SCREEN_UV * viewport_size;

    mat2 R = pane_rot_matrix();
    vec2 pane_pos = R * screen_pos;

    float height = height_at(pane_pos, R);

    float eps = 1.0;
    float hx = height_at(pane_pos + vec2(eps, 0.0), R) - height;
    float hy = height_at(pane_pos + vec2(0.0, eps), R) - height;

    // Normal (thin sheet)
	vec3 N = normalize(vec3(-hx, -hy, 0.2));

	// Light
	vec2 L2 = -normalize(R * light_dir);
	vec3 L = normalize(vec3(L2, 1.0));

	// View
	vec3 V = vec3(0.0, 0.0, 1.0);

	// Diffuse
	float ndl = max(dot(N, L), 0.0);
	ndl = pow(ndl, 5.0);

	// Base shading
	vec3 col = base_color.rgb * (0.55 + ndl * 1.1);
	float transmission = 0.15; // subtle glow
	col += base_color.rgb * transmission;
	
	float fresnel = pow(1.0 - max(dot(N, V), 0.0), 4.0);
	col += fresnel * 0.25;

	// Specular
	vec3 H = normalize(L + V);
	float spec = pow(max(dot(N, H), 0.0), 64.0);
	col += spec * 0.25;

	// Final clamp
	col = clamp(col, 0.0, 1.0);

	COLOR = vec4(col, transparency);

}
