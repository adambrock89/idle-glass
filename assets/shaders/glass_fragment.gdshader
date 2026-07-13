shader_type canvas_item;

uniform vec4 tint_color = vec4(1.0, 1.0, 1.0, 0.7);
uniform float tint_intensity = 4.8;
uniform float opacity_multiplier = 1.0;
uniform float glare_intensity = 12.0;
uniform vec2 light_dir = vec2(1.0, 1.0);
uniform sampler2D screen_tex : hint_screen_texture;
uniform float face_count = 6.0;
uniform float bevel_width = 0.30;

float hash11(float x) {
    return fract(sin(x * 57.31) * 43758.5453);
}

void fragment() {
    vec4 polygon_color = COLOR;
    vec3 dynamic_tint = polygon_color.rgb * tint_color.rgb;

    float base_alpha = tint_color.a * polygon_color.a;
    float glass_alpha = clamp(base_alpha * opacity_multiplier, 0.0, 1.0);
    float tint_strength = max(tint_intensity, 0.0);
    float glare_strength = max(glare_intensity, 0.0);

    vec3 bg = texture(screen_tex, SCREEN_UV).rgb;
    float tint_blend = clamp(glass_alpha * (1.7 + tint_strength), 0.0, 1.0);
    vec3 col = mix(bg, dynamic_tint, tint_blend);

    vec2 local = UV * 2.0 - 1.0;
    float radius = clamp(length(local), 0.0, 1.0);

    float safe_faces = max(face_count, 3.0);
    float face_step = TAU / safe_faces;
    float angle = atan(local.y, local.x);
    float sector = floor((angle + PI) / face_step);
    float face_angle = (sector + 0.5) * face_step - PI;

    vec2 face_dir = vec2(cos(face_angle), sin(face_angle));
    float ndl = dot(normalize(light_dir), face_dir) * 0.5 + 0.5;

    float face_tint = mix(0.85, 1.24, ndl);
    face_tint *= mix(0.94, 1.08, hash11(sector + 1.0));

    float inner = clamp(1.0 - bevel_width, 0.0, 0.98);
    float bevel_mask = smoothstep(inner, 1.0, radius);
    col *= mix(1.0, face_tint, bevel_mask);

    float fresnel = pow(radius, 2.2);
    float spec = pow(ndl, 24.0) * bevel_mask;
    float glare_core = pow(ndl, 48.0) * bevel_mask;

    float edge = fresnel * bevel_mask * 0.55;
    col.r += edge * 0.18;
    col.g += edge * 0.12;
    col.b += edge * 0.24;

    float highlight_tint = 0.26 + tint_strength * 0.26;
    float fresnel_tint = 0.18 + tint_strength * 0.18;
    col += spec * (vec3(0.12) + dynamic_tint * highlight_tint) * glare_strength;
    col += fresnel * (vec3(0.04) + dynamic_tint * fresnel_tint) * (0.55 + glare_strength * 0.45);

    // Strong white-hot glare lobe to push that glass sparkle.
    col += vec3(1.0) * glare_core * (0.22 + glare_strength * 0.28);

    float reinject = clamp(glass_alpha * (0.55 + tint_strength * 0.28), 0.0, 1.0);
    col = mix(col, dynamic_tint, reinject);

    COLOR = vec4(col, glass_alpha);
}
