#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uCenter; // 0.0 -> 1.0
uniform float uStretchX;
uniform float uSquashY;
uniform float uScale;

out vec4 fragColor;

float sdSquircle(vec2 p, vec2 r) {
    float k = 3.0; // Hình dáng vuông vức hơn một chút để ra dáng khối kính
    return pow(abs(p.x/r.x), k) + pow(abs(p.y/r.y), k) - 1.0;
}

void main() {
    // 1. CHUẨN HÓA TỌA ĐỘ (LOGIC AN TOÀN HƠN)
    vec2 uv = FlutterFragCoord().xy / uResolution;

    // Đưa tâm về giữa (0.0, 0.0)
    vec2 p = uv;
    p.x -= uCenter; // Dịch chuyển theo vị trí tab (uCenter chạy từ 0 đến 1)
    p.y -= 0.5;     // Dịch chuyển Y về giữa

    // Cân bằng tỷ lệ khung hình (Aspect Ratio Correction)
    // Nếu không có dòng này, hình sẽ bị kéo dãn theo chiều ngang của thanh navi
    p.x *= (uResolution.x / uResolution.y);
    p.y *= 2.0; // Scale Y lên để coordinate chạy từ -1 đến 1

    // 2. KÍCH THƯỚC KHỐI KÍNH
    // baseRadius 0.75 nghĩa là cao bằng 75% chiều cao thanh navi
    float baseRadius = 0.75;
    float currentRadius = baseRadius * uScale;

    // Rad x/y
    vec2 rad = vec2(currentRadius * uStretchX, currentRadius * uSquashY);

    // Tính khoảng cách
    float d = sdSquircle(p, rad);

    // 3. KHỬ RĂNG CƯA
    float edgeAlpha = 1.0 - smoothstep(-0.02, 0.02, d);

    // Cắt bỏ phần thừa (nhưng giữ lại 1 chút viền mờ để khử răng cưa)
    if (edgeAlpha <= 0.0) { fragColor = vec4(0.0); return; }

    // 4. HIỆU ỨNG 3D (HEIGHT MAP)
    // Tạo độ cong cho mặt kính
    float height = sqrt(1.0 - clamp(d + 1.0, 0.0, 1.0));
    vec3 normal = normalize(vec3(p.x, p.y, height * 1.5)); // 1.5 tăng độ lồi

    // 5. ÁNH SÁNG (BOOST SÁNG LÊN ĐỂ NHÌN THẤY)
    vec3 lightPos = normalize(vec3(-0.5, -1.0, 1.0));
    vec3 viewDir = vec3(0.0, 0.0, 1.0);

    // Specular (Bóng loáng)
    vec3 halfDir = normalize(lightPos + viewDir);
    float spec = pow(max(dot(normal, halfDir), 0.0), 40.0);

    // Fresnel (Viền sáng)
    float fresnel = pow(1.0 - max(dot(normal, viewDir), 0.0), 2.5);

    // 6. MÀU SẮC & ALPHA (TĂNG ĐỘ ĐẬM)
    vec3 glassColor = vec3(0.9, 0.95, 1.0); // Trắng xanh

    vec3 col = vec3(0.0);
    col += glassColor * 0.1;             // Tăng nền từ 0.02 -> 0.1 (để thấy khối)
    col += vec3(1.0) * spec * 1.2;       // Bóng gắt hơn
    col += glassColor * fresnel * 0.8;   // Viền sáng rõ hơn

    // Alpha: Tăng tối thiểu lên 0.1 (10%) để không bị tàng hình
    float alpha = 0.1 + fresnel * 0.6 + spec;

    fragColor = vec4(col, clamp(alpha * edgeAlpha, 0.0, 1.0));
}