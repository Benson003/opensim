#version 450

layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec2 inUV;
layout(location = 2) in vec4 inColor;


layout(location = 0) out vec2  fragUV;
layout(location = 1) out vec4 fragColor;

layout(push_constant) uniform PushConstants {
    vec2 screenSize;
} push;

void main(){
    vec2 ndc = (inPosition / push.screenSize) * 2.0 - 1.0;
    gl_Position = vec4(ndc,0.0,1.0);

    fragUV = inUV;
    fragColor = inColor;
}
