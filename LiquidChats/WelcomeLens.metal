#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 messageEdgeBlur(float2 position, SwiftUI::Layer layer, float edge) {
    float reveal = smoothstep(edge-28.0f, edge+44.0f, position.y);
    if (reveal <= 0.0f) return half4(0);
    if (reveal >= 1.0f) return layer.sample(position);

    // Blur increases toward the boundary while premultiplied alpha fades the whole bubble.
    float radius = 6.0f*(1.0f-reveal);
    const float weights[5] = {1, 4, 6, 4, 1};
    half4 color = half4(0);
    for (int y = 0; y < 5; ++y) {
        for (int x = 0; x < 5; ++x) {
            float2 offset = float2(x-2, y-2)*radius*0.5f;
            color += layer.sample(position+offset)*half(weights[x]*weights[y]/256.0f);
        }
    }
    return color*half(reveal);
}

[[ stitchable ]] half4 partyRipple(float2 position, SwiftUI::Layer layer, float2 center, float2 size, float time) {
    float2 delta = position-center;
    float distance = length(delta);
    float displacement = 0;
    // Four staggered packets emit a soft wave every 1.3 seconds without a hard loop reset.
    for (int index = 0; index < 4; ++index) {
        float age = fmod(time + float(index)*1.3f, 5.2f);
        float radius = age*170.0f;
        float envelope = exp(-pow((distance-radius)/85.0f, 2.0f));
        float emission = smoothstep(0.0f, 0.3f, age)*(1.0f-smoothstep(4.7f, 5.2f, age));
        displacement += sin((distance-radius)/15.0f)*envelope*3.2f*emission;
    }
    displacement *= smoothstep(0.0f, 0.6f, time)*exp(-distance/900.0f);
    float2 samplePosition = position + delta/max(distance, 1.0f)*displacement;
    return layer.sample(clamp(samplePosition, float2(1), size-float2(1)));
}

[[ stitchable ]] half4 welcomeLens(float2 position, SwiftUI::Layer layer, float2 center, float radius, float time) {
    float2 delta = position - center;
    float r = length(delta) / radius;
    half4 original = layer.sample(position);
    if (r >= 1.0f) return original;

    float edge = 1.0f - smoothstep(0.78f, 1.0f, r);
    float bend = 0.52f + 0.48f * r*r;
    float ripple = sin(r*12.0f - time*5.0f) * 0.7f * edge;
    float2 normal = delta / max(length(delta), 1.0f);
    float2 uv = center + delta*bend + normal*ripple;
    float fringe = 3.2f * (1.0f-r*r);
    half4 green = layer.sample(uv);
    half4 red = layer.sample(uv + normal*fringe);
    half4 blue = layer.sample(uv - normal*fringe);
    half alpha = max(green.a, max(red.a, blue.a));
    // Sampled colors are premultiplied: keep colored fringes inside their alpha.
    half4 refracted = half4(min(red.r, alpha), min(green.g, alpha), min(blue.b, alpha), alpha);
    return mix(original, refracted, half(edge));
}

// Adapted from eujinco/ripple-image-transition (MIT), copyright 2026 Eujin Nam.
// Ripple shader for the sample transition effect.


[[ stitchable ]]
half4 themeRipple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float time,
    float amplitude,
    float frequency,
    float decay,
    float speed
) {
    float2 delta = position - origin;
    float distance = length(delta);
    float safeSpeed = max(fabs(speed), 0.0001);
    float delay = distance / safeSpeed;

    time -= delay;
    time = max(0.0, time);

    float rippleAmount = amplitude * sin(frequency * time) * exp(-decay * time);
    float2 direction = distance > 0.0001 ? (delta / distance) : float2(0.0);
    float2 newPosition = position + rippleAmount * direction;

    half4 color = layer.sample(newPosition);
    float safeAmplitude = max(fabs(amplitude), 0.0001);
    color.rgb += 0.3 * (rippleAmount / safeAmplitude) * color.a;

    return color;
}

// Adapted from eujinco/ripple-image-transition (MIT), copyright 2026 Eujin Nam.

[[ stitchable ]]
half4 themeReveal(
    float2 position,
    half4 color,
    float2 origin,
    float time,
    float duration,
    float maxRadius,
    float feather
) {
    float safeDuration = max(duration, 0.0001);
    float progress = clamp(time / safeDuration, 0.0, 1.0);
    float radius = progress * maxRadius;
    float d = distance(position, origin);
    float alpha = 1.0f-smoothstep(radius - feather, radius + feather, d);
    half reveal = half(alpha);

    return half4(color.rgb * reveal, color.a * reveal);
}
