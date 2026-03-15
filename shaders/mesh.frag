#version 450

layout(location = 0) in vec2 fragUV;
layout(location = 1) in vec3 fragNormal;
layout(location = 2) in vec3 fragWorldPos;

layout(location = 0) out vec4 outColor;

void main() {
    // flat white for now — toon ramp shader replaces this later
    // normal visualized as color so you can verify normals are correct
    vec3 normal_color = fragNormal * 0.5 + 0.5;
    outColor = vec4(normal_color, 1.0);
}
