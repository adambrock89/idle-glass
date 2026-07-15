shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.45, 0.45, 0.45, 1.0);
uniform vec4 dark_color : source_color = vec4(0.25, 0.25, 0.25, 1.0);
uniform vec4 light_color : source_color = vec4(0.70, 0.70, 0.70, 1.0);

uniform float bevel_width = 0.22;
uniform float bevel_softness = 0.12;

uniform vec2 light_dir = vec2(-0.4, -0.8);

uniform float noise_scale = 6.0;
uniform float noise_strength = 0.55;

uniform float contrast = 1.1;
uniform float brightness = 1.0;

float hash(vec2 p) {
    p = vec2(
        dot(p, vec2(127.1, 311.7)),
        dot(p, vec2(269.5, 183.3))
    );
    return fract(sin(p.x) * 43758.5453123 + sin(p.y) * 37483.5439213);
}

float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
    vec2 uv = FRAGCOORD.xy / 256.0;

    float d_left   = uv.x;
    float d_right  = 1.0 - uv.x;
    float d_top    = uv.y;
    float d_bottom = 1.0 - uv.y;

    float d = min(min(d_left, d_right), min(d_top, d_bottom));

    float inner = smoothstep(0.0, bevel_width, d);
    float soft  = smoothstep(bevel_width, bevel_width + bevel_softness, d);
    float bevel = inner * soft;

    vec3 col = base_color.rgb;

    float n = noise2d(uv * noise_scale);
    n = (n - 0.5) * 2.0;
    col += n * noise_strength;

    vec3 fake_normal = normalize(vec3(uv.x - 0.5, uv.y - 0.5, 0.6));
    vec3 L = normalize(vec3(light_dir.x, light_dir.y, 0.6));

    float ndotl = clamp(dot(fake_normal, L), -1.0, 1.0);
    float edge_light = mix(0.0, ndotl * 0.7 + 0.3, 1.0 - bevel);

    vec3 lit = mix(dark_color.rgb, light_color.rgb, edge_light);
    col = mix(col, lit, 0.6);

    col = (col - 0.5) * contrast + 0.5;
    col *= brightness;

    COLOR = vec4(uv, 0.0, 1.0);
}
