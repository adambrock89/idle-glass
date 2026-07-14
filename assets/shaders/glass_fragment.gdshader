shader_type canvas_item;
render_mode blend_mix;

// Passed every frame
uniform float object_rotation;

uniform vec4 tint_color : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform float transparency = 0.75;
uniform float gloss_strength = 0.35;
uniform float noise_scale = 4.0;

// -------------------------
// Noise helpers
// -------------------------
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

    return mix(a, b, u.x)
         + (c - a) * u.y * (1.0 - u.x)
         + (d - b) * u.x * u.y;
}

void fragment() {
    vec4 base = tint_color;
    base.a = transparency;

    vec2 uv = UV;

    // -------------------------
    // Cathedral texture (LOCAL)
    // -------------------------
    float wave1 = sin(uv.y * 12.0 + uv.x * 4.0) * 0.03;
    float wave2 = sin(uv.x * 18.0 - uv.y * 6.0) * 0.02;
    float wave  = wave1 + wave2;

    vec2 warped_uv = uv + vec2(wave1, wave2);

    float n = noise(warped_uv * noise_scale);
    base.rgb *= 0.85 + n * 0.15;

    float thickness = 1.0 - uv.y;
    base.rgb *= mix(0.85, 1.25, thickness);

    base.rgb += vec3(
        wave * 0.12,
        wave * 0.06,
        wave * -0.08
    );

    float micro = noise(warped_uv * 22.0) * 0.12;
    base.rgb *= 1.0 + micro;

    float edge = smoothstep(0.85, 1.0, uv.y);
    base.rgb *= 1.0 - edge * 0.25;
   
	// -------------------------
	// TOP-RIGHT STREAK (visible at 0° AND 180°)
	// -------------------------

	// Rotation matrix
	mat2 rot = mat2(
	    vec2(cos(object_rotation), -sin(object_rotation)),
	    vec2(sin(object_rotation),  cos(object_rotation))
	);

	// Light direction (screen-space top-right)
	vec2 light_dir = normalize(vec2(1.0, -1.0));

	// Pane facing direction
	vec2 pane_dir = vec2(cos(object_rotation), sin(object_rotation));

	// *** KEY FIX: highlight at 0° AND 180° ***
	float facing = abs(dot(pane_dir, light_dir));

	// Move UV so top-right is the origin
	vec2 uv_shift = uv - vec2(0.85, 0.15);

	// Rotate UV so streak aligns with light direction
	vec2 uv_rot = rot * uv_shift;

	// Thin diagonal streak
	float line = abs(uv_rot.x + uv_rot.y * 0.4);

	// Small radius + sharper falloff
	float streak_mask = smoothstep(0.15, 0.0, line);

	// Balanced intensity
	float streak_intensity = facing * gloss_strength * 0.8;

	// Final streak highlight
	vec3 highlight = vec3(1.0) * streak_mask * streak_intensity;



    // -------------------------
    // Final color
    // -------------------------
    COLOR = vec4(base.rgb + highlight, base.a);
}
