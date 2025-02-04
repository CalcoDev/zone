#version 430

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec2 vertexTexcoord;

layout(location = 0) uniform mat4 mvp;

layout(binding = 0, std430) buffer PositionsBuffer {
    vec3 positions[];
};

out vec2 fragTexcoord;

void main() {
    gl_Position = mvp * vec4(vertexPosition + positions[gl_InstanceID], 1.0);
    fragTexcoord = vertexTexcoord;
}