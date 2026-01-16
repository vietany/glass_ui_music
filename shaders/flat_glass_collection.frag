#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uRefraction;   // Index 3 (Thay cho uVariant cũ)
uniform vec2 uScreenSize;    // Index 4, 5
uniform vec2 uItemPos;       // Index 6, 7
uniform float uStretchX;     // Index 8
uniform float uSquashY;      // Index 9

// --- CÁC THAM SỐ TÙY CHỈNH MỚI ---
uniform float uSpecular;     // Index 10: Độ bóng
uniform float uOpacity;      // Index 11: Độ đậm
uniform float uFrost;        // Index 12: Độ mờ đục
uniform float uChroma;       // Index 13: Tán sắc

out vec4 fragColor;

// --- HÀM HÌNH DÁNG ---
float sdRoundedBox(vec2 p, vec2 b, vec4 r) {
    r.xy = (p.x>0.0)?r.xy : r.zw;
    r.x  = (p.y>0.0)?r.x  : r.y;
    vec2 q = abs(p)-b+r.x;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
}

// --- HÀM NỀN CARO ---
vec3 getCheckerboardBackground(vec2 globalUV) {
    vec2 uv = globalUV * vec2(uScreenSize.x / 40.0, uScreenSize.y / 40.0);
    vec2 id = floor(uv);
    float checker = mod(id.x + id.y, 2.0);
    vec3 col = mix(vec3(0.15), vec3(0.22), checker);
    float d = length(globalUV - 0.5);
    col *= 1.0 - d * 0.5;
    return col;
}

void main() {
    // 1. Chuẩn hóa & Biến dạng
    vec2 p = (FlutterFragCoord().xy * 2.0 - uResolution) / min(uResolution.x, uResolution.y);
    p.x /= uStretchX;
    p.y /= uSquashY;

    vec2 absolutePixelPos = FlutterFragCoord().xy + uItemPos;
    vec2 globalUV = absolutePixelPos / uScreenSize;

    // --- VẼ BACKGROUND TOÀN MÀN HÌNH ---
    // Dùng uRefraction = -1.0 làm tín hiệu vẽ nền
    if (uRefraction < -0.5) {
        fragColor = vec4(getCheckerboardBackground(globalUV), 1.0);
        return;
    }

    // --- VẼ HÌNH KHỐI ---
    vec2 boxSize = vec2(0.85, 0.55);
    vec4 cornerRad = vec4(0.2);

    float d = sdRoundedBox(p, boxSize, cornerRad);

    // Khử răng cưa
    float edgeAlpha = 1.0 - smoothstep(-0.01, 0.01, d);
    if (edgeAlpha <= 0.0) { fragColor = vec4(0.0); return; }

    // --- QUANG HỌC ---
    float border = smoothstep(-0.15, 0.0, d);
    vec3 normal = normalize(vec3(p.x * border, p.y * border, 0.6));

    // 1. Khúc xạ (Refraction)
    vec2 refUV = globalUV + normal.xy * uRefraction; // Dùng tham số động

    if (uFrost > 0.0) {
        float noise = fract(sin(dot(globalUV, vec2(12.9898, 78.233))) * 43758.5453);
        refUV += (noise - 0.5) * uFrost * 0.02;
    }

    vec3 bgCol = getCheckerboardBackground(refUV); // Không vẽ đè, chỉ lấy màu để tính toán (nếu cần blend sau này)

    // 2. Phản xạ (Specular)
    vec3 lightDir = normalize(vec3(-0.5, 0.5, 1.0));
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 halfDir = normalize(lightDir + viewDir);

    float spec = pow(max(dot(normal, halfDir), 0.0), uSpecular); // Dùng tham số động
    float fresnel = pow(1.0 - max(dot(normal, viewDir), 0.0), 3.0);
    fresnel = smoothstep(0.0, 1.0, fresnel);

    // --- TỔNG HỢP MÀU (TRANSPARENT LAYERING) ---
    vec3 tint = vec3(0.96, 0.98, 1.0); // Mặc định tint trắng xanh nhẹ

    // Tán sắc (Chromatic Aberration) - Cộng màu vào viền
    vec3 chromaCol = vec3(0.0);
    if (uChroma > 0.0) {
        chromaCol = vec3(1.0, 0.0, 0.5) * uChroma * border; // Màu tím/đỏ ở viền
    }

    vec3 finalCol = tint;
    finalCol += vec3(1.0) * spec; // Bóng
    finalCol += vec3(0.9, 0.95, 1.0) * fresnel * 0.8; // Viền sáng
    finalCol += chromaCol; // Tán sắc

    // Tính Alpha cuối cùng
    float finalAlpha = uOpacity + spec + fresnel * 0.5;

    fragColor = vec4(finalCol * finalAlpha, finalAlpha * edgeAlpha);
}