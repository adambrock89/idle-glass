shader_type canvas_item;

uniform vec4 top_color = vec4(0.15, 0.20, 0.35, 1.0);   // deep blue
uniform vec4 mid_color = vec4(0.90, 0.45, 0.30, 1.0);   // orange
uniform vec4 bottom_color = vec4(1.0, 0.75, 0.45, 1.0); // peach

uniform vec2 light_dir = vec2(1.0, -1.0); // top-right

void fragment() {
    vec2 uv = UV;

    // Vertical gradient
    float t = uv.y;

    // Smooth blend
    vec4 sky = mix(top_color, mid_color, smoothstep(0.0, 0.7, t));
    sky = mix(sky, bottom_color, smoothstep(0.6, 1.0, t));

    // Fake sun glow from top-right
    vec2 dir = normalize(light_dir);
    float glow = dot(normalize(uv - vec2(1.0, 0.0)), dir);
    glow = clamp(glow * 1.5, 0.0, 1.0);

    COLOR = sky + vec4(glow * 0.25);
}
