shader_type canvas_item;

// 0 = Copper, 1 = Silver, 2 = Gold, 3 = Crystal/Platinum
uniform int metal_type = 0;

// 0 = soft, 1 = sharp, 2 = deep
uniform int bevel_mode = 0;

// Fixed top-right light in screen/world space
uniform vec2 light_dir = vec2(1.0, -1.0);

// Motion factor (0..0.25), used for animation only
uniform float motion_factor = 0.0;


// ----------------------
// Dispersion / crystal
// ----------------------
vec3 get_dispersion(vec2 uv, float fresnel) {
    float ref = 0.012 * fresnel;

    vec2 offset_r = vec2(ref * 0.5, ref * -0.3);
    vec2 offset_g = vec2(ref * 0.2, ref * 0.1);
    vec2 offset_b = vec2(ref * -0.4, ref * 0.6);

    float r = uv.x + offset_r.x;
    float g = uv.y + offset_g.y;
    float b = (uv.x + uv.y) * 0.5 + offset_b.x;

    return vec3(r, g, b);
}

vec3 get_crystal_color(float input_fresnel, float input_motion_factor, vec2 uv) {
    vec3 dispersion = get_dispersion(uv, input_fresnel);

    vec3 base    = vec3(0.50, 0.70, 1.10);
    vec3 scatter = mix(base, vec3(1.0), 0.20);
    vec3 edge_glow = vec3(0.9, 1.0, 1.2) * pow(input_fresnel, 2.0);

    float motion_intensity = smoothstep(0.0, 0.6, clamp(input_motion_factor, 0.0, 1.0));
    vec3 sparkle = vec3(1.2, 1.2, 1.4) * (0.10 + motion_intensity * 0.08);

    vec3 crystal = mix(base, dispersion, 0.6);

    float facet = sin(uv.x * 6.0) * sin(uv.y * 6.0);
    facet = abs(facet);
    facet = pow(facet, 2.0);
    crystal = mix(crystal, crystal * (1.0 + facet * 0.25), 0.5);

    return crystal * 0.5 + scatter * 0.15 + edge_glow * 0.6 + sparkle * 0.7;
}


// ----------------------
// Metal / material
// ----------------------
vec3 get_metal_color(int m, float fresnel_val, float input_motion_factor, vec2 uv_val) {
    if (m == 0) return vec3(0.65, 0.40, 0.22); // darker copper
    if (m == 1) return vec3(0.78, 0.78, 0.83); // softer silver
    if (m == 2) return vec3(0.88, 0.75, 0.32); // slightly muted gold
    return get_crystal_color(fresnel_val, input_motion_factor, uv_val); // Crystal/Platinum
}

float get_sparkle_strength(int m) {
    if (m == 0) return 0.08;
    if (m == 1) return 0.20;
    if (m == 2) return 0.35;
    return 0.40;
}


// ----------------------
// Bevel / shape
// ----------------------
float get_bevel_factor(float y, int mode) {
    if (mode == 0) {
        return smoothstep(0.0, 0.5, y) * (1.0 - smoothstep(0.5, 1.0, y));
    }
    if (mode == 1) {
        return step(0.3, y) * (1.0 - step(0.7, y));
    }
    float c = 1.0 - abs(y - 0.5) * 2.0;
    return clamp(c, 0.0, 1.0);
}


// ----------------------
// Microfacet / anisotropic
// ----------------------
float microfacet(vec2 uv, float motion) {
    float t = TIME * mix(0.3, 1.4, clamp(motion, 0.0, 1.0));
    float n1 = fract(sin(dot(uv * 250.0, vec2(12.9898, 78.233))) * 43758.5453);
    float n2 = fract(sin(dot(uv * 420.0 + vec2(t, t * 0.7), vec2(93.9898, 47.233))) * 15731.5453);
    return (n1 * 0.6 + n2 * 0.4);
}

float anisotropic(vec2 uv, vec2 dir) {
    float proj = dot(uv - vec2(0.5), normalize(dir));
    float streak = smoothstep(0.0, 1.0, sin(proj * 16.0));
    return streak;
}


// ----------------------
// Fragment
// ----------------------
void fragment() {
    vec2 uv = UV;

    float nz = clamp(NORMAL.z, 0.0, 1.0);
    float fresnel = pow(1.0 - nz, 2.0);

    vec3 base_color = get_metal_color(metal_type, fresnel, motion_factor, uv);
    float sparkle_strength = get_sparkle_strength(metal_type);

    float bevel = get_bevel_factor(uv.y, bevel_mode);

    vec2 dir = normalize(light_dir);

    vec2 bevel_normal = normalize(NORMAL.xy + vec2(0.0, bevel * 0.3));

    float ndl = dot(bevel_normal, dir);
    ndl = clamp(ndl, 0.0, 0.45);

    float spec = ndl * 0.7;

    float sparkle = microfacet(uv, motion_factor);
    float aniso = anisotropic(uv, dir);

    vec3 color = base_color;

    color *= 0.85 + bevel * 0.15;
    color += spec * 0.8;
    color += aniso * 0.10;
    color = mix(color, color + sparkle, sparkle_strength * 0.12);

    color *= 0.85;
    color = clamp(color, vec3(0.0), vec3(0.9));

    COLOR = vec4(color, 1.0);
}
