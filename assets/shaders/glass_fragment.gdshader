shader_type canvas_item;

// Use premultiplied alpha blending correctly
render_mode blend_premul_alpha;

uniform vec4 tint_color : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform float object_rotation = 0.0; // updated every frame
uniform float transparency = 0.75;   // base transparency of the glass
uniform float gloss_strength = 0.35; // intensity of directional highlight
uniform float noise_scale = 4.0;     // stained-glass texture variation

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

void fragment() {
    // Base tinted color with transparency
    vec4 base = tint_color;
    base.a = transparency;

    // Stained-glass irregularity
    float n = noise(UV * noise_scale);
    base.rgb *= 0.85 + n * 0.15;

    // Simulated directional light from top-right, rotated by object_rotation
    float angle = object_rotation;
    vec2 light_dir = normalize(vec2(1.0, -1.0)); // top-right
    mat2 rot = mat2(
	    vec2(cos(angle), -sin(angle)),
	    vec2(sin(angle),  cos(angle))
	);

    light_dir = rot * light_dir;

    // Light intensity based on UV gradient
    float light_intensity = clamp(dot(normalize(UV - vec2(0.5)), light_dir), 0.0, 1.0);

    // Glossy highlight
    vec3 highlight = vec3(1.0) * light_intensity * gloss_strength;

    // Premultiplied alpha output
    vec3 rgb = base.rgb + highlight;
    float a = base.a;
    COLOR = vec4(rgb * a, a);
}
