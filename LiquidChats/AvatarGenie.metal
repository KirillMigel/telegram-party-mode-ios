// Horizontal adaptation of alexwidua/genie, © 2024 Alex Widua,
// original distortion © 2023 Janum Trivedi. MIT license in ThirdParty/Genie.
#include <metal_stdlib>
using namespace metal;

float genieSmooth(float x) {
    x = clamp(x, 0.0f, 1.0f);
    return x*x*x*(x*(x*6.0f-15.0f)+10.0f);
}

[[ stitchable ]] float2 avatarGenie(float2 position, float4 bounds, float progress, float2 target) {
    float p = clamp(progress, 0.0f, 1.0f);
    float sourceLeft = 91.0f;
    float sourceWidth = max(1.0f, bounds.z - sourceLeft);
    float squeeze = genieSmooth(p / 0.72f);
    float travel = genieSmooth((p - 0.22f) / 0.78f);
    float scaleX = mix(1.0f, 0.008f, travel);
    float left = mix(sourceLeft, target.x, travel);
    float sourceX = sourceLeft + (position.x - left) / scaleX;

    // The edge nearest the avatar narrows first; the tail follows it.
    // As in Genie, sample in the opposite direction of the visible deformation.
    float edge = mix(1.0f, -2.0f, squeeze) * sourceWidth;
    float along = sourceWidth - (sourceX - sourceLeft);
    float funnel = genieSmooth((along - edge) / max(1.0f, sourceWidth - edge));
    float inverseSqueeze = 1.0f + 23.0f * squeeze * funnel;
    float centerY = mix(43.0f, target.y, travel);
    float sourceY = 43.0f + (position.y - centerY) * inverseSqueeze;
    return float2(sourceX, sourceY);
}

// The same funnel, directed downward into the inline group-name field.
[[ stitchable ]] float2 headerNameGenie(float2 position, float4 bounds, float progress, float2 target) {
    float p = clamp(progress, 0.0f, 1.0f);
    float height = max(1.0f, bounds.w);
    float squeeze = genieSmooth(p / 0.72f);
    float travel = genieSmooth((p - 0.22f) / 0.78f);
    float scaleY = mix(1.0f, 0.008f, travel);
    float top = mix(0.0f, target.y, travel);
    float sourceY = (position.y - top) / scaleY;
    float edge = mix(1.0f, -2.0f, squeeze) * height;
    float funnel = genieSmooth((height - sourceY - edge) / max(1.0f, height - edge));
    float inverseSqueeze = 1.0f + 23.0f * squeeze * funnel;
    float centerX = mix(bounds.z * 0.5f, target.x, travel);
    float sourceX = bounds.z * 0.5f + (position.x - centerX) * inverseSqueeze;
    return float2(sourceX, sourceY);
}

// Leading edge arrives first while the tail follows, as in alexwidua/genie's delayed translation.
[[ stitchable ]] float2 avatarTransferGenie(float2 position, float2 source, float2 direction,
                                           float4 shape, float sourceRadius) {
    float2 normal = float2(-direction.y, direction.x);
    float2 relative = position-source;
    float along = (dot(relative, direction)-shape.x) / max(0.001f, shape.y-shape.x);
    float sourceU = mix(-sourceRadius, sourceRadius, along);
    float inverseSqueeze = 1.0f + shape.w*genieSmooth(along);
    float sourceV = dot(relative, normal)*sourceRadius/max(0.001f, shape.z)*inverseSqueeze;
    return source + direction*sourceU + normal*sourceV;
}
