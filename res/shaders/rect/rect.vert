#version 430

layout(location = 0) in vec4 vertexPosition;
layout(location = 1) in vec4 vertexColor;

uniform mat4 mvp;

out vec4 fragColor;

void main() {
    gl_Position = mvp * vertexPosition;
    fragColor = vertexColor;
}