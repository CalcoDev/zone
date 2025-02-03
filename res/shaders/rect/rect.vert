#version 430

layout(location = 0) in vec4 vertexPosition;
layout(location = 1) in vec4 vertexColor;

uniform mat4 mvp;
uniform vec2 positions[100];

out vec4 fragColor;

void main() {
    gl_Position = mvp * vertexPosition;
    // gl_Position = mvp * vec4(vertexPosition.xyz + vec3(positions[gl_InstanceID], 0.0), 1.0);
    // gl_Position = mvp * vec4(vertexPosition.xyz + vec3(positions[0], 0.0), 1.0);
    fragColor = vertexColor;
}