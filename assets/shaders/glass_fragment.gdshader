shader_type canvas_item;

uniform vec4 tint_color = vec4(1.0, 1.0, 1.0, 0.75);
uniform vec2 light_dir = vec2(1.0, -1.0);
uniform sampler2D screen_tex : hint_screen_texture;

// Object center in SCREEN_UV space (set from GDScript)
uniform vec2 object_screen_pos; // e.g. (0..1, 0..1)

void fragment() {
    vec3 bg = texture(screen_tex, SCREEN_UV).rgb;
    vec3 col = mix(bg, tint_color.rgb, tint_color.a);

    // Position relative to object center, in screen space
    vec2 rel = SCREEN_UV - object_screen_pos;

    // Rim lighting around object center
    float fresnel = pow(1.0 - clamp(length(rel) * 2.0, 0.0, 1.0), 3.0);

    // Fixed glare: top-right relative to screen
    vec2 glare_offset = vec2(0.2, -0.2); // tweak for taste
    vec2 glare_vec = normalize(rel - glare_offset);
    float glare = dot(glare_vec, normalize(light_dir));
    glare = pow(max(glare, 0.0), 6.0);

    // Chromatic edge shift
    float edge = fresnel * 0.4;
    col.r += edge * 0.15;
    col.g += edge * 0.10;
    col.b += edge * 0.20;

    // Combine
    col += glare * 0.4;
    col += fresnel * 0.2;

    COLOR = vec4(col, tint_color.a);
}
