shader_type canvas_item;

// ColorRect no tiene textura propia (TEXTURE ahí siempre da blanco opaco) -
// hay que leer la pantalla real detrás con este sampler.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// ======================
// Parámetros ajustables
// ======================
uniform float crt_curve : hint_range(0.0, 0.4) = 0.18;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_count : hint_range(100.0, 800.0) = 320.0;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.85;
uniform float aberration : hint_range(0.0, 0.02) = 0.006;

// Efectos ácidos
uniform float wave_strength : hint_range(0.0, 0.08) = 0.025;
uniform float wave_speed : hint_range(0.0, 6.0) = 2.2;
uniform float color_shift_speed : hint_range(0.0, 3.0) = 0.8;
uniform float color_intensity : hint_range(0.0, 1.5) = 0.7;
uniform float noise_amount : hint_range(0.0, 0.15) = 0.04;

// ======================
// Funciones auxiliares
// ======================
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / vec2(6.0, 4.0);
    uv = uv + uv * offset * offset * crt_curve * 12.0;
    uv = uv * 0.5 + 0.5;
    return uv;
}

void fragment() {
    vec2 uv = UV;

    // 1. Curvatura CRT
    uv = curve(uv);

    // Descartar bordes curvados - Godot no permite 'return' dentro de
    // fragment(), así que el resto del efecto va en el else.
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        // 2. Ondulación ácida (viaje)
        float time = TIME * wave_speed;
        uv.x += sin(uv.y * 9.0 + time) * wave_strength;
        uv.y += cos(uv.x * 7.5 + time * 0.8) * wave_strength * 0.7;
        uv.x += sin(uv.y * 18.0 - time * 1.3) * wave_strength * 0.4;

        // 3. Aberración cromática + shift de color
        float shift = aberration + sin(TIME * color_shift_speed) * aberration * 1.8;

        float r = texture(screen_texture, uv + vec2(shift, 0.0)).r;
        float g = texture(screen_texture, uv).g;
        float b = texture(screen_texture, uv - vec2(shift, 0.0)).b;

        vec3 col = vec3(r, g, b);

        // 4. Distorsión de color psicodélica
        float hue_shift = sin(TIME * color_shift_speed + uv.x * 4.0) * color_intensity * 0.15;
        col.r = mix(col.r, col.g, hue_shift * 0.6);
        col.b = mix(col.b, col.r, hue_shift * 0.4);
        col.g = mix(col.g, col.b, sin(TIME * 1.7) * color_intensity * 0.12);

        // 5. Scanlines
        float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
        scanline = pow(scanline, 1.4);
        col *= 1.0 - (scanline * scanline_intensity);

        // 6. Viñeta
        vec2 vig_uv = uv * (1.0 - uv.yx);
        float vig = vig_uv.x * vig_uv.y * 18.0;
        vig = pow(vig, vignette_strength);
        col *= vig;

        // 7. Ruido / grain
        float noise = random(uv + TIME * 0.1) * noise_amount;
        col += noise * 0.6 - noise_amount * 0.3;

        // Clamp final
        col = clamp(col, 0.0, 1.0);

        COLOR = vec4(col, 1.0);
    }
}