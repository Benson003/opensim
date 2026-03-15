#version 450

// vertex buffer inputs
layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;

// outputs to fragment shader
layout(location = 0) out vec2 fragUV;
layout(location = 1) out vec3 fragNormal;
layout(location = 2) out vec3 fragWorldPos;

// MVP matrices pushed per object
layout(push_constant) uniform PushConstants {
    mat4 model;
    mat4 view;
    mat4 projection;
} push;

void main() {
    vec4 worldPos = push.model * vec4(inPosition, 1.0);
    gl_Position = push.projection * push.view * worldPos;
    fragUV = inUV;
    // transform normal into world space for lighting
    fragNormal = normalize(mat3(transpose(inverse(push.model))) * inNormal);
    fragWorldPos = worldPos.xyz;
}
