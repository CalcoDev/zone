#version 430

layout(location = 0) in vec4 vertexPosition;
layout(location = 1) in vec4 vertexColor;

layout(location = 0) uniform mat4 mvp;
layout(location = 1) uniform vec3 positions[100];

out vec4 fragColor;

void main() {
    gl_Position = mvp * vec4(vertexPosition.xyz + positions[gl_InstanceID], 1.0);
    fragColor = vertexColor;
}