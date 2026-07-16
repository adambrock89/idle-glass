shader_type canvas_item;

// Polygon geometry
uniform int point_count;
uniform vec2 points[256];

// Bevel controls
uniform float bevel_thickness = 40.0;
uniform float carve_noise = 0.55;      // stronger irregularity for medieval carving
uniform float carve_scale = 0.10;      // slightly lower frequency

// Lighting
uniform vec2 light_dir = vec2(1.0, -0.3);

// Wood base color (medieval dark oak)
uniform vec3 wood_base = vec3(0.45, 0.28, 0.10);


// ------------------------------------------------------------
// Utility
// ------------------------------------------------------------
float softmin(float a, float b, float k) {
    return -log(exp(-k * a) + exp(-k * b)) / k;
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 random2(vec2 p) {
    return fract(sin(vec2(
        dot(p, vec2(127.1, 311.7)),
        dot(p, vec2(269.5, 183.3))
    )) * 43758.5453);
}

float grad_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 a = random2(i);
    vec2 b = random2(i + vec2(1.0, 0.0));
    vec2 c = random2(i + vec2(0.0, 1.0));
    vec2 d = random2(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    float va = dot(a, f - vec2(0.0, 0.0));
    float vb = dot(b, f - vec2(1.0, 0.0));
    float vc = dot(c, f - vec2(0.0, 1.0));
    float vd = dot(d, f - vec2(1.0, 1.0));

    return mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y);
}



// ------------------------------------------------------------
// FBM turbulence
// ------------------------------------------------------------
float fbm(vec2 p) {
    float f = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 5; i++) {
        f += amp * grad_noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return f;
}



// ------------------------------------------------------------
// Wood grain function (rings + knots + fibers)
// ------------------------------------------------------------
float wood(vec2 p) {
    // Stretch grain direction (vertical fibers)
    p.x *= 0.25;

    // Base rings with turbulence
    float rings = p.x + fbm(p * 0.5) * 2.0;

    // Sharpen rings
    rings = fract(rings);

    // Knot turbulence
    float knot = fbm(p * 3.0);

    // Combine rings + knots
    float grain = rings * 0.6 + knot * 0.4;

    return grain;
}


// ------------------------------------------------------------
// Fragment
// ------------------------------------------------------------
void fragment() {
    vec2 p = FRAGCOORD.xy;

    float min_dist = 999999.0;
    int closest_index = 0;

    float k = 12.0;

    for (int i = 0; i < point_count; i++) {
        vec2 a = points[i];
        vec2 b = points[(i + 1) % point_count];

        float d = sd_segment(p, a, b);
        float blended = softmin(min_dist, d, k);

        if (d < min_dist) {
            closest_index = i;
        }

        min_dist = blended;
    }

    // Hand‑carved irregularity (stronger for medieval)
    float carve = grad_noise(p * carve_scale) * carve_noise;
    min_dist += carve;

    min_dist = sqrt(min_dist * min_dist + 0.0001);

    float nd = clamp(min_dist / bevel_thickness, 0.0, 1.0);
    float bevel = nd * nd * (3.0 - 2.0 * nd);
    bevel = 1.0 - bevel;

    vec2 a = points[closest_index];
    vec2 b = points[(closest_index + 1) % point_count];
    vec2 edge_dir = normalize(b - a);
    vec2 normal2d = vec2(-edge_dir.y, edge_dir.x);

    float light = clamp(dot(normal2d, -normalize(light_dir)), 0.0, 1.0);


    // ------------------------------------------------------------
    // Wood grain
    // ------------------------------------------------------------
    float grain = wood(p * 0.12);

    // Fiber streaks (medieval rough-cut)
    float fibers = fbm(p * vec2(20.0, 1.0)) * 0.1;

    vec3 wood_color = wood_base;

    // Darken rings (medieval oak)
    wood_color *= 1.0 - grain * 0.25;

    // Add fiber streaks
    wood_color += fibers * 0.15;

    // Slight burn tint inside carved areas
    wood_color *= mix(1.0, 0.85, bevel);


    // ------------------------------------------------------------
    // Lighting only on bevel
    // ------------------------------------------------------------
    float edge_light = mix(1.0, 1.0 + light * 0.8, bevel);

    COLOR = vec4(wood_color * edge_light, 1.0);
}
